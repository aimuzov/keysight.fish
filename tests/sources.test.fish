source (status dirname)/helpers.fish

# skhd

set -l rows (_keysight_source_skhd)

@test "skhd reads every binding, and only bindings" (count $rows) -eq 8

set -l row (_kt_shortcut 'alt - h' $rows)
@test "skhd takes the description from the trailing comment" \
    (_kt_field $row 3) = 'Focus the window to the left  ·  Windows'
@test "skhd resolves a .define alias" (_kt_field $row 4) = 'yabai -m window --focus west'
@test "skhd records file and line" (_kt_field $row 5) = "$keysight_fixtures/skhd/skhdrc:10"

set -l row (_kt_shortcut 'alt - l' $rows)
@test "skhd falls back to the alias name when there is no comment" \
    (_kt_field $row 3) = 'focus east  ·  Windows'

set -l row (_kt_shortcut 'alt - r' $rows)
@test "skhd joins a continued line into one action" \
    (_kt_field $row 4) = 'yabai -m space --rotate 90 && yabai -m space --balance'
@test "the tail of a continued line does not become a binding of its own" \
    (_kt_has 'balance' (_kt_column 2 $rows)) = no

set -l row (_kt_shortcut 'cmd - q' $rows)
@test "skhd marks a swallowed key" \
    (_kt_field $row 3) = 'Blocked on purpose: Quitting by accident is too easy  ·  Windows'

set -l row (_kt_shortcut 'alt - w' $rows)
@test "a mode switch is described as one" (_kt_field $row 3) = 'Enter skhd mode: resize  ·  Modes'
@test "a mode switch carries the mode it is bound in" (_kt_field $row 6) = default

set -l row (_kt_shortcut h $rows)
@test "a binding inside a mode carries that mode" (_kt_field $row 6) = resize

set -l row (_kt_shortcut 'ctrl + alt - t' $rows)
@test "skhd reads every file it is pointed at" \
    (_kt_field $row 5) = "$keysight_fixtures/skhd/helpers.skhdrc:3"

# ghostty

set -l rows (_keysight_source_ghostty)

@test "ghostty reads the keybind lines only" (count $rows) -eq 3
@test "ghostty ignores a commented out keybind" (_kt_has 'undo' $rows) = no

set -l row (_kt_shortcut cmd-shift-t $rows)
@test "ghostty normalises the shortcut spelling" (_kt_field $row 2) = cmd-shift-t
@test "ghostty makes the action readable" (_kt_field $row 3) = 'new tab'
@test "ghostty keeps the raw action" (_kt_field $row 4) = new_tab

set -l row (_kt_shortcut cmd-k $rows)
@test "ghostty spells out a literal input action" (_kt_field $row 3) = 'Send literal input: \x0c'

# wezterm

set -l rows (_keysight_source_wezterm)

@test "wezterm reads every key entry" (count $rows) -eq 3

set -l row (_kt_shortcut cmd-shift-t $rows)
@test "wezterm folds the modifiers into the shortcut" (_kt_field $row 2) = cmd-shift-t
@test "wezterm keeps the action" (_kt_field $row 4) = 'wezterm.action.SpawnTab("CurrentPaneDomain")'

set -l row (_kt_shortcut enter $rows)
@test "wezterm explains a disabled assignment" \
    (_kt_field $row 3) = 'Disabled, passes the key through to the shell'

# yazi

set -l rows (_keysight_source_yazi)

@test "yazi reads inline tables and per-binding sections alike" (count $rows) -eq 5

set -l row (_kt_shortcut gr $rows)
@test "yazi joins a key sequence" (_kt_field $row 2) = gr
@test "yazi prefers the desc field" (_kt_field $row 3) = 'Jump to the repository root'
@test "yazi keeps a single quoted run intact" \
    (_kt_field $row 4) = 'shell -- ya emit cd "$(git rev-parse --show-toplevel)"'

set -l row (_kt_shortcut q $rows)
@test "yazi falls back to the command when desc is missing" (_kt_field $row 3) = quit

set -l row (_kt_shortcut '<C-a>' $rows)
@test "yazi reads a [[...keymap]] section" (_kt_field $row 3) = 'Move to the beginning of the line'

set -l row (_kt_shortcut '<Esc>' $rows)
@test "yazi accepts a bare string as the key" (_kt_field $row 4) = close

# lazygit

set -l rows (_keysight_source_lazygit)

@test "lazygit reads the custom commands" (count $rows) -eq 2
@test "lazygit ignores the keys of nested prompts" (_kt_has 'Branch name' $rows) = no

set -l row (_kt_shortcut n $rows)
@test "lazygit takes the description" (_kt_field $row 3) = 'Start a branch'
@test "lazygit takes the command" (_kt_field $row 4) = 'git checkout -b {{.Form.Branch}}'
@test "lazygit points at the line the command starts on" \
    (_kt_field $row 5) = "$keysight_fixtures/lazygit/config.yml:7"
