return function(config, wezterm)
  local act = wezterm.action

  -- Catppuccin Mocha palette
  local mocha = {
    crust    = '#11111b',
    mantle   = '#181825',
    base     = '#1e1e2e',
    surface0 = '#313244',
    surface1 = '#45475a',
    surface2 = '#585b70',
    overlay0 = '#6c7086',
    overlay1 = '#7f849c',
    subtext0 = '#a6adc8',
    subtext1 = '#bac2de',
    text     = '#cdd6f4',
    lavender = '#b4befe',
    blue     = '#89b4fa',
    sapphire = '#74c7ec',
    sky      = '#89dceb',
    teal     = '#94e2d5',
    green    = '#a6e3a1',
    yellow   = '#f9e2af',
    peach    = '#fab387',
    maroon   = '#eba0ac',
    red      = '#f38ba8',
    mauve    = '#cba6f7',
    pink     = '#f5c2e7',
    flamingo = '#f2cdcd',
    rosewater = '#f5e0dc',
  }

  -- Catppuccin Latte palette
  local latte = {
    crust    = '#dce0e8',
    mantle   = '#e6e9ef',
    base     = '#eff1f5',
    surface0 = '#ccd0da',
    surface1 = '#bcc0cc',
    surface2 = '#acb0be',
    overlay0 = '#9ca0b0',
    overlay1 = '#8c8fa1',
    subtext0 = '#6c6f85',
    subtext1 = '#5c5f77',
    text     = '#4c4f69',
    lavender = '#7287fd',
    blue     = '#1e66f5',
    sapphire = '#209fb5',
    sky      = '#04a5e5',
    teal     = '#179299',
    green    = '#40a02b',
    yellow   = '#df8e1d',
    peach    = '#fe640b',
    maroon   = '#e64553',
    red      = '#d20f39',
    mauve    = '#8839ef',
    pink     = '#ea76cb',
    flamingo = '#dd7878',
    rosewater = '#dc8a78',
  }

  -- Select palette based on macOS system appearance
  local function is_dark()
    local appearance = wezterm.gui and wezterm.gui.get_appearance() or "Dark"
    return appearance:find("Dark") ~= nil
  end

  local palette = is_dark() and mocha or latte
  config.color_scheme = is_dark() and "Catppuccin Mocha" or "Catppuccin Latte"

  if is_dark() then
    local bg_background = os.getenv("HOME") .. "/.config/wezterm/assets/Wezterm Background Blurred.png"
    config.window_background_image = bg_background
  end

  -- Tab bar
  config.hide_tab_bar_if_only_one_tab = false
  config.use_fancy_tab_bar = false
  config.show_new_tab_button_in_tab_bar = false
  config.tab_bar_at_bottom = false
  config.tab_max_width = 32
  config.window_decorations = "RESIZE"
  config.macos_window_background_blur = 30
  config.window_background_opacity = 0.9

  config.window_padding = {
    left = 3,
    right = 3,
    top = 3,
    bottom = 3,
  }

  -- Miscellaneous settings
  config.max_fps = 120
  config.prefer_egl = true

  -- Tab bar colors
  config.colors = {
    tab_bar = {
      background = palette.crust,
      active_tab = {
        bg_color = palette.base,
        fg_color = palette.lavender,
        intensity = 'Bold',
      },
      inactive_tab = {
        bg_color = palette.crust,
        fg_color = palette.overlay1,
      },
      inactive_tab_hover = {
        bg_color = palette.surface0,
        fg_color = palette.text,
      },
      new_tab = {
        bg_color = palette.crust,
        fg_color = palette.overlay0,
      },
      new_tab_hover = {
        bg_color = palette.surface0,
        fg_color = palette.text,
      },
    },
  }

  -- Command palette appearance
  config.command_palette_bg_color = palette.base
  config.command_palette_fg_color = palette.text

  -- Tab title helper
  local function tab_title(tab_info)
    local title = tab_info.tab_title
    if title and #title > 0 then
      return title
    end
    return tab_info.active_pane.title
  end

  -- Half-circle separators for rounded tab look
  local LEFT_CIRCLE = wezterm.nerdfonts.ple_left_half_circle_thick
  local RIGHT_CIRCLE = wezterm.nerdfonts.ple_right_half_circle_thick

  wezterm.on('format-tab-title', function(tab, tabs, panes, _config, hover, max_width)
    local tab_bg = palette.crust
    local tab_fg = palette.overlay1
    local edge_bg = palette.crust

    if tab.is_active then
      tab_bg = palette.base
      tab_fg = palette.lavender
    elseif hover then
      tab_bg = palette.surface0
      tab_fg = palette.text
    end

    local title = tab_title(tab)
    local index = tab.tab_index + 1

    -- Truncate title to fit
    title = wezterm.truncate_right(title, max_width - 6)

    return {
      { Background = { Color = edge_bg } },
      { Foreground = { Color = tab_bg } },
      { Text = LEFT_CIRCLE },
      { Background = { Color = tab_bg } },
      { Foreground = { Color = tab_fg } },
      { Attribute = { Intensity = tab.is_active and 'Bold' or 'Normal' } },
      { Text = ' ' .. index .. ': ' .. title .. ' ' },
      { Background = { Color = edge_bg } },
      { Foreground = { Color = tab_bg } },
      { Text = RIGHT_CIRCLE },
    }
  end)

  -- Right status with hostname
  wezterm.on('update-status', function(window)
    local LEFT_ARROW = wezterm.nerdfonts.ple_left_half_circle_thick

    window:set_right_status(wezterm.format({
      { Background = { Color = palette.crust } },
      { Foreground = { Color = palette.surface0 } },
      { Text = LEFT_ARROW },
      { Background = { Color = palette.surface0 } },
      { Foreground = { Color = palette.subtext0 } },
      { Text = ' ' .. wezterm.hostname() .. ' ' },
    }))
  end)

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
