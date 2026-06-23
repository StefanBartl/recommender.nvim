---@module 'recommender_nvim.config'

---@class Recommender.Config
---@field analyzer "regex"|"treesitter"  Analyzer backend (default: "regex")
---@field threshold integer              Min occurrences before a chain is suggested (default: 3)
---@field custom_aliases table<string,string> Chain → preferred alias name override
---@field blacklist string[]             Prefix-blocked chains (never suggested)
---@field keymaps boolean                Install global keymaps in setup() (default: true)

local M = {}

local _cfg = nil

---@return Recommender.Config
local function defaults()
  return {
    analyzer       = "regex",
    threshold      = 3,
    custom_aliases = require("recommender_nvim.custom_aliases"),
    blacklist      = require("recommender_nvim.blacklist").default,
    keymaps        = true,
  }
end

---@param opts Recommender.Config|nil
function M.setup(opts)
  _cfg = vim.tbl_deep_extend("force", defaults(), opts or {})
end

---@return Recommender.Config
function M.get()
  return _cfg or defaults()
end

return M
