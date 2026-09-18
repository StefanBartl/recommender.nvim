-- TESTS/keymaps_spec.lua — recommender.bindings.keymaps: the global-keymap
-- override resolution (config.keymaps = true/false/table), and the run(args)
-- closures' count-to-"--threshold=N" logic.
--
-- Deliberately excludes recommender.bindings.usrcmds/init: both pull in
-- recommender.float.rendering/keymaps, which require "ui.kit" (ui.nvim) at
-- module load -- unavailable in this repo's own CI (only lib.nvim is a
-- sibling there). bindings/keymaps.lua itself only needs lib.nvim, so it is
-- safe to require directly. (usrcmds.lua's own pure logic -- the part that
-- does not need a real `execute()` dispatch through rendering/keymaps -- is
-- covered separately in TESTS/usrcmds_spec.lua, which unlocks the require by
-- stubbing "ui.kit" in package.loaded first; see that file's header.)

return function(H)
  local keymaps = require("recommender.bindings.keymaps")

  -- Override resolution --------------------------------------------------
  local defaults = keymaps.bind(true)
  H.eq(#defaults, 8, "all eight actions are declared")

  -- `H.find` looks entries up by `.chain`, which registered keymap entries
  -- don't have -- a small local lookup by `.name` instead.
  local function by_name(bound, name)
    for _, e in ipairs(bound) do
      if e.name == name then
        return e
      end
    end
    return nil
  end

  H.eq(by_name(defaults, "run").lhs, "<leader>lr", "run's default lhs")
  H.eq(by_name(defaults, "regex").lhs, "<leader>lrr", "regex's default lhs")
  H.ok(by_name(defaults, "run").bound, "keymaps = true binds the defaults")

  local disabled = keymaps.bind(false)
  H.ok(not by_name(disabled, "run").bound, "keymaps = false binds nothing")
  H.ok(not by_name(disabled, "regex").bound, "...for every action, not just one")

  local overridden = keymaps.bind({ regex = "<leader>zr" })
  H.eq(by_name(overridden, "regex").lhs, "<leader>zr", "an override table moves exactly the named action")
  H.ok(by_name(overridden, "run").bound, "...and leaves every other action on its default")
  H.eq(by_name(overridden, "run").lhs, "<leader>lr", "including its lhs")

  local one_disabled = keymaps.bind({ regex = false })
  H.falsy(by_name(one_disabled, "regex").lhs, "false for one action drops just that key")
  H.ok(by_name(one_disabled, "run").bound, "...without touching the others")

  local nil_user = keymaps.bind(nil)
  H.ok(by_name(nil_user, "run").bound, "nil (no keymaps option at all) behaves like true")

  -- run(args): count -> --threshold=N, args composition --------------------
  -- Reach the closures the same way a real keypress would invoke them: by
  -- name from a fresh bind(true), not by re-deriving them.
  local bound = keymaps.bind(true)

  local saved_cmd = vim.cmd
  local saved_count_raw = require("lib.nvim.count").raw
  local captured

  ---@param count integer
  local function with_count(count, fn)
    require("lib.nvim.count").raw = function()
      return count
    end
    vim.cmd = function(cmd)
      captured = cmd
    end
    local ok, err = pcall(fn)
    vim.cmd = saved_cmd
    require("lib.nvim.count").raw = saved_count_raw
    if not ok then
      error(err, 0)
    end
  end

  with_count(0, function()
    by_name(bound, "run").rhs()
  end)
  H.eq(captured, "Recommender", "no count, no args -> plain :Recommender")

  with_count(3, function()
    by_name(bound, "run").rhs()
  end)
  H.eq(captured, "Recommender --threshold=3", "a count sets the threshold even for the bare run action")

  with_count(0, function()
    by_name(bound, "regex").rhs()
  end)
  H.eq(captured, "Recommender regex", "the regex action appends its own args")

  with_count(5, function()
    by_name(bound, "regex").rhs()
  end)
  H.eq(captured, "Recommender regex --threshold=5", "...and a count still appends --threshold=N after them")

  with_count(0, function()
    by_name(bound, "high_threshold").rhs()
  end)
  H.eq(captured, "Recommender regex 5", 'high_threshold\'s own args ("regex 5") pass through untouched with no count')

  with_count(9, function()
    by_name(bound, "high_threshold").rhs()
  end)
  H.eq(captured, "Recommender regex 5 --threshold=9", "...and a count on it overrides the baked-in 5, per its own doc comment")
end
