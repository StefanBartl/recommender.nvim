---@meta
---@module 'recommender.@types'
---@brief Type definitions for recommender.nvim.
---@description
--- Central type catalog so the source files stay free of long annotation
--- blocks. All `@types` modules return an empty table.

---@class Recommender.Config
---@field analyzer?       "regex"|"treesitter"|"javascript"|"python"|"perf"  Analyzer backend (default: "regex")
---@field threshold?      integer               Min occurrences before a chain is suggested (default: 3)
---@field custom_aliases? table<string,string>  Chain -> preferred alias name override
---@field blacklist?      string[]              Prefix-blocked chains (never suggested)
---@field keymaps?        boolean|Recommender.Keymaps  Global keymaps: `true`/`nil` defaults, `false` none, or per-action overrides (default: true)
---@field cwd_ignore?     string[]              Directory names skipped (any depth) by `cwd`/`path` scope scans
---@field cwd_max_files?  integer               Cap on files read by `cwd`/`path` scope scans (default: 500; 0 = unbounded)
---@field float_layout?   "detailed"|"compact"  Float window layout (default: "detailed")
---@field float_keymaps?  boolean|Recommender.FloatKeymaps  Keys inside the suggestion float (default: true)

--- Per-action overrides for the global keys. Each is an lhs, a list of them,
--- or `false` to drop that one; anything unset keeps its default.
---@class Recommender.Keymaps
---@field run?            string|string[]|false  default `<leader>lr`
---@field replace?        string|string[]|false  default `<leader>lR`
---@field regex?          string|string[]|false  default `<leader>lrr`
---@field treesitter?     string|string[]|false  default `<leader>lrt`
---@field javascript?     string|string[]|false  default `<leader>lrj`
---@field python?         string|string[]|false  default `<leader>lrp`
---@field high_threshold? string|string[]|false  default `<leader>lrh`
---@field cwd?            string|string[]|false  default `<leader>lrc`

--- Per-action overrides for the buffer-local keys inside the float. Navigation
--- (`j`/`k`/arrows), `<CR>` and `q`/`<Esc>` belong to lib.nvim's chooser and
--- are not listed here.
---@class Recommender.FloatKeymaps
---@field yank?       string|string[]|false  default `y`
---@field insert_all? string|string[]|false  default `A`
---@field ignore?     string|string[]|false  default `<BS>`
---@field unignore?   string|string[]|false  default `U`
---@field help?       string|string[]|false  default `?`

---@class Recommender.Suggestion
---@field chain string   Dotted chain (e.g. "vim.api"), or a fixed pattern key for analyzer = "perf" (e.g. "table.insert(...)")
---@field count integer  Occurrence count in the scanned scope
---@field alias string   Rendered "local <name> = <chain>" declaration, or (for "perf") an advisory "-- perf: ..." comment

return {}
