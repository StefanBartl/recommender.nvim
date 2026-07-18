# Commands

## The `:Recommender` command

```vim
:Recommender                       " use configured defaults
:Recommender treesitter            " override analyzer
:Recommender regex 5               " regex, threshold 5
:Recommender treesitter 4 -r       " treesitter, threshold 4, replace mode
:Recommender -r                    " replace mode with defaults
```

The command is a **toggle** — running it while the float is open closes it.

Tab-completion is available for `regex`, `treesitter`, `-r`, `--replace`.

## Float window keymaps

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

## Replace mode

Enabled with the `-r` / `--replace` flag. When replace mode is active, pressing `Enter` on a suggestion:

1. Runs `:Replace <chain> <alias> %` to substitute all occurrences in the buffer.
2. After the replace completes, inserts the `local alias = chain` declaration.

**Requires** a `:Replace` user command to be available (e.g., from a surround/replace plugin). [replacer.nvim](https://github.com/StefanBartl/replacer.nvim) provides one.

The detection of "replace finished" is event-driven — a one-shot `WinClosed` autocmd watches for the `TelescopePrompt` window closing. No polling, no timers, no race conditions.
