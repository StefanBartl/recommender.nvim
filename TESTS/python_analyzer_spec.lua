-- TESTS/python_analyzer_spec.lua — the Python analyzer: same chain-counting
-- rules as analyzers/regex.lua (the Lua backend), but with a plain `%s = %s`
-- alias instead of `local %s = %s` — Python has no `local`/`const` keyword.

return function(H)
  local py = require("recommender.analyzers.python")

  local function analyze(lines, threshold, aliases, bl)
    return py.analyze(threshold or 2, aliases or {}, bl or {}, lines)
  end

  -- Counting -----------------------------------------------------------------
  local res = analyze({
    "os.path.join(a, b)",
    "os.path.join(c, d)",
  })
  local chain = H.find(res, "os.path")
  H.ok(chain, "the shared two-part prefix is reported")
  H.eq(chain.count, 2, "counted once per line")

  -- One line, one count -------------------------------------------------------
  local once = analyze({ "x = os.environ.get('A')", "y = os.environ.get('B')" })
  H.eq(H.find(once, "os.environ").count, 2, "a chain twice on one line still counts once for it")

  -- Alias syntax: plain `%s = %s`, no `local`/`const` -------------------------
  local derived = analyze({ "json.dumps.__doc__", "json.dumps.__name__" })
  local dumps = H.find(derived, "json.dumps")
  H.ok(dumps, "the two-part prefix is reported")
  H.eq(dumps.alias, "dumps = json.dumps", "derived alias is a plain assignment, last segment as name")

  local custom = analyze({ "json.dumps.__doc__", "json.dumps.__name__" }, 2, { ["json.dumps"] = "to_json" })
  H.eq(H.find(custom, "json.dumps").alias, "to_json = json.dumps", "a custom alias overrides the derived name")

  -- Threshold ------------------------------------------------------------------
  H.eq(#analyze({ "logging.getLogger(__name__)" }, 3), 0, "below threshold, nothing is reported")

  -- Blacklist --------------------------------------------------------------
  local blocked = analyze({ "os.path.join(a, b)", "os.path.join(c, d)" }, 2, {}, { "os.path" })
  H.eq(#blocked, 0, "a blacklisted prefix removes the chain entirely")

  -- Reads the current buffer when given no lines ------------------------------
  H.scratch({ "sys.argv.append(1)", "sys.argv.append(2)" })
  local from_buffer = py.analyze(2, {}, {})
  H.ok(H.find(from_buffer, "sys.argv"), "omitting `lines` scans the current buffer")

  -- Ordering: sorted by count, descending ------------------------------------
  local ordered = analyze({
    "a.b() c.d()",
    "a.b() c.d()",
    "a.b()",
  })
  H.ok(#ordered >= 2, "both chains reported")
  H.ok(ordered[1].count >= ordered[#ordered].count, "results are sorted by count, descending")
end
