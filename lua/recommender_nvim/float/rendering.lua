---@module 'recommender_nvim.float.rendering'
---Float window: open, close, state, and syntax highlighting.

local notify = require("recommender_nvim.util.notify").create("[recommender_nvim]")

local M = {}

local api = vim.api

local NS = api.nvim_create_namespace("recommender_nvim")

M.float_buf = nil ---@type integer|nil
M.float_win = nil ---@type integer|nil
M.source_win = nil ---@type integer|nil
M.cursor_index = 2 -- 1-based line, starts at first selectable entry

---@return boolean
function M.is_open()
  return M.float_win ~= nil and api.nvim_win_is_valid(M.float_win)
end

function M.close()
  if M.float_win and api.nvim_win_is_valid(M.float_win) then
    pcall(api.nvim_win_close, M.float_win, true)
  end
  if M.float_buf and api.nvim_buf_is_valid(M.float_buf) then
    pcall(api.nvim_buf_delete, M.float_buf, { force = true })
  end
  M.float_buf = nil
  M.float_win = nil
  M.source_win = nil
  M.cursor_index = 2
end

---Build the display lines for a list of suggestions.
---Format per suggestion (3 lines):
---   → chain.name (N hits)
---     local alias = chain.name
---   (blank)
---@param suggestions {chain:string, count:integer, alias:string}[]
---@return string[]
local function build_lines(suggestions)
  local lines = { "" }
  for _, s in ipairs(suggestions) do
    lines[#lines + 1] = ("→ %s (%d hits)"):format(s.chain, s.count)
    lines[#lines + 1] = "  " .. s.alias
    lines[#lines + 1] = ""
  end
  return lines
end

---Apply syntax highlights to the float buffer.
---@param buf integer
---@param suggestions {chain:string, count:integer, alias:string}[]
---@param lines string[]
local function apply_highlights(buf, suggestions, lines)
  api.nvim_buf_clear_namespace(buf, NS, 0, -1)

  for i = 1, #suggestions do
    local chain_row = 1 + (i - 1) * 3 -- 0-based row index
    local alias_row = chain_row + 1

    local chain_line = lines[chain_row + 1] -- lines is 1-indexed

    -- "→" arrow (3 UTF-8 bytes)
    api.nvim_buf_add_highlight(buf, NS, "Special", chain_row, 0, 3)
    -- chain name: after "→ " (byte 4 onwards)
    local paren_byte = chain_line:find(" %(") -- 1-based byte position
    if paren_byte then
      api.nvim_buf_add_highlight(buf, NS, "Identifier", chain_row, 4, paren_byte - 1)
      api.nvim_buf_add_highlight(buf, NS, "Comment", chain_row, paren_byte - 1, -1)
    else
      api.nvim_buf_add_highlight(buf, NS, "Identifier", chain_row, 4, -1)
    end

    -- alias line: full line as Statement
    api.nvim_buf_add_highlight(buf, NS, "Statement", alias_row, 0, -1)
  end
end

---Open (or reopen) the float window with the given suggestions.
---@param suggestions {chain:string, count:integer, alias:string}[]
---@param title string
---@param restore_index integer|nil  Restore cursor to this line index
function M.open(suggestions, title, restore_index)
  M.source_win = api.nvim_get_current_win()
  M.close()

  if #suggestions == 0 then
    return
  end

  M.float_buf = api.nvim_create_buf(false, true)
  if not M.float_buf or M.float_buf == 0 then
    notify.error("Failed to create buffer")
    return
  end

  local lines = build_lines(suggestions)

  vim.bo[M.float_buf].buftype = "nofile"
  vim.bo[M.float_buf].bufhidden = "wipe"
  vim.bo[M.float_buf].swapfile = false

  api.nvim_buf_set_lines(M.float_buf, 0, -1, false, lines)
  vim.bo[M.float_buf].modifiable = false

  -- Calculate window size
  local width = 52
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 2)
  end
  width = math.min(width, vim.o.columns - 8)
  local height = math.min(#lines + 2, vim.o.lines - 8)

  M.float_win = api.nvim_open_win(M.float_buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  if not M.float_win or M.float_win == 0 then
    notify.error("Failed to create window")
    M.close()
    return
  end

  vim.wo[M.float_win].cursorline = true
  vim.wo[M.float_win].wrap = false
  vim.wo[M.float_win].number = false
  vim.wo[M.float_win].relativenumber = false
  vim.wo[M.float_win].signcolumn = "no"

  -- Set cursor
  M.cursor_index = (restore_index and restore_index >= 2) and restore_index or 2
  if M.cursor_index > #lines then
    M.cursor_index = 2
  end
  pcall(api.nvim_win_set_cursor, M.float_win, { M.cursor_index, 0 })

  apply_highlights(M.float_buf, suggestions, lines)
end

return M
