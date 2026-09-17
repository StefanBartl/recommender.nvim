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

Finds the repetition in your code and offers to do something about it. It
reads a buffer — or a wider scope — for dotted chains repeated often enough to
be worth aliasing, and puts the suggestions in a float you can act on without
leaving it. Pure Neovim, no external tooling.

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
> **[ui.nvim](https://github.com/StefanBartl/ui.nvim)** — shows how many
> alias suggestions are open for the current buffer as a statusline
> badge, so you notice them without running the analyzer by hand.
>
> All of the above are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
> dependency — see [Requirements](docs/installation.md#requirements).

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

**The Basics**

- [Requirements](docs/installation.md#requirements) — Neovim version, required plugins, no external tools.
- [Installation](docs/installation.md) — a spec per plugin manager.
- [Quickstart](docs/quickstart.md) — the first thing to run after installing.

**Configuration**

- [What you get with the defaults](docs/what-you-get.md) — the full argument surface at a glance.
- [All options](docs/configuration.md) — every `setup()` option, its default, and the default keymaps.
- [Command reference](docs/commands.md) — `:Recommender`, the scopes, the float's keys, and replace mode.
- [Statusline](docs/statusline.md) — the open-suggestion count as a component, for lualine, heirline, the native statusline or ui.nvim.

**The Rest**

- [Features](docs/FEATURES.md) — everything this plugin does, in one file: what it analyses, what it suggests from that, and the [perf analyzer](docs/FEATURES.md#perf-analyzer-analyzer--perf)'s own benchmark.
- [Examples](docs/examples.md) — a worked before/after of the suggestion float.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, command and autocommand in one reference.
- [Workflow](docs/WORKFLOW.md) — when to run the analysis and what to do with the answer, rather than what it reports.
- [Architecture](docs/architecture.md) — module layout and design principles.
- [Troubleshooting](docs/troubleshooting.md) — what `:checkhealth recommender` asks.
- [Contributing](docs/CONTRIBUTING.md) — ground rules, project layout, and how to add an analyzer.
- [Feedback](https://github.com/StefanBartl/recommender.nvim/issues) — bugs, feature requests and usage questions; broader discussion in [Discussions](https://github.com/StefanBartl/recommender.nvim/discussions).

`:help recommender` is the same reference inside the editor.

---

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

recommender.nvim is released under the [MIT License](https://opensource.org/licenses/MIT).
