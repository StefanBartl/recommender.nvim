-- TESTS/util_lib_spec.lua — recommender.util.lib (the soft lib.nvim bridge for
-- notify/keymap), recommender.util.notify (its thin delegate), and
-- recommender.util.progress (the analogous bridge for lib.nvim.progress).
--
-- lib.nvim is always present in this suite's own environment (it is a hard
-- runtime dependency, see TESTS/README.md), so the "lib.nvim is missing"
-- fallback branches -- the whole reason these modules exist -- can only be
-- reached by temporarily hiding the dependency. `hide()` below does that by
-- forcing `require(name)` to fail, the same failure shape `pcall(require, ...)`
-- inside the source already guards against.

return function(H)
  ---@internal
  ---Force `require(name)` to fail until `restore()` is called, simulating the
  ---dependency being absent -- without touching anything else that may
  ---already have `name` cached differently.
  ---@param name string
  ---@return fun() restore
  local function hide(name)
    local saved_loaded = package.loaded[name]
    local saved_preload = package.preload[name]
    package.loaded[name] = nil
    package.preload[name] = function()
      error(("stubbed-unavailable: %s"):format(name), 0)
    end
    return function()
      package.loaded[name] = saved_loaded
      package.preload[name] = saved_preload
    end
  end

  -- util/lib.lua: notifier() ---------------------------------------------
  do
    local lib = require("recommender.util.lib")

    H.ok(lib.available(), "lib.nvim.notify is present in this suite's environment")

    local real = lib.notifier("[test]")
    H.eq(type(real.info), "function", "the real lib.nvim.notify path returns a usable notifier")

    local restore = hide("lib.nvim.notify")
    H.falsy(require("recommender.util.lib").available(), "available() reflects lib.nvim.notify's absence")

    local saved_notify = vim.notify
    local captured = {}
    vim.notify = function(msg, level)
      captured[#captured + 1] = { msg = msg, level = level }
    end

    local fallback = require("recommender.util.lib").notifier("[test]")
    fallback.info("hello")
    H.eq(captured[1].msg, "[test] hello", "the fallback notifier prefixes the message itself")
    H.eq(captured[1].level, vim.log.levels.INFO, "...at the right level")

    fallback.warn("careful")
    H.eq(captured[2].level, vim.log.levels.WARN, "warn() uses WARN")

    fallback.error("broken")
    H.eq(captured[3].level, vim.log.levels.ERROR, "error() uses ERROR")

    -- debug() is gated on vim.g.recommender_debug, unlike the other three.
    vim.g.recommender_debug = nil
    fallback.debug("quiet")
    H.eq(#captured, 3, "debug() emits nothing when recommender_debug is unset")

    vim.g.recommender_debug = true
    fallback.debug("loud")
    H.eq(#captured, 4, "...but does once it's set")
    H.eq(captured[4].level, vim.log.levels.DEBUG, "...at DEBUG level")
    vim.g.recommender_debug = nil

    vim.notify = saved_notify
    restore()
  end

  -- util/lib.lua: map() -----------------------------------------------------
  do
    local lib = require("recommender.util.lib")

    -- Real path: lib.nvim.bindings.keymap is present, so the mapping goes
    -- through it (and is therefore visible via its own registry, not
    -- maparg() -- see registry.lua's `record = false` for direct set()s,
    -- which is exactly what M.map's `lib_map(...)` call is).
    lib.map("n", "<Plug>(RecommenderUtilLibSpecReal)", function() end, { desc = "real path" })
    H.ok(
      vim.fn.maparg("<Plug>(RecommenderUtilLibSpecReal)", "n") ~= "",
      "map() through lib.nvim.bindings.keymap still lands a real mapping"
    )

    local restore = hide("lib.nvim.bindings.keymap")
    require("recommender.util.lib").map("n", "<Plug>(RecommenderUtilLibSpecFallback)", function() end, { desc = "fallback path" })
    H.ok(
      vim.fn.maparg("<Plug>(RecommenderUtilLibSpecFallback)", "n") ~= "",
      "map() falls back to vim.keymap.set directly when lib.nvim.bindings.keymap is unavailable"
    )
    restore()

    vim.keymap.del("n", "<Plug>(RecommenderUtilLibSpecReal)")
    vim.keymap.del("n", "<Plug>(RecommenderUtilLibSpecFallback)")
  end

  -- util/notify.lua: a thin delegate to lib.notifier() ----------------------
  do
    local notify = require("recommender.util.notify")
    local n = notify.create("[delegate-test]")
    H.eq(type(n.info), "function", "notify.create() returns the same shape lib.notifier() does")
  end

  -- util/progress.lua -------------------------------------------------------
  -- `ok_progress` is captured once, at module load, from
  -- `pcall(require, "lib.nvim.progress")` -- so unlike notify/map above (which
  -- probe fresh on every call), reaching the "unavailable" branch here means
  -- reloading the module itself with the dependency hidden first.
  do
    local progress = require("recommender.util.progress")
    H.ok(progress.available(), "lib.nvim.progress is present in this suite's environment")

    local handle = progress.create("auto")
    H.ok(handle ~= nil, "create() returns a real handle when lib.nvim.progress is available")

    package.loaded["recommender.util.progress"] = nil
    local restore = hide("lib.nvim.progress")
    local unavailable = require("recommender.util.progress")
    H.falsy(unavailable.available(), "a fresh load with lib.nvim.progress hidden captures ok_progress = false")
    H.eq(unavailable.create("auto"), nil, "...so create() returns nil instead of erroring")
    restore()

    -- Reload once more with the real dependency back, so any later spec (or
    -- this module's own top-level `ok_progress`) sees the normal state again.
    package.loaded["recommender.util.progress"] = nil
    require("recommender.util.progress")
  end
end
