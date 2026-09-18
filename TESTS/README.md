# TESTS/

Headless spec suite. No plugin manager, no tree, no picker — every spec drives
a module directly and asserts on what it returns.

```
nvim --headless -u NONE -c "set rtp+=." -l TESTS/run.lua
```

Exit 0 is a pass; the runner prints one line per spec and exits non-zero on the
first failure. CI runs exactly this command.

## lib.nvim

`recommender.blacklist` and `recommender.util.lib` require lib.nvim at module
load, so the suite cannot run without it. `run.lua` resolves it in this order:

1. `$LIB_NVIM_PATH`
2. a sibling checkout, `../lib.nvim`
3. the lazy.nvim-managed copy under `stdpath("data")/lazy/lib.nvim`

A sibling wins over the plugin-manager copy on purpose: that one is often older
than the working checkout, and testing against a stale lib.nvim gives
misleading failures.

## The specs

| | |
| --- | --- |
| `blacklist_spec.lua` | prefix matching, including the sharp edge that it matches strings and not dot-separated segments |
| `regex_analyzer_spec.lua` | which chains the default analyzer finds, how it counts them, the derived and custom alias forms |
| `javascript_analyzer_spec.lua` | the JS/TS analyzer: `$`-permissive identifiers, the `const %s = %s;` alias form |
| `python_analyzer_spec.lua` | the Python analyzer: the plain `%s = %s` alias form (no `local`/`const`) |
| `treesitter_analyzer_spec.lua` | the pure "counts → ranked, aliased suggestions" half (`_internal.build_suggestions`, `_internal.common_prefix`), and `M.analyze()` end-to-end against a real Tree-sitter-parsed buffer |
| `perf_analyzer_spec.lua` | the block tracker: the same call is a finding inside a loop and noise outside one |
| `config_spec.lua` | the merge, that `DEFAULTS` survives it unmutated, and the cached no-`setup()` snapshot |
| `project_spec.lua` | file collection for the non-buffer scopes, the ignore list, the cap |
| `float_autocmds_spec.lua` | the one-shot `WinClosed` replace-mode detector: change-vs-no-change, the `TelescopePrompt`-only filetype gate, an already-closed target window |
| `keymaps_spec.lua` | `config.keymaps = true/false/table` override resolution, and the `run(args)` closures' count → `--threshold=N` composition |
| `util_lib_spec.lua` | `util/lib.lua`'s notify/keymap fallback when `lib.nvim` is hidden, `util/notify.lua`'s delegation, `util/progress.lua`'s load-time availability capture |
| `statusline_spec.lua` | the buffer/changedtick cache, and the `""` fallback for "no suggestions" and every failure mode alike |
| `usrcmds_spec.lua` | `bindings/usrcmds.lua`'s pure dispatch helpers: `classify_pos_args`'s order-independent scope/analyzer/threshold classification, `resolve_cfile`'s literal → buffer-relative → `'path'` resolution order |
| `rendering_spec.lua` | `float/rendering.lua`'s pure item-building half (`_internal.build_item`): the "detailed" vs. "compact" `float_layout`s, and the byte-offset highlight spans for the arrow glyph/chain/count/alias |
| `float_keymaps_spec.lua` | `float/keymaps.lua`'s pure window-selection helpers (`_internal.is_normal_window`, `_internal.find_target_window`): the source_win → alternate window → first-normal-window-in-the-list fallback chain |

