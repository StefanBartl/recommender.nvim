---@module 'recommender_nvim.util.notify'
---@brief Prefixed notification wrapper. Delegates to `lib.nvim.notify` when
---available (see `recommender_nvim.util.lib`), else a plain `vim.notify` wrapper.

local lib = require("recommender_nvim.util.lib")

local M = {}

---@param prefix string
---@return {info:fun(msg:string), warn:fun(msg:string), error:fun(msg:string), debug:fun(msg:string)}
function M.create(prefix)
  return lib.notifier(prefix)
end

return M
