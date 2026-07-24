# Commands

## The `:Recommender` command

```vim
:Recommender                       " use configured defaults
:Recommender treesitter            " override analyzer
:Recommender regex 5               " regex, threshold 5
:Recommender treesitter 4 -r       " treesitter, threshold 4, replace mode
:Recommender javascript            " JS/TS regex analyzer
:Recommender python 4              " Python regex analyzer, threshold 4
:Recommender -r                    " replace mode with defaults
:Recommender -c                    " project-wide (cwd) scope
:Recommender -c javascript 5       " cwd scope, JS/TS analyzer, threshold 5
```

The command is a **toggle** — running it while the float is open closes it.

Tab-completion is available for `regex`, `treesitter`, `javascript`, `python`, `-r`, `--replace`, `-c`, `--cwd`.

Built via `lib.nvim.usercmd.composer`: a single flat root route (no
subcommand word) with `-r`/`--replace` and `-c`/`--cwd` declared as
short-flag aliases. Dispatch is unchanged; an undeclared `--flag` is now a
hard error (an undeclared `-x` still stays a lenient positional, same as
before).

## Project-wide (`-c` / `--cwd`) scope

By default `:Recommender` analyzes only the current buffer. With `-c` /
`--cwd`, it instead scans every file under the working directory that
matches the active analyzer's extensions (`regex`/`treesitter` → `*.lua`,
`javascript` → `*.js`/`*.jsx`/`*.ts`/`*.tsx`, `python` → `*.py`), reads them
from disk, and aggregates chain counts across **all** of them before
applying the threshold. This surfaces chains that repeat throughout a whole
project even if no single file crosses the threshold on its own.

Pressing `Enter`/`A` still inserts into the **current buffer** — cwd scope
only changes where chains are *counted*, not where the alias is written.

Only the regex-based analyzers support `-c` — `treesitter` parses a live
Neovim buffer's syntax tree, not raw file text, so combining `-c` with
`treesitter` is a hard error telling you to pick `regex`, `javascript`, or
`python` instead.

Two config keys tune the scan (see [Configuration](configuration.md)):
`cwd_ignore` (directory names skipped at any depth; defaults cover `.git`,
`node_modules`, `.venv`, etc.) and `cwd_max_files` (safety cap, default
`500`; `0` = unbounded). If the cap is hit, a warning names the config key
to raise.

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
