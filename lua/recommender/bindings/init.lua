---@module 'recommender.bindings'
---@brief Orchestrates recommender.nvim's bindings: usrcmds, keymaps, autocmds.
---@description
--- Always registers the `:Recommender` command. `config.keymaps` decides what
--- happens to the global keys: `true`/`nil` takes the defaults, `false` binds
--- nothing, and a table overrides individual actions. Labelling the
--- `<leader>lr` group in which-key comes with declaring them.

local M = {}

---Wire up every binding for the resolved config.
---@param cfg Recommender.Config
---@return nil
function M.setup(cfg)
  require("recommender.bindings.usrcmds").setup(cfg)

  -- The registry handles `false` and the per-action overrides itself, and
  -- puts the which-key group label up as part of declaring the preset.
  require("recommender.bindings.keymaps").bind(cfg.keymaps)

  require("recommender.bindings.autocmds").setup(cfg)
end

return M
