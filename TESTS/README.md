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
| `perf_analyzer_spec.lua` | the block tracker: the same call is a finding inside a loop and noise outside one |
| `config_spec.lua` | the merge, and that `DEFAULTS` survives it unmutated |
| `project_spec.lua` | file collection for the non-buffer scopes, the ignore list, the cap |

Adding one: write `TESTS/<name>_spec.lua` returning
`function(H) ... end`, then list it in `run.lua`. `H` is the harness —
`eq`, `ok`, `falsy`, `find` (look a suggestion up by chain, so a spec never
depends on result order it is not asserting) and `scratch` (a buffer filled
with lines, made current).

## A note on fixtures

`project_spec.lua` writes its fixture under `TESTS/.fixture/` rather than into
`vim.fn.tempname()`. On Windows the temp path contains an 8.3 short component
(`STEFAN~1`), and `glob()`/`globpath()` return nothing for files written
beneath it — so a tempname-based fixture would pass on Linux and quietly assert
nothing here. A path inside the repository has no such component on either OS.
