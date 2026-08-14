# The recording in the README. Records the machine it runs on, so the shortcuts on
# screen are whatever the recorder has configured.
#
#   brew install vhs ttyd
#   cd docs && vhs demo.tape
#
# The nvim source starts a headless nvim on the first run, which is slow enough to show
# up in the recording — run `keys --refresh` once before recording.

Output demo.gif

Set Shell "bash"
Set FontFamily "JetBrainsMonoNL Nerd Font"
Set FontSize 15
Set Width 1900
Set Height 900
Set Padding 18
Set Theme "Catppuccin Mocha"
Set TypingSpeed 75ms
Set Framerate 24

# A fish profile of its own, so that no personal prompt or colour scheme is in the way
Hide
Type "env XDG_CONFIG_HOME=$PWD/demo-profile XDG_CACHE_HOME=$PWD/demo-profile/cache fish -i"
Enter
Sleep 4s
Type "clear"
Enter
Sleep 1s
Show

Sleep 1s
Type "keys"
Enter
Sleep 4s

# one shortcut, bound in more than one place
Type "ctrl-r"
Sleep 3s
Down
Sleep 3s

# the window management keys, where the preview shows the config and the line
Ctrl+U
Sleep 500ms
Type "skhd window"
Sleep 3s
Down
Sleep 2500ms

# ctrl-e opens that config, at that line
Ctrl+E
Sleep 3500ms
Type ":q"
Enter
Sleep 2500ms

# enter copies the shortcut
Enter
Sleep 3s
