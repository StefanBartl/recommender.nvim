# Features

Analyzes a buffer (or a whole project) for dotted chains repeated often
enough to be worth aliasing, and lets you act on the suggestions without
leaving the float.

## Four analyzer backends

`regex` and `treesitter` both target Lua; `javascript` and `python` are
separate regex-based backends for JS/TS and Python respectively. All four
count occurrences of dotted chains (`vim.api`, `table.insert`, …) and feed
the same suggestion float.

- **Module:** `analyzers/regex.lua`, `analyzers/treesitter.lua`, `analyzers/javascript.lua`, `analyzers/python.lua`
- **Usercmds:** `:Recommender treesitter`, `:Recommender javascript`, `:Recommender python` ([commands](BINDINGS.md#user-commands))
- **Config:** `opts.analyzer` (default `"regex"`)

`treesitter.lua` is only required the first time it's actually selected —
the other three analyzers never pay for loading a parser they don't use.

## Scopes: `buffer` (default), `path`, `cwd`, `cfile`, `line`

Changes what gets scanned before the threshold is applied — the current
buffer only (default), every matching file under the current file's own
directory (`path`) or the working directory (`cwd`), a single file named
under the cursor (`cfile`), or just the current line (`line`).
`cwd`/`path` surface chains that repeat across many files even when no
single file crosses the threshold alone; `cfile` isolates one file without
touching the buffer or `cwd`; `line` is a quick single-line check.

- **Module:** `project.lua`
- **Usercmds:** `:Recommender cwd` / `:Recommender path` / `:Recommender cfile` / `:Recommender line` (`-c`/`--cwd` is a backward-compatible flag alias for `cwd`)
- **Config:** `opts.cwd_ignore` (skip-list for `cwd`/`path`, default covers `.git`, `node_modules`, `.venv`, etc.), `opts.cwd_max_files` (safety cap for `cwd`/`path`, default `500`, `0` = unbounded)

`Enter`/`A` still insert into the *current* buffer regardless of scope —
scope only changes where chains are counted. Only the regex-based analyzers
support any non-`buffer` scope; combining one with `treesitter` is a hard
error, since treesitter parses a live buffer's syntax tree, not raw file
text on disk. `line` scope defaults its threshold to `1` instead of
`config.threshold`, since a single line dedups each chain to at most one
hit — pass an explicit threshold token to override.

## Interactive suggestion float

- **Tab:** true
- **Module:** `float/rendering.lua`, `float/keymaps.lua`
- **Keymaps:** [float window keymaps](BINDINGS.md#float-window-keymaps)

### Why it's a picker, not a report

The float is built on `lib.nvim.ui.kit.select`, so navigation (`j`/`k`/arrows),
`<CR>`-submit, and `q`/`<Esc>`-close come for free from kit.select itself.
`recommender.nvim` only supplies what's specific to this use case: `<CR>`'s
actual insert behavior, plus extra buffer-local keymaps layered on top for
actions that read the highlighted suggestion without submitting or closing
the picker.

- `j`/`k` (or arrows) — navigate suggestions, one logical suggestion at a
  time regardless of layout (3 buffer lines per entry in `"detailed"`, 1 in
  `"compact"`)
- `Enter` — insert the selected alias declaration into the source buffer
- `y` — yank the selected alias to the `+`/`*` registers
- `A` — insert *all* visible aliases at once
- `Backspace` — ignore this entry for the current buffer's session
- `U` — un-ignore all, restoring dismissed suggestions
- `q`/`Esc` — close
- `?` — show the keymap reference via `vim.notify`

`:Recommender` itself is a toggle: running it again while the float is open
just closes it, no separate close command needed. Chain, alias, and hit
count are each highlighted distinctly in the float.

## Replace mode

After inserting an alias, automatically replaces every occurrence of the
original chain in the buffer via a `:Replace` call, then inserts the
`local alias = chain` declaration.

- **Module:** `float/autocmds.lua`
- **Usercmds:** `:Recommender -r` / `:Recommender --replace`
- **Keymaps:** `<leader>lR` ([global keymaps](BINDINGS.md#global-keymaps))

Requires a `:Replace` user command from another plugin —
[replacer.nvim](https://github.com/StefanBartl/replacer.nvim) provides one.
Detection of "the replace finished" is event-driven: a one-shot `WinClosed`
autocmd watches for the `TelescopePrompt` window closing, then removes
itself immediately after firing. No polling, no timers.

## Per-buffer ignore

Dismissing a suggestion (`Backspace` in the float) only affects that buffer's
session — ignoring `vim.api` in one file doesn't hide it in another. `U`
restores everything dismissed so far.

- **Module:** `float/keymaps.lua`

## Prefix blacklist

Blocks an entire namespace from ever being suggested — `"vim.fn"` in the
blacklist blocks `vim.fn`, `vim.fn.expand`, and every other `vim.fn.*` chain.

- **Module:** `blacklist.lua`
- **Config:** `opts.blacklist` (default: empty)

## Custom alias map

Overrides the generated alias name for any chain. Built-in defaults cover
common chains (`vim.api` → `api`, `table.insert` → `tbl_insert`, …); `setup()`
extends or overrides them.

- **Module:** `custom_aliases.lua`
- **Config:** `opts.custom_aliases`

## Configurable float layout

`"detailed"` (default) renders each suggestion across 3 lines (chain + hit
count, the alias declaration, a blank separator). `"compact"` renders one
line per suggestion instead. Both share the same keymaps; navigation moves
by logical suggestion either way.

- **Module:** `float/rendering.lua` (`build_item`)
- **Config:** `opts.float_layout` (`"detailed"` | `"compact"`, default `"detailed"`)

## Default global keymaps

Installed by `setup()` unless `opts.keymaps == false`. Nothing is registered
globally beyond these opt-out mappings — no autocommands run at startup,
no global state outside the current buffer's ignore list. which-key (if
installed) labels the `<leader>lr` group automatically; the individual keys
are plain global mappings onto `:Recommender` with no `<Plug>` indirection.

- **Module:** `bindings/keymaps.lua`, `bindings/which_key.lua`
- **Keymaps:** [global keymaps](BINDINGS.md#global-keymaps)
- **Config:** `opts.keymaps` (default `true`)

## Health check

`:checkhealth recommender` verifies the environment (dependencies,
treesitter parser availability) independent of running an actual analysis.

- **Module:** `health.lua`
