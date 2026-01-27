{ config, lib, pkgs, ... }:

{
  programs.wezterm = {
    enable = true;

    # WezTerm configuration in Lua
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = {}

      -- Use config builder for newer WezTerm versions
      if wezterm.config_builder then
        config = wezterm.config_builder()
      end

      -- Font configuration - JetBrains Mono for readability
      config.font = wezterm.font('JetBrains Mono Nerd Font', { weight = 'Regular' })
      config.font_size = 11.0
      config.line_height = 1.2

      -- Claude-inspired color scheme (deep blues, warm oranges)
      config.colors = {
        -- Foreground and background
        foreground = '#e0e0e0',
        background = '#1a1d23',

        -- Cursor
        cursor_bg = '#f5a97f',
        cursor_fg = '#1a1d23',
        cursor_border = '#f5a97f',

        -- Selection
        selection_fg = '#1a1d23',
        selection_bg = '#4a5568',

        -- Scrollbar
        scrollbar_thumb = '#4a5568',

        -- Normal colors
        ansi = {
          '#1a1d23', -- black
          '#e06c75', -- red
          '#98c379', -- green
          '#e5c07b', -- yellow
          '#61afef', -- blue
          '#c678dd', -- magenta
          '#56b6c2', -- cyan
          '#abb2bf', -- white
        },

        -- Bright colors
        brights = {
          '#5c6370', -- bright black
          '#e06c75', -- bright red
          '#98c379', -- bright green
          '#e5c07b', -- bright yellow
          '#61afef', -- bright blue
          '#c678dd', -- bright magenta
          '#56b6c2', -- bright cyan
          '#ffffff', -- bright white
        },
      }

      -- Tab bar configuration - disabled for clean look
      config.enable_tab_bar = false
      config.use_fancy_tab_bar = false

      -- Window configuration
      config.window_padding = {
        left = 8,
        right = 8,
        top = 8,
        bottom = 8,
      }
      -- Use title bar with integrated buttons for GNOME Wayland
      config.window_decorations = "TITLE | RESIZE"
      config.window_close_confirmation = "NeverPrompt"

      -- Performance
      config.enable_wayland = true
      config.front_end = "WebGpu"

      -- Cursor configuration
      config.default_cursor_style = "SteadyBlock"
      config.cursor_blink_rate = 0

      -- Scrollback
      config.scrollback_lines = 10000

      -- Key bindings
      config.keys = {
        -- New tab
        {
          key = 't',
          mods = 'CTRL|SHIFT',
          action = wezterm.action.SpawnTab 'CurrentPaneDomain',
        },
        -- Close tab
        {
          key = 'w',
          mods = 'CTRL|SHIFT',
          action = wezterm.action.CloseCurrentTab { confirm = false },
        },
      }

      return config
    '';
  };
}
