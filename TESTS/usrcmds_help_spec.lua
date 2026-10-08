-- TESTS/usrcmds_help_spec.lua -- every flag and positional argument of `:Recommender` has a line in
-- lib.nvim's option float.
--
-- The flag text comes from the `desc` of each FlagSpec in recommender.bindings.usrcmds, the
-- argument text from the `desc` / `enum_desc` of the three interchangeable slots. A new flag or
-- completion value without one shows up as a bare row in the cheatsheet, so this fails until it is
-- described.

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

  -- The three positional slots (a1..a3) too: a text of their own and one per completion value.
  local missing_args = {}
  for _, m in ipairs(composer.help.undocumented("Recommender", { args = true })) do
    missing_args[#missing_args + 1] = m.kind .. ":" .. m.name
  end
  H.eq(#missing_args, 0, ":Recommender entries without a help text: " .. table.concat(missing_args, ", "))

  -- The texts follow the house style (one line, no trailing period, at most 80 characters), and
  -- every completion value is described -- a bare value is a row without an explanation.
  local texts, malformed, bare = 0, {}, {}
  for _, arg in ipairs(composer.registry().Recommender:spec().routes[1].args) do
    local all = { arg.desc }
    for _, text in pairs(arg.enum_desc or {}) do
      all[#all + 1] = text
    end
    for _, text in ipairs(all) do
      texts = texts + 1
      if text:find("\n", 1, true) or text:sub(-1) == "." or #text > 80 then
        malformed[#malformed + 1] = text
      end
    end
    for _, value in ipairs(arg.values or {}) do
      if not (arg.enum_desc or {})[value] then
        bare[#bare + 1] = arg.name .. "=" .. value
      end
    end
  end
  H.ok(texts >= 33, "the texts of a1..a3 and their ten values were found")

  -- The flags follow the same style; `--replace` in particular promises a `:Replace` that only some
  -- analyzers' suggestions get (see float_on_select_spec.lua), which its text has to say.
  local flag_texts = 0
  for _, flag in ipairs(composer.registry().Recommender:spec().routes[1].flags) do
    flag_texts = flag_texts + 1
    local text = flag.desc or ""
    if text == "" or text:find("\n", 1, true) or text:sub(-1) == "." or #text > 80 then
      malformed[#malformed + 1] = flag.name .. ": " .. text
    end
  end
  H.eq(flag_texts, 3, "the flags -r, -c and -t were found")
  H.eq(#malformed, 0, "malformed texts: " .. table.concat(malformed, " | "))
  H.eq(#bare, 0, "completion values without a text: " .. table.concat(bare, ", "))
end
