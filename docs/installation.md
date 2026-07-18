# Installation

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| Neovim | **>= 0.9** | core |
| Lua Tree-sitter parser | optional | needed for `analyzer = "treesitter"` |

## lazy.nvim

```lua
{
  "StefanBartl/recommender.nvim",
  ft  = { "lua" },
  cmd = { "Recommender" },
  config = function()
    require("recommender_nvim").setup()
  end,
}
```

## packer.nvim

```lua
use {
  "StefanBartl/recommender.nvim",
  config = function()
    require("recommender_nvim").setup()
  end,
}
```

## vim-plug

```vim
Plug 'StefanBartl/recommender.nvim'

lua require("recommender_nvim").setup()
```

## Verifying the installation

```
:checkhealth recommender_nvim
```

See [Troubleshooting](troubleshooting.md) if the health-check reports a problem.
