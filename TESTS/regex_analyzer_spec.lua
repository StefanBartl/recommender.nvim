-- TESTS/regex_analyzer_spec.lua — the default analyzer: which dotted chains it
-- finds, how it counts them, and what alias it proposes.

return function(H)
  local regex = require("recommender.analyzers.regex")

  local function analyze(lines, threshold, aliases, bl)
    return regex.analyze(threshold or 2, aliases or {}, bl or {}, lines)
  end

  -- Counting -----------------------------------------------------------------
  local res = analyze({
    "local a = vim.api.nvim_buf_get_lines(0, 0, -1, false)",
    "local b = vim.api.nvim_buf_set_lines(0, 0, -1, false, {})",
  })
  local api = H.find(res, "vim.api")
  H.ok(api, "the shared two-part prefix is reported")
  H.eq(api.count, 2, "counted once per line")

  -- One line, one count ------------------------------------------------------
  -- Chains are deduplicated per line before counting, so a line that repeats a
  -- chain does not look like two separate uses of it.
  local once = analyze({ "vim.fn.expand(vim.fn.getcwd())", "vim.fn.tempname()" })
  H.eq(H.find(once, "vim.fn").count, 2, "a chain twice on one line still counts once for it")

  -- Threshold ----------------------------------------------------------------
  H.eq(#analyze({ "vim.fn.getcwd()" }), 0, "a single use is below the default threshold")

  -- At threshold 1 the same line yields *two* suggestions, not one: the
  -- extractor collects the three-part chain and the two-part prefix inside it
  -- separately, so `vim.fn.getcwd` and `vim.fn` are both candidates. That is
  -- deliberate -- aliasing either one is a legitimate choice -- and it is the
  -- reason the default threshold is above 1.
  local both = analyze({ "vim.fn.getcwd()" }, 1)
  H.eq(#both, 2, "a three-part chain also offers its two-part prefix")
  H.ok(H.find(both, "vim.fn.getcwd"), "the full chain is one of them")
  H.ok(H.find(both, "vim.fn"), "its prefix is the other")

  -- Alias derivation ---------------------------------------------------------
  local derived = analyze({ "vim.lsp.buf_request()", "vim.lsp.get_clients()" })
  H.eq(H.find(derived, "vim.lsp").alias, "local lsp = vim.lsp", "the variable name is the chain's last segment")

  local custom = analyze({ "vim.lsp.buf_request()", "vim.lsp.get_clients()" }, 2, { ["vim.lsp"] = "L" })
  H.eq(H.find(custom, "vim.lsp").alias, "local L = vim.lsp", "a custom alias overrides the derived name")

  -- Blacklist ----------------------------------------------------------------
  local blocked = analyze({ "vim.api.nvim_get_mode()", "vim.api.nvim_list_bufs()" }, 2, {}, { "vim.api" })
  H.eq(#blocked, 0, "a blacklisted prefix removes the chain entirely")

  -- Ordering -----------------------------------------------------------------
  local ordered = analyze({
    "vim.fn.a() vim.lsp.x()",
    "vim.fn.b() vim.lsp.y()",
    "vim.fn.c()",
  })
  H.ok(#ordered >= 2, "both chains reported")
  H.ok(ordered[1].count >= ordered[#ordered].count, "results are sorted by count, descending")

  -- Reads the current buffer when given no lines ------------------------------
  H.scratch({ "vim.o.number = true", "vim.o.relativenumber = true" })
  local from_buffer = regex.analyze(2, {}, {})
  H.ok(H.find(from_buffer, "vim.o"), "omitting `lines` scans the current buffer")
end
