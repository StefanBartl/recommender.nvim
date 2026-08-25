-- TESTS/perf_analyzer_spec.lua — the perf analyzer, whose whole value is that
-- it only reports a pattern when it sits *inside a loop*. Everything here is
-- about that distinction: the same line is a finding in one place and noise in
-- the other, so the block tracker is what the spec is really pinning down.

return function(H)
  local perf = require("recommender.analyzers.perf")

  local function analyze(lines, threshold)
    return perf.analyze(threshold or 1, {}, {}, lines)
  end

  -- Outside a loop: not a finding ---------------------------------------------
  H.eq(#analyze({
    "local t = {}",
    "table.insert(t, 1)",
    "local s = string.format('%d', 1)",
  }), 0, "the same calls outside any loop are not reported")

  -- Inside a loop: a finding --------------------------------------------------
  local inside = analyze({
    "for i = 1, 10 do",
    "  table.insert(t, i)",
    "end",
  })
  H.eq(#inside, 1, "one pattern found")
  H.eq(inside[1].chain, "table.insert(...)", "and it is the right one")
  H.ok(inside[1].alias:find("t%[#t%+1%]"), "the tip names the indexed-assignment alternative")

  -- `while` counts as a loop, `if` does not ------------------------------------
  H.eq(#analyze({ "while cond do", "  table.insert(t, 1)", "end" }), 1, "while is a loop")
  H.eq(#analyze({ "if cond then", "  table.insert(t, 1)", "end" }), 0, "if is not")

  -- Nesting: a non-loop block inside a loop is still inside the loop ----------
  H.eq(#analyze({
    "for i = 1, 10 do",
    "  if cond then",
    "    table.insert(t, i)",
    "  end",
    "end",
  }), 1, "an if nested inside a for is still loop context")

  -- ...and the loop has to actually still be open ------------------------------
  H.eq(#analyze({
    "for i = 1, 10 do",
    "  print(i)",
    "end",
    "table.insert(t, 1)",
  }), 0, "a call after the loop closed is not in it")

  -- Single-line blocks --------------------------------------------------------
  -- `for i=1,3 do table.insert(t,i) end` opens and closes on one physical line,
  -- so it never reaches the stack. It is classified separately, and the body
  -- still has to be scanned.
  H.eq(#analyze({ "for i = 1, 3 do table.insert(t, i) end" }), 1, "a single-line for is loop context for its own body")
  H.eq(#analyze({ "if x then table.insert(t, 1) end" }), 0, "a single-line if is not")

  -- The other three patterns --------------------------------------------------
  local chains = {}
  for _, r in
    ipairs(analyze({
      "for i = 1, 10 do",
      "  s = s .. tostring(i)",
      "  local msg = string.format('%d', i)",
      "end",
      "for _, v in ipairs(list) do print(v) end",
    }))
  do
    chains[r.chain] = r.count
  end
  H.ok(chains["x = x .. y (concat accumulator)"], "the self-concat accumulator is found")
  H.ok(chains["string.format(...)"], "string.format in a loop is found")
  H.ok(chains["ipairs(...)"], "an ipairs loop header is found")

  -- Threshold -----------------------------------------------------------------
  local twice = {
    "for i = 1, 10 do",
    "  table.insert(t, i)",
    "  table.insert(u, i)",
    "end",
  }
  H.eq(#analyze(twice, 3), 0, "below the threshold, nothing is reported")
  H.eq(#analyze(twice, 2), 1, "at the threshold it is")
end
