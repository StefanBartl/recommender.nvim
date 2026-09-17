-- TESTS/statusline_spec.lua — `recommender.statusline`, the component a
-- statusline plugin calls.
--
-- These assertions used to live in ui.nvim, against injected fakes for
-- `recommender.config` and `recommender.analyzers.*`. The component moved
-- here (cross-feature report, finding E) and the tests came with it, which
-- means they now run against the real analyzer and the real config rather
-- than a stub of this plugin written in another repository.

return function(H)
  local statusline = require("recommender.statusline")
  local config = require("recommender.config")

  --- A buffer with `lines`, made current, with the cache dropped so each
  --- case starts from a real analysis.
  ---@param lines string[]
  ---@return integer bufnr
  local function buffer(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(buf)
    statusline.invalidate(buf)
    return buf
  end

  config.setup({ analyzer = "regex", threshold = 2 })

  -- Nothing to say ----------------------------------------------------------
  local empty = buffer({ "local x = 1", "return x" })
  H.eq(statusline.status(empty), "", "a buffer with no repeated chains renders empty")

  -- Plural ------------------------------------------------------------------
  -- Two distinct chains, each used twice, so both clear the threshold.
  local many = buffer({
    "local a = vim.api.nvim_buf_get_lines(0, 0, -1, false)",
    "local b = vim.api.nvim_buf_set_lines(0, 0, -1, false, {})",
    "local c = vim.fn.expand('%')",
    "local d = vim.fn.getcwd()",
  })
  local out = statusline.status(many)
  H.ok(out:find("alias suggestions", 1, true) ~= nil, "several suggestions use the plural")
  H.ok(out:find("open for this file", 1, true) ~= nil, "the wording names the file")
  H.ok(out:match("%d") ~= nil, "the count is in the string")

  -- Singular ----------------------------------------------------------------
  local one = buffer({
    "local a = vim.api.nvim_buf_get_lines(0, 0, -1, false)",
    "local b = vim.api.nvim_buf_set_lines(0, 0, -1, false, {})",
  })
  local single = statusline.status(one)
  H.ok(single:find("1 alias suggestion ", 1, true) ~= nil, "exactly one uses the singular")
  H.ok(single:find("suggestions", 1, true) == nil, "...and not the plural")

  -- Caching -----------------------------------------------------------------
  -- The analyzer rescans the buffer, and a statusline redraws many times a
  -- second, so the result must be reused until the buffer actually changes.
  local cached_buf = buffer({
    "local a = vim.api.nvim_buf_get_lines(0, 0, -1, false)",
    "local b = vim.api.nvim_buf_set_lines(0, 0, -1, false, {})",
  })
  local first = statusline.status(cached_buf)
  H.eq(statusline.status(cached_buf), first, "a second call with no edit returns the same text")

  vim.api.nvim_buf_set_lines(cached_buf, 0, -1, false, { "local x = 1" })
  H.eq(statusline.status(cached_buf), "", "an edit invalidates the cache and re-analyses")

  -- Degradation -------------------------------------------------------------
  local gone = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_delete(gone, { force = true })
  H.eq(statusline.status(gone), "", "an invalid buffer renders empty rather than erroring")

  -- An analyzer name that resolves to nothing must not raise into a redraw.
  config.setup({ analyzer = "no-such-analyzer", threshold = 2 })
  local unknown = buffer({ "local a = vim.api.nvim_buf_get_lines(0, 0, -1, false)" })
  H.eq(statusline.status(unknown), "", "an unknown analyzer renders empty rather than erroring")
  config.setup({ analyzer = "regex", threshold = 2 })

  -- The lualine alias -------------------------------------------------------
  H.eq(type(statusline.lualine_component), "function", "lualine_component is callable")
  H.eq(type(statusline.lualine_component()), "string", "...and returns a string")
end
