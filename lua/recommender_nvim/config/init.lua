---@module 'recommender_nvim.config'
---@brief Runtime configuration store for recommender.nvim.
---@description
--- Merges user options over the immutable DEFAULTS and exposes the active
--- config via `get()`. No global state — the active table is module-local.

local DEFAULTS = require("recommender_nvim.config.DEFAULTS")

local M = {}

---@type Recommender.Config|nil
local _active = nil

---Merge user options over the defaults and store the result.
---@param opts Recommender.Config|nil
---@return Recommender.Config
function M.setup(opts)
  _active = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {})
  return _active
end

---@return Recommender.Config
function M.get()
  if _active == nil then
    _active = vim.deepcopy(DEFAULTS)
  end
  return _active
end

return M
