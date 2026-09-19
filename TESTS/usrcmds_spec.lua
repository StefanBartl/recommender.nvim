-- TESTS/usrcmds_spec.lua — recommender.bindings.usrcmds's pure dispatch
-- helpers: `classify_pos_args` (order-independent scope/analyzer/threshold
-- classification) and `resolve_cfile` (<cfile> resolution for `:Recommender
-- cfile`), both exposed via `M._internal`.
--
-- usrcmds.lua requires recommender.float.rendering and recommender.float.
-- keymaps at module load, and both of those require "ui.kit" (ui.nvim) at
-- their own module load -- unavailable in this repo's own CI (only lib.nvim
-- is checked out as a sibling there, see TESTS/README.md). Neither function
-- under test here calls into `kit` at all, so a minimal stub dropped into
-- `package.loaded["ui.kit"]` *before* the first `require` of any of these
-- three modules is enough to unlock them, without needing a real ui.nvim
-- checkout anywhere -- see TESTS/rendering_spec.lua and
-- TESTS/float_keymaps_spec.lua for the same technique against the other two.
if not package.loaded["ui.kit"] then
  package.loaded["ui.kit"] = {}
end

return function(H)
  local usrcmds = require("recommender.bindings.usrcmds")
  local classify_pos_args = usrcmds._internal.classify_pos_args
  local resolve_cfile = usrcmds._internal.resolve_cfile

  -- classify_pos_args: order-independence -------------------------------------
  do
    local analyzer, threshold, scope = classify_pos_args({ "cwd", "javascript", "5" })
    H.eq(analyzer, "javascript", "analyzer classified regardless of slot")
    H.eq(threshold, 5, "threshold classified regardless of slot")
    H.eq(scope, "cwd", "scope classified regardless of slot")
  end

  do
    local analyzer, threshold, scope = classify_pos_args({ "javascript", "cwd", "5" })
    H.eq(analyzer, "javascript", "same result, args reordered (1)")
    H.eq(threshold, 5, "same result, args reordered (1)")
    H.eq(scope, "cwd", "same result, args reordered (1)")
  end

  do
    local analyzer, threshold, scope = classify_pos_args({ "5", "javascript", "cwd" })
    H.eq(analyzer, "javascript", "same result, args reordered (2)")
    H.eq(threshold, 5, "same result, args reordered (2)")
    H.eq(scope, "cwd", "same result, args reordered (2)")
  end

  do
    local analyzer, threshold, scope = classify_pos_args({})
    H.falsy(analyzer, "no tokens -> no analyzer")
    H.falsy(threshold, "no tokens -> no threshold")
    H.falsy(scope, "no tokens -> no scope")
  end

  do
    local analyzer, threshold, scope = classify_pos_args({ "7" })
    H.falsy(analyzer, "a lone number is not an analyzer")
    H.eq(threshold, 7, "...but is the threshold")
    H.falsy(scope, "a lone number is not a scope")
  end

  -- Each category takes only its first match; a second candidate for an
  -- already-filled category is not reassigned, and (for scope/analyzer
  -- names, which are not numbers) is not picked up by `tonumber` either --
  -- it is simply dropped.
  do
    local analyzer, threshold, scope = classify_pos_args({ "cwd", "path" })
    H.eq(scope, "cwd", "the first scope name wins")
    H.falsy(analyzer, "'path' does not double as an analyzer name")
    H.falsy(threshold, "...nor does it parse as a number, so the threshold stays unset")
  end

  do
    local analyzer, threshold, scope = classify_pos_args({ "3", "5" })
    H.eq(threshold, 3, "the first numeric token wins the threshold slot")
    H.falsy(analyzer, "a second number is not an analyzer")
    H.falsy(scope, "a second number is not a scope")
  end

  -- A token matching none of the three is reported, not dropped (ERR-10):
  -- "no argument" and "a garbage argument" must not look identical.
  do
    local analyzer, threshold, scope, unrecognized = classify_pos_args({ "javascrpt" })
    H.falsy(analyzer, "a near-miss token is not treated as the analyzer")
    H.falsy(threshold, "...nor coerced into a threshold")
    H.falsy(scope, "...nor a scope")
    H.eq(#unrecognized, 1, "the unrecognized token is reported")
    H.eq(unrecognized[1], "javascrpt", "...by its own text")
  end

  -- A second candidate for an already-filled category is unrecognized too,
  -- not silently absorbed -- {"cwd", "path"} used to leave "path" with no
  -- trace at all once "cwd" had already claimed the scope slot.
  do
    local _, _, scope, unrecognized = classify_pos_args({ "cwd", "path" })
    H.eq(scope, "cwd", "the first scope name still wins the slot")
    H.eq(#unrecognized, 1, "the second scope-shaped token is reported")
    H.eq(unrecognized[1], "path", "...by its own text")
  end

  -- Every token classifies cleanly -> nothing unrecognized.
  do
    local _, _, _, unrecognized = classify_pos_args({ "cwd", "javascript", "5" })
    H.eq(#unrecognized, 0, "a fully valid token set reports nothing unrecognized")
  end

  -- resolve_cfile ---------------------------------------------------------------
  do
    local root = vim.fs.normalize(vim.fn.getcwd()) .. "/TESTS/.fixture_usrcmds"
    vim.fn.delete(root, "rf")
    vim.fn.mkdir(root .. "/bufdir", "p")
    vim.fn.mkdir(root .. "/pathdir", "p")
    vim.fn.writefile({ "in bufdir" }, root .. "/bufdir/foo.txt")
    vim.fn.writefile({ "in pathdir" }, root .. "/pathdir/bar.txt")

    local saved_path = vim.o.path

    -- nil/empty <cfile> -> the "nothing under the cursor" message, not a crash.
    do
      local path, err = resolve_cfile(nil, 0)
      H.falsy(path, "nil cfile resolves to nothing")
      H.eq(err, "no file name under the cursor", "...with the expected message")

      local path2, err2 = resolve_cfile("", 0)
      H.falsy(path2, "empty cfile resolves to nothing")
      H.eq(err2, "no file name under the cursor", "...with the same message")
    end

    -- Literal path, readable as typed (independent of any buffer).
    do
      local literal = root .. "/bufdir/foo.txt"
      local buf = H.scratch({ "" })
      local path, err = resolve_cfile(literal, buf)
      H.eq(path, vim.fn.fnamemodify(literal, ":p"), "a literally-readable cfile resolves as-is")
      H.falsy(err, "...with no error")
    end

    -- Relative to the source buffer's own directory.
    do
      local buf = H.scratch({ "" })
      vim.api.nvim_buf_set_name(buf, root .. "/bufdir/dummy_source.lua")
      local path, err = resolve_cfile("foo.txt", buf)
      H.eq(
        path,
        vim.fn.fnamemodify(root .. "/bufdir/foo.txt", ":p"),
        "a bare filename resolves relative to the buffer's directory"
      )
      H.falsy(err, "...with no error")
    end

    -- Not literal, not next to the buffer, but found via 'path'. `findfile`
    -- returns a native-separator path (backslashes on Windows) regardless of
    -- which slash style `vim.o.path` was given in, so the comparison
    -- normalizes before asserting -- same reasoning as TESTS/project_spec.lua's
    -- sync-vs-async path comparison.
    do
      vim.o.path = vim.o.path .. "," .. root .. "/pathdir"
      local buf = H.scratch({ "" })
      vim.api.nvim_buf_set_name(buf, root .. "/bufdir/dummy_source2.lua") -- no bar.txt here
      local path, err = resolve_cfile("bar.txt", buf)
      H.eq(
        vim.fs.normalize(path),
        vim.fs.normalize(root .. "/pathdir/bar.txt"),
        "falls back to 'path' when neither the literal nor the buffer-relative candidate exists"
      )
      H.falsy(err, "...with no error")
    end

    -- An unnamed buffer (bufname == "") skips the buffer-relative candidate
    -- entirely rather than erroring on an empty base directory.
    do
      local buf = H.scratch({ "" }) -- freshly created, never named
      local path, err = resolve_cfile("bar.txt", buf)
      H.eq(vim.fs.normalize(path), vim.fs.normalize(root .. "/pathdir/bar.txt"), "an unnamed buffer still resolves via 'path'")
      H.falsy(err, "...with no error")
    end

    -- Found nowhere -> nil plus a message naming the file.
    do
      local buf = H.scratch({ "" })
      vim.api.nvim_buf_set_name(buf, root .. "/bufdir/dummy_source3.lua")
      local path, err = resolve_cfile("does_not_exist.txt", buf)
      H.falsy(path, "an unresolvable cfile returns nil")
      H.eq(err, [[no readable file found for "does_not_exist.txt" under the cursor]], "...with a message naming the file")
    end

    vim.o.path = saved_path
    vim.fn.delete(root, "rf")
  end
end
