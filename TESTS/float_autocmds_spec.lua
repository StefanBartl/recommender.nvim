-- TESTS/float_autocmds_spec.lua — recommender.float.autocmds: the one-shot
-- watcher that inserts a replace-mode alias once :Replace's picker window
-- (Telescope prompt or fzf-lua terminal) closes and the buffer changed.
--
-- Deliberately excludes recommender.float.rendering/keymaps and
-- recommender.bindings.usrcmds here: all three require "ui.kit" (ui.nvim) at
-- module load, which this repo's own CI does not check out (only lib.nvim is
-- a sibling there) -- requiring them here would pass locally and fail in CI.
-- float/autocmds.lua has no such dependency, only lib.nvim.bindings.autocmd,
-- so it is safe to exercise directly.
--
-- The picker windows are doubles: an ordinary split whose buffer carries the
-- backend's filetype (`TelescopePrompt`, `fzf`). No real picker is needed.
--
-- The three ui.kit-adjacent modules' pure logic (no rendering, no picker) is
-- covered separately in TESTS/usrcmds_spec.lua, TESTS/rendering_spec.lua, and
-- TESTS/float_keymaps_spec.lua, which unlock the require by dropping a
-- minimal stub into `package.loaded["ui.kit"]` before it happens -- CI still
-- never needs a real ui.nvim checkout.

