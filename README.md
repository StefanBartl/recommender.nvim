# recommender.nvim

```
  ___                                              _
 | _ \___  __ ___ _ __  _ __  ___ _ _  __| |___ _ _
 |   / -_)/ _/ _ \ '  \| '  \/ -_) ' \/ _` / -_) '_|
 |_|_\___|\__\___/_|_|_|_|_|_\___|_||_\__,_\___|_|
              nvim
```

![version](https://img.shields.io/badge/version-0.1.0-blue.svg)
![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-success.svg)
![Lua](https://img.shields.io/badge/language-Lua-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

Analyzes the current Lua buffer for frequently repeated dotted chains (`vim.api`, `table.insert`, …) and suggests `local` alias declarations in an interactive floating window. Pure Neovim — no external dependencies.

---

## Features

| Feature | Description |
|---------|-------------|
| **Two analyzers** | `regex` (fast, always works) and `treesitter` (precise, requires Lua parser) |
| **Interactive float** | Navigate suggestions, insert, yank, or insert all at once |
| **Replace mode** | After inserting an alias, auto-replaces all occurrences via `:Replace` |
| **Per-buffer ignore** | Dismiss individual suggestions for the session without losing others |
| **Prefix blacklist** | Block entire namespaces (`"vim.fn"` blocks all `vim.fn.*`) |
| **Custom alias map** | Override the generated name for any chain |
| **Syntax highlighting** | Chain, alias, and count are colored distinctly in the float |
| **Zero global pollution** | Nothing registered globally; keymaps are opt-out |

---

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| Neovim | **>= 0.9** | core |
| Lua Tree-sitter parser | optional | needed for `analyzer = "treesitter"` |

---

## Installation

### lazy.nvim

```lua
{
  "StefanBartl/recommender.nvim",
  ft  = { "lua" },
  cmd = { "Recommender" },
  config = function()
    require("recommender_nvim").setup()
  end,
}
```

### Local development

```lua
{
  dir = "E:/repos/recommender.nvim",
  ft  = { "lua" },
  cmd = { "Recommender" },
  config = function()
    require("recommender_nvim").setup()
  end,
}
```

---

## Configuration

```lua
require("recommender_nvim").setup({
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

### Default global keymaps

Installed when `keymaps = true` (the default):

| Key | Command | Description |
|-----|---------|-------------|
| `<leader>lr`  | `:Recommender`              | Open with configured defaults |
| `<leader>lR`  | `:Recommender -r`           | Open in replace mode |
| `<leader>lrr` | `:Recommender regex`        | Force regex analyzer |
| `<leader>lrt` | `:Recommender treesitter`   | Force treesitter analyzer |
| `<leader>lrh` | `:Recommender regex 5`      | Regex, threshold 5 (large files) |

---

## Usage

### Command

```vim
:Recommender                       " use configured defaults
:Recommender treesitter            " override analyzer
:Recommender regex 5               " regex, threshold 5
:Recommender treesitter 4 -r       " treesitter, threshold 4, replace mode
:Recommender -r                    " replace mode with defaults
```

The command is a **toggle** — running it while the float is open closes it.

Tab-completion is available for `regex`, `treesitter`, `-r`, `--replace`.

### Float window keymaps

| Key | Action |
|-----|--------|
| `j` / `↓` | Next suggestion |
| `k` / `↑` | Previous suggestion |
| `Enter` | Insert selected alias into source buffer |
| `y` | Yank selected alias to system clipboard (`+`/`*`) |
| `A` | Insert **all** visible aliases at once |
| `Backspace` | Ignore this entry for the session |
| `U` | Un-ignore all — restore dismissed suggestions |
| `q` / `Esc` | Close |
| `?` | Show keymap help |

---

## Replace mode (`-r` / `--replace`)

When replace mode is active, pressing `Enter` on a suggestion:

1. Runs `:Replace <chain> <alias> %` to substitute all occurrences in the buffer.
2. After the replace completes, inserts the `local alias = chain` declaration.

**Requires** a `:Replace` user command to be available (e.g., from a surround/replace plugin).

The detection of "replace finished" is event-driven — a one-shot `WinClosed` autocmd watches for the `TelescopePrompt` window closing. No polling, no timers, no race conditions.

---

## Example

**Buffer before:**

```lua
vim.api.nvim_create_user_command("Foo", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  table.insert(results, vim.api.nvim_get_current_buf())
  table.insert(results, vim.api.nvim_list_bufs())
  table.insert(results, vim.api.nvim_get_current_win())
end, {})
```

**Float shows:**

```
╭─ Recommender: 2 suggestions ──────────╮
│                                        │
│ → vim.api (6 hits)                     │
│   local api = vim.api                  │
│                                        │
│ → table.insert (3 hits)                │
│   local tbl_insert = table.insert      │
│                                        │
╰────────────────────────────────────────╯
```

Press `A` to insert both aliases at once, then use your preferred replace workflow.

---

## Architecture

```
lua/recommender_nvim/
  init.lua              setup() entry point; :Recommender command; global keymaps
  config.lua            option merging and defaults
  rendering.lua         float window open/close/highlight
  keymaps.lua           buffer-local keymaps for the float
  autocmds.lua          one-shot WinClosed hook for replace-mode finish detection
  blacklist.lua         prefix matching + default blacklist
  custom_aliases.lua    built-in alias map
  analyzers/
    regex.lua           regex-based chain counter
    treesitter.lua      tree-sitter-based chain counter
  util/
    notify.lua          vim.notify wrapper
plugin/
  recommender_nvim.lua  loaded-guard
doc/
  recommender.nvim.txt  :h recommender.nvim
```

### Design principles

- **No lib.* dependencies** — fully self-contained.
- **Lazy analyzer loading** — `treesitter.lua` is only required when first used.
- **Per-buffer ignore state** — ignores are stored by bufnr, not globally.
- **No deprecated API** — uses `vim.bo` / `vim.wo` throughout.
- **Toggle pattern** — `:Recommender` while open closes the float; no extra close command.

---

## License

MIT
