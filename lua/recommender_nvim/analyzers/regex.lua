---@module 'recommender_nvim.analyzers.regex'
---Regex-based Lua chain analyzer. Fast, no parser dependency.

local blacklist = require("recommender_nvim.blacklist")

local M = {}

---Extract all dotted chains from a single line.
---Collects 3-part chains first (e.g., vim.api.nvim_*), then 2-part.
---@param line string
---@return string[]
local function extract_chains(line)
  local out, seen = {}, {}

  for c in line:gmatch("([%w_]+%.[%w_]+%.[%w_]+)") do
    if not seen[c] then
      out[#out + 1] = c
      seen[c] = true
    end
  end

  for c in line:gmatch("([%w_]+%.[%w_]+)") do
    if not seen[c] then
      out[#out + 1] = c
      seen[c] = true
    end
  end

  return out
end

---Analyze the current buffer and return alias suggestions.
---@param threshold integer
---@param custom_aliases table<string,string>
---@param bl string[]
---@return {chain:string, count:integer, alias:string}[]
function M.analyze(threshold, custom_aliases, bl)
  local api = vim.api
  local counts = {}
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)

  for _, line in ipairs(lines) do
    for _, chain in ipairs(extract_chains(line)) do
      if not blacklist.is_blacklisted(chain, bl) then
        counts[chain] = (counts[chain] or 0) + 1
      end
    end
  end

  local res = {}
  for chain, count in pairs(counts) do
    if count >= threshold then
      local alias
      if custom_aliases and custom_aliases[chain] then
        alias = ("local %s = %s"):format(custom_aliases[chain], chain)
      else
        local last = chain:match("([%w_]+)$")
        local var = last or chain:gsub("%.", "_")
        alias = ("local %s = %s"):format(var, chain)
      end
      res[#res + 1] = { chain = chain, count = count, alias = alias }
    end
  end

  table.sort(res, function(a, b)
    return a.count > b.count
  end)
  return res
end

return M
