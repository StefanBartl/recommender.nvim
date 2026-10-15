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

  -- Two- and three-argument insert are told apart -------------------------------
  -- `table.insert(t, pos, v)` shifts the tail, `t[#t+1] = v` cannot replace it.
  H.eq(#analyze({ "for i = 1, 10 do", "  table.insert(t, 1, i)", "end" }), 0, "the three-argument insert is not reported")
  H.eq(
    #analyze({ "for i = 1, 10 do", "  table.insert(t, { a = 1, b = 2 })", "end" }),
    1,
    "a comma inside a table constructor does not make a second argument"
  )
  H.eq(#analyze({ "for i = 1, 10 do", "  table.insert(t, f(a, b))", "end" }), 1, "nor does a comma inside a nested call")
  H.eq(#analyze({ "for i = 1, 10 do", "  table.insert(t, 'a,b')", "end" }), 1, "nor one inside a string")
  H.eq(
    #analyze({ "for i = 1, 10 do", "  table.insert(t, 1, i); table.insert(u, i)", "end" }),
    1,
    "a line with both forms still reports the appending one"
  )
  H.eq(
    #analyze({ "for i = 1, 10 do", "  table.insert(", "    t, v)", "end" }),
    1,
    "a call that does not close on its line is still reported"
  )
  local fmt = analyze({ "for i = 1, 10 do", "  local s = string.format('%d', i)", "end" })
  H.ok(fmt[1].alias:find("plain join", 1, true), "the string.format tip names its limit")

  -- The help file and the feature doc state the same limits as the code.
  for _, path in ipairs({ "doc/recommender.txt", "docs/FEATURES.md" }) do
    local text = table.concat(vim.fn.readfile(vim.fn.getcwd() .. "/" .. path), "\n")
    H.ok(text:find("three-argument", 1, true), path .. " names the three-argument table.insert exception")
    H.ok(text:find("plain join", 1, true), path .. " names the limit of the string.format tip")
  end

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

  -- The accumulator check is about *growth across iterations*, not about the
  -- shape of the line. Both negatives below came out of the first run against a
  -- real config, where all three "O(n^2)" findings were this and nothing else.
  do
    local function accum_count(lines)
      for _, r in ipairs(perf.analyze(1, {}, {}, lines)) do
        if r.chain:find("accumulator", 1, true) then
          return r.count
        end
      end
      return 0
    end

    H.eq(
      accum_count({
        'local out = ""',
        "for _, s in ipairs(t) do",
        "  out = out .. s",
        "end",
      }),
      1,
      "a variable declared outside the loop and appended inside it is an accumulator"
    )

    H.eq(
      accum_count({
        "local acc = ''",
        "for i = 1, n do",
        "  for j = 1, m do",
        "    acc = acc .. x",
        "  end",
        "end",
      }),
      1,
      "...including from inside a nested loop"
    )

    -- Re-declared every iteration, so each append starts from a fresh string.
    H.eq(
      accum_count({
        "while u do",
        "  local ident = ts_identifier_of(u)",
        "  if ident then",
        '    ident = ident .. "()"',
        "  end",
        "end",
      }),
      0,
      "a local declared inside the loop cannot accumulate across iterations"
    )

    -- `dir` here is a table key being given a value built from the *outer*
    -- `dir`; the unanchored back-reference used to read it as an assignment.
    H.eq(
      accum_count({
        "for _, short in ipairs(subdirs(dir)) do",
        '  entries[#entries + 1] = { short = short, dir = dir .. "/" .. short }',
        "end",
      }),
      0,
      "a table field is not an assignment to the variable it reads"
    )
  end
end
