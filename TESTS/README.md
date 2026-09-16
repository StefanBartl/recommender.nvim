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

Adding one: write `TESTS/<name>_spec.lua` returning
`function(H) ... end`, then list it in `run.lua`. `H` is the harness —
`eq`, `ok`, `falsy`, `find` (look a suggestion up by chain, so a spec never
depends on result order it is not asserting) and `scratch` (a buffer filled
with lines, made current).

## Coverage

Every `lua/recommender/**/*.lua` file with real logic or branching that can be
required without `ui.kit` (see "Deliberately left untested" below) now has a
dedicated real-assertion spec: the regex/javascript/python/tree-sitter
analyzers, the blacklist, the config merge, project-wide file/line collection
(sync and async), the replace-mode `WinClosed` detector, the global-keymap
override resolution, and the `lib.nvim`-soft-dependency fallbacks in
`util/lib.lua` and `util/progress.lua`.

### Deliberately left untested

- **`recommender/init.lua`, `bindings/init.lua`, `bindings/usrcmds.lua`,
  `float/rendering.lua`, `float/keymaps.lua`** — all require `ui.kit`
  (ui.nvim) transitively at module load (`usrcmds.lua` requires
  `float/rendering.lua` and `float/keymaps.lua` directly; `bindings/init.lua`
  and `recommender/init.lua` require `usrcmds.lua` in turn). This repo's own
  CI (`.github/workflows/ci.yml`) checks out only `lib.nvim` as a sibling, not
  `ui.nvim` — so a spec that so much as `require`s any of these five modules
  would pass locally (where a `ui.nvim` checkout happens to be on disk) and
  fail in CI. `usrcmds.lua` in particular has real, pure logic worth testing
  (`classify_pos_args`, `resolve_cfile`) that is currently untestable for
  exactly this reason — see the note in the final report for a possible
  follow-up (lazy-requiring `float/rendering`/`float/keymaps` from inside
  `execute()` instead of at module top level would unblock this without
  changing any behavior).
- **`custom_aliases.lua`, `config/DEFAULTS.lua`** — plain data tables (`return
  { ... }`), no branching of their own; `DEFAULTS`'s merge behavior is what
  `config_spec.lua` actually tests.
- **`health.lua`** — a declarative `:checkhealth` reporter: each line maps a
  runtime probe (an optional dependency, a version check, a config value)
  straight to one `vim.health.*` call with no computed value returned.
  Exercising every branch would mean mocking every probe and asserting "the
  right `vim.health.*` method got the right string" — testing the mocks more
  than the code, for a module whose failure mode (a wrong hint in
  `:checkhealth`) has no functional blast radius.
- **`bindings/autocmds.lua`** — an intentionally empty stub (see its own
  header comment): `bindings/` mirrors the usrcmds/keymaps/autocmds shape used
  across the other plugins even though this one has no plugin-level
  autocommands to register.
- **`@types.lua`** — a `---@meta` type-anchor file; no runtime behavior.

## A note on fixtures

`project_spec.lua` writes its fixture under `TESTS/.fixture/` rather than into
`vim.fn.tempname()`. On Windows the temp path contains an 8.3 short component
(`STEFAN~1`), and `glob()`/`globpath()` return nothing for files written
beneath it — so a tempname-based fixture would pass on Linux and quietly assert
nothing here. A path inside the repository has no such component on either OS.
