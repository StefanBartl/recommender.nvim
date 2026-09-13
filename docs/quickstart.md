# Quickstart

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

See [what-you-get.md](what-you-get.md) for the rest of the surface at a
glance, or [commands.md](commands.md) for the full reference.
