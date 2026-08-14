# keysight.fish

One command that shows every keyboard shortcut your machine actually has — pulled from the live
configs of your shell, terminal, window manager and TUI apps, browsable in `fzf` with a preview
that tells you what each key does and where it is defined.

```
keys
```

No cheat sheet to maintain: every source is parsed on each run, so the list cannot drift away from
your configs.

## Why

Shortcuts end up scattered across a dozen config files in a dozen formats. You remember the ones you
use daily and forget the rest, and nothing tells you that `ctrl-r` is bound in two places at once.
`keysight.fish` reads all of them, normalises the spelling, and sorts by shortcut so collisions land
next to each other.

## Requirements

- [fish](https://fishshell.com) 4.0 or newer — key names like `ctrl-alt-p` only exist since 4.0
- [fzf](https://github.com/junegunn/fzf) — optional, falls back to plain output
- `awk`, `grep`, `sort`, `mktemp` — any POSIX system has these
- [nvim](https://neovim.io) — optional, only for the nvim source

## Install

With [fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install aimuzov/keysight.fish
```

Manually — copy `functions/keys.fish` into `~/.config/fish/functions/`.

## Usage

```fish
keys                  # browse everything
keys ctrl-r           # open with a starting query
keys --source skhd    # limit to one source
keys --list           # raw TSV instead of the fzf UI, for scripting
keys --refresh        # rebuild the nvim mapping cache
keys --help
```

Inside the picker:

| Key | Action |
| --- | --- |
| <kbd>Enter</kbd> | copy the shortcut to the clipboard |
| <kbd>Ctrl</kbd>+<kbd>E</kbd> | open the config it comes from, at the right line |

The left pane lists source, shortcut and what it does; the preview shows the full command, the
category it belongs to, and the exact file and line where it is defined.

## Sources

| Source | Read from | Notes |
| --- | --- | --- |
| fish | `bind` in the running session | needs an interactive shell, see below |
| skhd | `skhd/skhdrc`, `skhd/helpers.skhdrc` | resolves `.define` aliases, handles modes and line continuations |
| ghostty | `ghostty/config` | |
| wezterm | `wezterm/wezterm.lua` | one binding per line |
| yazi | `yazi/keymap.toml` | inline tables and `[[...keymap]]` sections alike, uses the `desc` field |
| lazygit | `lazygit/config.yml` | `customCommands` only |
| nvim | a headless nvim instance | real mappings including plugin defaults, cached |

Paths are relative to `$XDG_CONFIG_HOME`, or `~/.config` when that is unset. Missing configs are
skipped silently, so the plugin is useful even if you only have one or two of these installed.

## Configuration

Every source looks at one variable, and uses its default when that variable is unset. Set them in
`config.fish`:

```fish
set -g keysight_skhd_config ~/dotfiles/skhdrc ~/dotfiles/skhd-helpers.skhdrc
set -g keysight_ghostty_config ~/dotfiles/ghostty.conf
set -g keysight_wezterm_config ~/dotfiles/wezterm.lua
set -g keysight_yazi_config ~/dotfiles/yazi-keymap.toml
set -g keysight_lazygit_config ~/dotfiles/lazygit.yml
set -g keysight_nvim_config ~/dotfiles/nvim
set -g keysight_cache_dir ~/.cache/keysight
```

A list is allowed wherever several files make up one config, as with skhd above; files that do not
exist are skipped.

The command is called `keys` because that is the point of it — one short word. If the name is taken
on your machine, copy `functions/keys.fish` to `~/.config/fish/functions/<yourname>.fish` and rename
the `keys` function inside it; the private `_keysight_*` functions can stay as they are.

## Notes and limitations

- **fish shortcuts need an interactive session.** `bind` returns nothing outside one, so
  `keys --list` from a script will show every source except fish.
- **nvim mappings are cached** in `$XDG_CACHE_HOME/keysight/nvim.tsv` (`~/.cache/keysight/nvim.tsv`
  by default), since a headless start costs roughly 800 ms. The cache is invalidated when any
  `*.lua` or `lazy-lock.json` under the nvim config changes; force it with `keys --refresh`.
- **Only normal mode is read from nvim** at the moment.
- **lazygit and yazi expose only what you overrode.** Their built-in keys live inside the binaries;
  press `?` in the app for those.
- Rows that differ only by editor mode are collapsed into one, with the modes shown in parentheses:
  `ctrl-r (default/insert)`. Only vi bindings report a mode, so with the default emacs bindings no
  row carries a suffix.

## Adding a source

Each source is a single function that prints tab-separated rows:

```
source <TAB> shortcut <TAB> description <TAB> action <TAB> origin <TAB> mode
```

Write `_keysight_source_<name>`, return nothing when the config is absent, and add `<name>` to
`_keysight_sources`. `origin` should be `path:line` so that <kbd>Ctrl</kbd>+<kbd>E</kbd> can jump
straight to it; `mode` is `-` when the source has no notion of modes.

## Tests

The suite runs on fixtures, not on the configs of whoever runs it:

```fish
fisher install jorgebucaran/fishtape
fishtape tests/*.test.fish
```

## License

[MIT](LICENSE)
