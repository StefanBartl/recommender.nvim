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
    rendering.lua           float window open/close/highlight
    keymaps.lua             buffer-local keymaps for the float
    autocmds.lua            one-shot WinClosed hook for replace-mode finish detection
  blacklist.lua             prefix matching + default blacklist
  custom_aliases.lua        built-in alias map
  analyzers/
    regex.lua               regex-based chain counter
    treesitter.lua          tree-sitter-based chain counter
plugin/
  recommender.lua          loaded-guard
  recommender_autodoc.lua  generates doc/tags on first load if missing
doc/
  recommender.nvim.txt  :h recommender.nvim
```

Cheatsheet of all keymaps/commands/autocmds: [BINDINGS.md](BINDINGS.md).
Planned/rejected features: [ROADMAP.md](ROADMAP.md).

## Design principles

- **No hard `lib.nvim` dependency** — `util/lib.lua` uses it when present
  (notify/map), falls back to native Neovim APIs otherwise.
- **Lazy analyzer loading** — `treesitter.lua` is only required when first used.
- **Per-buffer ignore state** — ignores are stored by bufnr, not globally.
- **No deprecated API** — uses `vim.bo` / `vim.wo` throughout.
- **Toggle pattern** — `:Recommender` while open closes the float; no extra close command.
