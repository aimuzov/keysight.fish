function keys --description 'Interactive cheat sheet for keyboard shortcuts: fish, terminals, skhd, TUI apps'
    argparse h/help l/list r/refresh 's/source=' -- $argv
    or return 22

    if set --query _flag_help
        _keysight_help
        return
    end

    set -f self (status filename)
    set -f refresh (set --query _flag_refresh; and echo refresh; or echo '')
    set -f rows (_keysight_collect "$_flag_source" "$refresh")

    if test (count $rows) -eq 0
        echo "keys: no shortcuts found for source '$_flag_source'" >&2
        echo "keys: known sources are "(string join ', ' (_keysight_sources)) >&2
        return 1
    end

    if set --query _flag_list
        printf '%s\n' $rows
        return
    end

    if not command --query fzf
        printf '%s\n' $rows
        return
    end

    # fzf needs the rows on disk: the preview runs in a separate process and looks them up by index.
    # The template keeps its X's because GNU mktemp, which shadows the BSD one here, insists on them.
    set -f data (mktemp -t keysight.XXXXXX)
    or begin
        echo 'keys: could not create a temporary file' >&2
        return 1
    end

    printf '%s\n' $rows >$data

    set -f picked (
        fzf --ansi \
            --delimiter \t \
            --with-nth 2,3,4 \
            --prompt 'Keys> ' \
            --header 'enter: copy shortcut · ctrl-e: open the config it comes from' \
            --preview "fish --no-config --command 'source $self; _keysight_preview $data {1}'" \
            --preview-window 'right,52%,wrap,border-left' \
            --bind "ctrl-e:execute(fish --no-config --command 'source $self; _keysight_edit $data {1}')" \
            --query "$argv" <$data
    )

    command rm --force $data

    test -n "$picked"; or return 0

    # The visible column carries colouring, padding and the mode suffix; none of that
    # belongs in the clipboard. Padding goes first: it sits after the mode suffix and
    # would keep the regex below from ever seeing the end of the string.
    set -f shortcut (string trim -- (_keysight_strip (string split \t -- $picked)[3]))
    set shortcut (string trim -- (string replace --regex ' *\(.*\)$' '' -- $shortcut))

    if command --query pbcopy
        printf '%s' $shortcut | pbcopy
        echo "copied: $shortcut"
    else
        echo $shortcut
    end
end

function _keysight_help --description 'Usage text for the keys cheat sheet'
    echo 'keys — interactive cheat sheet for every shortcut configured on this machine.'
    echo
    echo 'Usage:'
    echo '  keys [query]            browse everything, optionally pre-filtered'
    echo '  keys --source fish      limit to one source'
    echo '  keys --list             dump raw TSV instead of opening fzf'
    echo '  keys --refresh          rebuild the nvim mapping cache'
    echo
    echo 'Sources: '(string join ', ' (_keysight_sources))'.'
    echo 'Data is parsed from the live configs on every run, so it cannot go stale.'
end

function _keysight_sources --description 'Names of every known source, in display order'
    printf '%s\n' fish ghostty wezterm skhd yazi lazygit nvim
end

function _keysight_config --description 'Config paths for a source: user override first, XDG default second'
    set -f override keysight_{$argv[1]}_config

    if set --query $override
        printf '%s\n' $$override
        return
    end

    set -f base $XDG_CONFIG_HOME
    test -n "$base"; or set base ~/.config

    printf '%s\n' $base/$argv[2..]
end

function _keysight_cache_dir --description 'Directory the nvim mapping cache lives in'
    if set --query keysight_cache_dir
        echo $keysight_cache_dir
        return
    end

    set -f base $XDG_CACHE_HOME
    test -n "$base"; or set base ~/.cache

    echo $base/keysight
end

