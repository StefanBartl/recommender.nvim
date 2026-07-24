# Configuration

```lua
require("recommender").setup({
  -- Analyzer backend
  analyzer = "regex",           -- "regex" | "treesitter" | "javascript" | "python"

  -- Minimum occurrences before a chain is suggested
  threshold = 3,

  -- Chain → preferred alias name (built-in defaults shown; extend or override)
  custom_aliases = {
    ["vim.api"]        = "api",
    ["vim.fn"]         = "fn",
    ["vim.keymap.set"] = "km_set",
    ["table.insert"]   = "tbl_insert",
    ["string.format"]  = "str_fmt",
    -- …
  },

  -- Prefix-matched chains that are NEVER suggested
  blacklist = {
    -- "vim.fn",      -- blocks vim.fn, vim.fn.expand, etc.
    -- "table.insert",
  },

  -- Install default global keymaps (set false to manage keymaps yourself)
  keymaps = true,

  -- Directory names skipped (any depth) by `:Recommender --cwd` scans
  cwd_ignore = { ".git", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".next", "target", ".tox" },

  -- Safety cap on files read by a `--cwd` scan (0 = unbounded)
  cwd_max_files = 500,

  -- Float window layout: "detailed" (chain / alias / blank, 3 lines each)
  -- or "compact" (one line per suggestion)
  float_layout = "detailed",
})
```

## Float layout

`float_layout = "detailed"` (default) shows each suggestion across 3 lines
(chain + hit count, the alias declaration, a blank separator) — see
[Examples](examples.md). Set `float_layout = "compact"` for one line per
suggestion instead: `→ chain.name (N)  alias-declaration`. Both layouts
share the same float keymaps ([Commands](commands.md#float-window-keymaps));
`j`/`k` navigate suggestion-by-suggestion either way.

## Default global keymaps

Installed when `keymaps = true` (the default). which-key (if installed) labels
the `<leader>lr` group automatically — no extra config needed. Full cheatsheet:
[BINDINGS.md](BINDINGS.md).

| Key | Command | Description |
|-----|---------|-------------|
| `<leader>lr`  | `:Recommender`              | Open with configured defaults |
| `<leader>lR`  | `:Recommender -r`           | Open in replace mode |
| `<leader>lrr` | `:Recommender regex`        | Force regex analyzer |
| `<leader>lrt` | `:Recommender treesitter`   | Force treesitter analyzer |
| `<leader>lrj` | `:Recommender javascript`   | Force JS/TS regex analyzer |
| `<leader>lrp` | `:Recommender python`       | Force Python regex analyzer |
| `<leader>lrh` | `:Recommender regex 5`      | Regex, threshold 5 (large files) |
| `<leader>lrc` | `:Recommender -c`           | Project-wide (cwd) scope — see [Commands](commands.md#project-wide--c----cwd-scope) |
