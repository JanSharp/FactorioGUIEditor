
local styles = data.raw["gui-style"]["default"]

styles.gui_editor_node_normal = {
  type = "button_style",
  font = "default",
  -- doing this with style_mods for now
  -- horizontally_stretchable = "on",
  horizontal_align = "left",
  -- vertical_align = "center",
  -- icon_horizontal_align = "center",
  -- ignored_by_search = true,
  -- top_padding = 0,
  -- bottom_padding = 0,
  left_padding = 4,
  right_padding = 4,
  minimal_width = 100,
  minimal_height = 14,
  default_font_color = default_font_color,
  default_graphical_set = {
    base = {position = {17 * 1 + 8, 17 * 0 + 8}, width = 1, height = 1},
  },
  -- hovered_font_color = button_hovered_font_color,
  hovered_graphical_set = {
    base = {position = {17 * 2 + 8, 17 * 1 + 8}, width = 1, height = 1},
    -- glow = default_glow(default_glow_color, 0.5),
  },
  -- clicked_font_color = button_hovered_font_color,
  clicked_vertical_offset = 0, -- stop "text/icon goes down on click"
  clicked_graphical_set = {
    base = {position = {17 * 3 + 8, 17 * 1 + 8}, width = 1, height = 1},
  },
  -- disabled_font_color = {179, 179, 179},
  disabled_graphical_set = {
    base = {position = {17 * 1 + 8, 17 * 1 + 8}, width = 1, height = 1},
  },
  -- selected_font_color = button_hovered_font_color,
  selected_graphical_set = {
    base = {position = {17 * 1 + 8, 17 * 0 + 8}, width = 1, height = 1},
  },
  -- selected_hovered_font_color = button_hovered_font_color,
  selected_hovered_graphical_set = {
    base = {position = {17 * 2 + 8, 17 * 1 + 8}, width = 1, height = 1},
  },
  -- selected_clicked_font_color = button_hovered_font_color,
  selected_clicked_graphical_set = {
    base = {position = {17 * 3 + 8, 17 * 1 + 8}, width = 1, height = 1},
  },
  -- strikethrough_color = {0.5, 0.5, 0.5},
  -- pie_progress_color = {1, 1, 1},
  left_click_sound = {},
  -- left_click_sound = {{ filename = "__core__/sound/gui-click.ogg", volume = 1 }},
}

styles.gui_editor_node_selected = {
  type = "button_style",
  parent = "gui_editor_node_normal",
  default_graphical_set = {
    base = {position = {329 + 17 * 0 + 8, 47 + 8}, width = 1, height = 1},
  },
  hovered_graphical_set = {
    base = {position = {329 + 17 * 1 + 8, 47 + 8}, width = 1, height = 1},
    -- glow = default_glow(default_glow_color, 0.5),
  },
  clicked_graphical_set = {
    base = {position = {329 + 17 * 2 + 8, 47 + 8}, width = 1, height = 1},
  },
}

styles.gui_editor_node_cursor = {
  type = "button_style",
  parent = "gui_editor_node_normal",
  default_graphical_set = {
    base = {position = {431 + 17 * 0 + 8, 47 + 8}, width = 1, height = 1},
  },
  hovered_graphical_set = {
    base = {position = {431 + 17 * 1 + 8, 47 + 8}, width = 1, height = 1},
    -- glow = default_glow(default_glow_color, 0.5),
  },
  clicked_graphical_set = {
    base = {position = {431 + 17 * 2 + 8, 47 + 8}, width = 1, height = 1},
  },
}

styles.gui_editor_invisible_frame = {
  type = "frame_style",
  parent = "frame",
  top_padding  = 0,
  right_padding = 0,
  bottom_padding = 0,
  left_padding = 0,
  graphical_set = {},
}

styles.gui_editor_invisible_textbox = {
  type = "textbox_style",
  parent = "textbox",
  default_background = {},
  active_background = {},
  disabled_background = {},
}

styles.gui_editor_selected_frame_action_button = {
  type = "button_style",
  parent = "frame_action_button",
  default_font_color = _ENV.button_hovered_font_color,
  default_graphical_set = {
    base = { position = { 225, 17 }, corner_size = 8 },
    shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" },
  },
  hovered_font_color = _ENV.button_hovered_font_color,
  hovered_graphical_set = {
    base = { position = { 369, 17 }, corner_size = 8 },
    shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" },
  },
  clicked_font_color = _ENV.button_hovered_font_color,
  clicked_graphical_set = {
    base = { position = { 352, 17 }, corner_size = 8 },
    shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" },
  },
}

-- to make the arrow tooltips for invisible resize frames look better
styles.tooltip_label.minimal_width = 0

data:extend{
  {
    type = "sprite",
    name = "gui-editor-resize-white",
    filename = "__gui-editor__/graphics/icons/resize-white.png",
    width = 32,
    height = 32,
    flags = {"gui-icon"},
    scale = 0.5,
  },
  {
    type = "sprite",
    name = "gui-editor-resize-black",
    filename = "__gui-editor__/graphics/icons/resize-black.png",
    width = 32,
    height = 32,
    flags = {"gui-icon"},
    scale = 0.5,
  },
  {
    type = "font",
    name = "default-mono",
    from = "default-mono",
    size = 14,
  },
}
