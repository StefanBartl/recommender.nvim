-- TESTS/float_keymaps_spec.lua — recommender.float.keymaps's pure
-- window-selection helpers (`M._internal.is_normal_window`,
-- `M._internal.find_target_window`): picking a real, modifiable, ordinary
-- window to insert an alias into once the suggestion float has focus.
-- Neither helper touches `kit` at all.
--
-- float/keymaps.lua requires "ui.kit" (ui.nvim) at module load --
-- unavailable in this repo's own CI (only lib.nvim is checked out as a
-- sibling there, see TESTS/README.md). A minimal stub dropped into
-- `package.loaded["ui.kit"]` before the first `require` is enough to unlock
-- it, without needing a real ui.nvim checkout anywhere -- see
-- TESTS/usrcmds_spec.lua and TESTS/rendering_spec.lua for the same
-- technique against the other two ui.kit-adjacent modules.
if not package.loaded["ui.kit"] then
  package.loaded["ui.kit"] = {}
end

return function(H)
  local fk = require("recommender.float.keymaps")
  local rendering = require("recommender.float.rendering")
  local api = vim.api
  local is_normal_window = fk._internal.is_normal_window
  local find_target_window = fk._internal.find_target_window

  ---@internal
  ---Open a new window on a fresh, dedicated buffer, with the given buftype/
  ---modifiable state, and return its window id.
  ---
  ---`:new` rather than `:split`: `:split` opens a second window onto the
  ---*same* buffer, so setting buftype/modifiable on it would also change
  ---every other window currently showing that buffer -- including whichever
  ---window this function was called from. `:new` starts a fresh, empty
  ---buffer per window, so each call's buftype/modifiable is that window's
  ---own and cannot leak into any other.
  ---@param buftype string  "" for an ordinary window
  ---@param modifiable boolean
  ---@return integer win
  local function open_window(buftype, modifiable)
    vim.cmd("botright new")
    local win = api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    vim.bo[buf].buftype = buftype
    vim.bo[buf].modifiable = modifiable
    return win
  end

  -- is_normal_window ------------------------------------------------------------
  do
    local ordinary = open_window("", true)
    H.ok(is_normal_window(ordinary), "an ordinary, modifiable window is normal")

    local special = open_window("nofile", true)
    H.falsy(is_normal_window(special), "a special buftype (e.g. nofile) is not normal")

    local locked = open_window("", false)
    H.falsy(is_normal_window(locked), "a non-modifiable window is not normal, even with buftype=''")

    api.nvim_win_close(ordinary, true)
    api.nvim_win_close(special, true)
    api.nvim_win_close(locked, true)
    H.falsy(is_normal_window(ordinary), "a closed window id is never normal")
    H.falsy(is_normal_window(999999), "a window id that never existed is never normal")
  end

  -- find_target_window: rendering.source_win wins outright ---------------------
  do
    local source = open_window("", true)
    local other = open_window("", true) -- current window when find_target_window() runs

    local saved_source_win = rendering.source_win
    rendering.source_win = source

    H.eq(find_target_window(), source, "a valid, normal rendering.source_win is used regardless of the current window")

    rendering.source_win = saved_source_win
    api.nvim_win_close(source, true)
    api.nvim_win_close(other, true)
  end

  -- find_target_window: falls back to the alternate window ----------------------
  do
    local a = open_window("", true)
    local b = open_window("", true) -- switching a -> b makes a the alternate ("#") window

    local saved_source_win = rendering.source_win
    rendering.source_win = nil -- no picker-remembered source window

    H.eq(vim.fn.win_getid(vim.fn.winnr("#")), a, "sanity: the alternate window really is 'a' after splitting from it")
    H.eq(find_target_window(), a, "with no usable source_win, falls back to the alternate window")

    rendering.source_win = saved_source_win
    api.nvim_win_close(a, true)
    api.nvim_win_close(b, true)
  end

  -- find_target_window: falls back to the first normal window in the list ------
  -- `normal_elsewhere` is opened *first*, then two special windows on top of
  -- it, so whichever of the two specials ends up as the alternate ("#")
  -- window, it is not normal -- source_win and the alternate both miss,
  -- forcing the third-tier fallback (a scan of every window) to be what
  -- actually finds `normal_elsewhere`.
  do
    local normal_elsewhere = open_window("", true)
    local special_1 = open_window("nofile", true)
    local special_2 = open_window("nofile", true)

    local saved_source_win = rendering.source_win
    rendering.source_win = nil

    H.falsy(is_normal_window(vim.fn.win_getid(vim.fn.winnr("#"))), "sanity: the alternate window is not normal here")
    H.eq(find_target_window(), normal_elsewhere, "falls through to the one normal window left in the list")

    rendering.source_win = saved_source_win
    api.nvim_win_close(special_1, true)
    api.nvim_win_close(special_2, true)
    api.nvim_win_close(normal_elsewhere, true)
  end

  -- find_target_window: no normal window anywhere -> nil -----------------------
  do
    -- Make every window currently open special, so none of them qualifies.
    local made_special = {}
    for _, win in ipairs(api.nvim_list_wins()) do
      local buf = api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "" then
        vim.bo[buf].buftype = "nofile"
        made_special[#made_special + 1] = buf
      end
    end

    local saved_source_win = rendering.source_win
    rendering.source_win = nil

    H.falsy(find_target_window(), "no normal window anywhere -> nil, not a wrong guess")

    rendering.source_win = saved_source_win
    for _, buf in ipairs(made_special) do
      vim.bo[buf].buftype = ""
    end
  end
end
