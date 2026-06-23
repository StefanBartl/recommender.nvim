---@module 'recommender_nvim'
---recommender.nvim — Lua alias suggester for Neovim.
---
---Analyzes the current buffer for repeated dotted chains (vim.api, table.insert, …)
---and suggests local alias declarations. Two backends: regex (fast, no deps) and
---tree-sitter (precise, requires Lua parser).

local M = {}

local notify    = require("recommender_nvim.util.notify").create("[recommender_nvim]")
local rendering = require("recommender_nvim.rendering")
local keymaps_m = require("recommender_nvim.keymaps")
local cfg_mod   = require("recommender_nvim.config")

local api = vim.api

-- Per-buffer ignore state: { [bufnr] = { [chain] = true } }
local ignore_by_buf = {}

-- ── analyzer loader ─────────────────────────────────────────────────────────

local _analyzer_cache = {}

---Load an analyzer backend by name, with error propagation.
---Results are cached so the module is only required once per session.
---@param name "regex"|"treesitter"
---@return table
local function get_analyzer(name)
  if _analyzer_cache[name] then return _analyzer_cache[name] end
  local mod_name = "recommender_nvim.analyzers." .. name
  local ok, mod  = pcall(require, mod_name)
  if not ok then
    error(("[recommender_nvim] Unknown analyzer %q — expected 'regex' or 'treesitter'"):format(name), 2)
  end
  _analyzer_cache[name] = mod
  return mod
end

-- ── setup ───────────────────────────────────────────────────────────────────

local _setup_done = false

---@param opts Recommender.Config|nil
function M.setup(opts)
  if _setup_done then return end
  _setup_done = true

  cfg_mod.setup(opts)
  local cfg = cfg_mod.get()

  api.nvim_create_user_command("Recommender", function(cmd)
    -- Parse flags and positional args
    local replace_mode = false
    local pos_args     = {}
    for _, arg in ipairs(vim.split(vim.trim(cmd.args or ""), "%s+", { trimempty = true })) do
      if arg == "-r" or arg == "--replace" then
        replace_mode = true
      else
        pos_args[#pos_args + 1] = arg
      end
    end

    local analyzer_name = (pos_args[1] and (pos_args[1] == "regex" or pos_args[1] == "treesitter"))
      and pos_args[1] or cfg.analyzer
    local threshold = tonumber(pos_args[2]) or tonumber(pos_args[1]) or cfg.threshold

    -- Toggle: close if already open
    if rendering.is_open() then
      rendering.close()
      return
    end

    local bufnr = api.nvim_get_current_buf()
    ignore_by_buf[bufnr] = ignore_by_buf[bufnr] or {}

    ---@type table
    local state = {
      source_bufnr   = bufnr,
      ignored        = ignore_by_buf[bufnr],
      custom_aliases = cfg.custom_aliases or {},
      blacklist      = cfg.blacklist      or {},
      replace_mode   = replace_mode,
      visible        = {},
    }

    function state.refresh()
      local ok, err = pcall(function()
        if not (state.source_bufnr and api.nvim_buf_is_valid(state.source_bufnr)) then
          notify.warn("Source buffer is no longer valid")
          rendering.close()
          return
        end

        local analyzer = get_analyzer(analyzer_name)
        local all

        api.nvim_buf_call(state.source_bufnr, function()
          all = analyzer.analyze(threshold, state.custom_aliases, state.blacklist)
        end)

        state.visible = {}
        for _, s in ipairs(all) do
          if not state.ignored[s.chain] then
            state.visible[#state.visible + 1] = s
          end
        end

        if #state.visible == 0 then
          notify.info(("No suggestions (threshold: %d)"):format(threshold))
          rendering.close()
          return
        end

        local title = ("Recommender: %d suggestion%s"):format(
          #state.visible, #state.visible == 1 and "" or "s"
        )
        if replace_mode then title = title .. "  [REPLACE MODE]" end

        rendering.open(state.visible, title, rendering.cursor_index)

        if rendering.float_buf and api.nvim_buf_is_valid(rendering.float_buf) then
          keymaps_m.attach(rendering.float_buf, state)
        end
      end)

      if not ok then
        notify.error("Error: " .. tostring(err))
        rendering.close()
      end
    end

    vim.schedule(state.refresh)
  end, {
    nargs = "*",
    desc  = "Suggest local aliases for repeated Lua chains. Flags: -r/--replace [analyzer] [threshold]",
    complete = function(arg_lead)
      local candidates = { "regex", "treesitter", "-r", "--replace" }
      if arg_lead == "" then return candidates end
      local out = {}
      for _, c in ipairs(candidates) do
        if c:sub(1, #arg_lead) == arg_lead then out[#out + 1] = c end
      end
      return out
    end,
  })

  -- Global keymaps (opt-out via keymaps = false)
  if cfg.keymaps ~= false then
    local km = vim.keymap.set
    km("n", "<leader>lr",  "<cmd>Recommender<cr>",             { desc = "Recommender",                  silent = true })
    km("n", "<leader>lR",  "<cmd>Recommender -r<cr>",          { desc = "Recommender (replace mode)",   silent = true })
    km("n", "<leader>lrr", "<cmd>Recommender regex<cr>",       { desc = "Recommender (regex)",          silent = true })
    km("n", "<leader>lrt", "<cmd>Recommender treesitter<cr>",  { desc = "Recommender (treesitter)",     silent = true })
    km("n", "<leader>lrh", "<cmd>Recommender regex 5<cr>",     { desc = "Recommender (high threshold)", silent = true })
  end
end

return M
