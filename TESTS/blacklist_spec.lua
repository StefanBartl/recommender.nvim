-- TESTS/blacklist_spec.lua — recommender.blacklist: prefix matching.
--
-- The blocklist is prefix-based on purpose: one `vim.api` entry has to cover
-- every `vim.api.nvim_*` chain, or a user would have to list them one by one.
-- The flip side is that a prefix can match more than it looks like it does,
-- which is what most of this spec pins down.

return function(H)
  local bl = require("recommender.blacklist")

  -- No list at all -----------------------------------------------------------
  -- Deliberately the wrong argument: what is under test is that it copes.
  ---@diagnostic disable-next-line: param-type-mismatch
  H.falsy(bl.is_blacklisted("vim.api.nvim_buf_get_lines", nil), "nil list blocks nothing")
  H.falsy(bl.is_blacklisted("vim.api.nvim_buf_get_lines", {}), "empty list blocks nothing")

  -- Exact and prefix ---------------------------------------------------------
  H.ok(bl.is_blacklisted("vim.api", { "vim.api" }), "an entry blocks itself")
  H.ok(bl.is_blacklisted("vim.api.nvim_buf_get_lines", { "vim.api" }), "an entry blocks every chain beneath it")
  H.falsy(bl.is_blacklisted("vim.fn", { "vim.api" }), "a sibling namespace is not blocked")

  -- Prefix, not segment ------------------------------------------------------
  -- Worth stating outright: matching is on the string, not on dot-separated
  -- segments, so `vim.a` also blocks `vim.api`. That is a real sharp edge for
  -- anyone writing a blocklist, and pinning it here means a future switch to
  -- segment matching cannot happen silently.
  H.ok(bl.is_blacklisted("vim.api", { "vim.a" }), "matching is by string prefix, not by segment")

  -- Several entries ----------------------------------------------------------
  local list = { "vim.fn", "vim.api" }
  H.ok(bl.is_blacklisted("vim.api.nvim_set_hl", list), "any entry in the list is enough")
  H.falsy(bl.is_blacklisted("vim.lsp.buf", list), "a chain matching none of them passes")
end
