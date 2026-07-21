# recommender.nvim — Roadmap

## Implemented (v0.1)

- `:Recommender [-r|--replace] [regex|treesitter] [threshold]` — toggleable
  floating suggestion window
- Two analyzer backends: `regex` (fast, no deps) and `treesitter` (precise,
  requires the Lua parser), with lazy loading (only required on first use)
- Per-buffer ignore state — dismissed suggestions don't reappear for that
  buffer's session
- Prefix-matched blacklist (`config.blacklist`) and per-chain alias override
  (`config.custom_aliases`)
- Replace mode: after inserting an alias, auto-replaces all occurrences via
  a `:Replace` user command (soft dependency; falls back to a plain insert
  if unavailable)
- Syntax-highlighted float (chain, alias, count colored distinctly)
- `bindings/` module (usrcmds/keymaps/which_key/autocmds) with opt-out
  global keymaps (`config.keymaps = false`) and which-key group label
- `config/DEFAULTS.lua` config system, idempotent `setup()`
- `:checkhealth recommender`
- No hard `lib.nvim` dependency (optional soft bridge for notify/map)
- `docs/BINDINGS.md` cheatsheet

## Ideas / not yet planned

- Additional analyzer backends for other languages (currently Lua-only by
  design — the plugin targets Neovim config/plugin authoring)
- Project-wide (`cwd`) analysis, aggregating chain counts across multiple
  buffers/files rather than a single buffer
- Configurable float layout (e.g. compact single-line-per-suggestion mode)

## Nicht geplant

- **Auto-apply on save** — too invasive; suggestions must always be a
  deliberate, reviewed action via `:Recommender`.
