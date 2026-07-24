# Features

| Feature | Description |
|---------|-------------|
| **Four analyzers** | `regex`/`treesitter` for Lua (treesitter requires the Lua parser), plus regex-based `javascript` (JS/TS) and `python` backends |
| **Interactive float** | Navigate suggestions, insert, yank, or insert all at once |
| **Replace mode** | After inserting an alias, auto-replaces all occurrences via `:Replace` |
| **Per-buffer ignore** | Dismiss individual suggestions for the session without losing others |
| **Prefix blacklist** | Block entire namespaces (`"vim.fn"` blocks all `vim.fn.*`) |
| **Custom alias map** | Override the generated name for any chain |
| **Syntax highlighting** | Chain, alias, and count are colored distinctly in the float |
| **Zero global pollution** | Nothing registered globally; keymaps are opt-out |
