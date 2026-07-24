# Features

| Feature | Description |
|---------|-------------|
| **Four analyzers** | `regex`/`treesitter` for Lua (treesitter requires the Lua parser), plus regex-based `javascript` (JS/TS) and `python` backends |
| **Project-wide scope** | `-c`/`--cwd` aggregates chain counts across every matching file under the cwd instead of just the current buffer |
| **Interactive float** | Navigate suggestions, insert, yank, or insert all at once |
| **Replace mode** | After inserting an alias, auto-replaces all occurrences via `:Replace` |
| **Per-buffer ignore** | Dismiss individual suggestions for the session without losing others |
| **Prefix blacklist** | Block entire namespaces (`"vim.fn"` blocks all `vim.fn.*`) |
| **Custom alias map** | Override the generated name for any chain |
| **Syntax highlighting** | Chain, alias, and count are colored distinctly in the float |
| **Configurable float layout** | `float_layout = "detailed"` (default, 3 lines/suggestion) or `"compact"` (1 line/suggestion) |
| **Zero global pollution** | Nothing registered globally; keymaps are opt-out |
