---@module 'recommender.bindings.usrcmds'
---@brief The `:Recommender` user command, built via lib.nvim.usercmd.composer.
---@description
--- Parses flags/positional args, resolves the analyzer + threshold, and owns
--- the per-invocation state passed to `recommender.float.keymaps`.
---
--- execute() is the unchanged dispatch engine (state/refresh/rendering logic
--- untouched). The one composer route is a `path = {}` root route — this
--- grammar has no subcommand word at all — declaring `flags = {{name=
--- "replace", short="r", bool=true}}` (Phase 7's short-flag alias, added
--- specifically to unblock this repo) and two optional positional slots for
--- analyzer/threshold. Composer's flag/positional split is the same algorithm
--- the original inline loop used (strip -r/--replace tokens, keep the rest in
--- order), so ctx.flags.replace / ctx.pos feed execute() directly — no
--- reconstruction needed.

local composer = require("lib.nvim.usercmd.composer")

local rendering = require("recommender.float.rendering")
local keymaps_m = require("recommender.float.keymaps")
local notify = require("recommender.util.notify").create("[recommender]")

local M = {}

local api = vim.api

---Names accepted for `{analyzer}` positional args and `config.analyzer`.
---@type string[]
local ANALYZER_NAMES = { "regex", "treesitter", "javascript", "python" }

---@type table<string, boolean>
local _is_analyzer_name = {}
for _, name in ipairs(ANALYZER_NAMES) do
  _is_analyzer_name[name] = true
end

---@type table<string, table>
local _analyzer_cache = {}

---Load an analyzer backend by name, with error propagation.
---Results are cached so the module is only required once per session.
---@param name "regex"|"treesitter"|"javascript"|"python"
---@return table
local function get_analyzer(name)
  if _analyzer_cache[name] then
    return _analyzer_cache[name]
  end
  local mod_name = "recommender.analyzers." .. name
  local ok, mod = pcall(require, mod_name)
  if not ok then
    error(("[recommender] Unknown analyzer %q — expected one of: %s"):format(name, table.concat(ANALYZER_NAMES, ", ")), 2)
  end
  _analyzer_cache[name] = mod
  return mod
end

-- Per-buffer ignore state: { [bufnr] = { [chain] = true } }
local ignore_by_buf = {}

---@param cfg Recommender.Config
---@param replace_mode boolean
---@param pos_args string[]
---@return nil
local function execute(cfg, replace_mode, pos_args)
  local analyzer_name = (pos_args[1] and _is_analyzer_name[pos_args[1]]) and pos_args[1] or cfg.analyzer
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
    source_bufnr = bufnr,
    ignored = ignore_by_buf[bufnr],
    custom_aliases = cfg.custom_aliases or {},
    blacklist = cfg.blacklist or {},
    replace_mode = replace_mode,
    visible = {},
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

      local title = ("Recommender: %d suggestion%s"):format(#state.visible, #state.visible == 1 and "" or "s")
      if replace_mode then
        title = title .. "  [REPLACE MODE]"
      end

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
end

---@param cfg Recommender.Config
---@return nil
function M.setup(cfg)
  composer.verb("Recommender", {
    desc = "Suggest local aliases for repeated chains. Flags: -r/--replace [analyzer] [threshold]",
    routes = {
      {
        path = {},
        args = {
          { name = "a1", type = "STRING", values = ANALYZER_NAMES, optional = true },
          { name = "a2", type = "STRING", values = ANALYZER_NAMES, optional = true },
        },
        flags = { { name = "replace", short = "r", bool = true } },
        run = function(ctx)
          execute(cfg, ctx.flags.replace or false, ctx.pos)
        end,
      },
    },
  })
end

return M