function _keysight_collect --description 'Gather, normalise and index shortcuts from every source'
    set -f wanted $argv[1]
    set -f refresh $argv[2]
    set -f raw

    for source in (_keysight_sources)
        test -z "$wanted"; or test "$wanted" = "$source"; or continue
        set --append raw (_keysight_source_$source $refresh)
    end

    test (count $raw) -gt 0; or return

    # Collapse rows that differ only by editor mode, then sort by shortcut so that
    # collisions between sources end up next to each other, and finally add the index
    # that the preview uses to find the full row.
    printf '%s\n' $raw | awk -F'\t' '
        # A binding that also exists outside every mode is not scoped to one, so the
        # collapsed list of modes only means something when none of them is "-"
        function scoped(list,   part, i, n) {
            if (list == "") return 0
            n = split(list, part, "/")
            for (i = 1; i <= n; i++) if (part[i] == "-" || part[i] == "") return 0
            return 1
        }

        {
            key = $1 FS $2 FS $4
            if (key in modes) { modes[key] = modes[key] "/" $6; next }
            order[++n] = key
            modes[key] = $6
            row[key] = $0
        }
        END {
            for (i = 1; i <= n; i++) {
                key = order[i]
                split(row[key], f, FS)
                shortcut = f[2]
                if (scoped(modes[key])) shortcut = shortcut " (" modes[key] ")"
                printf "%s\t%s\t%s\t%s\t%s\n", f[1], shortcut, f[3], f[4], f[5]
            }
        }
    ' | sort -t\t -k2,2 -k1,1 | awk -F'\t' '
        function pad(s, w,   n) { n = length(s); return n >= w ? s : s sprintf("%" (w - n) "s", "") }
        {
            printf "%d\t\033[38;5;245m%s\033[0m\t\033[1;36m%s\033[0m\t%s\t%s\t%s\n", \
                NR, pad($1, 8), pad($2, 26), $3, $4, $5
        }
    '
end

function _keysight_source_fish --description 'Shortcuts from the running fish session'
    status is-interactive; or return

    for line in (bind 2>/dev/null)
        set -l rest (string replace -r '^bind ' '' -- $line)

        set -l builtin 1
        if string match --quiet -- '--preset *' $rest
            set rest (string replace -- '--preset ' '' $rest)
        else
            set builtin 0
        end

        # Only `-M` says anything about modes. Outside vi bindings fish never prints it,
        # and calling that "default" would tag every single row with a mode nobody has.
        set -l mode -
        if string match --quiet --regex '^-M \S+ ' -- $rest
            set mode (string replace --regex '^-M (\S+) .*$' '$1' -- $rest)
            set rest (string replace --regex '^-M \S+ ' '' -- $rest)
        end
        # `bind -m mode` only switches mode after the command, it is not a separate binding
        set rest (string replace --regex '^-m \S+ ' '' -- $rest)

        set -l parts (string split --max 1 ' ' -- $rest)
        set -l shortcut $parts[1]
        set -l action (string trim --chars="'" -- "$parts[2]")

        set shortcut (string trim --chars="'" -- $shortcut)
        test -n "$shortcut"; and test -n "$action"; or continue
        # plain characters in insert mode are just typing, not shortcuts worth listing
        string match --quiet --regex '^(self-insert|and-self-insert)' -- $action; and continue
        string match --quiet --regex '^.$' -- $shortcut; and continue
        # raw terminal escapes duplicate the same keys fish already lists by name
        string match --quiet '\e*' -- $shortcut; and continue

        # Autoloaded functions know their own file, which makes ctrl-e useful
        set -l origin (test $builtin -eq 1; and echo 'fish (built-in)'; or echo 'fish (custom)')
        set -l details (functions --details $action 2>/dev/null)
        test -f "$details"; and set origin $details

        printf 'fish\t%s\t%s\t%s\t%s\t%s\n' $shortcut (_keysight_fish_describe $action) $action $origin $mode
    end
end

