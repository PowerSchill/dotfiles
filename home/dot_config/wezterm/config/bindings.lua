return function(config, wezterm)
  local act = wezterm.action
  config.keys = {
    {
      key = "t",
      mods = "CMD|SHIFT",
      action = act.ShowTabNavigator,
    },
    {
      key = "R",
      mods = "CMD|SHIFT",
      action = act.PromptInputLine({
        description = "Enter new name for tab",
        action = wezterm.action_callback(function(window, _, line)
          -- line will be `nil` if they hit escape without entering anything
          -- An empty string if they just hit enter
          -- Or the actual line of text they wrote
          if line then
            window:active_tab():set_title(line)
          end
        end),
      }),
    },
    {
      key = "p",
      mods = "CMD|SHIFT",
      action = act.ActivateCommandPalette,
    },
  }
end
