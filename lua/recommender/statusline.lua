---@module 'recommender.statusline'
---@brief A statusline component: how many alias suggestions are open for
--- the current buffer.
---@description
--- `"3 alias suggestions open for this file"` — the count of repeated
--- dotted chains this plugin would suggest aliasing, without opening the
--- suggestion float or running `:Recommender`.
---
--- A plain Lua string with no dependency on any statusline plugin, and
--- `""` on anything unexpected rather than an error: a statusline is not
--- the place for a failure popup.
---
--- **Why it lives here.** It used to live in `ui.nvim`, which reached into
--- `recommender.config` and `recommender.analyzers.*` from the outside to
--- build it. That works right up until one of those is renamed, and
--- nothing in this repository's tests would have noticed. Two siblings
--- (`sandbox.nvim`, `sessions.nvim`) already shipped their own component
--- and `ui.nvim` was a thin adapter over them; this closes the gap for
--- this plugin (cross-feature report, finding E). `docs/statusline.md` has
--- the wiring for lualine, heirline and the native statusline.
---
--- **Caching.** The analyzer rescans the buffer, and a statusline redraws
--- many times a second. The result is cached per buffer against
--- `nvim_buf_get_changedtick`, so it is recomputed exactly once per edit
--- and never between them.

local M = {}

---@type table<integer, { tick: integer, count: integer }>
local cache = {}

---Forget a buffer's cached count.
---@param buf integer
---@return nil
function M.invalidate(buf)
  cache[buf] = nil
end

---@internal
---Suggestions for `buf` at its current tick, or nil when the count cannot
---be established (unknown analyzer, config not loaded yet, ...).
---@param buf integer
---@return integer|nil
local function suggestion_count(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end

  local ok_cfg, config = pcall(require, "recommender.config")
  if not ok_cfg or type(config) ~= "table" then
    return nil
  end

  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cached = cache[buf]
  if cached and cached.tick == tick then
    return cached.count
  end

  local cfg = config.get()
  local ok_analyzer, analyzer = pcall(require, "recommender.analyzers." .. (cfg.analyzer or "regex"))
  if not ok_analyzer or type(analyzer) ~= "table" then
    return nil
  end

  local suggestions
  local ok_run = pcall(function()
    vim.api.nvim_buf_call(buf, function()
      suggestions = analyzer.analyze(cfg.threshold, cfg.custom_aliases, cfg.blacklist)
    end)
  end)
  if not ok_run or type(suggestions) ~= "table" then
    return nil
  end

  local count = #suggestions
  cache[buf] = { tick = tick, count = count }
  return count
end

---The component text, or `""` when there is nothing worth showing.
---
---Empty is the answer for "no suggestions" as well as for any failure: a
---badge with nothing to act on is clutter, and the two cases look the same
---from a statusline's point of view.
---@param buf integer|nil # defaults to the current buffer
---@return string
function M.status(buf)
  local count = suggestion_count(buf or vim.api.nvim_get_current_buf())
  if not count or count == 0 then
    return ""
  end

  local label = count == 1 and "alias suggestion" or "alias suggestions"
  return (" %d %s open for this file "):format(count, label)
end

---`status` under the name a lualine spec reads naturally.
---@return string
function M.lualine_component()
  return M.status()
end

-- Drop a buffer's entry when it goes away. Registered at require time
-- rather than from a setup(): this module is only ever loaded because
-- somebody put the component in their statusline.
local ok_au, au = pcall(require, "lib.nvim.bindings.autocmd")
if ok_au then
  au.create({ "BufDelete", "BufWipeout" }, function(args)
    cache[args.buf] = nil
  end, {
    group = au.group("recommender_statusline", true),
    desc = "recommender: forget a deleted buffer's statusline count",
  })
end

return M
