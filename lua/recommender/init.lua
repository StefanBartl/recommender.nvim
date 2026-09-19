---@module 'recommender'
---recommender.nvim — Lua alias suggester for Neovim.
---
---Analyzes the current buffer for repeated dotted chains (vim.api, table.insert, …)
---and suggests local alias declarations. Two backends: regex (fast, no deps) and
---tree-sitter (precise, requires Lua parser).

local M = {}

---@type boolean
local _setup_done = false

---@param opts Recommender.Config|nil
---@return nil
function M.setup(opts)
  local cfg = require("recommender.config").setup(opts)

  if _setup_done then
    -- Registration (the :Recommender command, global keymaps, autocmds)
    -- happens once; re-running it on every setup() call would risk
    -- double-binding. The merge above still applies immediately, though:
    -- `cfg` is the same table bindings/usrcmds.lua captured on the first
    -- call (config.setup() mutates it in place, see ERR-53), so a changed
    -- analyzer/threshold/blacklist/float_keymaps/etc. takes effect on the
    -- very next :Recommender invocation. Only the global keymaps' actual
    -- key bindings stay as first configured.
    require("recommender.util.notify").create("[recommender]").info(
      "setup() called again — config re-merged and takes effect immediately; :Recommender and the global keymaps stay bound as first configured"
    )
    return
  end
  _setup_done = true

  require("recommender.bindings").setup(cfg)

  vim.g.loaded_recommender = 1
end

return M
