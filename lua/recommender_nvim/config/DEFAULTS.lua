---@module 'recommender_nvim.config.DEFAULTS'
---@brief Immutable default configuration for recommender.nvim.
---@description
--- Single source of truth. `config/init.lua` deep-merges user options over a
--- copy of this table, so it is never mutated at runtime.

---@type Recommender.Config
local DEFAULTS = {
  analyzer = "regex",
  threshold = 3,
  custom_aliases = require("recommender_nvim.custom_aliases"),
  blacklist = require("recommender_nvim.blacklist").default,
  keymaps = true,
}

return DEFAULTS
