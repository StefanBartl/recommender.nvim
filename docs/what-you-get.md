# What you get with the defaults

| Argument | Does |
| --- | --- |
| *(none)* | The current buffer, with the configured analyzer |
| `line` · `cfile` · `path` · `cwd` | The scope to count in: the current line, the file named under the cursor, this file's directory, or the whole working tree |
| `5` / `-t 5` / `--threshold=5` | How many occurrences make a chain worth aliasing |
| `regex` | The default Lua backend |
| `treesitter` | The Lua backend with a parser, loaded only when chosen |
| `javascript` · `python` | The JS/TS and Python backends |
| `perf` | The four benchmarked Lua anti-patterns — see [FEATURES.md](FEATURES.md#perf-analyzer-analyzer--perf) |
| `-r` / `--replace` | Accepting a suggestion rewrites every occurrence, via replacer.nvim |

Inside the float, the keys accept, skip and inspect a suggestion — they are in
[commands.md](commands.md) together with the full argument list, and
[examples.md](examples.md) walks one through end to end.
