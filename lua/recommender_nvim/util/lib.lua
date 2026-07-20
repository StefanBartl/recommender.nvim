---@module 'recommender_nvim.util.lib'
---@brief Soft, guarded bridge to the optional `lib.nvim` helper library.
---@description
--- recommender.nvim prefers `lib.nvim.notify` / `lib.nvim.map` when present,
--- and every accessor here probes the corresponding module with `pcall` and
--- falls back to the native Neovim API — no hard dependency on THESE specific
--- helpers is ever introduced. `lib.nvim` as a whole, however, IS a hard
--- dependency since the composer migration: `:Recommender` itself is
--- registered via `lib.nvim.usercmd.composer` (`bindings/usrcmds.lua`), with
--- no raw-`nvim_create_user_command` fallback. See `docs/installation.md`.

local M = {}

---@param name string
---@return table|nil
local function try_require(name)
  local ok, mod = pcall(require, name)
  if ok and type(mod) == "table" then
    return mod
  end
  return nil
end

---Prefixed notifier. Uses `lib.nvim.notify` if available, else `vim.notify`.
---@param prefix string
---@return {info:fun(msg:string), warn:fun(msg:string), error:fun(msg:string), debug:fun(msg:string)}
function M.notifier(prefix)
  local lib_notify = try_require("lib.nvim.notify")
  if lib_notify and type(lib_notify.create) == "function" then
    local ok, notifier = pcall(lib_notify.create, prefix)
    if ok and type(notifier) == "table" then
      return notifier
    end
  end

  local function emit(msg, level)
    vim.notify(prefix .. " " .. msg, level)
  end
  return {
    info = function(msg)
      emit(msg, vim.log.levels.INFO)
    end,
    warn = function(msg)
      emit(msg, vim.log.levels.WARN)
    end,
    error = function(msg)
      emit(msg, vim.log.levels.ERROR)
    end,
    debug = function(msg)
      if vim.g.recommender_nvim_debug then
        emit(msg, vim.log.levels.DEBUG)
      end
    end,
  }
end

---Set a keymap. Uses `lib.nvim.map` if available, else `vim.keymap.set`.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts table|nil
---@return nil
function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  local ok, lib_map = pcall(require, "lib.nvim.map")
  if ok and type(lib_map) == "function" then
    local desc = opts.desc
    opts.desc = nil
    local mapped = pcall(lib_map, mode, lhs, rhs, opts, desc)
    if mapped then
      return
    end
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

---Whether lib.nvim is installed (for :checkhealth reporting).
---@return boolean
function M.available()
  return try_require("lib.nvim.notify") ~= nil
end

return M
