---@module 'recommender.float.keymaps'
---Buffer-local keymaps for the Recommender float window. Navigation
---(j/k/arrows/mouse), <CR>-submits, and q/<Esc>-closes are handled by
---lib.nvim.ui.kit's chooser itself now (see UI-KIT-CONCEPT.md §13b) -- this
---module only builds the <CR> handler passed into `rendering.open()` and
---attaches the extra actions chooser doesn't know about (y/A/<BS>/U/?),
---which read the highlighted suggestion via `kit.chooser.current_item()`
---without submitting/closing the picker.

local notify = require("recommender.util.notify").create("[recommender]")
local rendering = require("recommender.float.rendering")
local lib = require("recommender.util.lib")
local kit = require("lib.nvim.ui.kit")

local M = {}

local api = vim.api
local km_set = lib.map
local schedule = vim.schedule

-- ── helpers ────────────────────────────────────────────────────────────────

---Returns true only for normal, modifiable, non-special windows.
---@param winid integer
---@return boolean
local function is_normal_window(winid)
  if not api.nvim_win_is_valid(winid) then
    return false
  end
  local bufnr = api.nvim_win_get_buf(winid)
  if not api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end
  if not vim.bo[bufnr].modifiable then
    return false
  end
  return true
end

---Find the best window to insert the alias into.
---Priority: stored source_win → alternate window → first normal window.
---@return integer|nil
local function find_target_window()
  if rendering.source_win and is_normal_window(rendering.source_win) then
    return rendering.source_win
  end
  local alt = vim.fn.win_getid(vim.fn.winnr("#"))
  if alt and alt ~= 0 and is_normal_window(alt) then
    return alt
  end
  for _, win in ipairs(api.nvim_list_wins()) do
    if is_normal_window(win) then
      return win
    end
  end
  return nil
end

---The suggestion at the picker's current cursor position, or nil.
---@return {chain:string, count:integer, alias:string}|nil
local function current_suggestion()
  local item = kit.chooser.current_item()
  return item and item.suggestion
end

-- ── public ─────────────────────────────────────────────────────────────────

---Build the <CR> handler passed to `rendering.open()`: inserts (or, in
---replace mode, dispatches :Replace for) the chosen suggestion's alias.
---@param state table  Recommender state table (visible, ignored, replace_mode, …)
---@return fun(item: {chain:string, count:integer, alias:string})
function M.make_on_select(state)
  return function(item)
    local target_win = find_target_window()
    if not target_win then
      notify.warn("No suitable window for insertion")
      return
    end

    state._pending_insert = { win = target_win, text = item.alias }

    schedule(function()
      if not api.nvim_win_is_valid(target_win) then
        return
      end
      api.nvim_set_current_win(target_win)
      vim.cmd("normal! \27") -- ensure Normal mode
      vim.cmd("redraw")

      if state.replace_mode then
        local buf = api.nvim_win_get_buf(target_win)
        local snapshot = api.nvim_buf_get_lines(buf, 0, -1, false)

        require("recommender.float.autocmds").register_replace_finish(target_win, snapshot, item.alias)

        local var_name = item.alias:match("^%s*local%s+([%w_]+)") or item.alias:match("^%s*([%w_]+)%s*=")

        if var_name and vim.fn.exists(":Replace") == 2 then
          vim.cmd(("Replace %s %s %%"):format(item.chain, var_name))
        else
          api.nvim_put({ item.alias }, "l", false, true)
          state._pending_insert = nil
        end
      else
        api.nvim_put({ item.alias }, "l", false, true)
        state._pending_insert = nil
      end
    end)
  end
end

---Attach the extra buffer-local keymaps chooser doesn't provide: y (yank
---without closing), A (insert all), <BS>/U (ignore/un-ignore + refresh in
---place), ? (help).
---@param bufnr integer
---@param state table  Recommender state table (visible, ignored, replace_mode, …)
function M.attach_extra(bufnr, state)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    return
  end

  local opts = { buffer = bufnr, silent = true, nowait = true }

  -- Yank selected alias to system clipboard without inserting or closing
  km_set("n", "y", function()
    local item = current_suggestion()
    if not item then
      return
    end
    vim.fn.setreg("+", item.alias)
    vim.fn.setreg("*", item.alias)
    notify.info("Yanked: " .. item.alias)
  end, opts)

  -- Insert ALL visible aliases at once into source buffer
  km_set("n", "A", function()
    if #state.visible == 0 then
      return
    end

    local all_aliases = {}
    for _, item in ipairs(state.visible) do
      all_aliases[#all_aliases + 1] = item.alias
    end

    local target_win = find_target_window()
    rendering.close()

    schedule(function()
      if not target_win or not api.nvim_win_is_valid(target_win) then
        notify.warn("No suitable window for insertion")
        return
      end
      api.nvim_set_current_win(target_win)
      api.nvim_put(all_aliases, "l", false, true)
      notify.info(("Inserted %d alias(es)"):format(#all_aliases))
    end)
  end, opts)

  -- Ignore current entry for this buffer session
  km_set("n", "<BS>", function()
    local item = current_suggestion()
    if not item then
      return
    end

    state.ignored[item.chain] = true

    state._restore_index = kit.chooser.current_index()
    local source_bufnr = state.source_bufnr
    schedule(function()
      if not (source_bufnr and api.nvim_buf_is_valid(source_bufnr)) then
        notify.warn("Source buffer no longer valid")
        rendering.close()
        return
      end
      api.nvim_buf_call(source_bufnr, state.refresh)
    end)
  end, opts)

  -- Un-ignore all → refresh
  km_set("n", "U", function()
    for k in pairs(state.ignored) do
      state.ignored[k] = nil
    end
    state._restore_index = kit.chooser.current_index()
    local source_bufnr = state.source_bufnr
    schedule(function()
      if not (source_bufnr and api.nvim_buf_is_valid(source_bufnr)) then
        notify.warn("Source buffer no longer valid")
        rendering.close()
        return
      end
      api.nvim_buf_call(source_bufnr, state.refresh)
    end)
  end, opts)

  -- Inline help
  km_set("n", "?", function()
    notify.info(table.concat({
      "Recommender keymaps:",
      "",
      "  j / k, ↓ / ↑   Navigate entries",
      "  Enter           Insert selected alias",
      "  y               Yank alias to clipboard",
      "  A               Insert ALL visible aliases",
      "  Backspace       Ignore entry (this session)",
      "  U               Un-ignore all",
      "  q / Esc         Close",
    }, "\n"))
  end, opts)
end

return M
