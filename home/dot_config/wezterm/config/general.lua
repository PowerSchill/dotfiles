return function(config, wezterm)
  config.exit_behavior = "CloseOnCleanExit"
  config.scrollback_lines = 5000

  config.hyperlink_rules = wezterm.default_hyperlink_rules()

  table.insert(config.hyperlink_rules, {
    regex = [[["']?([\w\d]{1}[-\w\d]+)(/){1}([-w\d\.]+)["']?]],
    format = "https://www.github.com/$1/$3",
  })

  config.audible_bell = "Disabled"
  config.visual_bell = {
    fade_in_duration_ms = 75,
    fade_out_duration_ms = 75,
    target = "CursorColor",
  }

  -- Prompt before closing
  config.window_close_confirmation = "AlwaysPrompt"
end
