# CLAUDE.md — keysight.fish

## What this is

A fish plugin exposing one command, `keys`: it parses the live configs of the shell, terminal,
window manager and TUI apps on the machine, and shows every keyboard shortcut in an `fzf` picker
with a preview. Nothing is hardcoded into a static cheat sheet — every run re-reads the sources.

The code started as a personal function in a chezmoi-managed dotfiles repo and was extracted here to
be published. The upstream copy still lives at
`~/.local/share/chezmoi/home/dot_config/fish/functions/core/keys.fish`; until the plugin is
installed from git, changes made here must be copied back there (or the other way round) by hand.

## Layout

```
functions/keys.fish     everything: the command, one parser per source, preview and edit helpers
completions/keys.fish   option completions
tests/*.test.fish       fishtape suites
tests/fixtures/         a config per source, so the tests do not depend on the machine
```

`functions/keys.fish` defines several functions in one file. Fish autoloads it by the name of the
public one (`keys`) and the rest become available at the same time.

## Conventions

- Target fish 4.0+. The fish parser relies on the modern `bind` output (`ctrl-alt-p`), which does
  not exist in 3.x.
- The public command is `keys`; everything private is `_keysight_*`.
- No path to a config is hardcoded. A source reads `_keysight_config <name> <relative path...>`,
  which returns `$keysight_<name>_config` when set and the `$XDG_CONFIG_HOME` path otherwise. Both
  can be lists. New sources follow the same rule, as does the cache (`_keysight_cache_dir`).
- Code, comments and `--description` strings are in English.
- Comment only what the code cannot say by itself — mostly the parsing quirks below.
- Do not add a dependency without a strong reason; the plugin should work with the tools any system
  already has. fishtape is a test-only dependency.

## Data format

Every `_keysight_source_*` function prints tab-separated rows:

```
source <TAB> shortcut <TAB> description <TAB> action <TAB> origin <TAB> mode
```

`_keysight_collect` then collapses rows that differ only by editor mode, sorts by shortcut so that
collisions between sources end up adjacent, and prefixes each row with an index. The index is how
the preview — which runs in a separate process — finds the full row in the temp file.

## Traps already hit (do not re-discover these)

- **fish collapses `\\` inside single quotes.** An awk regex or string matching a literal backslash
  needs four of them in the fish source (`/\\\\[ \t]*$/`, `c == "\\\\"`). This silently broke the
  skhd line-continuation handling and, later, the yazi parser, which failed to compile at all.
- **A single quote cannot be written inside a single-quoted awk program.** The yazi parser builds
  the character with `sprintf("%c", 39)` instead.
- **awk patterns match `$0`, not your variable.** When joining continued lines, assign back into
  `$0`, otherwise every later rule tests the unjoined line.
- **`mktemp` here is GNU coreutils, not BSD.** It rejects a template without `XXXXXX`, so keep the
  X's; that form works on both.
- **The displayed shortcut column carries ANSI colouring and padding.** Strip both before copying to
  the clipboard or comparing — and strip the padding *first*: it sits after the ` (mode)` suffix, so
  a regex anchored at the end of the string never matches while it is there.
- **`bind` only prints `-M` for vi bindings.** With the default emacs bindings there is no mode at
  all, so the fish source emits `-`; calling it `default` tagged every row with a mode nobody has.
- **fish local variables are not visible to called functions.** Flags parsed by `argparse` in `keys`
  must be passed down explicitly (that is why `--refresh` travels as an argument). The same applies
  to tests: a `set -l` override of `keysight_*_config` never reaches the parser.
- **`bind` is empty outside an interactive session**, so the fish source silently yields nothing
  under `fish --no-config -c`.
- **yazi keymaps come in two shapes**: inline tables inside `prepend_keymap = [ ... ]` and one
  `[[mgr.prepend_keymap]]` section per binding. Both are in the fixture; a line-based parser only
  ever handled the first.
- **`fish_indent` explodes the compact `case x; echo '...'` table** in `_keysight_fish_describe`
  into twice as many lines. The compact form is deliberate, so the formatter is not run in CI.

## Testing

[fishtape](https://github.com/jorgebucaran/fishtape) drives the suites; the fixtures under
`tests/fixtures/` stand in for real configs.

```fish
fisher install jorgebucaran/fishtape
fishtape tests/*.test.fish
```

Run fishtape from a normal `fish`, not `fish --no-config`: it counts tests in universal variables,
which are unavailable there — the output still shows every failure, but the summary claims zero
tests and the exit status is 0 regardless.

The interactive path is covered by `tests/ui.test.fish`, which puts stubs for `fzf` and `pbcopy`
early in `PATH` — the `fzf` stub prints one line to simulate a selection, the `pbcopy` stub writes
to a file instead of the clipboard. That is how the ANSI and the padding bugs were found; the fzf UI
itself cannot be verified this way.

Things the suites cannot cover, to check by hand:

```fish
# the fish source needs an interactive shell, whose output includes cursor-shape escapes
fish -i -c 'source functions/keys.fish; _keysight_source_fish'

# the nvim source starts a real headless nvim
fish --no-config -c 'source functions/keys.fish; _keysight_source_nvim refresh'
```
