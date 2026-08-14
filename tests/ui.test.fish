source (status dirname)/helpers.fish

# The picker itself cannot be tested, but everything around it can: stubs for fzf and
# pbcopy early in PATH stand in for the selection and for the clipboard.

function _keysight_sources
    echo fish
end

function _keysight_source_fish
    printf 'fish\tctrl-r\tSearch history backwards\thistory-search-backward\tfish (built-in)\tdefault\n'
    printf 'fish\tctrl-r\tSearch history backwards\thistory-search-backward\tfish (built-in)\tinsert\n'
end

set -l stubs (mktemp -d -t keysight-stubs.XXXXXX)
set -l clipboard $stubs/clipboard

echo '#!/bin/sh
head -n 1' >$stubs/fzf

echo "#!/bin/sh
cat >$clipboard" >$stubs/pbcopy

chmod +x $stubs/fzf $stubs/pbcopy
set -gx PATH $stubs $PATH

set -l said (keys)

@test "the selected shortcut is echoed back" "$said" = 'copied: ctrl-r'
@test "the clipboard gets the shortcut" (cat $clipboard) = ctrl-r
@test "with no colouring in it" (_kt_has \e'[' (cat $clipboard)) = no
@test "and no mode suffix" (_kt_has '(' (cat $clipboard)) = no

@test "--list prints the rows as they are" (count (keys --list)) -eq 1
@test "--help explains the command" (_kt_has 'Usage' (keys --help)) = yes
@test "--help lists the sources it knows" (_kt_has 'Sources: fish' (_keysight_help)) = yes

set -e PATH[1]
command rm --recursive --force $stubs

# The preview card

set -l data (mktemp -t keysight-test.XXXXXX)
printf '%s\n' (_keysight_collect '' '') >$data
set -l card (_keysight_preview $data 1)

@test "the preview leads with the shortcut" (_kt_has 'ctrl-r' $card) = yes
@test "the preview says what the key does" (_kt_has 'Search history backwards' $card) = yes
@test "the preview says what it runs" (_kt_has 'history-search-backward' $card) = yes
@test "the preview says where it comes from" (_kt_has 'fish (built-in)' $card) = yes

command rm --force $data
