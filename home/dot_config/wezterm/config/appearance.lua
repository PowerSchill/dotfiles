return function(config, wezterm)
	local function is_dark()
		if wezterm.gui then
			local overrides = wezterm.gui.get_appearance()
			return overrides:find("Dark") ~= nil
		else
			return false
		end
	end

	-- Color
	if is_dark() then
		config.color_scheme = "Catppuccin Mocha"
	else
		config.color_scheme = "Catppuccin Mocha" -- will enable this when more of my configurations support light mode
	end

	config.hide_tab_bar_if_only_one_tab = true
	config.window_decorations = "RESIZE" -- "TITLE | RESIZE" is the default
	config.window_padding = {
		left = 10,
		right = 10,
		top = 10,
		bottom = 10,
	}
	config.macos_window_background_blur = 30

	-- Miscellaneous settings
	config.max_fps = 120
	config.prefer_egl = true
end
