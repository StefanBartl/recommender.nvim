---@meta
---@module 'recommender.@types'
---@brief Type definitions for recommender.nvim.
---@description
--- Central type catalog so the source files stay free of long annotation
--- blocks. All `@types` modules return an empty table.

---@class Recommender.Config
---@field analyzer       "regex"|"treesitter"|"javascript"|"python"  Analyzer backend (default: "regex")
---@field threshold      integer               Min occurrences before a chain is suggested (default: 3)
---@field custom_aliases table<string,string>  Chain -> preferred alias name override
---@field blacklist      string[]              Prefix-blocked chains (never suggested)
---@field keymaps        boolean               Install global keymaps in setup() (default: true)

---@class Recommender.Suggestion
---@field chain string   Dotted chain, e.g. "vim.api"
---@field count integer  Occurrence count in the buffer
---@field alias string   Rendered "local <name> = <chain>" declaration

return {}
