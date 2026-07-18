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
