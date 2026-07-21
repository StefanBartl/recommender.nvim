---@module 'recommender.bindings'
---@brief Orchestrates recommender.nvim's bindings: usrcmds, keymaps, autocmds.
---@description
--- Always registers the `:Recommender` command. When `config.keymaps` is
--- true (the default) it also binds the global keymaps and labels the
--- `<leader>lr` group in which-key (no-op if not installed).

local M = {}

---Wire up every binding for the resolved config.
---@param cfg Recommender.Config
---@return nil
function M.setup(cfg)
  require("recommender.bindings.usrcmds").setup(cfg)

  if cfg.keymaps ~= false then
    require("recommender.bindings.keymaps").bind()
    require("recommender.bindings.which_key").setup()
  end

  require("recommender.bindings.autocmds").setup(cfg)
end

return M
