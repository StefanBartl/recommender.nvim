---@module 'recommender_nvim.blacklist'

local M = {}

---Default blacklist entries (empty — users opt-in via setup).
M.default = {}

---Check if a chain is blacklisted using prefix matching.
---A blacklist entry of "vim.api" blocks "vim.api", "vim.api.nvim_buf_get_lines", etc.
---@param chain string
---@param blacklist string[]
---@return boolean
function M.is_blacklisted(chain, blacklist)
  if not blacklist or #blacklist == 0 then
    return false
  end
  for _, prefix in ipairs(blacklist) do
    if chain:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

return M
