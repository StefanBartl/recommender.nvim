---@module 'recommender.custom_aliases'
---Built-in alias map for common Lua / Neovim chains.
---Users extend or override this table via setup({ custom_aliases = ... }).

---@type table<string, string>
return {
  -- Neovim API
  ["vim.api"] = "api",
  ["vim.fn"] = "fn",
  ["vim.keymap.set"] = "km_set",
  ["vim.opt"] = "opt",
  ["vim.cmd"] = "cmd",
  ["vim.lsp"] = "lsp",
  ["vim.schedule"] = "schedule",
  ["vim.defer_fn"] = "defer_fn",
  ["vim.notify"] = "notify",
  ["vim.log.levels"] = "levels",
  ["vim.uv"] = "uv",
  ["vim.loop"] = "loop",

  -- Table stdlib
  ["table.insert"] = "tbl_insert",
  ["table.concat"] = "tbl_concat",
  ["table.remove"] = "tbl_remove",

  -- String stdlib
  ["string.format"] = "str_fmt",
  ["string.match"] = "str_match",

  -- Math stdlib
  ["math.floor"] = "floor",
  ["math.ceil"] = "ceil",
  ["math.max"] = "max",
  ["math.min"] = "min",

  -- OS
  ["os.date"] = "os_date",
  ["os.execute"] = "os_execute",
}