function _keysight_fish_describe --description 'Human readable description for a fish binding'
    set -f action $argv[1]

    # A custom function carries its own description, which beats anything hardcoded here
    if functions --query $action
        set -f details (functions --details --verbose $action 2>/dev/null)
        if test (count $details) -ge 5; and test -n "$details[5]"; and test "$details[5]" != n/a
            echo $details[5]
            return
        end
    end

    switch $action
        case beginning-of-line; echo 'Jump to start of line'
        case end-of-line; echo 'Jump to end of line'
        case beginning-of-buffer; echo 'Jump to start of buffer'
        case end-of-buffer; echo 'Jump to end of buffer'
        case forward-char forward-single-char; echo 'Move one character right'
        case backward-char; echo 'Move one character left'
        case forward-word forward-word-vi; echo 'Move one word right'
        case backward-word backward-word-vi; echo 'Move one word left'
        case forward-token; echo 'Move one token right'
        case backward-token; echo 'Move one token left'
        case forward-bigword; echo 'Move one WORD right'
        case backward-bigword; echo 'Move one WORD left'
        case kill-line; echo 'Cut to end of line'
        case backward-kill-line; echo 'Cut to start of line'
        case kill-whole-line; echo 'Cut the whole line'
        case kill-word; echo 'Cut word to the right'
        case backward-kill-word backward-kill-path-component; echo 'Cut word to the left'
        case kill-bigword backward-kill-bigword; echo 'Cut WORD'
        case yank; echo 'Paste from kill ring'
        case yank-pop; echo 'Cycle through kill ring'
        case delete-char; echo 'Delete character under cursor'
        case backward-delete-char; echo 'Delete character to the left'
        case accept-autosuggestion; echo 'Accept the autosuggestion'
        case forward-single-char-passthrough; echo 'Accept one character of the suggestion'
        case suppress-autosuggestion; echo 'Hide the autosuggestion'
        case complete; echo 'Complete the current token'
        case complete-and-search; echo 'Complete and open the search pager'
        case history-search-backward history-prefix-search-backward; echo 'Search history backwards'
        case history-search-forward history-prefix-search-forward; echo 'Search history forwards'
        case history-token-search-backward; echo 'Search history for this token, backwards'
        case history-token-search-forward; echo 'Search history for this token, forwards'
        case up-line; echo 'Move up one line'
        case down-line; echo 'Move down one line'
        case execute; echo 'Run the command'
        case cancel; echo 'Cancel the current operation'
        case cancel-commandline; echo 'Clear the command line'
        case clear-screen; echo 'Clear the screen'
        case repaint repaint-mode; echo 'Redraw the prompt'
        case undo; echo 'Undo'
        case redo; echo 'Redo'
        case transpose-chars; echo 'Swap the two characters around the cursor'
        case transpose-words; echo 'Swap the two words around the cursor'
        case upcase-word; echo 'Uppercase the word'
        case downcase-word; echo 'Lowercase the word'
        case capitalize-word; echo 'Capitalize the word'
        case expand-abbr; echo 'Expand the abbreviation'
        case edit_command_buffer; echo 'Edit the command line in $EDITOR'
        case fish_clipboard_copy; echo 'Copy to the system clipboard'
        case fish_clipboard_paste; echo 'Paste from the system clipboard'
        case togglebind; echo 'Toggle between emacs and vi bindings'
        case pager-toggle-search; echo 'Toggle search inside the pager'
        case 'exit'; echo 'Exit the shell'
        case '*'
            # Inline fish snippets are their own best description, just keep them short
            echo (string shorten --max 70 -- $action)
    end
end

function _keysight_source_ghostty --description 'Shortcuts from the ghostty config'
    for config in (_keysight_config ghostty ghostty/config)
        test -f $config; or continue

        grep --line-number '^keybind' $config | while read --line entry
            set -l lineno (string split --max 1 ':' -- $entry)[1]
            set -l value (string replace --regex '^[0-9]+:keybind *= *' '' -- $entry)
            set -l shortcut (string split --max 1 '=' -- $value)[1]
            set -l action (string split --max 1 '=' -- $value)[2]

            printf 'ghostty\t%s\t%s\t%s\t%s\t-\n' \
                (_keysight_normalise $shortcut) (_keysight_describe_action $action) $action "$config:$lineno"
        end
    end
end

function _keysight_source_wezterm --description 'Shortcuts from the wezterm config'
    for config in (_keysight_config wezterm wezterm/wezterm.lua)
        test -f $config; or continue

        grep --line-number 'key *=' $config | while read --line entry
            set -l lineno (string split --max 1 ':' -- $entry)[1]
            set -l body (string replace --regex '^[0-9]+:' '' -- $entry)

            string match --quiet --regex 'key *= *"' -- $body; or continue

            set -l shortcut (string replace --regex '.*key *= *"([^"]*)".*' '$1' -- $body)
            set -l mods (string replace --regex '.*mods *= *"([^"]*)".*' '$1' -- $body)
            set -l action (string trim -- (string replace --regex '.*action *= *(.*[^,])[, ]*\}.*' '$1' -- $body))

            test "$mods" = "$body"; and set mods ''
            test -n "$mods"; and set shortcut "$mods|$shortcut"

            printf 'wezterm\t%s\t%s\t%s\t%s\t-\n' \
                (_keysight_normalise $shortcut) (_keysight_describe_action $action) $action "$config:$lineno"
        end
    end
