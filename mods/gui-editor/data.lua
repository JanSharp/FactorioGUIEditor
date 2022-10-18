
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

styles.gui_editor_script_textbox = {
  type = "textbox_style",
  parent = "textbox",
  default_background = {},
  active_background = {},
  disabled_background = {},
  selection_background_color = {80, 80, 80},
}

styles.gui_editor_selection_textfield = {
  type = "textbox_style",
  parent = "textbox",
  default_background = {},
  -- active_background = {base = {position = {432, 152 - 4}, width = 1, height = 1}}, -- darker transparent yellow
  -- active_background = {base = {position = {389, 49}, width = 1, height = 1}}, -- lighter transparent yellow
  active_background = {base = {position = {200, 950}, width = 1, height = 1}}, -- very transparent white
  -- active_background = {base = {position = {300, 950}, width = 1, height = 1}}, -- less transparent white
  disabled_background = {},
  selection_background_color = {0, 0, 0, 0},
  font_color = {0, 0, 0, 0},
  rich_text_setting = "disabled",
  width = 0,
  minimal_height = 0,
}

-- NOTE: _currently_ unused, but very most likely used again soon TM
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

styles.gui_editor_list_box_scroll_pane = {
  type = "scroll_pane_style",
  parent = "naked_scroll_pane",
  -- copied from `list_box_scroll_pane`
  background_graphical_set =
  {
    position = {282, 17},
    corner_size = 8,
    overall_tiling_vertical_size = 20,
    overall_tiling_vertical_spacing = 8,
    overall_tiling_vertical_padding = 4,
    overall_tiling_horizontal_padding = 4,
  },
}

-- to make the arrow tooltips for invisible resize frames look better
styles.tooltip_label.minimal_width = 0

local fira_code_font_size = 12
-- oddly enough font size 14 with fira code puts the text pretty high up in each line which looks
-- really weird with the cursor going so much farther down than the actual text
-- default-mono is kind of similar, but not as extreme. Although I didn't test anything but 14

local function make_gui_icon(name)
  return {
    type = "sprite",
    name = "gui-editor-"..name,
    filename = "__gui-editor__/graphics/icons/"..name..".png",
    width = 32,
    height = 32,
    flags = {"gui-icon"},
    scale = 0.5,
  }
end

data:extend{
  make_gui_icon("resize-white"),
  make_gui_icon("resize-black"),
  make_gui_icon("locked-white"),
  make_gui_icon("locked-black"),
  make_gui_icon("unlocked-white"),
  make_gui_icon("unlocked-black"),
  {
    type = "sprite",
    name = "gui-editor-script-error",
    filename = "__core__/graphics/gui-new.png",
    priority = "medium",
    width = 8 * 2,
    height = 6 * 2,
    x = 80,
    y = 930,
    flags = {"gui-icon"},
    scale = 0.5,
  },
  {
    type = "font",
    name = "default-mono",
    from = "default-mono",
    size = 14,
  },
  -- {
  --   type = "font",
  --   name = "fira-code-bold",
  --   from = "fira-code-bold",
  --   size = fira_code_font_size,
  -- },
  {
    type = "font",
    name = "fira-code-light",
    from = "fira-code-light",
    size = fira_code_font_size,
  },
  {
    type = "font",
    name = "fira-code-medium",
    from = "fira-code-medium",
    size = fira_code_font_size,
  },
  {
    type = "font",
    name = "fira-code",
    from = "fira-code-regular",
    size = fira_code_font_size,
  },
  -- No idea what retina is supposed to mean, but it seems like a very slight variation of medium
  -- {
  --   type = "font",
  --   name = "fira-code",
  --   from = "fira-code-retina",
  --   size = fira_code_font_size,
  -- },
  -- {
  --   type = "font",
  --   name = "fira-code-semibold",
  --   from = "fira-code-semibold",
  --   size = fira_code_font_size,
  -- },
  {
    type = "custom-input",
    name = "gui-editor-open-runner",
    key_sequence = "CONTROL + SHIFT + P",
    enabled_while_spectating = true,
    enabled_while_in_cutscene = true,
    action = "lua",
  },
}
