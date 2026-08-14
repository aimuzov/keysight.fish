source (status dirname)/helpers.fish

# Where the configs are looked for.
# The variables are set globally on purpose: a local one would not reach the functions.

set -l fixture $keysight_ghostty_config
set -e keysight_ghostty_config

set -gx XDG_CONFIG_HOME /xdg/config
@test "a source falls back to its XDG path" \
    (_keysight_config ghostty ghostty/config) = /xdg/config/ghostty/config

set -e XDG_CONFIG_HOME
@test "and to ~/.config when XDG_CONFIG_HOME is unset" \
    (_keysight_config ghostty ghostty/config) = ~/.config/ghostty/config

set -g keysight_ghostty_config /somewhere/else/config
@test "an override wins over the default" \
    (_keysight_config ghostty ghostty/config) = /somewhere/else/config

set -g keysight_skhd_config /first /second
@test "an override may list several files" \
    (count (_keysight_config skhd skhd/skhdrc)) -eq 2

# A config that is not there is skipped, not reported

@test "a source with no config prints nothing" (count (_keysight_source_ghostty)) -eq 0
@test "and still succeeds" (_keysight_source_ghostty; echo $status) -eq 0

set -g keysight_ghostty_config $fixture
set -g keysight_skhd_config $keysight_fixtures/skhd/skhdrc

@test "the fixtures are reached through the same overrides" \
    (count (_keysight_source_ghostty)) -eq 3
@test "and only the files listed are read" (count (_keysight_source_skhd)) -eq 7

# Where the nvim cache goes

set -gx XDG_CACHE_HOME /xdg/cache
@test "the cache honours XDG_CACHE_HOME" (_keysight_cache_dir) = /xdg/cache/keysight

set -e XDG_CACHE_HOME
@test "and lands in ~/.cache/keysight otherwise" (_keysight_cache_dir) = ~/.cache/keysight

set -g keysight_cache_dir /tmp/keysight-cache
@test "the cache directory can be overridden" (_keysight_cache_dir) = /tmp/keysight-cache
