---@module 'recommender.float.keymaps'
---Buffer-local keymaps for the Recommender float window. Navigation
---(j/k/arrows/mouse), <CR>-submits, and q/<Esc>-closes are handled by
---lib.nvim.ui.kit's chooser itself now -- this
---module only builds the <CR> handler passed into `rendering.open()` and
---attaches the extra actions chooser doesn't know about (y/A/<BS>/U/?),
---which read the highlighted suggestion via `kit.chooser.current_item()`
---without submitting/closing the picker.
---
---Those five are declared through `lib.nvim.bindings.keymap`'s registry, so
---`float_keymaps = { yank = "Y" }` moves one and `= false` drops one -- they
---were fixed single letters before, which is a problem in a buffer where `A`
---and `U` are also perfectly ordinary Vim keys somebody may want back. The
---`?` help lists what is actually bound rather than a hardcoded table, so it
---cannot describe keys the user has moved.

local notify = require("recommender.util.notify").create("[recommender]")
local rendering = require("recommender.float.rendering")
local kit = require("lib.nvim.ui.kit")

local M = {}

local api = vim.api
local schedule = vim.schedule

-- ── helpers ────────────────────────────────────────────────────────────────

---@internal
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

---@internal
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

---@internal
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
---@param state table  Recommender state table (visible, ignored, replace_mode, ...)
---@param user table|boolean|nil  `config.float_keymaps`
---@return Lib.Keymap.Registered[]|nil
function M.attach_extra(bufnr, state, user)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    return
  end

  ---@internal
  ---Re-run the analysis in the source buffer, keeping the cursor where it is.
  ---@return nil
  local function refresh_in_place()
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
  end

  ---@type Lib.Keymap.Registered[]
  local bound

  ---@type Lib.Keymap.Spec
  local spec = {
    order = { "yank", "insert_all", "ignore", "unignore", "help" },
    actions = {
      -- Yank selected alias to system clipboard without inserting or closing
      yank = {
        default = "y",
        desc = "yank alias to clipboard",
        rhs = function()
          local item = current_suggestion()
          if not item then
            return
          end
          vim.fn.setreg("+", item.alias)
          vim.fn.setreg("*", item.alias)
          notify.info("Yanked: " .. item.alias)
        end,
      },

      -- Insert ALL visible aliases at once into source buffer
      insert_all = {
        default = "A",
        desc = "insert ALL visible aliases",
        rhs = function()
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
        end,
      },

      -- Ignore current entry for this buffer session
      ignore = {
        default = "<BS>",
        desc = "ignore entry (this session)",
        rhs = function()
          local item = current_suggestion()
          if not item then
            return
          end
          state.ignored[item.chain] = true
          refresh_in_place()
        end,
      },

      -- Un-ignore all -> refresh
      unignore = {
        default = "U",
        desc = "un-ignore all",
        rhs = function()
          for k in pairs(state.ignored) do
            state.ignored[k] = nil
          end
          refresh_in_place()
        end,
      },

      -- Inline help, built from what is actually bound: a hardcoded list
      -- would start lying the moment somebody moved one of these keys.
      help = {
        default = "?",
        desc = "this help",
        rhs = function()
          local lines = { "Recommender keymaps:", "" }
          -- The navigation keys belong to kit's chooser, not to this module,
          -- so they are named rather than read back.
          for _, l in ipairs({
            "  j / k, arrows   Navigate entries",
            "  Enter           Insert selected alias",
          }) do
            lines[#lines + 1] = l
          end
          for _, entry in ipairs(bound or {}) do
            if entry.lhs and entry.bound then
              lines[#lines + 1] = ("  %-15s %s"):format(entry.lhs, entry.desc or entry.name)
            end
          end
          lines[#lines + 1] = "  q / Esc         Close"
          notify.info(table.concat(lines, "\n"))
        end,
      },
    },
  }

  ---@type table|false|nil
  local overrides = nil
  if type(user) == "table" or user == false then
    overrides = user
  end

  bound = require("lib.nvim.bindings.keymap").register("Recommender", spec, overrides, {
    buffer = bufnr,
    surface = "float",
  })
  return bound
end

return M
