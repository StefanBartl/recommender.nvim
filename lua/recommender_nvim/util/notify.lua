---@module 'recommender_nvim.util.notify'
local M = {}

---@param prefix string
---@return {info:fun(msg:string), warn:fun(msg:string), error:fun(msg:string), debug:fun(msg:string)}
function M.create(prefix)
  local function emit(msg, level)
    vim.notify(prefix .. " " .. msg, level)
  end
  return {
    info  = function(msg) emit(msg, vim.log.levels.INFO) end,
    warn  = function(msg) emit(msg, vim.log.levels.WARN) end,
    error = function(msg) emit(msg, vim.log.levels.ERROR) end,
    debug = function(msg)
      if vim.g.recommender_nvim_debug then
        emit(msg, vim.log.levels.DEBUG)
      end
    end,
  }
end

return M
