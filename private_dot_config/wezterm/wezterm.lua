-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- config.enable_wayland = true
-- config.front_end = "OpenGL"
-- This is where you actually apply your config choices

-- For example, changing the color scheme:
-- config.color_scheme = "Catppuccin Mocha"
config.font_size = 18.0

-- config.color_scheme = "GruvboxDarkHard"
config.colors = require("cyberdream")

-- config.window_background_image = '/home/milos/.config/wezterm/bg.jpg'
config.window_background_opacity = 0.9
config.text_background_opacity = 0.7

config.initial_cols = 160
config.initial_rows = 48

config.window_close_confirmation = "NeverPrompt"

config.window_padding = {
	left = 2,
	right = 2,
	top = 2,
	bottom = 2,
}

config.inactive_pane_hsb = {
	saturation = 1.0,
	brightness = 0.85,
}

-- config.font = wezterm.font("JetBrainsMono NF", { weight = "Regular" })
config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font",
	-- "JetBrainsMonoNL Nerd Font",
	"Symbola",
	"Noto Sans Symbols",
	"DejaVu Sans",

	-- "Symbols Nerd Font Mono",
	-- "Noto Mono",
	-- "JetBrainsMono NF",
	-- "Noto Sans Symbols 2",
	-- "Apple Color Emoji",
	-- "Segoe UI Emoji",
	-- "Noto Color Emoji",
})
config.harfbuzz_features = { "calt=0" } -- disable ligatures

config.hide_tab_bar_if_only_one_tab = true

local act = wezterm.action
config.keys = {
	{ -- split pane
		key = "o",
		mods = "CTRL|SHIFT",
		action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "e",
		mods = "CTRL|SHIFT",
		action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{ -- close current pane
		key = "w",
		mods = "CTRL|SHIFT",
		action = act.CloseCurrentPane({ confirm = true }),
	},
	-- {-- rotate panes
	-- 	key = "b",
	-- 	mods = "CTRL",
	-- 	action = act.RotatePanes("CounterClockwise")
	-- },
	-- {
	-- 	key = "n",
	-- 	mods = "CTRL",
	-- 	action = act.RotatePanes("Clockwise")
	-- },
	{ -- switch panes
		key = "LeftArrow",
		mods = "CTRL",
		action = act.ActivatePaneDirection("Left"),
	},
	{
		key = "RightArrow",
		mods = "CTRL",
		action = act.ActivatePaneDirection("Right"),
	},
	{
		key = "UpArrow",
		mods = "CTRL",
		action = act.ActivatePaneDirection("Up"),
	},
	{
		key = "DownArrow",
		mods = "CTRL",
		action = act.ActivatePaneDirection("Down"),
	},
	{ -- switch tabs
		key = "[",
		mods = "ALT",
		action = act.ActivateTabRelative(-1),
	},
	{
		key = "]",
		mods = "ALT",
		action = act.ActivateTabRelative(1),
	},
	{ -- move tabs relative to
		key = "{",
		mods = "SHIFT|ALT",
		action = act.MoveTabRelative(-1),
	},
	{
		key = "}",
		mods = "SHIFT|ALT",
		action = act.MoveTabRelative(1),
	},
	{ -- split pane right and start btop
		key = "t",
		mods = "CTRL|ALT|SHIFT",
		action = act.SplitPane({
			direction = "Right",
			command = { args = { "btop" } },
			size = { Percent = 50 },
		}),
	},
	{ -- split pane right and start zellij
		key = "x",
		mods = "CTRL|ALT",
		action = act.SplitPane({
			direction = "Right",
			command = { args = { "zellij" } },
			size = { Percent = 50 },
		}),
	},
	{ -- open new window and start zellij
		key = "z",
		mods = "CTRL|ALT|SHIFT",
		action = act.SpawnCommandInNewWindow({ args = { "zellij" } }),
	},
	-- Reset font size to default (CTRL+0)
	{ key = "0", mods = "CTRL", action = act.ResetFontSize },
}

config.mouse_bindings = {
	-- Scrolling up while holding CTRL increases the font size
	{
		event = { Down = { streak = 1, button = { WheelUp = 1 } } },
		mods = "CTRL",
		action = act.IncreaseFontSize,
	},
	-- Scrolling down while holding CTRL decreases the font size
	{
		event = { Down = { streak = 1, button = { WheelDown = 1 } } },
		mods = "CTRL",
		action = act.DecreaseFontSize,
	},
}

if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	-- Configs for Windows only
	-- font_dirs = {
	--     'C:\\Users\\whoami\\.dotfiles\\.fonts'
	-- }
	-- config.default_prog = { 'pwsh.exe', '-l' }
	-- default_prog = {'wsl.exe', '~', '-d', 'Ubuntu-22.04'}
	config.default_domain = "WSL:Ubuntu-22.04"
end

if wezterm.target_triple == "x86_64-apple-darwin" then
	-- Configs for OSX only
	-- font_dirs    = { '$HOME/.dotfiles/.fonts' }
end

if wezterm.target_triple == "x86_65-unknown-linux-gnu" then
	-- Configs for Linux only
	-- font_dirs    = { '$HOME/.dotfiles/.fonts' }
end

-- and finally, return the configuration to wezterm
return config
