> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

# recommender.nvim

```
  ___                                              _
 | _ \___  __ ___ _ __  _ __  ___ _ _  __| |___ _ _
 |   / -_)/ _/ _ \ '  \| '  \/ -_) ' \/ _` / -_) '_|
 |_|_\___|\__\___/_|_|_|_|_|_\___|_||_\__,_\___|_|
                                               .nvim
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-beta-orange)
[![CI](https://github.com/StefanBartl/recommender.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/recommender.nvim/actions/workflows/ci.yml)

Finds the repetition in your code and offers to do something about it.

It reads a buffer — or a wider scope — for dotted chains repeated often enough
to be worth aliasing, and puts the suggestions in a float you can act on
without leaving it. Pure Neovim, no external tooling.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the defaults](#what-you-get-with-the-defaults)
- [The perf analyzer](#the-perf-analyzer)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

- [Features](docs/FEATURES.md) — everything this plugin does, in one file: what it analyses, and what it suggests from that.
- [Installation](docs/installation.md) — requirements, and a spec per plugin manager.
- [Configuration](docs/configuration.md) — every `setup()` option, its default, and the default keymaps.
- [Command reference](docs/commands.md) — `:Recommender`, the scopes, the float's keys, and replace mode.
- [Examples](docs/examples.md) — a worked before/after of the suggestion float.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, command and autocommand in one reference.
- [Workflow](docs/WORKFLOW.md) — when to run the analysis and what to do with the answer, rather than what it reports.
- [Architecture](docs/architecture.md) — module layout and design principles.
- [Troubleshooting](docs/troubleshooting.md) — what `:checkhealth recommender` asks.
- [Contributing](docs/CONTRIBUTING.md) — ground rules, project layout, and how to add an analyzer.

`:help recommender` is the same reference inside the editor.

---

## What it does

`vim.api` written forty times in a file is not a bug, and no linter will
mention it. It is the kind of thing you notice once, decide to fix later, and
never look at again. This plugin is the "later": it counts, it shows you the
count, and it writes the alias for you.

| Area | Does |
| --- | --- |
| **Chain analysis** | Counts repeated dotted chains — `vim.api`, `table.insert`, and the rest — and suggests an alias declaration for the ones over the threshold |
| **Four languages** | Lua through a regex or a Tree-sitter backend, plus separate backends for JS/TS and Python |
| **Scopes** | The current buffer by default, or `line`, `cfile`, `path` (this file's directory) or `cwd` (the whole tree). A wider scope surfaces chains that repeat across a project even when no single file crosses the threshold |
| **The float** | An interactive window: accept, skip, or look at the occurrences, without leaving it |
| **Replace mode** | With `-r`, accepting a suggestion rewrites every occurrence in the buffer as well as inserting the declaration |
| **The perf analyzer** | A different check entirely — four benchmarked Lua anti-patterns rather than chain repetition. See [below](#the-perf-analyzer) |

A `cwd` or `path` scan runs fully asynchronously: the editor never freezes,
however large the tree, and an optional `progress_style` indicator shows where
it is — a notification, the statusline, fidget, or a cancellable float.

---

## Around it

> **[replacer.nvim](https://github.com/StefanBartl/replacer.nvim)** — provides
> the `:Replace` command that replace mode drives. Without it a suggestion
> still inserts its declaration; it just does not rewrite the occurrences.
>
> **[insights.nvim](https://github.com/StefanBartl/insights.nvim)** — the other
> half of "what is actually in this code": imports, symbols, and the magic
> numbers this plugin does not look for.
>
> **[runtime-analysis.nvim](https://github.com/StefanBartl/runtime-analysis.nvim)** —
> where a claim about performance gets measured rather than assumed. The perf
> analyzer exists because that question was asked of this plugin's own premise.
>
> All of the above are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
> dependency — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — `:Recommender` is registered through its user-command composer, and the progress indicator is its `progress` module |

No external tools at all. Optional, each detected at runtime and degrading to
nothing when absent:

| | |
| --- | --- |
| A Tree-sitter Lua parser | Only needed for `analyzer = "treesitter"`, and only in the buffer scope; the module is required the first time that analyzer is actually selected, so the others never pay for it |
| [replacer.nvim](https://github.com/StefanBartl/replacer.nvim) | Replace mode (`-r`), which rewrites every occurrence rather than only inserting the alias |
| fidget.nvim | One of the `progress_style` back ends for a long scan |

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/recommender.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  ft  = { "lua" },
  cmd = { "Recommender" },
  opts = {},
}
```

`ft` plus `cmd`: Lua is where the analysis is asked for most, and the command
trigger covers the JS/TS and Python backends and the wider scopes. packer.nvim
and vim-plug are in [docs/installation.md](docs/installation.md).

---

## Quickstart

Open a file with some repetition in it and ask:

```vim
:Recommender
```

The float lists the chains worth aliasing, most repeated first. Then, for
something other than the defaults:

```vim
:Recommender cwd               " the whole working tree, asynchronously
:Recommender path              " this file's own directory instead
:Recommender python 4          " the Python backend, threshold 4
:Recommender treesitter 4 -r   " Tree-sitter, threshold 4, replace mode
:Recommender perf 1            " the benchmarked anti-patterns, every instance
```

Analyzer, scope and threshold are positional and order-independent:
`:Recommender cwd javascript 5` and `:Recommender 5 javascript cwd` are the
same call.

Verify your setup any time with:

```vim
:checkhealth recommender
```

---

## What you get with the defaults

| Argument | Does |
| --- | --- |
| *(none)* | The current buffer, with the configured analyzer |
| `line` · `cfile` · `path` · `cwd` | The scope to count in: the current line, the file named under the cursor, this file's directory, or the whole working tree |
| `5` / `-t 5` / `--threshold=5` | How many occurrences make a chain worth aliasing |
| `regex` | The default Lua backend |
| `treesitter` | The Lua backend with a parser, loaded only when chosen |
| `javascript` · `python` | The JS/TS and Python backends |
| `perf` | The four benchmarked Lua anti-patterns |
| `-r` / `--replace` | Accepting a suggestion rewrites every occurrence, via replacer.nvim |

Inside the float, the keys accept, skip and inspect a suggestion — they are in
[docs/commands.md](docs/commands.md) together with the full argument list, and
[docs/examples.md](docs/examples.md) walks one through end to end.

---

## The perf analyzer

Benchmarking this plugin's own core premise found that dotted-chain aliasing
has **no measurable benefit under LuaJIT**: Neovim's runtime hoists the
loop-invariant lookup itself, so `mod.fn(x)` in a loop and
`local fn = mod.fn; fn(x)` measure identically. The aliasing suggestions are
worth having for readability; they are not worth having for speed, and this
README is not going to claim otherwise.

What did show a real, repeatable win in the same benchmark run was four
specific Lua anti-patterns, each backed by an isolated before/after
measurement. `analyzer = "perf"` flags those four and nothing else:

| Pattern | Flagged when | Measured cost |
| --- | --- | --- |
| `table.insert(t, v)` in a loop | Inside `for` / `while` / `repeat` | ~4–5× slower than `t[#t+1] = v` |
| `x = x .. y` accumulator | Self-referential concat inside a loop | O(n²) against `table.concat()`'s O(n) |
| `for _, v in ipairs(t)` | Anywhere — the per-iteration cost does not depend on nesting | ~2× slower than `for i = 1, #t do` |
| `string.format(…)` in a loop | Inside `for` / `while` / `repeat` | ~3× slower than `..` concatenation |

The reasoning, and the benchmark it came out of, is
[docs/FEATURES.md](docs/FEATURES.md#perf-analyzer-analyzer--perf).

---

## Health check

```vim
:checkhealth recommender
```

Reports the Neovim version, whether the lib.nvim command layer resolved, and
whether a Lua Tree-sitter parser is there for the `treesitter` analyzer. It
also prints the two limits a large `cwd` scan runs into — `cwd_max_files` and
`cwd_ignore` — and the one constraint worth knowing before you hit it: the
non-buffer scopes run on the regex-based analyzers only, never on
`treesitter`. [docs/troubleshooting.md](docs/troubleshooting.md) says what each
answer means.

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules and the
project layout; [docs/architecture.md](docs/architecture.md) says which module
owns what, and where a new analyzer plugs in.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/recommender.nvim/issues) to
report bugs, suggest features or ask usage questions; anything more open-ended
fits a
[discussion](https://github.com/StefanBartl/recommender.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).
