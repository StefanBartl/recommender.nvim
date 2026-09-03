---@module 'recommender.util.progress'
---@brief Thin, optional wrapper over `lib.nvim.progress` for `cwd`/`path`
---scope scans.
---@description
--- `lib.nvim` is already a hard dependency of this plugin as a whole (the
--- `:Recommender` command itself is registered via
--- `lib.nvim.bindings.usercmd.composer`, no raw-`nvim_create_user_command`
--- fallback — see `util/lib.lua`), but `lib.nvim.progress` specifically is
--- still probed with `pcall` here: an older `lib.nvim` checkout that
--- predates the progress module must only lose the indicator, not break
--- `:Recommender` itself.
---
--- Same convention as the rest of the StefanBartl/*.nvim ecosystem
--- (reposcope.nvim's `utils/progress.lua`, replacer.nvim's `rg.lua`,
--- documentation.nvim's `bindings/progress.lua`): one `create()` per
--- operation, style read from `config.progress_style` at call time so
--- `setup()` ordering never matters, `nil` returned (never an error) when
--- `lib.nvim.progress` isn't available — every call site guards with
--- `if handle then`.

local M = {}

local ok_progress, progress_mod = pcall(require, "lib.nvim.progress")

---Create a progress handle for a `cwd`/`path` scope scan, or `nil` when
---`lib.nvim.progress` isn't available.
---@param style string|nil  "auto"|"notify"|"statusline"|"fidget"|"float"|"kit" (`config.progress_style`)
---@return table|nil
function M.create(style)
  if not ok_progress then
    return nil
  end
  return progress_mod.create({ title = "[recommender]", style = style or "auto" })
end

---Whether `lib.nvim.progress` is available (for `:checkhealth recommender`).
---@return boolean
function M.available()
  return ok_progress
end

return M
