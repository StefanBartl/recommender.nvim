---@module 'recommender_nvim.health'
---@brief :checkhealth recommender_nvim provider.

local M = {}

---@return nil
function M.check()
  vim.health.start("recommender_nvim")

  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.warn("Neovim 0.9+ required")
  end

  local has_ts_lua = pcall(vim.treesitter.query.parse, "lua", "(field_expression) @field")
  if has_ts_lua then
    vim.health.ok('Lua Tree-sitter parser found (analyzer = "treesitter" available)')
  else
    vim.health.info('Lua Tree-sitter parser not found — install with :TSInstall lua to use analyzer = "treesitter"')
  end

  if vim.g.loaded_recommender_nvim then
    vim.health.ok("plugin loaded (vim.g.loaded_recommender_nvim = " .. tostring(vim.g.loaded_recommender_nvim) .. ")")
  else
    vim.health.warn("plugin guard not set — call require('recommender_nvim').setup()")
  end

  if require("recommender_nvim.util.lib").available() then
    vim.health.ok("lib.nvim found (notify/map delegate to it)")
  else
    vim.health.info("lib.nvim not installed (optional; native vim.notify/vim.keymap.set fallback is used)")
  end

  if require("recommender_nvim.bindings.which_key").available() then
    vim.health.ok("which-key found (global keymaps get a labeled <leader>lr group)")
  else
    vim.health.info("which-key not installed (optional; only labels the <leader>lr group)")
  end

  local cfg = require("recommender_nvim.config").get()
  if cfg.keymaps ~= false then
    vim.health.ok("keymaps enabled (default) — <leader>lr, <leader>lR, <leader>lrr, <leader>lrt, <leader>lrh bound")
  else
    vim.health.info("keymaps disabled (config.keymaps = false) — use :Recommender directly")
  end

  if vim.fn.exists(":Replace") == 2 then
    vim.health.ok(":Replace command found (replace mode fully functional)")
  else
    vim.health.info(":Replace command not found — replace mode (-r) falls back to a plain alias insert")
  end
end

return M
