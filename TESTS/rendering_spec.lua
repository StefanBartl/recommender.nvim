-- TESTS/rendering_spec.lua — recommender.float.rendering's pure item-building
-- half (`M._internal.build_item`): turning one `{chain, count, alias}`
-- suggestion into the lines/highlights `kit.select` renders, for both the
-- "detailed" and "compact" `float_layout`s. No `kit.select`/`kit.chooser`
-- call is involved in any of this -- that half (actually opening/closing a
-- picker) is exactly the "needs a real live backend" UI this campaign
-- excludes, and stays untested here.
--
-- rendering.lua requires "ui.kit" (ui.nvim) at module load -- unavailable in
-- this repo's own CI (only lib.nvim is checked out as a sibling there, see
-- TESTS/README.md). `build_item` never touches `kit`, so a minimal stub
-- dropped into `package.loaded["ui.kit"]` before the first `require` is
-- enough to unlock it, without needing a real ui.nvim checkout anywhere --
-- see TESTS/usrcmds_spec.lua and TESTS/float_keymaps_spec.lua for the same
-- technique against the other two ui.kit-adjacent modules.
if not package.loaded["ui.kit"] then
  package.loaded["ui.kit"] = {}
end

return function(H)
  local rendering = require("recommender.float.rendering")
  local build_item = rendering._internal.build_item

  ---@internal
  ---Look a highlight up by its `hl_group`, so a case does not depend on
  ---array position beyond what it is explicitly asserting.
  ---@param highlights table[]
  ---@param hl_group string
  ---@return table|nil
  local function by_group(highlights, hl_group)
    for _, h in ipairs(highlights) do
      if h.hl_group == hl_group then
        return h
      end
    end
    return nil
  end

  local suggestion = { chain = "vim.api.nvim_buf_set_lines", count = 3, alias = "local set_lines = vim.api.nvim_buf_set_lines" }

  -- Detailed layout (the default) ----------------------------------------------
  do
    local item = build_item(suggestion, "detailed")
    H.eq(#item.lines, 3, "detailed layout: chain line, alias line, blank spacer")
    H.eq(item.lines[1], "→ vim.api.nvim_buf_set_lines (3 hits)", "chain line names the chain and its hit count")
    H.eq(item.lines[2], "  local set_lines = vim.api.nvim_buf_set_lines", "alias line is indented")
    H.eq(item.lines[3], "", "third line is a blank spacer")
    H.eq(item.suggestion, suggestion, "the original suggestion table is carried through unchanged")

    local arrow = by_group(item.highlights, "Special")
    H.ok(arrow, "the arrow glyph is highlighted")
    H.eq(arrow.line, 0, "...on the chain line")
    H.eq(arrow.col_start, 0, "...from the start")
    H.eq(arrow.col_end, 3, "...3 bytes ('→' is a 3-byte UTF-8 glyph)")

    local ident = by_group(item.highlights, "Identifier")
    H.ok(ident, "the chain itself is highlighted")
    H.eq(ident.line, 0, "...on the chain line")
    H.eq(ident.col_start, 4, "...starting right after '→ '")
    H.ok(
      item.lines[1]:sub(ident.col_start + 1, ident.col_end) == "vim.api.nvim_buf_set_lines",
      "...spanning exactly the chain text"
    )

    local comment = by_group(item.highlights, "Comment")
    H.ok(comment, "the hit-count parenthetical is highlighted")
    H.eq(comment.col_start, ident.col_end, "...starting right where the chain highlight ends")

    local statement = by_group(item.highlights, "Statement")
    H.ok(statement, "the alias line has its own highlight")
    H.eq(statement.line, 1, "...on line 1 (the alias line), not the chain line")
  end

  -- Compact layout ---------------------------------------------------------------
  do
    local item = build_item(suggestion, "compact")
    H.eq(#item.lines, 1, "compact layout: exactly one line, no spacer")
    H.eq(
      item.lines[1],
      "→ vim.api.nvim_buf_set_lines (3)  local set_lines = vim.api.nvim_buf_set_lines",
      "chain, count, and alias all on the single line"
    )

    local arrow = by_group(item.highlights, "Special")
    H.eq(arrow.col_start, 0, "the arrow is still highlighted from the start")
    H.eq(arrow.col_end, 3, "...3 bytes, same as detailed")

    local ident = by_group(item.highlights, "Identifier")
    H.ok(
      item.lines[1]:sub(ident.col_start + 1, ident.col_end) == "vim.api.nvim_buf_set_lines",
      "the chain highlight spans exactly the chain text"
    )

    local comment = by_group(item.highlights, "Comment")
    H.ok(comment, "the count parenthetical is highlighted")

    -- Compact has a fourth highlight the detailed layout does not: the text
    -- after the closing paren (the alias) gets its own Statement span on the
    -- *same* line, since compact has no separate alias line to put it on.
    local statement = by_group(item.highlights, "Statement")
    H.ok(statement, "the trailing alias text is highlighted too")
    H.eq(statement.line, 0, "...on the same (only) line")
    H.eq(statement.col_start, comment.col_end, "...starting right where the count highlight ends")
  end

  -- An unrecognized layout value falls back to "detailed", same as nil.
  do
    local nil_item = build_item(suggestion, nil)
    local weird_item = build_item(suggestion, "something_else")
    H.eq(#nil_item.lines, 3, "nil layout behaves like detailed")
    H.eq(#weird_item.lines, 3, "an unrecognized layout string also behaves like detailed")
  end

  -- A single-segment chain (no dots) still produces well-formed output.
  do
    local item = build_item({ chain = "print", count = 1, alias = "local print_ = print" }, "detailed")
    H.eq(item.lines[1], "→ print (1 hits)", "singular/plural is not this function's job -- it always says 'hits'")
  end
end
