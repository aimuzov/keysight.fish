source (status dirname)/helpers.fish

# Two sources, one of them binding the same key in two editor modes and colliding
# with the other one, is everything _keysight_collect has to get right.

function _keysight_sources
    printf '%s\n' fish ghostty
end

function _keysight_source_fish
    printf 'fish\tctrl-r\tSearch history backwards\thistory-search-backward\tfish (built-in)\tdefault\n'
    printf 'fish\tctrl-r\tSearch history backwards\thistory-search-backward\tfish (built-in)\tinsert\n'
    printf 'fish\tctrl-e\tJump to end of line\tend-of-line\tfish (built-in)\t-\n'
end

function _keysight_source_ghostty
    printf 'ghostty\tctrl-r\treload config\treload_config\t/tmp/ghostty:1\t-\n'
end

set -l rows (_keysight_collect '' '')
set -l plain
for row in $rows
    set --append plain (_keysight_strip $row)
end

@test "rows differing only by mode are collapsed" (count $rows) -eq 3
@test "the modes are shown next to the shortcut" \
    (_kt_has 'ctrl-r (default/insert)' $plain) = yes
@test "a source without modes gets no suffix" (_kt_has 'ctrl-e (' $plain) = no

@test "rows are numbered from one" (_kt_field $rows[1] 1) = 1
@test "and the numbering is contiguous" (_kt_field $rows[3] 1) = 3

set -l shortcuts (string trim -- (string replace --regex ' *\(.*\)' '' -- (_kt_column 3 $plain)))

@test "rows are sorted by shortcut" (string join , $shortcuts) = ctrl-e,ctrl-r,ctrl-r
@test "so that a collision between sources lands next to itself" \
    (string join , (string trim -- (_kt_column 2 $plain))) = fish,ghostty,fish

@test "the shortcut column is coloured for fzf" (_kt_has \e'[' $rows[1]) = yes
@test "and the colouring can be stripped back off" (_kt_has \e'[' $plain[1]) = no

# The preview reads its row back out of the temp file by that number

set -l data (mktemp -t keysight-test.XXXXXX)
printf '%s\n' $rows >$data

set -l row (_keysight_row $data 2)
@test "a row is read back by its number" (string trim (_keysight_strip $row[3])) = ctrl-r
@test "and arrives whole" (count $row) -eq 6

@test "an out of range number yields nothing" (count (_keysight_row $data 99)) -eq 0
@test "a missing data file yields nothing" (count (_keysight_row /nope/nothing 1)) -eq 0

command rm --force $data

# Limiting to one source

set -l rows (_keysight_collect ghostty '')
@test "--source keeps only the source asked for" (count $rows) -eq 1
@test "an unknown source finds nothing" (count (_keysight_collect nothing '')) -eq 0
