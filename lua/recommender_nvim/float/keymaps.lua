---@module 'recommender_nvim.float.keymaps'
---Buffer-local keymaps for the Recommender float window.

local notify = require("recommender_nvim.util.notify").create("[recommender_nvim]")
local rendering = require("recommender_nvim.float.rendering")

local M = {}

local api = vim.api
local km_set = vim.keymap.set
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

---Returns true when line (1-based) is a chain header line in the float.
---Layout: line 1 = blank, then groups of 3: chain / alias / blank.
---@param line integer
---@return boolean
local function is_selectable(line)
  return line > 1 and (line - 2) % 3 == 0
end

---Move float cursor to the next/previous selectable line.
---@param delta integer  +3 or -3
local function move(delta)
  if not rendering.is_open() then
    return
  end
  local ok, cursor = pcall(api.nvim_win_get_cursor, rendering.float_win)
  if not ok then
    return
  end

  local total = api.nvim_buf_line_count(rendering.float_buf)
  local target = cursor[1] + delta

  while target >= 2 and target <= total do
    if is_selectable(target) then
      pcall(api.nvim_win_set_cursor, rendering.float_win, { target, 0 })
      rendering.cursor_index = target
      return
    end
    target = target + delta
  end
end

---Get the suggestion item at the current cursor position.
---@param state table
---@return table|nil
local function current_item(state)
  local idx = math.floor((rendering.cursor_index - 2) / 3) + 1
  return state.visible[idx]
end

-- ── public ─────────────────────────────────────────────────────────────────

---Attach all buffer-local keymaps to the float buffer.
---@param bufnr integer
---@param state table  Recommender state table (visible, ignored, replace_mode, …)
function M.attach(bufnr, state)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    return
  end

  local opts = { buffer = bufnr, silent = true, nowait = true }

  -- Navigation
  km_set("n", "j", function()
    move(3)
  end, opts)
  km_set("n", "k", function()
    move(-3)
  end, opts)
  km_set("n", "<Down>", function()
    move(3)
  end, opts)
  km_set("n", "<Up>", function()
    move(-3)
  end, opts)

  -- Close
  km_set("n", "q", rendering.close, opts)
  km_set("n", "<Esc>", rendering.close, opts)

  -- Insert selected alias into source buffer
  km_set("n", "<CR>", function()
    if not rendering.is_open() then
      return
    end
    local item = current_item(state)
    if not item then
      return
    end

    local target_win = find_target_window()
    if not target_win then
      notify.warn("No suitable window for insertion")
      return
    end

    state._pending_insert = { win = target_win, text = item.alias }
    rendering.close()

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

        require("recommender_nvim.float.autocmds").register_replace_finish(target_win, snapshot, item.alias)

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
  end, opts)

  -- Yank selected alias to system clipboard without inserting or closing
  km_set("n", "y", function()
    if not rendering.is_open() then
      return
    end
    local item = current_item(state)
    if not item then
      return
    end
    vim.fn.setreg("+", item.alias)
    vim.fn.setreg("*", item.alias)
    notify.info("Yanked: " .. item.alias)
  end, opts)

  -- Insert ALL visible aliases at once into source buffer
  km_set("n", "A", function()
    if not rendering.is_open() then
      return
    end
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
    if not rendering.is_open() then
      return
    end
    local item = current_item(state)
    if not item then
      return
    end

    state.ignored[item.chain] = true

    local source_bufnr = state.source_bufnr
    if source_bufnr and api.nvim_buf_is_valid(source_bufnr) then
      schedule(function()
        api.nvim_buf_call(source_bufnr, state.refresh)
      end)
    else
      notify.warn("Source buffer no longer valid")
      rendering.close()
    end
  end, opts)

  -- Un-ignore all → refresh
  km_set("n", "U", function()
    if not rendering.is_open() then
      return
    end
    for k in pairs(state.ignored) do
      state.ignored[k] = nil
    end
    local source_bufnr = state.source_bufnr
    if source_bufnr and api.nvim_buf_is_valid(source_bufnr) then
      schedule(function()
        api.nvim_buf_call(source_bufnr, state.refresh)
      end)
    else
      notify.warn("Source buffer no longer valid")
      rendering.close()
    end
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
