# Installation

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| Neovim | **>= 0.9** | core |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | **required** | `:Recommender` is registered via `lib.nvim.bindings.usercmd.composer`, no fallback (`notify`/`map` specifically still degrade to a native fallback if somehow absent at that call site, but the command layer itself does not) |
| Lua Tree-sitter parser | optional | needed for `analyzer = "treesitter"`, and only in the buffer scope; the module is required the first time that analyzer is actually selected, so the others never pay for it |
| [replacer.nvim](https://github.com/StefanBartl/replacer.nvim) | optional | replace mode (`-r`), which rewrites every occurrence rather than only inserting the alias |
| fidget.nvim | optional | one of the `progress_style` back ends for a long scan |

No external tools at all — everything above is a Neovim plugin.

## lazy.nvim

```lua
{
  "StefanBartl/recommender.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  ft  = { "lua" },
  cmd = { "Recommender" },
  config = function()
    require("recommender").setup()
  end,
}
```

## packer.nvim

```lua
use {
  "StefanBartl/recommender.nvim",
  requires = { "StefanBartl/lib.nvim" },
  config = function()
    require("recommender").setup()
  end,
}
```

## vim-plug

```vim
Plug 'StefanBartl/lib.nvim'
Plug 'StefanBartl/recommender.nvim'

lua require("recommender").setup()
```

## Verifying the installation

```
:checkhealth recommender
```

See [Troubleshooting](troubleshooting.md) if the health-check reports a problem.
