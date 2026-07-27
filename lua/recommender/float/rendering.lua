---@module 'recommender.float.rendering'
---Float window: builds `kit.select` rich items from suggestions and opens/
---closes the picker. Navigation, the current-item highlight, multi-select,
---and the multi-line/per-column highlighting are all handled by
---lib.nvim.ui.kit's chooser now (see UI-KIT-CONCEPT.md §13b) -- this module
---only builds the item list and owns the bit of state other recommender
---modules still need (`source_win`, whether a picker is open).

local kit = require("lib.nvim.ui.kit")

local M = {}

M.source_win = nil ---@type integer|nil

---@return boolean
function M.is_open()
  return kit.chooser.is_open()
end

function M.close()
  kit.chooser.close()
end

---Build one rich `kit.select` item for a suggestion. `item.suggestion` carries
---the original `{chain, count, alias}` back out through `on_select`/
---`kit.chooser.current_item()`.
---@param s {chain:string, count:integer, alias:string}
---@param layout "detailed"|"compact"
---@return table item  # { lines, highlights, suggestion }
local function build_item(s, layout)
  if layout == "compact" then
    local line = ("→ %s (%d)  %s"):format(s.chain, s.count, s.alias)
    local highlights = { { line = 0, col_start = 0, col_end = 3, hl_group = "Special" } }
    local paren_byte = line:find(" %(")
    if not paren_byte then
      highlights[#highlights + 1] = { line = 0, col_start = 4, hl_group = "Identifier" }
    else
      highlights[#highlights + 1] = { line = 0, col_start = 4, col_end = paren_byte - 1, hl_group = "Identifier" }
      local close_byte = line:find("%)", paren_byte)
      if not close_byte then
        highlights[#highlights + 1] = { line = 0, col_start = paren_byte - 1, hl_group = "Comment" }
      else
        highlights[#highlights + 1] = { line = 0, col_start = paren_byte - 1, col_end = close_byte, hl_group = "Comment" }
        highlights[#highlights + 1] = { line = 0, col_start = close_byte, hl_group = "Statement" }
      end
    end
    return { lines = { line }, highlights = highlights, suggestion = s }
  end

  local chain_line = ("→ %s (%d hits)"):format(s.chain, s.count)
  local alias_line = "  " .. s.alias
  local highlights = { { line = 0, col_start = 0, col_end = 3, hl_group = "Special" } }
  local paren_byte = chain_line:find(" %(")
  if paren_byte then
    highlights[#highlights + 1] = { line = 0, col_start = 4, col_end = paren_byte - 1, hl_group = "Identifier" }
    highlights[#highlights + 1] = { line = 0, col_start = paren_byte - 1, hl_group = "Comment" }
  else
    highlights[#highlights + 1] = { line = 0, col_start = 4, hl_group = "Identifier" }
  end
  highlights[#highlights + 1] = { line = 1, hl_group = "Statement" }

  return { lines = { chain_line, alias_line, "" }, highlights = highlights, suggestion = s }
end

---Open (or reopen) the picker with the given suggestions.
---@param suggestions {chain:string, count:integer, alias:string}[]
---@param title string
---@param restore_index integer|nil  Restore cursor to this logical item index
---@param layout "detailed"|"compact"|nil  Defaults to "detailed"
---@param on_select fun(suggestion: table)  Fired on <CR> with the chosen suggestion
---@return Lib.UI.Kit.Surface|nil surf
function M.open(suggestions, title, restore_index, layout, on_select)
  M.source_win = vim.api.nvim_get_current_win()
  M.close()

  if #suggestions == 0 then
    return nil
  end

  layout = (layout == "compact") and "compact" or "detailed"

  local items = {}
  for i, s in ipairs(suggestions) do
    items[i] = build_item(s, layout)
  end

  return kit.select({
    items = items,
    title = title,
    relative = "editor",
    initial_index = restore_index,
    on_select = function(item)
      if on_select then
        on_select(item.suggestion)
      end
    end,
  })
end

return M
