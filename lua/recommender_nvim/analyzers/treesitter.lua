---@module 'recommender_nvim.analyzers.treesitter'
---Tree-sitter-based Lua chain analyzer. More precise than regex; requires the Lua parser.

local blacklist = require("recommender_nvim.blacklist")

local M = {}

local ts = vim.treesitter

---@param node TSNode
---@param src string
---@return string|nil
local function node_text(node, src)
  local ok, t = pcall(ts.get_node_text, node, src)
  return ok and t or nil
end

---Collect all dotted chains from the buffer via Tree-sitter.
---@param bufnr integer
---@param bl string[]
---@return string[]
local function collect_chains(bufnr, bl)
  local ok_parser, parser = pcall(ts.get_parser, bufnr, "lua")
  if not ok_parser or not parser then
    return {}
  end

  local ok_parse, trees = pcall(parser.parse, parser)
  if not ok_parse or not trees or #trees == 0 then
    return {}
  end

  local root = trees[1]:root()
  local src = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

  local ok_q, query = pcall(
    ts.query.parse,
    "lua",
    [[
    (field_expression) @field
    (call_expression function: (field_expression) @call)
  ]]
  )
  if not ok_q then
    return {}
  end

  local chains = {}
  for _, match in query:iter_matches(root, bufnr) do
    for _, node in pairs(match) do
      ---@cast node TSNode
      local val = node_text(node, src)
      if val and val:match("^[%w_]+%.[%w_]+") then
        if not blacklist.is_blacklisted(val, bl) then
          chains[#chains + 1] = val
        end
      end
    end
  end

  return chains
end

---Find the longest common prefix shared by all chains (min depth 2).
---@param chains string[]
---@return string|nil
local function common_prefix(chains)
  if #chains == 0 then
    return nil
  end

  local parts = vim.split(chains[1], ".", { plain = true })
  local depth = #parts

  for i = 2, #chains do
    local p = vim.split(chains[i], ".", { plain = true })
    depth = math.min(depth, #p)
    for j = 1, depth do
      if parts[j] ~= p[j] then
        depth = j - 1
        break
      end
    end
  end

  if depth < 2 then
    return nil
  end
  return table.concat(parts, ".", 1, depth)
end

---Analyze the current buffer and return alias suggestions.
---@param threshold integer
---@param custom_aliases table<string,string>
---@param bl string[]
---@return {chain:string, count:integer, alias:string}[]
function M.analyze(threshold, custom_aliases, bl)
  local bufnr = vim.api.nvim_get_current_buf()
  local counts = {}

  for _, chain in ipairs(collect_chains(bufnr, bl)) do
    counts[chain] = (counts[chain] or 0) + 1
  end

  local filtered = {}
  for chain, count in pairs(counts) do
    if count >= threshold then
      filtered[#filtered + 1] = { chain = chain, count = count }
    end
  end

  if #filtered == 0 then
    return {}
  end

  local chain_names = {}
  for _, v in ipairs(filtered) do
    chain_names[#chain_names + 1] = v.chain
  end
  local prefix = common_prefix(chain_names)

  local out = {}
  for _, item in ipairs(filtered) do
    local alias
    if custom_aliases and custom_aliases[item.chain] then
      alias = ("local %s = %s"):format(custom_aliases[item.chain], item.chain)
    elseif prefix and item.chain:sub(1, #prefix) == prefix then
      local name = prefix:match("([%w_]+)$")
      alias = ("local %s = %s"):format(name, prefix)
    else
      local last = item.chain:match("([%w_]+)$")
      alias = ("local %s = %s"):format(last, item.chain)
    end
    out[#out + 1] = { chain = item.chain, count = item.count, alias = alias }
  end

  table.sort(out, function(a, b)
    return a.count > b.count
  end)
  return out
end

return M
