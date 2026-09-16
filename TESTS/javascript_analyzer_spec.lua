-- TESTS/javascript_analyzer_spec.lua — the JS/TS analyzer: same chain-counting
-- rules as analyzers/regex.lua (the Lua backend), but with a `$`-permissive
-- identifier class and a `const %s = %s;` alias instead of `local %s = %s`.

return function(H)
  local js = require("recommender.analyzers.javascript")

  local function analyze(lines, threshold, aliases, bl)
    return js.analyze(threshold or 2, aliases or {}, bl or {}, lines)
  end

  -- Counting -------------------------------------------------------------
  local res = analyze({
    "console.log.bind(console)",
    "console.log.bind(console)",
  })
  local chain = H.find(res, "console.log")
  H.ok(chain, "the shared two-part prefix is reported")
  H.eq(chain.count, 2, "counted once per line")

  -- `$` is a valid identifier character in JS/TS, unlike the Lua backend ----
  local dollar = analyze({ "this.$refs.foo.bar()", "this.$refs.foo.baz()" }, 1)
  H.ok(H.find(dollar, "this.$refs"), "a `$`-prefixed identifier is part of the chain, not a chain boundary")

  -- Alias syntax: `const %s = %s;`, not Lua's `local %s = %s` --------------
  local derived = analyze({ "axios.get.bind(axios)", "axios.get.bind(axios)" })
  local get = H.find(derived, "axios.get")
  H.ok(get, "the two-part prefix is reported")
  H.eq(get.alias, "const get = axios.get;", "derived alias uses the last segment and a trailing semicolon")

  local custom = analyze({ "axios.get.bind(axios)", "axios.get.bind(axios)" }, 2, { ["axios.get"] = "httpGet" })
  H.eq(H.find(custom, "axios.get").alias, "const httpGet = axios.get;", "a custom alias overrides the derived name")

  -- Threshold --------------------------------------------------------------
  H.eq(#analyze({ "document.body.appendChild(x)" }, 3), 0, "below threshold, nothing is reported")

  -- One line, one count: a chain repeated within a line still counts once --
  local once = analyze({ "window.location.href = window.location.pathname", "window.location.reload()" })
  H.eq(H.find(once, "window.location").count, 2, "a chain twice on one line still counts once for it")

  -- Blacklist ----------------------------------------------------------------
  local blocked = analyze({ "console.log.bind(console)", "console.log.bind(console)" }, 2, {}, { "console.log" })
  H.eq(#blocked, 0, "a blacklisted prefix removes the chain entirely")

  -- Reads the current buffer when given no lines ------------------------------
  H.scratch({ "const a = process.env.NODE_ENV;", "const b = process.env.PATH;" })
  local from_buffer = js.analyze(2, {}, {})
  H.ok(H.find(from_buffer, "process.env"), "omitting `lines` scans the current buffer")

  -- Ordering: sorted by count, descending ------------------------------------
  local ordered = analyze({
    "a.b() c.d()",
    "a.b() c.d()",
    "a.b()",
  })
  H.ok(#ordered >= 2, "both chains reported")
  H.ok(ordered[1].count >= ordered[#ordered].count, "results are sorted by count, descending")
end
