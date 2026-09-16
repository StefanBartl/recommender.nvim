-- TESTS/float_autocmds_spec.lua — recommender.float.autocmds: the one-shot
-- WinClosed detector that inserts a replace-mode alias once :Replace's
-- (Telescope) prompt window closes.
--
-- Deliberately excludes recommender.float.rendering/keymaps and
-- recommender.bindings.usrcmds: all three require "ui.kit" (ui.nvim) at
-- module load, which this repo's own CI does not check out (only lib.nvim is
-- a sibling there) -- requiring them here would pass locally and fail in CI.
-- float/autocmds.lua has no such dependency, only lib.nvim.bindings.autocmd,
-- so it is safe to exercise directly.

return function(H)
  local fa = require("recommender.float.autocmds")
  local api = vim.api

  ---@internal
  ---Open a scratch "prompt" window (split off the current one), tag its
  ---buffer's filetype, and return the window id.
  ---@param filetype string
  ---@return integer win
  local function open_prompt(filetype)
    vim.cmd("botright split")
    local win = api.nvim_get_current_win()
    vim.bo[api.nvim_win_get_buf(win)].filetype = filetype
    return win
  end

  -- Change detected + right filetype -> alias inserted, cursor moved back ----
  do
    local target_buf = api.nvim_create_buf(false, true)
    local target_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(target_win, target_buf)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, { "line1", "line2" })
    local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)

    local prompt_win = open_prompt("TelescopePrompt")
    fa.register_replace_finish(target_win, snapshot, "local x = vim.x")

    -- Simulate :Replace having changed the target buffer while the prompt was open.
    api.nvim_buf_set_lines(target_buf, 0, -1, false, { "line1", "line2 CHANGED" })
    api.nvim_win_close(prompt_win, true)

    H.eq(api.nvim_get_current_win(), target_win, "closing the Telescope prompt moves focus back to the target window")
    H.eq(
      api.nvim_buf_get_lines(target_buf, 0, -1, false)[1],
      "local x = vim.x",
      "the alias line was inserted at the top of the target buffer"
    )
  end

  -- No change -> nothing inserted, even though the filetype matched ----------
  do
    local target_buf = api.nvim_create_buf(false, true)
    local target_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(target_win, target_buf)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, { "unchanged" })
    local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)

    local prompt_win = open_prompt("TelescopePrompt")
    fa.register_replace_finish(target_win, snapshot, "should not appear")
    api.nvim_win_close(prompt_win, true)

    H.eq(#api.nvim_buf_get_lines(target_buf, 0, -1, false), 1, ":Replace was cancelled (buffer unchanged) -> nothing inserted")
  end

  -- Wrong filetype -> the detector never fires, even though the buffer changed
  do
    local target_buf = api.nvim_create_buf(false, true)
    local target_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(target_win, target_buf)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, { "line1" })
    local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)

    -- An ordinary split, not a TelescopePrompt -- e.g. the fzf picker backend.
    local other_win = open_prompt("")
    fa.register_replace_finish(target_win, snapshot, "should not appear")

    api.nvim_buf_set_lines(target_buf, 0, -1, false, { "line1", "changed after all" })
    api.nvim_win_close(other_win, true)

    H.eq(
      #api.nvim_buf_get_lines(target_buf, 0, -1, false),
      2,
      "a non-TelescopePrompt window closing must not trigger the insert -- known gap for other picker backends"
    )
    H.falsy(
      api.nvim_buf_get_lines(target_buf, 0, -1, false)[1] == "should not appear",
      "and specifically, the alias text was never put into the buffer"
    )
  end

  -- Target window already gone by the time the prompt closes -----------------
  do
    local target_buf = api.nvim_create_buf(false, true)
    local scratch_win = api.nvim_open_win(target_buf, false, {
      relative = "editor",
      row = 0,
      col = 0,
      width = 10,
      height = 1,
    })
    local snapshot = { "irrelevant" }

    local prompt_win = open_prompt("TelescopePrompt")
    fa.register_replace_finish(scratch_win, snapshot, "should not appear")

    api.nvim_win_close(scratch_win, true) -- target window closes before the prompt does
    local ok = pcall(api.nvim_win_close, prompt_win, true)
    H.ok(ok, "an invalid target window must not make the WinClosed handler raise")
  end
end
