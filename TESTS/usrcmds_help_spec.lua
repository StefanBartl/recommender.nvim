-- TESTS/usrcmds_help_spec.lua -- every flag of `:Recommender` has a line in lib.nvim's option float.
--
-- The text comes from the `desc` of each FlagSpec in recommender.bindings.usrcmds. A new flag
-- without one shows up as a bare row in the cheatsheet, so this fails until it is described.

-- usrcmds.lua requires the float modules at load and those require "ui.kit", which this repo's own
-- CI does not check out; registering the command calls nothing in it (same stub as usrcmds_spec).
if not package.loaded["ui.kit"] then
  package.loaded["ui.kit"] = {}
end

return function(H)
  local ok, composer = pcall(require, "lib.nvim.bindings.usercmd.composer")
  H.ok(ok, "the composer loads")

  -- A lib.nvim older than `help.undocumented` cannot answer the question; that is a missing
  -- feature of the dependency, not a defect of this plugin.
  if type(composer.help.undocumented) ~= "function" then
    return
  end

  -- `setup` only stores `cfg` for `execute`, which registering the verb never runs.
  require("recommender.bindings.usrcmds").setup({})
  H.ok(composer.registry().Recommender ~= nil, ":Recommender is registered through the composer")

  local missing = {}
  for _, m in ipairs(composer.help.undocumented("Recommender")) do
    missing[#missing + 1] = m.name
  end
  H.eq(#missing, 0, ":Recommender options without a help text: " .. table.concat(missing, ", "))
end
