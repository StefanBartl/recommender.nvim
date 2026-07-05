---@module 'recommender_nvim.bindings.usrcmds'
---@brief The `:Recommender` user command (always defined).
---@description
--- Parses flags/positional args, resolves the analyzer + threshold, and owns
--- the per-invocation state passed to `recommender_nvim.float.keymaps`.

local rendering = require("recommender_nvim.float.rendering")
local keymaps_m = require("recommender_nvim.float.keymaps")
local notify = require("recommender_nvim.util.notify").create("[recommender_nvim]")

local M = {}

local api = vim.api

---@type table<string, table>
local _analyzer_cache = {}

---Load an analyzer backend by name, with error propagation.
---Results are cached so the module is only required once per session.
---@param name "regex"|"treesitter"
---@return table
local function get_analyzer(name)
  if _analyzer_cache[name] then
    return _analyzer_cache[name]
  end
  local mod_name = "recommender_nvim.analyzers." .. name
  local ok, mod = pcall(require, mod_name)
  if not ok then
    error(("[recommender_nvim] Unknown analyzer %q — expected 'regex' or 'treesitter'"):format(name), 2)
  end
  _analyzer_cache[name] = mod
  return mod
end

-- Per-buffer ignore state: { [bufnr] = { [chain] = true } }
local ignore_by_buf = {}

---@param cfg Recommender.Config
---@return nil
function M.setup(cfg)
  api.nvim_create_user_command("Recommender", function(cmd)
    -- Parse flags and positional args
    local replace_mode = false
    local pos_args = {}
    for _, arg in ipairs(vim.split(vim.trim(cmd.args or ""), "%s+", { trimempty = true })) do
      if arg == "-r" or arg == "--replace" then
        replace_mode = true
      else
        pos_args[#pos_args + 1] = arg
      end
    end

    local analyzer_name = (pos_args[1] and (pos_args[1] == "regex" or pos_args[1] == "treesitter")) and pos_args[1]
      or cfg.analyzer
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
  end, {
    nargs = "*",
    desc = "Suggest local aliases for repeated Lua chains. Flags: -r/--replace [analyzer] [threshold]",
    complete = function(arg_lead)
      local candidates = { "regex", "treesitter", "-r", "--replace" }
      if arg_lead == "" then
        return candidates
      end
      local out = {}
      for _, c in ipairs(candidates) do
        if c:sub(1, #arg_lead) == arg_lead then
          out[#out + 1] = c
        end
      end
      return out
    end,
  })
end

return M
