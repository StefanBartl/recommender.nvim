---@module 'recommender.config.DEFAULTS'
---@brief Immutable default configuration for recommender.nvim.
---@description
--- Single source of truth. `config/init.lua` deep-merges user options over a
--- copy of this table, so it is never mutated at runtime.

---@type Recommender.Config
local DEFAULTS = {
  analyzer = "regex",
  threshold = 3,
  custom_aliases = require("recommender.custom_aliases"),
  blacklist = require("recommender.blacklist").default,
  keymaps = true,
  -- Directory names skipped (at any depth) during `:Recommender --cwd` scans.
  cwd_ignore = { ".git", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".next", "target", ".tox" },
  -- Safety cap on the number of files a `--cwd` scan reads; 0 = unbounded.
  cwd_max_files = 500,
  -- Float window layout: "detailed" (chain / alias / blank, 3 lines each) or
  -- "compact" (one line per suggestion).
  float_layout = "detailed",
}

return DEFAULTS
