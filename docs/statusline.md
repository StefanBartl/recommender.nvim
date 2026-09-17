# Statusline

`require("recommender.statusline").status()` returns how many alias
suggestions are open for the current buffer —
`" 3 alias suggestions open for this file "` — so you notice them without
opening the suggestion float or running `:Recommender`.

It is a plain Lua string with no dependency on any statusline plugin, and
it degrades to `""` on anything unexpected rather than erroring or
notifying. A statusline is not the place for a failure popup.

## Wiring it up

### lualine

```lua
require("lualine").setup({
  sections = { lualine_x = { require("recommender.statusline").lualine_component } },
})
```

`lualine_component` is `status` under another name — the alias exists so
the lualine spec reads the way lualine specs read.

### heirline, or anything else that takes a function

```lua
{ provider = function() return require("recommender.statusline").status() end }
```

### The native statusline

```vim
set statusline+=%{v:lua.require('recommender.statusline').status()}
```

### ui.nvim

Nothing to do. [ui.nvim](https://github.com/StefanBartl/ui.nvim) ships a
`recommender_badge` segment that calls this module; enable it in your
statusline variant and it appears when there is something to show.

## When it is empty

- recommender.nvim is not loaded yet.
- The buffer has zero suggestions at your configured `analyzer`,
  `threshold`, `custom_aliases` and `blacklist`.
- The configured analyzer cannot be resolved.

All four render `""`. A badge with nothing to act on is clutter, and from a
statusline's point of view "nothing to suggest" and "could not ask" look
the same.

## Caching

The analyzer rescans the buffer, and a statusline redraws many times a
second. The result is cached per buffer against `nvim_buf_get_changedtick`,
so it is recomputed exactly once per edit and never between them. Buffers
drop out of the cache on `BufDelete`/`BufWipeout`.

`M.invalidate(buf)` forces a recount if you ever need one.

## Why this lives here

It used to live in ui.nvim, which reached into `recommender.config` and
`recommender.analyzers.*` from the outside to build the string. That works
until one of those is renamed, and no test in this repository would have
caught it.

Two siblings — [sandbox.nvim](https://github.com/StefanBartl/sandbox.nvim)
and [sessions.nvim](https://github.com/StefanBartl/sessions.nvim) — already
shipped their own component, with ui.nvim reduced to a thin adapter over
it. This closes the same gap here: the plugin owns how it presents itself,
and ui.nvim only places it.
