local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.keys = {
	{ key = "t", mods = "CMD|SHIFT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{ key = "Enter", action = wezterm.action.DisableDefaultAssignment },
	{ key = "v", mods = "CMD", action = wezterm.action.PasteFrom("Clipboard") },
}

return config
