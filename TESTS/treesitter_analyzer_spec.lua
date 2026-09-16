-- TESTS/treesitter_analyzer_spec.lua — the Tree-sitter analyzer.
--
-- `M._internal`'s pure "counts in, ranked+aliased suggestions out" half
-- (`build_suggestions`) and the longest-common-prefix helper it leans on
-- (`common_prefix`) are exercised directly, with plain counts tables,
-- independent of Tree-sitter. `M.analyze()` itself is then exercised
-- end-to-end against a real Lua buffer, relying on the Lua Tree-sitter parser
-- bundled with Neovim.

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

  -- M.analyze() end-to-end ------------------------------------------------
  -- `collect_chains`'s query matches on `dot_index_expression` (a plain
  -- dotted access, e.g. `vim.api`) and `function_call` (a call, capturing
  -- its `name:` field when that's itself a dotted access, e.g.
  -- `vim.api.nvim_buf_get_lines(...)`). Both patterns can match the very
  -- same node -- a called chain like `vim.api.nvim_buf_get_lines` is a
  -- `dot_index_expression` in its own right, so it is picked up once as a
  -- plain field access and once as a call target, hence count 2 below (not
  -- 1) for each fully-qualified call. `vim.api` is also a
  -- `dot_index_expression` in its own right (nested inside each outer
  -- chain), so it is picked up too, once per statement.
  H.scratch({
    "local a = vim.api.nvim_buf_get_lines(0, 0, -1, false)",
    "local b = vim.api.nvim_buf_set_lines(0, 0, -1, false, {})",
    "local c = vim.api.nvim_win_get_buf(0)",
  })
  local found = ts_analyzer.analyze(1, {}, {})
  H.eq(#found, 4, "the three full call chains plus the vim.api prefix they share")
  H.eq(H.find(found, "vim.api.nvim_buf_get_lines").count, 2, "matched as both a field access and a call target")
  H.eq(H.find(found, "vim.api.nvim_buf_set_lines").count, 2, "same double-match for the second call")
  H.eq(H.find(found, "vim.api.nvim_win_get_buf").count, 2, "same double-match for the third call")
  H.eq(H.find(found, "vim.api").count, 3, "the shared prefix, matched once per statement as a nested field access")
  H.eq(
    H.find(found, "vim.api.nvim_buf_get_lines").alias,
    "local api = vim.api",
    "all four chains share the vim.api prefix, so all alias to it"
  )
end
