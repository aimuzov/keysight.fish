# The fish profile the README recording runs in: none of the recorder's own prompt,
# bindings or fzf colours, but their real configs behind every source.

set -g fish_greeting

set -l here (dirname (status filename))

# keys is loaded straight out of this checkout, not from an installed copy
set -p fish_function_path (realpath $here/../../..)/functions

# a clipboard that goes nowhere, and an editor with no config of its own
set -gx PATH (realpath $here/../bin) $PATH
set -gx EDITOR demo-editor

set -gx FZF_DEFAULT_OPTS '--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 --color=border:#6c7086,label:#cdd6f4'

# fish has already read this profile, so every source — and the nvim instance the nvim
# source starts — goes back to the real configs of the machine
set -gx XDG_CONFIG_HOME $HOME/.config

function fish_prompt
    set_color brblack
    echo -n '~ '
    set_color normal
end
