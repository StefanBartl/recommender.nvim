---@module 'recommender.health'
---@brief :checkhealth recommender provider.

local M = {}

---@return nil
function M.check()
  vim.health.start("recommender")

  local cfg = require("recommender.config").get()

  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.warn("Neovim 0.9+ required")
  end

  -- lib.nvim.notify/map (util/lib.lua) stay soft — native fallback if
  -- absent — but lib.nvim.usercmd.composer is a hard dependency of the
  -- :Recommender command layer as of the composer migration, no fallback.
  if pcall(require, "lib.nvim.usercmd.composer") then
    vim.health.ok("lib.nvim.usercmd.composer available (:Recommender command layer)")
  else
    vim.health.error(":Recommender will fail to register — lib.nvim.usercmd.composer not found; install StefanBartl/lib.nvim")
  end

  local has_ts_lua = pcall(vim.treesitter.query.parse, "lua", "(field_expression) @field")
  if has_ts_lua then
    vim.health.ok('Lua Tree-sitter parser found (analyzer = "treesitter" available)')
  else
    vim.health.info('Lua Tree-sitter parser not found — install with :TSInstall lua to use analyzer = "treesitter"')
  end

  vim.health.ok('analyzer = "javascript" / "python" available (regex-based, no parser dependency)')

  vim.health.info(
    ("--cwd (project-wide) scope: regex/javascript/python only, not treesitter — cwd_max_files=%d, cwd_ignore=%s"):format(
      cfg.cwd_max_files or 0,
      table.concat(cfg.cwd_ignore or {}, ",")
    )
  )

  vim.health.ok(("float_layout = %q"):format(cfg.float_layout or "detailed"))

  if vim.g.loaded_recommender then
    vim.health.ok("plugin loaded (vim.g.loaded_recommender = " .. tostring(vim.g.loaded_recommender) .. ")")
  else
    vim.health.warn("plugin guard not set — call require('recommender').setup()")
  end

  if require("recommender.util.lib").available() then
    vim.health.ok("lib.nvim found (notify/map delegate to it)")
  else
    vim.health.info("lib.nvim.notify not found — native vim.notify/vim.keymap.set fallback used for notify/map specifically (lib.nvim itself is still required overall, see above)")
  end

  if require("recommender.bindings.which_key").available() then
    vim.health.ok("which-key found (global keymaps get a labeled <leader>lr group)")
  else
    vim.health.info("which-key not installed (optional; only labels the <leader>lr group)")
  end

  if cfg.keymaps ~= false then
    vim.health.ok(
      "keymaps enabled (default) — <leader>lr, <leader>lR, <leader>lrr, <leader>lrt, <leader>lrj, "
        .. "<leader>lrp, <leader>lrh, <leader>lrc bound"
    )
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
