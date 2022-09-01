
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
