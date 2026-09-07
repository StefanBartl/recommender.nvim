# Contributing to recommender.nvim

Thank you for your interest! Bugs, ideas and questions are welcome in the
[issue tracker](https://github.com/StefanBartl/recommender.nvim/issues); pull
requests very welcome.

## Getting the repository into a session

Clone it and either symlink the checkout into your plugin directory or add it
to the runtime path directly:

```lua
vim.opt.rtp:prepend("/path/to/recommender.nvim")
require("recommender").setup({})
```

[lib.nvim](https://github.com/StefanBartl/lib.nvim) has to be on the runtime
path too — `:Recommender` is registered through its user-command composer and
does not exist without it. Nothing else is required.

## Ground rules

- Lua only, idiomatic Neovim Lua. 2-space indentation, `stylua.toml` decides
  the rest.
- **A claim about performance is measured or it is not made.** The perf
  analyzer exists because benchmarking this plugin's own premise showed that
  dotted-chain aliasing has no measurable benefit under LuaJIT. Every pattern
  `perf` flags carries an isolated before/after measurement, and a new one
  without a measurement does not go in. The aliasing suggestions are a
  readability feature and the documentation says so.
- **An analyzer counts; the float decides.** An analyzer returns findings as
  data — chain, count, positions — and never touches a buffer or opens a
  window. That separation is what lets the same four backends feed one float
  and one replace path.
- **Nothing blocks.** A `cwd` or `path` scan is asynchronous and cancellable,
  with progress through `lib.nvim.progress`. A synchronous walk over a project
  tree is not an acceptable shortcut, and `cwd_max_files` and `cwd_ignore`
  exist so a scan has a ceiling rather than an apology.
- **Insertion always goes into the invoking buffer.** Scope changes where
  chains are *counted*, never where the declaration lands. A wider scope that
  starts editing other files would be a different plugin.
- **Optional dependencies are required lazily.** The Tree-sitter analyzer is
  required the first time it is selected, never at load; replacer.nvim is
  reached for only when replace mode runs. Without either, the corresponding
  feature is missing and everything else works.
- Commands are registered through `lib.nvim.bindings.usercmd.composer`.
  Analyzer, scope and threshold are positional and order-independent — keep new
  arguments in that shape rather than adding a required position.
- Descriptive commit messages.

## Project layout

| Path | Contains |
| --- | --- |
| `lua/recommender/analyzers/` | `regex.lua` and `treesitter.lua` (Lua), `javascript.lua`, `python.lua`, and `perf.lua` |
| `lua/recommender/float/` | The suggestion window: rendering, its keys, and accepting a suggestion |
| `lua/recommender/bindings/` | The `:Recommender` command and the default keymaps |
| `lua/recommender/config/` | Defaults and validation |
| `lua/recommender/util/` | The lib.nvim delegates, the file walk, and the shared helpers |
| `lua/recommender/health.lua` | `:checkhealth recommender` |
| `doc/`, `docs/` | The vimdoc, and everything the README links to |
| `TESTS/` | The spec suite |

[`architecture.md`](architecture.md) has the design principles behind that
layout.

## Adding an analyzer

1. Add the module under `lua/recommender/analyzers/`, modelled on
   `regex.lua`. It takes lines and returns findings; it does not open a window
   and it does not write to a buffer.
2. Declare the file extensions it applies to, so the `cwd` and `path` scans
   know what to feed it.
3. If it needs a parser or any other heavy dependency, require it inside the
   call, not at module load — `treesitter.lua` is the model, and the reason the
   other four never pay for a parser they do not use.
4. Register it so the analyzer name completes with `<Tab>` from the registry
   rather than from a second list.
5. Report its availability in `lua/recommender/health.lua`.
6. Add a spec under `TESTS/` against a fixture, asserting on the findings.
7. Document it in [`FEATURES.md`](FEATURES.md), [`commands.md`](commands.md)
   and [`configuration.md`](configuration.md).

If the analyzer flags something on performance grounds, the measurement goes in
the documentation with it. See the ground rules.

## Tests

`TESTS/` is a headless spec suite over the analyzers, the config and the
project walk.

```
nvim --headless -u NONE -c "set rtp+=." -l TESTS/run.lua
```

Exit 0 is a pass. [GitHub Actions](../.github/workflows/ci.yml) runs it plus
stylua and luacheck on every push and pull request to `main`.

## Workflow

1. Fork the repository.
2. Branch as `feature/<name>`.
3. Make the change, add a spec, update the affected pages under `docs/`.
4. Open a PR with a clear description of what changed and why.
