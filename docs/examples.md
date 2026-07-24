# Examples

## Suggesting aliases

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

## Compact float layout

Same buffer, with `float_layout = "compact"`:

```
╭─ Recommender: 2 suggestions ──────────────────────────╮
│                                                        │
│ → vim.api (6)  local api = vim.api                     │
│ → table.insert (3)  local tbl_insert = table.insert    │
╰────────────────────────────────────────────────────────╯
```

One line per suggestion instead of three — useful when `threshold` is low
and a buffer or [project-wide scan](commands.md#project-wide--c----cwd-scope)
surfaces many suggestions at once. Navigation (`j`/`k`) and every other float
keymap work identically in both layouts.