end

function _keysight_source_skhd --description 'Shortcuts from the skhd config'
    # skhd config is line-continued, aliased through .define and split into modes,
    # so it is parsed in one awk pass that resolves the aliases as it goes.
    for file in (_keysight_config skhd skhd/skhdrc skhd/helpers.skhdrc)
        test -f $file; or continue

        awk -v file="$file" '
            function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

            # Join continued lines into $0 itself: every pattern below matches against
            # $0, so stitching them in a side variable would leak continuations as rows.
            # fish collapses \\ inside single quotes, so a literal backslash needs four
            /\\\\[ \t]*$/ { sub(/[ \t]*\\\\[ \t]*$/, " ", $0); buffer = buffer $0; next }
            { if (buffer != "") sub(/^[ \t]+/, "", $0); $0 = buffer $0; buffer = ""; line = $0 }

            # section headers double as a category for everything below them
            /^#[ \t]*--/ {
                section = line
                sub(/^#[ \t]*--[ \t]*/, "", section)
                sub(/[ \t]*-+[ \t]*$/, "", section)
                section = trim(section)
                next
            }

            /^\.define/ {
                body = line
                sub(/^\.define[ \t]*/, "", body)
                split(body, part, ":")
                name = trim(part[1])
                value = body
                sub(/^[^:]*:[ \t]*/, "", value)
                define[name] = trim(value)
                next
            }

            /^::/ { next }                       # mode declarations carry no shortcut
            /^\.(blacklist|load)/ { next }
            /^[ \t]*#/ { next }
            /^[ \t]*$/ { next }
            !/[:;]/ { next }

            {
                lineno = NR
                comment = ""
                if (match(line, /#/)) {
                    comment = trim(substr(line, RSTART + 1))
                    line = substr(line, 1, RSTART - 1)
                }

                separator = match(line, /;/) && (!match(line, /:/) || index(line, ";") < index(line, ":")) ? ";" : ":"
                split(line, part, separator)
                shortcut = trim(part[1])
                action = trim(substr(line, index(line, separator) + 1))

                mode = "-"
                if (match(shortcut, /</)) {
                    mode = trim(substr(shortcut, 1, RSTART - 1))
                    shortcut = trim(substr(shortcut, RSTART + 1))
                }

                if (shortcut == "" || action == "") next

                # `key ; mode` switches skhd into that mode
                resolved = action
                if (separator == ";") {
                    description = "Enter skhd mode: " action
                } else {
                    alias = action
                    if (match(alias, /^@[a-zA-Z0-9_]+/)) {
                        name = substr(alias, RSTART + 1, RLENGTH - 1)
                        if (name in define) resolved = define[name] (RLENGTH < length(alias) ? "  " substr(alias, RSTART + RLENGTH) : "")
                    }
                    description = comment
                    if (description == "") {
                        # No comment to lean on, so make the alias itself readable
                        description = action
                        gsub(/^@/, "", description)
                        gsub(/_/, " ", description)
                        gsub(/\("|"\)/, " ", description)
                        description = trim(description)
                    }
                    if (action == "true") description = "Blocked on purpose: " (comment != "" ? comment : "swallowed by skhd")
                }

                if (section != "") description = description "  ·  " section

                printf "skhd\t%s\t%s\t%s\t%s:%d\t%s\n", shortcut, description, resolved, file, lineno, mode
            }
        ' $file
    end
end

function _keysight_source_yazi --description 'Shortcuts from the yazi keymap'
    for config in (_keysight_config yazi yazi/keymap.toml)
        test -f $config; or continue

        # yazi accepts two spellings of the same keymap: inline tables inside
        # `prepend_keymap = [ ... ]`, and one `[[mgr.prepend_keymap]]` section per binding
        # with the fields on their own lines. Both appear in the wild, so both are parsed.
        awk -v file="$config" '
            function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

            # A single quote cannot be written inside the single-quoted fish string that
            # carries this program, so the character is built from its code point
            function sq() { return sprintf("%c", 39) }

            # Values come quoted with either flavour, and the other flavour is routinely
            # used inside them, so the opening quote decides where the value ends
            function unquote(s,   q, out, i, c, escaped) {
                s = trim(s)
                q = substr(s, 1, 1)
                if (q != "\"" && q != sq()) return s
                out = ""
                for (i = 2; i <= length(s); i++) {
                    c = substr(s, i, 1)
                    if (escaped) { out = out c; escaped = 0; continue }
                    if (c == "\\\\" && q == "\"") { escaped = 1; out = out c; continue }
                    if (c == q) break
                    out = out c
                }
                return out
            }

            # `on` is a single key or a sequence of them; a sequence is shown the way it is
            # typed, one key after another
            function chord(s,   out, i, c, q, inside) {
                s = trim(s)
                if (substr(s, 1, 1) != "[") return unquote(s)
                out = ""
                inside = 0
                for (i = 2; i <= length(s); i++) {
                    c = substr(s, i, 1)
                    if (!inside && (c == "\"" || c == sq())) { inside = 1; q = c; continue }
                    if (inside && c == q) { inside = 0; continue }
                    if (inside) out = out c
                }
                return out
            }

            function store(segment,   at, key) {
                at = index(segment, "=")
                if (at == 0) return
                key = trim(substr(segment, 1, at - 1))
                field[key] = trim(substr(segment, at + 1))
            }

            # Split an inline table on its top level commas only: both the key sequence and
            # the quoted shell command it runs are full of commas of their own
            function split_table(s,   i, c, q, depth, segment) {
                delete field
                sub(/^[ \t]*\{/, "", s)
                sub(/\}[ \t]*,?[ \t]*$/, "", s)
                segment = ""
                q = ""
                depth = 0
                for (i = 1; i <= length(s); i++) {
                    c = substr(s, i, 1)
                    if (q != "") {
                        segment = segment c
                        if (c == "\\\\" && q == "\"") { segment = segment substr(s, ++i, 1); continue }
                        if (c == q) q = ""
                        continue
                    }
                    if (c == "\"" || c == sq()) { q = c; segment = segment c; continue }
                    if (c == "[") depth++
                    if (c == "]") depth--
                    if (c == "," && depth == 0) { store(segment); segment = ""; continue }
                    segment = segment c
                }
                store(segment)
            }

            function emit(   shortcut, action, description) {
                if (!("on" in field)) return
                shortcut = chord(field["on"])
                action = unquote(field["run"])
                description = ("desc" in field) ? unquote(field["desc"]) : action
                delete field
                if (shortcut == "") return
                printf "yazi\t%s\t%s\t%s\t%s:%d\t-\n", shortcut, description, action, file, lineno
            }

            /^[ \t]*#/ { next }

            /\{[^}]*on[ \t]*=/ {
                lineno = NR
                split_table($0)
                emit()
                next
            }

            /^[ \t]*\[\[.*keymap.*\]\]/ { emit(); block = 1; lineno = NR; next }
            /^[ \t]*\[/ { emit(); block = 0; next }

            block && /^[ \t]*(on|run|desc)[ \t]*=/ { store($0) }

            END { emit() }
        ' $config
    end
end

function _keysight_source_lazygit --description 'Custom commands from the lazygit config'
    for config in (_keysight_config lazygit lazygit/config.yml)
        test -f $config; or continue

        # Nested prompts carry their own key/description pairs, so every field is matched
        # against the indentation of the command it belongs to.
        awk -v file="$config" '
            function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^"|"$/, "", s); return s }
            function indent(s) { match(s, /^[ \t]*/); return RLENGTH }

            /^[ \t]*- key:/ && indent($0) <= 2 {
                if (key != "") printf "lazygit\t%s\t%s\t%s\t%s:%d\t-\n", key, description, command, file, lineno
                key = trim(substr($0, index($0, ":") + 1))
                level = indent($0) + 2
                lineno = NR
                command = ""
                description = ""
                next
            }
            key != "" && indent($0) == level && /^[ \t]*command:/ { command = trim(substr($0, index($0, ":") + 1)) }
            key != "" && indent($0) == level && /^[ \t]*description:/ { description = trim(substr($0, index($0, ":") + 1)) }

            END { if (key != "") printf "lazygit\t%s\t%s\t%s\t%s:%d\t-\n", key, description, command, file, lineno }
        ' $config
    end
