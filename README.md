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

Analyzes the current Lua buffer for frequently repeated dotted chains (`vim.api`, `table.insert`, …) and suggests `local` alias declarations in an interactive floating window. Pure Neovim — no external dependencies.

> Pairs well with [replacer.nvim](https://github.com/StefanBartl/replacer.nvim), which provides the `:Replace` command used by [replace mode](docs/commands.md#replace-mode).

## Quickstart

Requires Neovim >= 0.9 (Tree-sitter parser optional, only needed for `analyzer = "treesitter"`).

```lua
-- lazy.nvim
{
  "StefanBartl/recommender.nvim",
  ft  = { "lua" },
  cmd = { "Recommender" },
  config = function()
    require("recommender_nvim").setup()
  end,
}
```

```vim
:Recommender          " open with configured defaults
```

See [docs/installation.md](docs/installation.md) for packer.nvim, vim-plug, and health-check verification.

## Documentation

- [Features](docs/features.md) — what the plugin does, at a glance.
- [Installation](docs/installation.md) — requirements and setup for lazy.nvim, packer.nvim, and vim-plug.
- [Configuration](docs/configuration.md) — all `setup()` options, defaults, and the default global keymaps.
- [Commands](docs/commands.md) — the `:Recommender` command, float window keymaps, and replace mode.
- [Examples](docs/examples.md) — a worked before/after example of the suggestion float.
- [Architecture](docs/architecture.md) — module layout and design principles.
- [Bindings cheatsheet](docs/BINDINGS.md) — machine-readable reference for every keymap, command, and autocommand.
- [Roadmap](docs/ROADMAP.md) — implemented features and planned/rejected ideas.
- [Troubleshooting](docs/troubleshooting.md) — health-check and diagnostics.
