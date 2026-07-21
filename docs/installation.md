# Installation

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| Neovim | **>= 0.9** | core |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | **required** | `:Recommender` is registered via `lib.nvim.usercmd.composer`, no fallback (`notify`/`map` specifically still degrade to a native fallback if somehow absent at that call site, but the command layer itself does not) |
| Lua Tree-sitter parser | optional | needed for `analyzer = "treesitter"` |

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