end

function _keysight_source_nvim --description 'Normal mode mappings from a live nvim instance'
    command --query nvim; or return

    set -f cache (_keysight_cache_dir)/nvim.tsv
    set -f config (_keysight_config nvim nvim)

    if test "$argv[1]" != refresh
        and test -f $cache
        and test -z (find $config -newer $cache -name '*.lua' -o -newer $cache -name lazy-lock.json 2>/dev/null | head -1)
        cat $cache
        return
    end

    mkdir -p (dirname $cache)

    # LazyVim keeps its mappings in lua, not in the config files, so they are read
    # out of a headless instance and cached until the config changes.
    nvim --headless \
        -c 'lua local out = {} for _, m in ipairs(vim.api.nvim_get_keymap("n")) do if m.desc and m.desc ~= "" then out[#out + 1] = m.lhs .. "\t" .. m.desc end end io.write(table.concat(out, "\n") .. "\n")' \
        -c 'qa!' 2>/dev/null | while read --line mapping
        set -l parts (string split \t -- $mapping)
        set -l shortcut (string replace --regex '^ ' '<leader>' -- $parts[1])

        test -n "$shortcut"; or continue
        # <Plug> mappings are plugin extension points, not keys anyone presses
        string match --quiet '<Plug>*' -- $shortcut; and continue

        printf 'nvim\t%s\t%s\t%s\t%s\t-\n' $shortcut "$parts[2]" "$parts[2]" 'nvim (LazyVim defaults)'
    end >$cache

    cat $cache
