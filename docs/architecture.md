# Architecture

```
lua/recommender/
  init.lua                 setup() entry point
  @types.lua               LuaLS type definitions
  health.lua               :checkhealth recommender
  config/
    DEFAULTS.lua           immutable default configuration
    init.lua               merge + access to the active config
  util/
    notify.lua             prefixed vim.notify wrapper (via util/lib.lua)
    lib.lua                soft bridge to lib.nvim (notify/map), with fallback
  bindings/
    init.lua               orchestrates usrcmds/keymaps/which_key/autocmds
    usrcmds.lua             :Recommender command + per-invocation state
    keymaps.lua             global keymaps (config.keymaps ~= false)
    which_key.lua           optional which-key group label
    autocmds.lua            empty (structural symmetry only)
  float/
    rendering.lua           float window open/close/highlight; layout (detailed/compact) + stride
    keymaps.lua             buffer-local keymaps for the float; navigates by rendering.stride
    autocmds.lua            one-shot WinClosed hook for replace-mode finish detection
  blacklist.lua             prefix matching + default blacklist
  custom_aliases.lua        built-in alias map
  project.lua               cwd file discovery for -c/--cwd scope
  analyzers/
    regex.lua               regex-based chain counter (Lua)
    treesitter.lua          tree-sitter-based chain counter (Lua)
    javascript.lua          regex-based chain counter (JS/TS)
    python.lua              regex-based chain counter (Python)
plugin/
  recommender.lua          loaded-guard
  recommender_autodoc.lua  generates doc/tags on first load if missing
doc/
  recommender.nvim.txt  :h recommender.nvim
```

Cheatsheet of all keymaps/commands/autocmds: [BINDINGS.md](BINDINGS.md).
Roadmap (currently empty — every previously tracked idea has shipped): [ROADMAP.md](ROADMAP.md).

## Design principles

- **No hard `lib.nvim` dependency** — `util/lib.lua` uses it when present
  (notify/map), falls back to native Neovim APIs otherwise.
- **Lazy analyzer loading** — `treesitter.lua` is only required when first used.
- **Per-buffer ignore state** — ignores are stored by bufnr, not globally.
- **No deprecated API** — uses `vim.bo` / `vim.wo` throughout.
- **Toggle pattern** — `:Recommender` while open closes the float; no extra close command.
