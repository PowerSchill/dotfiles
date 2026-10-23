return function(config, wezterm)
  config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }
  config.keys = {
    {
      mods = "LEADER",
      key = "c",
      action = wezterm.action.SpawnTab("CurrentPaneDomain"),
    },
    {
      mods = "LEADER",
      key = "x",
      action = wezterm.action.CloseCurrentPane({ confirm = true }),
    },
    {
      mods = "LEADER",
      key = "b",
      action = wezterm.action.ActivateTabRelative(-1),
    },
    {
      mods = "LEADER",
      key = "n",
      action = wezterm.action.ActivateTabRelative(1),
    },
    {
      mods = "LEADER",
      key = "|",
      action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
    },
    {
      mods = "LEADER",
      key = "-",
      action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
    },
    {
      mods = "LEADER",
      key = "h",
      action = wezterm.action.ActivatePaneDirection("Left"),
    },
    {
      mods = "LEADER",
      key = "j",
      action = wezterm.action.ActivatePaneDirection("Down"),
    },
    {
      mods = "LEADER",
      key = "k",
      action = wezterm.action.ActivatePaneDirection("Up"),
    },
    {
      mods = "LEADER",
      key = "l",
      action = wezterm.action.ActivatePaneDirection("Right"),
    },
    {
      mods = "LEADER",
      key = "LeftArrow",
      action = wezterm.action.AdjustPaneSize({ "Left", 5 }),
    },
    {
      mods = "LEADER",
      key = "RightArrow",
      action = wezterm.action.AdjustPaneSize({ "Right", 5 }),
    },
    {
      mods = "LEADER",
      key = "DownArrow",
      action = wezterm.action.AdjustPaneSize({ "Down", 5 }),
    },
    {
      mods = "LEADER",
      key = "UpArrow",
      action = wezterm.action.AdjustPaneSize({ "Up", 5 }),
    },
  }

  for i = 0, 9 do
    -- leader + number to activate that tab
    table.insert(config.keys, {
      key = tostring(i),
      mods = "LEADER",
      action = wezterm.action.ActivateTab(i),
    })
  end
end
