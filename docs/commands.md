# Commands

## The `:Recommender` command

```vim
:Recommender                       " use configured defaults (buffer scope)
:Recommender treesitter            " override analyzer
:Recommender regex 5               " regex, threshold 5 (positional, inferred)
:Recommender regex --threshold=5   " the same, said explicitly
:Recommender -t 5                  " short form
:Recommender treesitter 4 -r       " treesitter, threshold 4, replace mode
:Recommender javascript            " JS/TS regex analyzer
:Recommender python 4              " Python regex analyzer, threshold 4
:Recommender perf 1                " perf anti-pattern analyzer, every instance
:Recommender -r                    " replace mode with defaults
:Recommender cwd                   " project-wide scope
:Recommender -c                    " same as above (backward-compat flag)
:Recommender path                  " scope to the current file's directory
:Recommender cfile                 " scope to the file named under the cursor
:Recommender line                  " scope to the current line only
:Recommender cwd javascript 5      " cwd scope, JS/TS analyzer, threshold 5
```

The command is a **toggle** — running it while the float is open closes it.

Tab-completion is available for `regex`, `treesitter`, `javascript`,
`python`, `perf`, `buffer`, `path`, `cwd`, `cfile`, `line`, `-r`, `--replace`,
`-c`, `--cwd`.

`perf` is a different kind of analyzer — it flags Lua performance
anti-patterns with a measured benefit (not dotted-chain repetition). See
[Features](FEATURES.md#perf-analyzer-analyzer--perf) for the four patterns
it looks for and why the others don't have one.

Built via `lib.nvim.bindings.usercmd.composer`: a single flat root route (no
subcommand word) with `-r`/`--replace` and `-c`/`--cwd` declared as
short-flag aliases, plus three optional positional slots. Any of the three
may hold an analyzer name, a scope name, or a threshold number, in any
order — `:Recommender cwd javascript 5` and `:Recommender 5 javascript cwd`
resolve identically, since positional tokens are classified by content, not
by slot. An undeclared `--flag` is a hard error (an undeclared `-x` still
stays a lenient positional, same as before).

## Scopes

`{scope}` is an optional positional value: `buffer` (default) | `path` |
`cwd` | `cfile` | `line`. Pressing `Enter`/`A` always inserts into the
**buffer that was active when `:Recommender` was invoked**, regardless of
scope — scope only changes where chains are *counted*.

  `buffer` (default)  Analyzes only the current buffer's in-memory content.

  `cwd`               Scans every file under the working directory matching
                       the active analyzer's extensions (`regex`/`treesitter`
                       → `*.lua`, `javascript` → `*.js`/`*.jsx`/`*.ts`/`*.tsx`,
                       `python` → `*.py`), reads them from disk, and
                       aggregates chain counts across **all** of them —
                       surfaces chains that repeat throughout a whole project
                       even if no single file crosses the threshold alone.
                       `-c`/`--cwd` is a backward-compatible flag alias for
                       this scope; an explicit scope positional always wins
                       over it.

  `path`              Same scan as `cwd`, but rooted at the **current
                       buffer's own directory** instead of the working
                       directory — useful for a subtree scan without
                       changing `cwd`. Requires the current buffer to have a
                       file path (errors on an unnamed buffer).

  `cfile`              Scans a **single file**: whichever file is named
                       under the cursor (`<cfile>`), resolved as typed, then
                       relative to the current buffer's directory, then via
                       Vim's `'path'` option — the same resolution order
                       `gf` effectively relies on. Errors if nothing
                       file-like is under the cursor, or the resolved file
                       isn't readable.

  `line`               Scans only the current line. Each analyzer dedups a
                       chain to at most one hit per line scanned (see
                       [Architecture](architecture.md)), so a 1-line scan
                       maxes out at count `1` per chain — the threshold
                       therefore defaults to `1` for this scope specifically
                       (not `config.threshold`) unless you pass an explicit
                       `{threshold}` token.

Only the regex-based analyzers (`regex`, `javascript`, `python`, `perf`)
support any non-`buffer` scope — `treesitter` parses a live Neovim buffer's
syntax tree, not raw file text, so combining it with
`path`/`cwd`/`cfile`/`line` is a hard error naming the supported analyzers
instead.

`cwd` and `path` share two config keys that tune the scan (see
[Configuration](configuration.md)): `cwd_ignore` (directory names skipped at
any depth; defaults cover `.git`, `node_modules`, `.venv`, etc.) and
`cwd_max_files` (safety cap, default `500`; `0` = unbounded). If the cap is
hit, a warning names the config key to raise.

Both scans run asynchronously — walking the directory tree and reading the
matching files never blocks Neovim, no matter how many files are involved.
`progress_style` (default `"auto"`) shows an indicator while it runs; see
[Configuration](configuration.md#async-cwdpath-scanning).

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

For `analyzer = "perf"`, "alias" above means the pattern's advisory
`-- perf: ...` comment, not a `local` declaration — see
[Features](FEATURES.md#perf-analyzer-analyzer--perf).

## Replace mode

Enabled with the `-r` / `--replace` flag. When replace mode is active, pressing `Enter` on a suggestion:

1. Runs `:Replace <chain> <alias> %` to substitute all occurrences in the buffer.
2. After the replace completes, inserts the `local alias = chain` declaration.

**Requires** a `:Replace` user command to be available (e.g., from a surround/replace plugin). [replacer.nvim](https://github.com/StefanBartl/replacer.nvim) provides one.

The detection of "replace finished" is event-driven — a one-shot `WinClosed` autocmd watches for the `TelescopePrompt` window closing. No polling, no timers, no race conditions.
