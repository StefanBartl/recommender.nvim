---@module 'recommender.bindings.autocmds'
---@brief No plugin-level autocommands — kept as an empty module for structural symmetry.
---@description
--- recommender.nvim has no autocmd-driven activation (the `:Recommender`
--- command is the only entry point). The replace-mode `WinClosed` detector
--- is a per-invocation, dynamically registered autocmd — see
--- `recommender.float.autocmds`, not this module. This stub exists so
--- `bindings/` mirrors the usrcmds/keymaps/autocmds shape used across the
--- other plugins.

local M = {}

---@param _cfg Recommender.Config
---@return nil
function M.setup(_cfg) end

return M
