-- TESTS/float_on_select_spec.lua -- what <CR> in the float does with a suggestion in replace mode
-- (`float/keymaps.lua`'s `make_on_select`).
--
-- The `--replace` flag text promises a `:Replace` of the chain only where one is dispatched, so this
-- pins down exactly where that is: a suggestion that is an assignment (`local x = chain` from the
-- regex analyzer, `x = chain` from the python one) drives `:Replace chain x %`; the javascript
-- analyzer (`const x = chain;`), the perf analyzer (an advisory comment) and any analyzer without a
-- `:Replace` command get the plain alias insert. Each case feeds the alias a real analyzer produced
-- through the real handler, so a new alias form shows up here instead of in a user's buffer.
--
-- float/keymaps.lua requires "ui.kit" at load; the same stub as float_keymaps_spec.lua is enough, the
-- handler never touches it.
if not package.loaded["ui.kit"] then
  package.loaded["ui.kit"] = {}
end

return function(H)
  local api = vim.api
  local fk = require("recommender.float.keymaps")
  local rendering = require("recommender.float.rendering")

  H.eq(vim.fn.exists(":Replace"), 0, "sanity: no :Replace command exists before the spec defines its own")

  ---@param buf integer
  ---@param text string
  ---@return boolean
  local function has_line(buf, text)
    return vim.tbl_contains(api.nvim_buf_get_lines(buf, 0, -1, false), text)
  end

  ---Pick `suggestion` in replace mode on a fresh ordinary window.
  ---@param suggestion {chain:string, count:integer, alias:string}
  ---@param with_replace boolean  define a recording `:Replace` first
  ---@return string[][] calls  the `args` each `:Replace` call received
  ---@return boolean inserted  the alias line landed in the target buffer
  local function pick(suggestion, with_replace)
    vim.cmd("botright new")
    local win = api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    api.nvim_buf_set_lines(buf, 0, -1, false, { "-- target" })

    local saved_source_win = rendering.source_win
    rendering.source_win = win

    local calls = {}
    if with_replace then
      api.nvim_create_user_command("Replace", function(o)
        calls[#calls + 1] = o.fargs
      end, { nargs = "*" })
    end

    fk.make_on_select({ replace_mode = true })(suggestion)
    -- The handler defers its work; it is done once :Replace ran or the alias line is in the buffer.
    H.wait_until(function()
      return #calls > 0 or has_line(buf, suggestion.alias)
    end, "the handler acted on " .. suggestion.alias)
    local inserted = has_line(buf, suggestion.alias)

    pcall(api.nvim_del_user_command, "Replace")
    pcall(api.nvim_del_augroup_by_name, "RecommenderNvimReplaceInsert")
    rendering.source_win = saved_source_win
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    pcall(api.nvim_buf_delete, buf, { force = true })
    return calls, inserted
  end

  local regex = H.find(require("recommender.analyzers.regex").analyze(2, {}, {}, { "vim.api.a()", "vim.api.b()" }), "vim.api")
  local python = H.find(
    require("recommender.analyzers.python").analyze(2, {}, {}, { "json.dumps.__doc__", "json.dumps.__name__" }),
    "json.dumps"
  )
  local javascript = H.find(
    require("recommender.analyzers.javascript").analyze(2, {}, {}, { "axios.get.bind(axios)", "axios.get.bind(axios)" }),
    "axios.get"
  )
  local perf = require("recommender.analyzers.perf").analyze(1, {}, {}, { "for i = 1, 10 do", "  table.insert(t, i)", "end" })[1]
  H.ok(regex and python and javascript and perf, "every analyzer produced a suggestion to pick")

  -- Assignments drive :Replace, and the alias line is left for the WinClosed hook ---------
  local calls, inserted = pick(regex, true)
  H.eq(#calls, 1, "a regex suggestion (local x = chain) dispatches :Replace once")
  H.eq(calls[1][1], "vim.api", "... on the chain")
  H.eq(calls[1][2], "api", "... with the alias name as the replacement")
  H.falsy(inserted, "... and the alias line waits for the replace prompt to close")

  calls, inserted = pick(python, true)
  H.eq(#calls, 1, "a python suggestion (x = chain) dispatches :Replace once")
  H.eq(calls[1][1], "json.dumps", "... on the chain")
  H.eq(calls[1][2], "dumps", "... with the alias name as the replacement")
  H.falsy(inserted, "... and the alias line waits for the replace prompt to close")

  -- Not an assignment, or no :Replace: a plain insert, no matter that -r is set ---------
  calls, inserted = pick(javascript, true)
  H.eq(#calls, 0, "a javascript suggestion (const x = chain;) never reaches :Replace")
  H.ok(inserted, "... it is inserted as it is")

  calls, inserted = pick(perf, true)
  H.eq(#calls, 0, "a perf suggestion (an advisory comment) never reaches :Replace")
  H.ok(inserted, "... it is inserted as it is")

  calls, inserted = pick(regex, false)
  H.eq(#calls, 0, "without a :Replace command nothing is dispatched")
  H.ok(inserted, "... and the regex suggestion falls back to the plain insert")

  -- The flag text names exactly these exclusions --------------------------------------------
  require("recommender.bindings.usrcmds").setup({})
  local composer = require("lib.nvim.bindings.usercmd.composer")
  local replace_desc
  for _, flag in ipairs(composer.registry().Recommender:spec().routes[1].flags) do
    if flag.name == "replace" then
      replace_desc = flag.desc
    end
  end
  H.ok(replace_desc, "the --replace flag has a text")
  H.ok(
    replace_desc:find("javascript", 1, true) and replace_desc:find("perf", 1, true),
    "the --replace text names the analyzers that only insert: " .. tostring(replace_desc)
  )
end
