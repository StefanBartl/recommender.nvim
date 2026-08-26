# recommender.nvim — Binding Cheatsheet

Machine-readable overview of every keymap, user command, and autocommand
defined by `recommender.nvim`. This file is documentation only and mirrors
the source of truth in `lua/recommender/bindings/`. Any change there
must be reflected here.

Every global mapping binds directly onto `:Recommender` — there is no
`<Plug>` indirection. which-key (if installed) only labels the `<leader>lr`
prefix as a group; it does not register the individual keys.

## Global Keymaps

Installed by `setup()` unless `config.keymaps == false` (default: enabled).

Each is a named action, declared through
[`lib.nvim.bindings.keymap`](https://github.com/StefanBartl/lib.nvim) and
individually overridable — `config.keymaps` used to be a boolean, so a
colliding `<leader>lr` meant all eight or none:

```lua
keymaps = {
  regex  = "<leader>zr",            -- move one
  cwd    = { "<leader>lrc", "gR" }, -- or give it several
  python = false,                   -- or drop it
}
```

A misspelled action name is reported rather than silently binding nothing.

| lhs | mode | action | desc |
| --- | --- | --- | --- |
| `<leader>lr`  | n | `:Recommender`             | Open with configured defaults |
| `<leader>lR`  | n | `:Recommender -r`          | Open in replace mode |
| `<leader>lrr` | n | `:Recommender regex`       | Force regex analyzer |
| `<leader>lrt` | n | `:Recommender treesitter`  | Force treesitter analyzer |
| `<leader>lrj` | n | `:Recommender javascript`  | Force JS/TS regex analyzer |
| `<leader>lrp` | n | `:Recommender python`      | Force Python regex analyzer |
| `<leader>lrh` | n | `:Recommender regex 5`    | Regex, threshold 5 (large files) |
| `<leader>lrc` | n | `:Recommender -c`          | Project-wide (cwd) scope |

**A count sets the threshold.** `3<leader>lrr` runs the regex analyzer with
`--threshold=3`; `12<leader>lr` uses the configured analyzer with threshold
12. Without a count every mapping behaves exactly as before. On
`<leader>lrh` a count overrides its built-in 5 — that key is kept for muscle
memory, though `5<leader>lrr` now says the same thing without a dedicated
mapping.

This is why the mappings are Lua functions rather than `<cmd>…<cr>` strings:
a `<cmd>` mapping swallows the count prefix, with no way to read it back.

## User Commands

Always defined, regardless of `config.keymaps`. Built via
`lib.nvim.bindings.usercmd.composer` (`bindings/usrcmds.lua`) — a required
dependency of the command layer, unlike the soft `lib.nvim.notify`/`map`
helpers in `util/lib.lua`.

| name | args | desc |
| --- | --- | --- |
| `:Recommender` | `[-r\|--replace] [-c\|--cwd] [-t\|--threshold=N] [regex\|treesitter\|javascript\|python\|perf] [threshold] [buffer\|path\|cwd\|cfile\|line]` | Toggle the suggestion float; scope changes where chains are counted (default: current buffer only; non-`buffer` scopes are regex/javascript/python/perf only) |

Tab completion offers `regex`, `treesitter`, `javascript`, `python`, `perf`, `buffer`, `path`, `cwd`, `cfile`, `line`, `-r`, `--replace`, `-c`, `--cwd`, `-t`, `--threshold` in any order — any positional slot accepts an analyzer name, a scope name, or a threshold number, classified by content rather than position (see [commands.md](commands.md#scopes)).

`--threshold=N` says outright what the bare number can only imply, and wins
over it when both are given. The positional form is inferred: a token is a
threshold when it is neither a scope nor an analyzer name and `tonumber`s.
That is fine typing by hand and exactly wrong when the command is generated —
by a keymap, or another plugin — where the intent needs stating rather than
inferring. `perf` is a fixed-pattern anti-pattern detector, not a dotted-chain analyzer — see [FEATURES.md](FEATURES.md#perf-analyzer-analyzer--perf).

## Float Window Keymaps

The float is a `lib.nvim.ui.kit.select` picker (see
[UI-KIT-CONCEPT.md §13b](https://github.com/StefanBartl/lib.nvim/blob/main/docs/ROADMAP/UI-KIT-CONCEPT.md)
for the rich-item design it relies on): `j`/`k`/arrows/mouse-click
navigation, `<CR>`-submits, and `q`/`<Esc>`-closes come from kit.select
itself. `lua/recommender/float/keymaps.lua` supplies `<CR>`'s actual insert
behavior (via `on_select`) and attaches the remaining actions — the ones
that read the highlighted suggestion without submitting/closing the
picker — as extra buffer-local keymaps each time the float opens.

Those five are named actions too, overridable via `config.float_keymaps` in
the same shape as `config.keymaps` (`false` for none). `?` lists what is
actually bound, so it stays correct after a remap.

| lhs | action |
| --- | --- |
| `j` / `<Down>` | Next suggestion |
| `k` / `<Up>`   | Previous suggestion |
| `<CR>`         | Insert selected alias into the source buffer |
| `y`            | `yank` — yank selected alias to `+`/`*` registers |
| `A`            | `insert_all` — insert ALL visible aliases at once |
| `<BS>`         | `ignore` — ignore this entry for the current buffer session |
| `U`            | `unignore` — restore dismissed suggestions |
| `q` / `<Esc>`  | Close the float |
| `?`            | `help` — show the bound keys via `vim.notify` |

Navigation moves by logical suggestion regardless of layout — 3 buffer lines
per entry for `float_layout = "detailed"`, 1 for `"compact"` (see
`lua/recommender/float/rendering.lua`'s `build_item`); every keymap above
works identically either way.

## Autocommands

No plugin-level autocommands — `lua/recommender/bindings/autocmds.lua`
exists only for structural symmetry with usrcmds/keymaps.

Replace mode (`-r`/`--replace`) registers a **temporary, one-shot** `WinClosed`
autocmd per invocation (`lua/recommender/float/autocmds.lua`) to detect
when the `:Replace` prompt closes, so the alias can be inserted right after.
It removes itself immediately after firing — see
[`doc/recommender.txt`](../doc/recommender.txt) section 8.