end

function _keysight_normalise --description 'Bring shortcut spelling in line across sources'
    string lower -- $argv[1] | string replace --all '+' '-' | string replace --all '|' '-' | string trim
end

function _keysight_describe_action --description 'Turn a config action into something readable'
    set -f action (string trim -- $argv[1])

    switch $action
        case 'text:*'
            echo "Send literal input: "(string replace 'text:' '' -- $action)
        case 'scroll_page_lines:*'
            echo "Scroll by "(string replace 'scroll_page_lines:' '' -- $action)" lines"
        case '*DisableDefaultAssignment*'
            echo 'Disabled, passes the key through to the shell'
        case '*SendString*'
            echo "Send literal input: "(string replace --regex '.*SendString\("?([^")]*)"?\).*' '$1' -- $action)
        case '*'
            echo (string shorten --max 70 -- (string replace --all '_' ' ' -- $action))
    end
end

function _keysight_preview --description 'Render the fzf preview card for one shortcut'
    set -f row (_keysight_row $argv[1] $argv[2])
    test (count $row) -ge 5; or return

    set_color --bold cyan
    echo (string trim -- (_keysight_strip $row[3]))
    set_color normal
    echo

    # skhd rows carry their config section as a trailing category
    set -f description (string split '  ·  ' -- $row[4])

    set_color --bold
    echo 'Does'
    set_color normal
    echo "  $description[1]"
    echo

    if test (count $description) -gt 1
        set_color --bold
        echo 'Category'
        set_color normal
        echo "  $description[2]"
        echo
    end

    set_color --bold
    echo 'Runs'
    set_color normal
    for chunk in (string split '  ·  ' -- $row[5] | string split ';')
        echo "  "(string trim -- $chunk)
    end
    echo

    set_color --bold
    echo 'Defined in'
    set_color normal
    echo "  $row[6]"
end

function _keysight_edit --description 'Open the config a shortcut comes from'
    set -f row (_keysight_row $argv[1] $argv[2])
    set -f origin $row[6]
    set -f file (string split ':' -- $origin)[1]

    test -f "$file"; or return

    set -f lineno (string split ':' -- $origin)[2]
    set -f editor $EDITOR
    test -n "$editor"; or set editor nvim

    if string match --quiet --regex '^\d+$' -- "$lineno"
        $editor +$lineno $file
    else
        $editor $file
    end
end

function _keysight_row --description 'Read one indexed row back from the data file'
    test -f "$argv[1]"; or return
    string split \t -- (awk -F'\t' -v n="$argv[2]" 'NR == n' $argv[1])
end

function _keysight_strip --description 'Drop ANSI colouring from a field'
    string replace --all --regex '\e\[[0-9;]*m' '' -- $argv[1]
end
