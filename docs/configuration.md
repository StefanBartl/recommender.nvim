# Configuration

```lua
require("recommender").setup({
  -- Analyzer backend
  analyzer = "regex",           -- "regex" | "treesitter"

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
})
```

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
| `<leader>lrh` | `:Recommender regex 5`      | Regex, threshold 5 (large files) |
