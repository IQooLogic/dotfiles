local wezterm = require('wezterm')
local act = wezterm.action
local colors = wezterm.color

wezterm.on('update-right-status', function(window, pane)
  local cells = {}

  local cwd_uri = pane:get_current_working_dir()
  if cwd_uri then
    local cwd = ''
    local hostname = ''

    if type(cwd_uri) == 'userdata' then
      cwd = cwd_uri.file_path
      hostname = cwd_uri.host or wezterm.hostname()
    else
      cwd_uri = cwd_uri:sub(8)
      local slash = cwd_uri:find '/'
      if slash then
        hostname = cwd_uri:sub(1, slash - 1)
        cwd = cwd_uri:sub(slash):gsub('%%(%x%x)', function(hex)
          return string.char(tonumber(hex, 16))
        end)
      end
    end

    local dot = hostname:find('[.]')
    if dot then
      hostname = hostname:sub(1, dot - 1)
    end
    if hostname == '' then
      hostname = wezterm.hostname()
    end

    table.insert(cells, cwd)
    table.insert(cells, hostname)
  end

  local date = wezterm.strftime('%a %-d %b - %H:%M:%S')
  table.insert(cells, date)

  for _, b in ipairs(wezterm.battery_info()) do
    table.insert(cells, string.format('%.0f%%', b.state_of_charge * 100))
  end

  local statusline_colors = {
    "#3c1361",
    "#52307c",
    "#663a82",
    "#7c5295",
    "#b491c8",
  }

  local text_fg = "#ffffff"

  local elements = {}
  local num_cells = 0

  local function push(text, is_last)
    local cell_no = num_cells + 1
    table.insert(elements, {Foreground = {Color = text_fg}})
    table.insert(elements, {Background = {Color = statusline_colors[cell_no]}})
    table.insert(elements, {Text = ' ' .. text .. ' '})
    if not is_last then
      table.insert(elements, {Foreground = {Color = statusline_colors[cell_no + 1]}})
    end
    num_cells = num_cells + 1
  end

  while #cells > 0 do
    local cell = table.remove(cells, 1)
    push(cell, #cells == 0)
  end

  window:set_right_status(wezterm.format(elements))
end)

return {
	default_domain = 'WSL:Ubuntu-22.04',
	window_close_confirmation = "NeverPrompt",
	font_size = 16.0,
	color_scheme = "GruvboxDarkHard",
	window_background_opacity = 0.9,
	text_background_opacity = 1.0,
	initial_cols = 140,
	initial_rows = 36,
	window_padding = {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	},
	font = wezterm.font "JetBrains Mono",
	harfbuzz_features = { 'calt=0' },
	hide_tab_bar_if_only_one_tab = true,
	keys = {
		{-- split pane
			key = "o",
			mods = "CTRL|SHIFT",
			action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" })
		},
		{
			key = "e",
			mods = "CTRL|SHIFT",
			action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" })
		},
		{-- close current pane
			key = "w",
			mods = "CTRL|SHIFT",
			action = wezterm.action.CloseCurrentPane({ confirm = true })
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
		{-- switch panes
			key = "LeftArrow",
			mods = "CTRL",
			action = wezterm.action.ActivatePaneDirection("Left")
		},
		{
			key = "RightArrow",
			mods = "CTRL",
			action = wezterm.action.ActivatePaneDirection("Right")
		},
		{
			key = "UpArrow",
			mods = "CTRL",
			action = wezterm.action.ActivatePaneDirection("Up")
		},
		{
			key = "DownArrow",
			mods = "CTRL",
			action = wezterm.action.ActivatePaneDirection("Down")
		},
		{-- switch tabs
			key = "[",
			mods = "ALT",
			action = wezterm.action.ActivateTabRelative(-1)
		},
		{
			key = "]",
			mods = "ALT",
			action = wezterm.action.ActivateTabRelative(1)
		},
		{-- split pane right and start btop
			key = "t",
			mods = "CTRL|ALT|SHIFT",
			action = wezterm.action.SplitPane({
				direction = "Right",
				command = { args = { "btop" } },
				size = { Percent = 50 }
			})
		},
		{-- split pane right and start zellij
			key = "x",
			mods = "CTRL|ALT",
			action = wezterm.action.SplitPane({
				direction = "Right",
				command = { args = { "zellij" } },
				size = { Percent = 50 }
			})
		},
		{-- open new window and start zellij
			key = "z",
			mods = "CTRL|ALT|SHIFT",
			action = wezterm.action.SpawnCommandInNewWindow({ args = { "zellij" } })
		}
	},
}