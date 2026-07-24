---@module 'recommender.analyzers.python'
---Regex-based Python chain analyzer. Fast, no parser dependency.
---Mirrors analyzers/regex.lua (the Lua backend); the only difference is the
---rendered alias declaration — Python has no `local`/`const` keyword, so the
---suggestion is a plain `%s = %s` assignment.

local blacklist = require("recommender.blacklist")

local M = {}

---Extract all dotted chains from a single line.
---Collects 3-part chains first (e.g., os.path.join), then 2-part.
---@param line string
---@return string[]
local function extract_chains(line)
  local out = {}

  for c in line:gmatch("([%w_]+%.[%w_]+%.[%w_]+)") do
    out[#out + 1] = c
  end

  for c in line:gmatch("([%w_]+%.[%w_]+)") do
    out[#out + 1] = c
  end

  return require("lib.lua.tables").dedup_list(out)
end

---Analyze a buffer (or an explicit line list) and return alias suggestions.
---@param threshold integer
---@param custom_aliases table<string,string>
---@param bl string[]
---@param lines string[]|nil  Explicit lines to scan (e.g. concatenated project
---                            files for cwd scope); defaults to the current
---                            buffer's lines when omitted.
---@return {chain:string, count:integer, alias:string}[]
function M.analyze(threshold, custom_aliases, bl, lines)
  local counts = {}
  lines = lines or vim.api.nvim_buf_get_lines(0, 0, -1, false)

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
        alias = ("%s = %s"):format(custom_aliases[chain], chain)
      else
        local last = chain:match("([%w_]+)$")
        local var = last or chain:gsub("%.", "_")
        alias = ("%s = %s"):format(var, chain)
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
