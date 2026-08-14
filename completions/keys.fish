complete --command keys --no-files

complete --command keys --short-option h --long-option help --description 'Show usage'
complete --command keys --short-option l --long-option list --description 'Dump raw TSV instead of opening fzf'
complete --command keys --short-option r --long-option refresh --description 'Rebuild the nvim mapping cache'
complete --command keys --short-option s --long-option source --require-parameter --description 'Limit to one source' \
    --arguments 'fish ghostty wezterm skhd yazi lazygit nvim'
