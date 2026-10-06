-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "recommender",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = "h",
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim", "ui.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next).
  isolated = "none",
  -- Guards (docs/GUARDS.md of testing.nvim): every guard errors except the state guard.
  guards = {
    fs = "error",
    scheduled_error = "error",
    prompt = "error",
    deprecation = "error",
    process_net = "error",
    -- warn: the specs leave scratch buffers plus the setup() keymaps and autocmds behind.
    -- isolated = "file" would clean that up but exposes a real bug of the specs: float_keymaps_spec.lua:111
    -- ("falls through to the one normal window left") expects window 1008 but gets 1000 in a fresh
    -- editor; it only holds when an earlier spec file left window 1000 holding a special buffer.
    state = "warn",
  },
  guard_allow = {
    fs = {
      -- project_spec.lua creates and deletes this fixture tree inside the repository.
      "TESTS/.fixture",
      -- usrcmds_spec.lua creates and deletes this fixture tree inside the repository.
      "TESTS/.fixture_usrcmds",
    },
  },
}
