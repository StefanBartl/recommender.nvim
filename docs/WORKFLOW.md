# Workflow — getting real use out of recommender.nvim day to day

Every feature here is documented on its own elsewhere ([Commands](commands.md),
[Configuration](configuration.md), [BINDINGS.md](BINDINGS.md)). This is the
different question: once you've written the same `vim.api.nvim_...` call for
the fifth time in a session, what do you actually press, and what's worth
knowing before you do.

## The default loop: `<leader>lr`, look, `A`

Most sessions don't need a flag. `<leader>lr` (or `:Recommender` bare) opens
the float against the current buffer with `analyzer = "regex"` and
`threshold = 3` (or whatever `setup()` set). If the suggestions look right,
`A` inserts every one of them at once rather than walking the list with
`j`/`Enter`/`j`/`Enter`. Reach for `A` by default and use the one-at-a-time
flow only when you actually want to skip some — that's what `Backspace`
(ignore) is for, not scrolling past entries you don't want.

## Picking an analyzer isn't a one-time setting

`analyzer` in `setup()` is just the *default* — the command itself takes an
override as a positional argument, so switching for one buffer doesn't mean
editing config:

```vim
:Recommender treesitter     " one Lua buffer, want AST-accurate chain counting
:Recommender javascript     " a .ts file in the same project
:Recommender python 4       " a .py file, raise the threshold for this pass
```

`treesitter` is the more accurate Lua analyzer (it parses the syntax tree
instead of pattern-matching text) but it only works on the current buffer's
live parse — that's the reason it's also the one analyzer that **cannot**
combine with `-c`. If you reach for `-c` on a Lua project, use `regex`, not
`treesitter`; the command errors out immediately if you try the combination,
rather than silently falling back.

## `-c` is a counting decision, not an insertion decision

`:Recommender -c` scans every matching file under the cwd and aggregates
counts before applying the threshold — good for surfacing a chain that
recurs six times across a project but never more than twice in any single
file, which plain per-buffer scanning would miss entirely. The trap: `-c`
does **not** change where `Enter`/`A` write the alias. Whatever suggestion
you insert still lands in the buffer you ran `:Recommender -c` from. Running
a cwd-wide scan from the wrong buffer and then hitting `A` puts a batch of
aliases into a file that may not even use most of those chains — check which
buffer you're in before a cwd scan, not just which chains show up.

If the scan is slow or the notification says the file cap was hit, that's
`cwd_max_files` (default `500`) — either raise it in `setup()` or narrow
`cwd_ignore` further so the scan skips more of the tree before hitting the
cap.

## Combining `-r` with an alias you already half-typed

Replace mode (`-r`/`--replace`, or `<leader>lR`) is worth the extra step
specifically when the chain already appears several times and you don't want
to hand-edit every call site after inserting the `local` line. The sequence
in practice:

```vim
:Recommender -r
" <CR> on vim.api.nvim_buf_set_lines
```

That runs `:Replace vim.api.nvim_buf_set_lines api.nvim_buf_set_lines %`
(via whatever plugin provides `:Replace` — [replacer.nvim](https://github.com/StefanBartl/replacer.nvim)
is the one this plugin is built to pair with) and only *after* that
replace's prompt window closes does it insert the `local api = vim.api`
declaration. **This means `-r` is useless without a `:Replace` command
registered** — if none exists, `Enter` in replace mode has nothing to drive,
and the alias never gets inserted at all, since insertion is chained behind
the replace finishing, not run unconditionally.

Note the detection mechanism is specifically a `WinClosed` autocmd watching
for a `TelescopePrompt` window — a `:Replace` implementation that doesn't
use a Telescope-style floating prompt won't trigger the follow-up insert.
Worth confirming once with whatever `:Replace` provider you actually use,
rather than assuming any drop-in works.

## Compact layout earns its keep at low thresholds

`float_layout = "compact"` isn't a cosmetic preference — drop `threshold`
to 2 on a large file or a `-c` scan and "detailed" (3 lines per suggestion)
turns into a float you have to scroll through. Compact keeps one line per
suggestion so more of the list is visible at once, and `j`/`k` still move
suggestion-by-suggestion either way, so there's no navigation cost to
switching.

## Blacklist vs. per-buffer ignore — permanent vs. session

Easy to reach for the wrong one: `Backspace` in the float only dismisses a
suggestion for *that buffer's current session* — reopen the float later (or
open a different buffer) and it comes back. `blacklist` in `setup()` is
permanent and prefix-matched — `"vim.fn"` there means `vim.fn`, `vim.fn.expand`,
`vim.fn.system`, all of it, forever, in every buffer. Use `Backspace` for
"not right now, this buffer", and the blacklist for "never suggest this
namespace" — a chain you dismiss with `Backspace` in ten different buffers
is really telling you it belongs in the blacklist instead.

## Custom aliases beat renaming after the fact

`custom_aliases` in `setup()` overrides the generated name *before* the
float ever shows it, so `vim.keymap.set` renders as `km_set` (the built-in
default) rather than whatever auto-generated name the last segment of the
chain would produce. Set project- or team-specific names here rather than
inserting the default and renaming afterward — the float always shows the
final name, so there's nothing to double check post-insert if the map is
right going in.
