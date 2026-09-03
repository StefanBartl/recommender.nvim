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
  -- Indicator while a `cwd`/`path` scope scan reads files asynchronously —
  -- "auto" (notify, or fidget.nvim if installed), "notify", "statusline"
  -- (read lib.nvim.progress.styles.statusline from your own statusline),
  -- "fidget", "float", or "kit". Needs lib.nvim.progress; no-op without it.
  -- Buffer/cfile/line scope never shows one -- reading a single buffer or
  -- file is fast enough that an indicator would only flash.
  progress_style = "auto",
  -- Float window layout: "detailed" (chain / alias / blank, 3 lines each) or
  -- "compact" (one line per suggestion).
  float_layout = "detailed",
  -- Keys inside the suggestion float: true = defaults, false = none, or a
  -- table of per-action overrides (see Recommender.FloatKeymaps).
  float_keymaps = true,
}

return DEFAULTS
