# Shared setup for every suite: load the plugin out of this checkout and point each
# source at a fixture, so that the tests say the same thing on any machine.

set --global keysight_tests (realpath (status dirname))
set --global keysight_fixtures $keysight_tests/fixtures

source $keysight_tests/../functions/keys.fish

set --global keysight_skhd_config $keysight_fixtures/skhd/skhdrc $keysight_fixtures/skhd/helpers.skhdrc
set --global keysight_ghostty_config $keysight_fixtures/ghostty/config
set --global keysight_wezterm_config $keysight_fixtures/wezterm/wezterm.lua
set --global keysight_yazi_config $keysight_fixtures/yazi/keymap.toml
set --global keysight_lazygit_config $keysight_fixtures/lazygit/config.yml

function _kt_field --description 'One tab separated field of a row'
    set -l fields (string split \t -- $argv[1])
    echo $fields[$argv[2]]
end

function _kt_shortcut --description 'The row whose shortcut column matches, out of the rows that follow'
    for row in $argv[2..]
        test (_kt_field $row 2) = "$argv[1]"; and echo $row
    end
end

function _kt_column --description 'One field of every row that follows'
    for row in $argv[2..]
        _kt_field $row $argv[1]
    end
end

function _kt_has --description 'yes when the needle appears anywhere in the rest of the arguments'
    string match --quiet -- "*$argv[1]*" $argv[2..]; and echo yes; or echo no
end