Adding one: write `TESTS/<name>_spec.lua` returning
`function(H) ... end`, then list it in `run.lua`. `H` is the harness —
`eq`, `ok`, `falsy`, `find` (look a suggestion up by chain, so a spec never
depends on result order it is not asserting), `scratch` (a buffer filled
with lines, made current), and `wait_until` (poll a predicate via `vim.wait`
for code that finishes through a `vim.schedule` chain rather than returning
a value directly — see `project_spec.lua`'s async cases).

## Coverage

Every `lua/recommender/**/*.lua` file with real logic or branching now has a
dedicated real-assertion spec: the regex/javascript/python/tree-sitter
analyzers, the blacklist, the config merge, project-wide file/line collection
(sync and async), the replace-mode `WinClosed` detector, the global-keymap
override resolution, the `lib.nvim`-soft-dependency fallbacks in
`util/lib.lua` and `util/progress.lua`, the statusline component's cache, and
(as of this re-audit) the pure logic inside the three modules that require
`ui.kit` at module load — `bindings/usrcmds.lua`'s token classification and
`<cfile>` resolution, `float/rendering.lua`'s item/highlight builder, and
`float/keymaps.lua`'s window-selection helpers.

### The `ui.kit` seam

`bindings/usrcmds.lua`, `float/rendering.lua`, and `float/keymaps.lua` all
`require("ui.kit")` (ui.nvim) at module load (`usrcmds.lua` transitively, via
`float/rendering.lua` and `float/keymaps.lua`). This repo's own CI
(`.github/workflows/ci.yml`) checks out only `lib.nvim` as a sibling, not
`ui.nvim` — so a spec that plainly `require`s any of these three modules would
pass locally (a `ui.nvim` checkout happens to sit next to this repo on the
maintainer's machine) and fail in CI.

None of the three functions actually tested here — `classify_pos_args`,
`resolve_cfile`, `build_item`, `is_normal_window`, `find_target_window` — ever
call into `kit` themselves; only the `require("ui.kit")` at the top of their
files needs satisfying. `TESTS/usrcmds_spec.lua`, `TESTS/rendering_spec.lua`,
and `TESTS/float_keymaps_spec.lua` each drop a minimal
`package.loaded["ui.kit"] = {}` in before their first `require` of the module
under test, which is enough: Lua's `require` consults `package.loaded` before
ever touching the runtimepath, so the stub wins regardless of whether a real
`ui.nvim` checkout happens to be sitting on disk. CI still never needs one.
This unblocks exactly the follow-up an earlier pass of this README flagged as
future work, without lazy-requiring anything or touching production code
beyond adding the three `M._internal` exports these specs read from (the same
pattern `treesitter.lua` already uses for `_internal.build_suggestions`).

What is *not* covered by this seam, and stays out of scope for this campaign:
actually calling `kit.select`/`kit.chooser` to open, navigate, or close a real
picker (`rendering.M.open/is_open/close`, `keymaps.M.make_on_select`'s
schedule-and-insert tail, `usrcmds.M.setup`'s full `execute()` dispatch) — all
of that needs a real, rendering `ui.nvim`, which is exactly the "UI that needs
a real live backend" this campaign's definition of "100%" excludes.

### Deliberately left untested

- **`custom_aliases.lua`, `config/DEFAULTS.lua`** — plain data tables (`return
  { ... }`), no branching of their own; `DEFAULTS`'s merge behavior is what
  `config_spec.lua` actually tests.
- **`health.lua`** — a declarative `:checkhealth` reporter: each line maps a
  runtime probe (an optional dependency, a version check, a config value)
  straight to one `vim.health.*` call with no computed value returned.
  Exercising every branch would mean mocking every probe and asserting "the
  right `vim.health.*` method got the right string" — testing the mocks more
  than the code, for a module whose failure mode (a wrong hint in
  `:checkhealth`) has no functional blast radius. Re-checked this round: every
  branch here is self-contained (each `pcall`/`vim.fn.has`/`vim.g` check
  reports its own `vim.health.*` line and never calls onward into whatever it
  just found missing), so the "warns, then crashes into the missing
  dependency anyway" pattern this campaign keeps finding elsewhere does not
  occur here.
- **`bindings/autocmds.lua`** — an intentionally empty stub (see its own
  header comment): `bindings/` mirrors the usrcmds/keymaps/autocmds shape used
  across the other plugins even though this one has no plugin-level
  autocommands to register.
- **`recommender/init.lua`, `bindings/init.lua`** — unconditional,
  one-line-per-call wiring (`bindings.setup()` → `usrcmds.setup()` +
  `keymaps.bind()` + `autocmds.setup()`) with no branching of their own beyond
  `init.lua`'s `_setup_done` guard against a second `setup()` call — every
  module they wire together is already covered by its own spec (directly, or,
  for the three `ui.kit`-adjacent ones, via the seam above).
- **`@types.lua`** — a `---@meta` type-anchor file; no runtime behavior.

### Bug patterns checked for and ruled out this round

This campaign has repeatedly found four bug shapes across other plugins'
`nvim-config` fleet. All four were checked against this repo specifically,
not assumed absent:

- **A `health.lua` that warns a dependency is missing, then calls into it
  anyway.** Not here — see `health.lua` above; every check is self-contained.
- **A non-idempotent `setup()`** (an augroup wrapper resolving a group by name
  without `clear = true`, so a second `setup()` doubles up handlers). This
  repo's two dynamic augroups (`float/autocmds.lua`'s
  `RecommenderNvimReplaceInsert`, `statusline.lua`'s `recommender_statusline`)
  both call `lib.nvim`'s `autocmd.group(name, true)` — the `true` is exactly
  the `clear` argument, so re-registration clears rather than accumulates.
  `recommender/init.lua`'s own `M.setup()` is additionally guarded by a
  `_setup_done` boolean, so a second call is a no-op rather than a
  re-registration at all.
- **Byte-offset vs. display-column vs. character-index confusion.** The one
  place this repo computes highlight columns from text is
  `float/rendering.lua`'s `build_item` (now covered by
  `TESTS/rendering_spec.lua`): every offset comes from `string.find`/`#`,
  which operate on bytes, and are handed straight to `kit.select`'s
  highlights, which Neovim's own highlight APIs also expect as 0-indexed byte
  columns — no display-column or character-index arithmetic is mixed in
  anywhere.
- **Windows path/separator bugs.** `project.lua`'s `is_ignored` already splits
  on `"[/\\]"` (both separators), and `find_files_async`'s uv-built paths vs.
  `find_files`'s `globpath()`-native ones are compared modulo separator style
  in `project_spec.lua`, not by string equality. `bindings/usrcmds.lua`'s
  `resolve_cfile` was not previously tested at all; `TESTS/usrcmds_spec.lua`
  (added this round) found the same native-vs-forward-slash split between a
  literal/buffer-relative candidate and a `vim.fn.findfile()` result, and
  normalizes before comparing for the same reason. No drive-letter-colon
  parsing exists anywhere in this repo (no code splits a path on `":"`).

## A note on fixtures

`project_spec.lua` writes its fixture under `TESTS/.fixture/` rather than into
`vim.fn.tempname()`. On Windows the temp path contains an 8.3 short component
(`STEFAN~1`), and `glob()`/`globpath()` return nothing for files written
beneath it — so a tempname-based fixture would pass on Linux and quietly assert
nothing here. A path inside the repository has no such component on either OS.
`usrcmds_spec.lua` writes its own, separate fixture under
`TESTS/.fixture_usrcmds/` for the same reason (`resolve_cfile` goes through
`vim.fn.filereadable`/`findfile`, which have the same 8.3 blind spot).
