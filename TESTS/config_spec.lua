-- TESTS/config_spec.lua — recommender.config: the merge, and that DEFAULTS
-- survives it.

return function(H)
  local config = require("recommender.config")
  local DEFAULTS = require("recommender.config.DEFAULTS")

  -- Defaults without setup() --------------------------------------------------
  local original_defaults_threshold = DEFAULTS.threshold
  local fresh = config.get()
  H.eq(fresh.threshold, DEFAULTS.threshold, "get() before setup() returns the defaults")
  H.ok(fresh ~= DEFAULTS, "and returns a copy, not the DEFAULTS table itself")
  H.ok(config.get() == fresh, "a second get() before any setup() reuses the same snapshot instead of re-copying")

  -- Merge ---------------------------------------------------------------------
  local merged = config.setup({ threshold = 5 })
  H.eq(merged.threshold, 5, "a user value wins")
  H.eq(merged.analyzer, DEFAULTS.analyzer, "a key the user did not set keeps its default")
  H.eq(DEFAULTS.threshold, original_defaults_threshold, "DEFAULTS itself was not mutated")
  -- `fresh` is the same live table `get()` still returns -- setup() mutates
  -- the active config in place rather than replacing it (ERR-53), so a
  -- reference captured before the first setup() call sees the merge too.
  H.ok(config.get() == fresh, "setup() mutates the active config in place rather than swapping the table")
  H.eq(fresh.threshold, 5, "...so a pre-setup() reference observes the merged value")

  -- Deep merge ----------------------------------------------------------------
  -- Nested tables merge key by key rather than being replaced wholesale, so
  -- setting one sub-option does not silently drop its siblings.
  -- Was written against `DEFAULTS.float`, which this config has never had --
  -- so the whole case was skipped by its own guard and proved nothing.
  -- `custom_aliases` is the nested table the rule is actually about.
  if type(DEFAULTS.custom_aliases) == "table" then
    local sub = next(DEFAULTS.custom_aliases)
    if sub then
      local deep = config.setup({ custom_aliases = { [sub] = DEFAULTS.custom_aliases[sub] } })
      local kept = 0
      for k in pairs(DEFAULTS.custom_aliases) do
        if deep.custom_aliases[k] ~= nil then
          kept = kept + 1
        end
      end
      H.ok(kept > 1, "setting one nested key keeps the others")
    end
  end

  -- Unknown keys (ERR-50) -------------------------------------------------------
  -- A typo in an option name must not vanish silently into the merge --
  -- config.setup() always merges fresh against DEFAULTS, so a dropped key's
  -- field lands on the shipped default rather than on whatever a *previous*
  -- setup() call left in place.
  do
    local out = config.setup({ threshhold = 5 })
    H.eq(out.threshold, DEFAULTS.threshold, "an unknown key never reaches the real field; the default applies")
    local issues = config.issues()
    H.eq(#issues, 1, "the typo is reported")
    H.ok(issues[1]:find("threshhold", 1, true) ~= nil, "...naming the typo itself")
    H.ok(issues[1]:find("threshold", 1, true) ~= nil, "...with a 'did you mean' hint at the real key")
  end

  -- Invalid analyzer degrades to the default (ERR-22) --------------------------
  do
    local out = config.setup({ analyzer = "no-such-analyzer" })
    H.eq(out.analyzer, DEFAULTS.analyzer, "an unrecognized analyzer degrades to the default rather than sticking")
    local issues = config.issues()
    H.eq(#issues, 1, "the bad value is reported")
    H.ok(issues[1]:find("no%-such%-analyzer", 1, false) ~= nil, "...naming the rejected value")
  end

  -- Invalid threshold degrades to the default (ERR-22) -------------------------
  -- `threshold` flows straight into `analyzers/*.lua`'s `count >= threshold`
  -- with no other guard, so a non-integer, non-positive, or wrong-type value
  -- must degrade before the merge rather than reach that comparison and crash.
  do
    for _, bad in ipairs({ "not-a-number", 0, -3, 2.5, {}, true }) do
      local out = config.setup({ threshold = bad })
      H.eq(out.threshold, DEFAULTS.threshold, ("threshold %s degrades to the default"):format(vim.inspect(bad)))
      H.eq(#config.issues(), 1, ("...and is reported (%s)"):format(vim.inspect(bad)))
    end
  end

  -- Invalid cwd_max_files degrades to the default (ERR-22) ----------------------
  -- Feeds `project.lua`'s `max_files > 0` the same way; 0 itself is valid
  -- (means unbounded), so only values below that, non-integers, and wrong
  -- types should be rejected.
  do
    for _, bad in ipairs({ "many", -5, 2.5, {}, true }) do
      local out = config.setup({ cwd_max_files = bad })
      H.eq(out.cwd_max_files, DEFAULTS.cwd_max_files, ("cwd_max_files %s degrades to the default"):format(vim.inspect(bad)))
      H.eq(#config.issues(), 1, ("...and is reported (%s)"):format(vim.inspect(bad)))
    end
    local out = config.setup({ cwd_max_files = 0 })
    H.eq(out.cwd_max_files, 0, "cwd_max_files = 0 (unbounded) is accepted, not degraded")
    H.eq(#config.issues(), 0, "...and reports no issues")
  end

  -- Invalid blacklist/custom_aliases/cwd_ignore degrade to the default (ERR-22) --
  -- All three are read straight into `ipairs`/index operations downstream
  -- (`blacklist.is_blacklisted`, `analyzers/*.lua`, `project.lua`) with no
  -- other guard, so a scalar (e.g. a forgotten `{}`) must degrade before the
  -- merge rather than reach those operations and crash.
  do
    for _, field in ipairs({ "blacklist", "custom_aliases", "cwd_ignore" }) do
      for _, bad in ipairs({ "not-a-table", 5, true }) do
        local out = config.setup({ [field] = bad })
        H.ok(vim.deep_equal(out[field], DEFAULTS[field]), ("%s = %s degrades to the default"):format(field, vim.inspect(bad)))
        H.eq(#config.issues(), 1, ("...and is reported (%s = %s)"):format(field, vim.inspect(bad)))
      end
    end
  end

  -- A clean setup() reports no issues -------------------------------------------
  do
    config.setup({ threshold = 4 })
    H.eq(#config.issues(), 0, "nothing to report once the input is clean")
  end

  -- In-place mutation, not table replacement (ERR-53) --------------------------
  -- A submodule that captured `config.get()`'s table once (as
  -- bindings/usrcmds.lua does, in the :Recommender command's `run` closure)
  -- must keep seeing new values through that same reference after a second
  -- `setup()`, not a stale snapshot from whenever it was first captured.
  do
    local captured = config.get()
    config.setup({ threshold = 9 })
    H.ok(captured == config.get(), "setup() never swaps the table out from under a held reference")
    H.eq(captured.threshold, 9, "...and the held reference sees the new value")
  end

  -- Restore, so specs after this one see the defaults.
  config.setup({})
  H.eq(config.get().threshold, DEFAULTS.threshold, "setup({}) restores the defaults")
  H.eq(#config.issues(), 0, "...and reports no issues doing so")
end