return function(H)
  local fa = require("recommender.float.autocmds")
  local api = vim.api

  local BACKENDS = { "TelescopePrompt", "fzf" }
  local orig_buf = api.nvim_get_current_buf()

  local created = {} ---@type integer[]
  ---@return integer buf  a scratch buffer, wiped at the end of the spec
  local function scratch()
    local buf = api.nvim_create_buf(false, true)
    created[#created + 1] = buf
    return buf
  end

  ---@internal
  ---Open a scratch "prompt" window (split off the current one), tag its
  ---buffer's filetype, and return the window id.
  ---@param filetype string
  ---@return integer win
  local function open_prompt(filetype)
    vim.cmd("botright split")
    local win = api.nvim_get_current_win()
    local buf = scratch()
    api.nvim_win_set_buf(win, buf)
    vim.bo[buf].filetype = filetype
    return win
  end

  ---@internal
  ---A fresh target window/buffer with `lines`.
  ---@param lines string[]
  ---@return integer win, integer buf
  local function target(lines)
    vim.cmd("silent! only")
    local buf = scratch()
    local win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    return win, buf
  end

  ---@return boolean
  local function watcher_armed()
    return pcall(api.nvim_get_autocmds, { group = "RecommenderNvimReplaceInsert" })
      and #api.nvim_get_autocmds({ group = "RecommenderNvimReplaceInsert" }) > 0
  end

  ---Let scheduled callbacks run.
  local function flush()
    vim.wait(30, function()
      return false
    end, 5)
  end

  local unrecognised = {} ---@type string[]
  local opts = {
    start_timeout_ms = 60,
    on_unrecognised = function(msg)
      unrecognised[#unrecognised + 1] = msg
    end,
  }

  for _, ft in ipairs(BACKENDS) do
    -- Both backends close the window BEFORE running the apply. The insert
    -- must still see the change (it is decided on the next tick). -----------
    do
      local target_win, target_buf = target({ "line1", "line2" })
      local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)

      local prompt_win = open_prompt(ft)
      fa.register_replace_finish(target_win, snapshot, "local x = vim.x", opts)

      -- Same order as replacer's pickers: close the window, then apply.
      api.nvim_win_close(prompt_win, true)
      api.nvim_buf_set_lines(target_buf, 0, -1, false, { "line1", "line2 CHANGED" })

      H.wait_until(function()
        return api.nvim_buf_get_lines(target_buf, 0, 1, false)[1] == "local x = vim.x"
      end, ft .. ": the alias line is inserted although the apply ran after the window closed")
      H.eq(api.nvim_get_current_win(), target_win, ft .. ": focus moves back to the target window")
      H.falsy(watcher_armed(), ft .. ": the watcher is removed after the insert")
    end

    -- Change made while the picker was still open -> inserted as well -------
    do
      local target_win, target_buf = target({ "a" })
      local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
      local prompt_win = open_prompt(ft)
      fa.register_replace_finish(target_win, snapshot, "local y = vim.y", opts)
      api.nvim_buf_set_lines(target_buf, 0, -1, false, { "b" })
      api.nvim_win_close(prompt_win, true)
      H.wait_until(function()
        return api.nvim_buf_get_lines(target_buf, 0, 1, false)[1] == "local y = vim.y"
      end, ft .. ": change before the close -> alias inserted")
    end

    -- Cancelled (buffer unchanged) -> nothing inserted, watcher removed ------
    do
      local target_win, target_buf = target({ "unchanged" })
      local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
      local prompt_win = open_prompt(ft)
      fa.register_replace_finish(target_win, snapshot, "should not appear", opts)
      api.nvim_win_close(prompt_win, true)
      flush()
      H.eq(
        table.concat(api.nvim_buf_get_lines(target_buf, 0, -1, false), "|"),
        "unchanged",
        ft .. ": :Replace cancelled (buffer unchanged) -> nothing inserted"
      )
      H.falsy(watcher_armed(), ft .. ": a cancel removes the watcher (no stale insert on a later picker)")
    end

    -- Replace-and-reopen: another picker window is still open -> wait for it -
    do
      local target_win, target_buf = target({ "l1" })
      local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
      local first = open_prompt(ft)
      fa.register_replace_finish(target_win, snapshot, "local z = vim.z", opts)
      local second = open_prompt(ft)
      api.nvim_win_close(first, true)
      api.nvim_buf_set_lines(target_buf, 0, -1, false, { "l1 CHANGED" })
      flush()
      H.eq(#api.nvim_buf_get_lines(target_buf, 0, -1, false), 1, ft .. ": no insert while a reopened picker is open")
      api.nvim_win_close(second, true)
      H.wait_until(function()
        return api.nvim_buf_get_lines(target_buf, 0, 1, false)[1] == "local z = vim.z"
      end, ft .. ": inserted once the last picker window closed")
    end

    -- Replace-and-reopen in the order replacer really uses: close, apply, and
    -- only then schedule the reopen. The alias must wait for the reopened
    -- picker: inserting it after the first apply shifts every line below it,
    -- and replacer skips the remaining (now stale) matches. ----------------
    do
      local target_win, target_buf = target({ "l1", "l2" })
      local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
      local first = open_prompt(ft)
      fa.register_replace_finish(target_win, snapshot, "local r = vim.r", opts)
      local reopened ---@type integer?
      api.nvim_win_close(first, true)
      api.nvim_buf_set_lines(target_buf, 0, 1, false, { "l1 CHANGED" })
      vim.schedule(function()
        reopened = open_prompt(ft)
      end)
      flush()
      H.ok(reopened ~= nil, ft .. ": the reopened picker is open")
      H.eq(
        table.concat(api.nvim_buf_get_lines(target_buf, 0, -1, false), "|"),
        "l1 CHANGED|l2",
        ft .. ": no insert after the first apply of a replace-and-reopen"
      )
      api.nvim_win_close(reopened --[[@as integer]], true)
      api.nvim_buf_set_lines(target_buf, 1, 2, false, { "l2 CHANGED" })
      H.wait_until(function()
        return api.nvim_buf_get_lines(target_buf, 0, 1, false)[1] == "local r = vim.r"
      end, ft .. ": inserted once the reopened picker closed")
    end

    -- Apply-all with replacer's default `confirm_all = true`: the picker
    -- closes, a lib.nvim confirm float opens, and the apply runs only on
    -- "Yes" (synchronously, right after the float closed). -----------------
    do
      local target_win, target_buf = target({ "c1" })
      local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
      local picker = open_prompt(ft)
      fa.register_replace_finish(target_win, snapshot, "local c = vim.c", opts)
      api.nvim_win_close(picker, true)
      local confirm_win = open_prompt("lib-kit-confirm")
      flush()
      H.ok(watcher_armed(), ft .. ": the watcher waits while the apply-all confirmation is open")
      api.nvim_win_close(confirm_win, true)
      api.nvim_buf_set_lines(target_buf, 0, -1, false, { "c1 CHANGED" })
      H.wait_until(function()
        return api.nvim_buf_get_lines(target_buf, 0, 1, false)[1] == "local c = vim.c"
      end, ft .. ": confirmed apply-all -> alias inserted")
    end

    -- ... and answered "No": nothing inserted, watcher removed --------------
    do
      local target_win, target_buf = target({ "n1" })
      local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
      local picker = open_prompt(ft)
      fa.register_replace_finish(target_win, snapshot, "should not appear", opts)
      api.nvim_win_close(picker, true)
      local confirm_win = open_prompt("lib-kit-confirm")
      flush()
      api.nvim_win_close(confirm_win, true)
      flush()
      H.eq(
        table.concat(api.nvim_buf_get_lines(target_buf, 0, -1, false), "|"),
        "n1",
        ft .. ": apply-all declined -> nothing inserted"
      )
      H.falsy(watcher_armed(), ft .. ": and the watcher is removed")
    end
  end

  H.eq(#unrecognised, 0, "a recognised picker never triggers the 'not recognised' notification")

  -- A non-picker window closing is ignored; the watcher stays armed ----------
  do
    local target_win, target_buf = target({ "line1" })
    local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
    local prompt_win = open_prompt("fzf")
    local other_win = open_prompt("")
    fa.register_replace_finish(target_win, snapshot, "local w = vim.w", opts)

    api.nvim_buf_set_lines(target_buf, 0, -1, false, { "line1", "changed" })
    api.nvim_win_close(other_win, true)
    flush()
    H.eq(#api.nvim_buf_get_lines(target_buf, 0, -1, false), 2, "an unrelated window closing does not insert")
    H.ok(watcher_armed(), "and the watcher is still armed")
    api.nvim_win_close(prompt_win, true)
    H.wait_until(function()
      return api.nvim_buf_get_lines(target_buf, 0, 1, false)[1] == "local w = vim.w"
    end, "the picker closing afterwards inserts")
  end

  -- No picker ever opens and nothing changes -> notification, watcher gone ---
  do
    local target_win, target_buf = target({ "x" })
    local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
    fa.register_replace_finish(target_win, snapshot, "local v = vim.v", opts)
    H.wait_until(function()
      return #unrecognised == 1
    end, "an unrecognised picker (or no matches) is reported instead of failing silently")
    H.ok(unrecognised[1]:find("local v = vim.v", 1, true) ~= nil, "the notification names the alias")
    H.falsy(watcher_armed(), "and the watcher is removed")
    H.eq(table.concat(api.nvim_buf_get_lines(target_buf, 0, -1, false), "|"), "x", "nothing inserted")
  end

  -- No picker, but the buffer changed (applied directly) -> inserted ---------
  do
    local target_win, target_buf = target({ "x" })
    local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
    fa.register_replace_finish(target_win, snapshot, "local u = vim.u", opts)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, { "y" })
    H.wait_until(function()
      return api.nvim_buf_get_lines(target_buf, 0, 1, false)[1] == "local u = vim.u"
    end, "a :Replace that applied without a picker still gets its alias")
    H.eq(#unrecognised, 1, "no extra notification in that case")
  end

  -- Re-arming supersedes the previous watcher; its timer stays silent --------
  do
    local target_win, target_buf = target({ "x" })
    local snapshot = api.nvim_buf_get_lines(target_buf, 0, -1, false)
    fa.register_replace_finish(target_win, snapshot, "old", opts)
    local prompt_win = open_prompt("TelescopePrompt")
    fa.register_replace_finish(target_win, snapshot, "new", opts)
    vim.wait(120, function()
      return false
    end, 5)
    H.eq(#unrecognised, 1, "the superseded watcher's timer does not notify")
    api.nvim_win_close(prompt_win, true)
    flush()
    H.eq(table.concat(api.nvim_buf_get_lines(target_buf, 0, -1, false), "|"), "x", "nothing inserted on cancel")
  end

  -- Target window already gone by the time the prompt closes -----------------
  do
    vim.cmd("silent! only")
    local target_buf = scratch()
    local scratch_win = api.nvim_open_win(target_buf, false, {
      relative = "editor",
      row = 0,
      col = 0,
      width = 10,
      height = 1,
    })
    local snapshot = { "irrelevant" }

    local prompt_win = open_prompt("TelescopePrompt")
    fa.register_replace_finish(scratch_win, snapshot, "should not appear", opts)

    api.nvim_win_close(scratch_win, true) -- target window closes before the prompt does
    local ok = pcall(api.nvim_win_close, prompt_win, true)
    flush()
    H.ok(ok, "an invalid target window must not make the WinClosed handler raise")
    H.falsy(watcher_armed(), "and the watcher is removed")
  end

  vim.cmd("silent! only")
  api.nvim_win_set_buf(0, orig_buf)
  for _, buf in ipairs(created) do
    pcall(api.nvim_buf_delete, buf, { force = true })
  end
end
