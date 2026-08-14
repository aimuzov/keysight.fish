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
```

`functions/keys.fish` defines several functions in one file. Fish autoloads it by the name of the
public one (`keys`) and the rest become available at the same time.

## Conventions

- Target fish 4.0+. The fish parser relies on the modern `bind` output (`ctrl-alt-p`), which does
  not exist in 3.x.
- Code, comments and `--description` strings are in English.
- Comment only what the code cannot say by itself — mostly the parsing quirks below.
- Do not add a dependency without a strong reason; the plugin should work with the tools any system
  already has.

## Data format

Every `_keys_source_*` function prints tab-separated rows:

```
source <TAB> shortcut <TAB> description <TAB> action <TAB> origin <TAB> mode
```

`_keys_collect` then collapses rows that differ only by editor mode, sorts by shortcut so that
collisions between sources end up adjacent, and prefixes each row with an index. The index is how
the preview — which runs in a separate process — finds the full row in the temp file.

## Traps already hit (do not re-discover these)

- **fish collapses `\\` inside single quotes.** An awk regex matching a literal backslash needs four
  of them in the fish source (`/\\\\[ \t]*$/`). This silently broke the skhd line-continuation
  handling and leaked continuation fragments into the output as fake bindings.
- **awk patterns match `$0`, not your variable.** When joining continued lines, assign back into
  `$0`, otherwise every later rule tests the unjoined line.
- **`mktemp` here is GNU coreutils, not BSD.** It rejects a template without `XXXXXX`, so keep the
  X's; that form works on both.
- **The displayed shortcut column carries ANSI colouring and padding.** Strip it before copying to
  the clipboard or comparing.
- **fish local variables are not visible to called functions.** Flags parsed by `argparse` in `keys`
  must be passed down explicitly (that is why `--refresh` travels as an argument).
- **`bind` is empty outside an interactive session**, so the fish source silently yields nothing
  under `fish --no-config -c`.

## Testing

There is no test suite yet. What works today:

```fish
# syntax
fish --no-config -n functions/keys.fish

# one parser in isolation (any source that does not need an interactive shell)
fish --no-config -c 'source functions/keys.fish; _keys_source_skhd'

# the fish source needs -i, whose output includes cursor-shape escapes
fish -i -c 'source functions/keys.fish; _keys_source_fish'

# the preview, called exactly the way fzf calls it
fish --no-config -c 'source functions/keys.fish; _keys_preview <datafile> <row>'
```

The interactive path can be exercised end to end by putting stubs for `fzf` and `pbcopy` early in
`PATH` — a `fzf` stub that prints one line simulates a selection, and a `pbcopy` stub keeps the real
clipboard untouched. That is how the ANSI-in-clipboard bug was found; the fzf UI itself cannot be
verified this way.
