-- TESTS/treesitter_analyzer_spec.lua — the Tree-sitter analyzer.
--
-- `M.analyze()` itself depends on a working Lua Tree-sitter grammar being
-- installed, which this suite cannot assume (see the BUG note below), so most
-- of what is actually testable here is `M._internal`: the pure "counts in,
-- ranked+aliased suggestions out" half (`build_suggestions`) and the
-- longest-common-prefix helper it leans on (`common_prefix`). Both are
-- exercised directly, with plain counts tables, independent of Tree-sitter.

return function(H)
  local ts_analyzer = require("recommender.analyzers.treesitter")
  local internal = ts_analyzer._internal

  -- common_prefix ---------------------------------------------------------
  H.eq(internal.common_prefix({}), nil, "no chains, no prefix")
  H.eq(
    internal.common_prefix({ "vim.api.nvim_buf_get_lines" }),
    "vim.api.nvim_buf_get_lines",
    'a single chain\'s "shared" prefix is itself -- there is nothing else to narrow it down'
  )

  H.eq(
    internal.common_prefix({ "vim.api.nvim_buf_get_lines", "vim.api.nvim_win_get_buf" }),
    "vim.api",
    "the shared two-part prefix of two chains"
  )

  H.eq(
    internal.common_prefix({ "vim.api.nvim_buf_get_lines", "vim.api.nvim_buf_set_lines", "vim.api.nvim_win_get_buf" }),
    "vim.api",
    "the shared prefix across three chains, not just the first two"
  )

  H.eq(internal.common_prefix({ "vim.api.nvim_buf_get_lines", "vim.fn.getcwd" }), nil, "no shared prefix at all -> nil")

  H.eq(
    internal.common_prefix({ "vim.api", "vim.fn" }),
    nil,
    'a shared prefix shallower than depth 2 (just "vim") is rejected outright'
  )

  H.eq(internal.common_prefix({ "a.b.c.d", "a.b.c.e" }), "a.b.c", "the shared prefix can be deeper than 2 segments")

  -- build_suggestions -------------------------------------------------------
  H.eq(#internal.build_suggestions({}, 1, {}), 0, "no counts, no suggestions")
  H.eq(#internal.build_suggestions({ ["vim.api.nvim_buf_get_lines"] = 1 }, 3, {}), 0, "below threshold, nothing is reported")

  -- A custom alias always wins, even when a shared prefix also matches the chain.
  local with_custom = internal.build_suggestions(
    { ["vim.api.nvim_buf_get_lines"] = 2, ["vim.api.nvim_win_get_buf"] = 2 },
    1,
    { ["vim.api.nvim_buf_get_lines"] = "get_lines" }
  )
  H.eq(
    H.find(with_custom, "vim.api.nvim_buf_get_lines").alias,
    "local get_lines = vim.api.nvim_buf_get_lines",
    "custom alias overrides the derived one"
  )
  H.eq(
    H.find(with_custom, "vim.api.nvim_win_get_buf").alias,
    "local api = vim.api",
    "the other chain still falls back to the shared-prefix alias"
  )

  -- No custom alias, but two chains share a prefix -> both alias to it.
  local shared = internal.build_suggestions({ ["vim.lsp.buf_request"] = 2, ["vim.lsp.get_clients"] = 2 }, 1, {})
  H.eq(H.find(shared, "vim.lsp.buf_request").alias, "local lsp = vim.lsp", "shared-prefix alias uses the prefix's last segment")
  H.eq(H.find(shared, "vim.lsp.get_clients").alias, "local lsp = vim.lsp", "...and the same for the other chain sharing it")

  -- A single chain has no prefix to share with anything -> falls back to its own last segment.
  local solo = internal.build_suggestions({ ["table.insert"] = 5 }, 1, {})
  H.eq(H.find(solo, "table.insert").alias, "local insert = table.insert", "a lone chain aliases to its own last segment")

  -- Sorted by count, descending.
  local ranked = internal.build_suggestions({ a = 1, b = 5, c = 3 }, 1, {})
  H.eq(ranked[1].count, 5, "highest count first")
  H.eq(ranked[#ranked].count, 1, "lowest count last")

  -- BUG: M.analyze() -----------------------------------------------------
  -- The query in `collect_chains` above asks for `(field_expression)` and
  -- `(call_expression function: (field_expression) @call)`, but the
  -- tree-sitter-lua grammar actually shipped with Neovim (checked against
  -- 0.12) names those nodes `dot_index_expression` and `function_call`.
  -- `ts.query.parse` therefore fails outright ("Invalid node type
  -- field_expression"), `collect_chains` always returns {} via its own
  -- pcall guard, and `M.analyze()` reports no suggestions no matter what the
  -- buffer contains — silently, since the failure is swallowed by design
  -- (an absent/mismatched parser is meant to degrade to "no findings", not
  -- error). This pins the CURRENT (broken) behavior as a regression test
  -- rather than fixing it here; see the final report for a follow-up.
  H.scratch({
    "local a = vim.api.nvim_buf_get_lines(0, 0, -1, false)",
    "local b = vim.api.nvim_buf_set_lines(0, 0, -1, false, {})",
    "local c = vim.api.nvim_win_get_buf(0)",
  })
  H.eq(#ts_analyzer.analyze(1, {}, {}), 0, "BUG: analyze() finds nothing on the current grammar -- see comment above")
end
