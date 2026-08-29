> **Active development.** This repository is in its development phase — breaking changes are to be expected at any time. Pin a commit or tag if you depend on it.

# recommender.nvim

```
  ___                                              _
 | _ \___  __ ___ _ __  _ __  ___ _ _  __| |___ _ _
 |   / -_)/ _/ _ \ '  \| '  \/ -_) ' \/ _` / -_) '_|
 |_|_\___|\__\___/_|_|_|_|_|_\___|_||_\__,_\___|_|
              nvim
```

![version](https://img.shields.io/badge/version-0.1.0-blue.svg)
![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-success.svg)
![Lua](https://img.shields.io/badge/language-Lua-yellow.svg)

> Pairs well with [replacer.nvim](https://github.com/StefanBartl/replacer.nvim), which provides the `:Replace` command used by [replace mode](docs/commands.md#replace-mode).

Analyzes the current buffer by default — or a wider [scope](docs/commands.md#scopes) (`path`, `cwd`, `cfile`, `line`) — for frequently repeated dotted chains (`vim.api`, `table.insert`, …) in Lua, JS/TS, or Python, and suggests alias declarations in an interactive floating window. With `-r`/`--replace`, accepting a suggestion also rewrites every occurrence of the chain in the buffer via [replacer.nvim](https://github.com/StefanBartl/replacer.nvim)'s `:Replace`, not just the alias declaration. A fifth analyzer, `perf`, is a different kind of check entirely: it flags four *benchmarked* Lua anti-patterns (`table.insert` and `string.format` in a loop, a `..` concat accumulator, `ipairs` vs. a numeric `for`) instead of counting chain repetition — see [Features](docs/FEATURES.md#perf-analyzer-analyzer--perf) for why. Pure Neovim — no external tooling. Requires [lib.nvim](https://github.com/StefanBartl/lib.nvim): `:Recommender` is registered via `lib.nvim.bindings.usercmd.composer`.

---

## Table of Contents

- [Quickstart](#quickstart)
- [Documentation](#documentation)

---

## Quickstart

Requires Neovim >= 0.9 and [lib.nvim](https://github.com/StefanBartl/lib.nvim) (Tree-sitter parser optional, only needed for `analyzer = "treesitter"`).

```lua
-- lazy.nvim
{
  "StefanBartl/recommender.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  ft  = { "lua" },
  cmd = { "Recommender" },
  opts = {},
}
```

```vim
:Recommender          " open with configured defaults
```

See [docs/installation.md](docs/installation.md) for packer.nvim, vim-plug, and health-check verification.

## Documentation

- [Features](docs/FEATURES.md) — what the plugin does, at a glance.
- [Installation](docs/installation.md) — requirements and setup for lazy.nvim, packer.nvim, and vim-plug.
- [Configuration](docs/configuration.md) — all `setup()` options, defaults, and the default global keymaps.
- [Commands](docs/commands.md) — the `:Recommender` command, float window keymaps, and replace mode.
- [Examples](docs/examples.md) — a worked before/after example of the suggestion float.
- [Architecture](docs/architecture.md) — module layout and design principles.
- [Bindings cheatsheet](docs/BINDINGS.md) — machine-readable reference for every keymap, command, and autocommand.
- [Troubleshooting](docs/troubleshooting.md) — health-check and diagnostics.
