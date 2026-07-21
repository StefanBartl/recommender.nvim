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
  if _setup_done then
    return
  end
  _setup_done = true

  local cfg_mod = require("recommender.config")
  local cfg = cfg_mod.setup(opts)

  require("recommender.bindings").setup(cfg)

  vim.g.loaded_recommender = 1
end

return M
