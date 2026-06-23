---@module 'recommender_nvim.autocmds'
---Temporary autocmd used by replace-mode to detect when :Replace finishes.

local M = {}

local api = vim.api

---Register a one-shot WinClosed autocmd that fires after a TelescopePrompt window
---closes. Used to insert the alias after the :Replace command completes.
---@param target_win integer  Window to insert the alias into
---@param buf_snapshot string[]  Buffer lines before :Replace ran
---@param alias_text string  Alias line to insert if the buffer changed
function M.register_replace_finish(target_win, buf_snapshot, alias_text)
  local group = api.nvim_create_augroup("RecommenderNvimReplaceInsert", { clear = true })

  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      local winid = tonumber(args.match)
      if not winid then return end

      -- Only react to Telescope prompt windows closing
      if api.nvim_win_is_valid(winid) then
        local closed_buf = api.nvim_win_get_buf(winid)
        if vim.bo[closed_buf].filetype ~= "TelescopePrompt" then
          return
        end
      end

      -- One-shot: remove immediately
      pcall(api.nvim_del_augroup_by_id, group)

      if not api.nvim_win_is_valid(target_win) then return end

      local buf = api.nvim_win_get_buf(target_win)
      if not api.nvim_buf_is_valid(buf) then return end

      -- Compare snapshot with current lines to determine if Replace ran
      local new_lines = api.nvim_buf_get_lines(buf, 0, -1, false)
      local changed = #new_lines ~= #buf_snapshot
      if not changed then
        for i = 1, #buf_snapshot do
          if buf_snapshot[i] ~= new_lines[i] then
            changed = true
            break
          end
        end
      end

      if changed then
        api.nvim_set_current_win(target_win)
        api.nvim_put({ alias_text }, "l", false, true)
      end
    end,
  })
end

return M
