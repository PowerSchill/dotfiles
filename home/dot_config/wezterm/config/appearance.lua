return function(config, wezterm)
  local act = wezterm.action

  -- Color
  config.color_scheme = "Catppuccin Mocha"
  config.hide_tab_bar_if_only_one_tab = true
  config.window_decorations = "RESIZE" -- "TITLE | RESIZE" is the default
  config.window_padding = {
    left = 10,
    right = 10,
    top = 10,
    bottom = 10,
  }
  config.macos_window_background_blur = 30
  config.window_background_opacity = 0.8

  -- Miscellaneous settings
  config.max_fps = 120
  config.prefer_egl = true

  -- Configure command palette appearance
  config.command_palette_bg_color = "#1e1e2e"
  config.command_palette_fg_color = "#cdd6f4"

  wezterm.on("augment-command-palette", function(window)
    return {
      {
        brief = "Toogle terminal transparency",
        icon = "md_circle_opacity",
        action = wezterm.action_callback(function()
          local overrides = window:get_config_overrides() or {}
          if overrides.window_background_opacity == 1.0 then
            overrides.window_background_opacity = 0.8
          else
            overrides.window_background_opacity = 1.0
          end
          window:set_config_overrides(overrides)
        end),
      },
    }
  end)
end
