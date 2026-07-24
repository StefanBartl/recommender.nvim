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

## User Commands

Always defined, regardless of `config.keymaps`. Built via
`lib.nvim.usercmd.composer` (`bindings/usrcmds.lua`) — a required
dependency of the command layer, unlike the soft `lib.nvim.notify`/`map`
helpers in `util/lib.lua`.

| name | args | desc |
| --- | --- | --- |
| `:Recommender` | `[-r\|--replace] [-c\|--cwd] [regex\|treesitter\|javascript\|python] [threshold]` | Toggle the suggestion float; `-c`/`--cwd` aggregates chain counts project-wide instead of just the current buffer (regex/javascript/python only) |

Tab completion offers `regex`, `treesitter`, `javascript`, `python`, `-r`, `--replace`, `-c`, `--cwd` in any order.

## Float Window Keymaps

Buffer-local to the float window (`lua/recommender/float/keymaps.lua`),
attached each time the float opens.

| lhs | action |
| --- | --- |
| `j` / `<Down>` | Next suggestion |
| `k` / `<Up>`   | Previous suggestion |
| `<CR>`         | Insert selected alias into the source buffer |
| `y`            | Yank selected alias to `+`/`*` registers |
| `A`            | Insert ALL visible aliases at once |
| `<BS>`         | Ignore this entry for the current buffer session |
| `U`            | Un-ignore all — restore dismissed suggestions |
| `q` / `<Esc>`  | Close the float |
| `?`            | Show this keymap reference via `vim.notify` |

## Autocommands

No plugin-level autocommands — `lua/recommender/bindings/autocmds.lua`
exists only for structural symmetry with usrcmds/keymaps.

Replace mode (`-r`/`--replace`) registers a **temporary, one-shot** `WinClosed`
autocmd per invocation (`lua/recommender/float/autocmds.lua`) to detect
when the `:Replace` prompt closes, so the alias can be inserted right after.
It removes itself immediately after firing — see
[`doc/recommender.nvim.txt`](../doc/recommender.nvim.txt) section 8.
