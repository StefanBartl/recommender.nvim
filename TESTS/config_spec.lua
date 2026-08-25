-- TESTS/config_spec.lua — recommender.config: the merge, and that DEFAULTS
-- survives it.

return function(H)
  local config = require("recommender.config")
  local DEFAULTS = require("recommender.config.DEFAULTS")

  -- Defaults without setup() --------------------------------------------------
  local fresh = config.get()
  H.eq(fresh.threshold, DEFAULTS.threshold, "get() before setup() returns the defaults")
  H.ok(fresh ~= DEFAULTS, "and returns a copy, not the DEFAULTS table itself")

  -- Merge ---------------------------------------------------------------------
  local merged = config.setup({ threshold = 5 })
  H.eq(merged.threshold, 5, "a user value wins")
  H.eq(merged.analyzer, DEFAULTS.analyzer, "a key the user did not set keeps its default")
  H.eq(DEFAULTS.threshold, fresh.threshold, "DEFAULTS itself was not mutated")

  -- Deep merge ----------------------------------------------------------------
  -- Nested tables merge key by key rather than being replaced wholesale, so
  -- setting one sub-option does not silently drop its siblings.
  if type(DEFAULTS.float) == "table" then
    local sub = next(DEFAULTS.float)
    if sub then
      local deep = config.setup({ float = { [sub] = DEFAULTS.float[sub] } })
      local kept = 0
      for k in pairs(DEFAULTS.float) do
        if deep.float[k] ~= nil then
          kept = kept + 1
        end
      end
      H.ok(kept > 1, "setting one nested key keeps the others")
    end
  end

  -- Restore, so specs after this one see the defaults.
  config.setup({})
  H.eq(config.get().threshold, DEFAULTS.threshold, "setup({}) restores the defaults")
end
