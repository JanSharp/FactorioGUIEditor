
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local hierarchy = depends("__gui-editor__.hierarchy")
local nodes = depends("__gui-editor__.nodes")

---@param parent_elem LuaGuiElement
---@param column_count uint
local function create_editor_root_table(parent_elem, column_count)
  return gui.create_elem(parent_elem, {
    type = "table",
    column_count = column_count,
    style_mods = {
      horizontal_spacing = 0,
    },
  })
end

---@param parent_elem LuaGuiElement
---@param name string
---@param description string?
local function create_editor_name_label(parent_elem, name, description)
  return gui.create_elem(parent_elem, {
    type = "label",
    caption = name,
    tooltip = description,
    style_mods = {
      minimal_width = 92,
      right_margin = 8,
    },
  })
end

---@param parent_elem LuaGuiElement
---@param editor_data EditorData
local function create_field_name_label(parent_elem, editor_data)
  return create_editor_name_label(parent_elem, editor_data.field.name, editor_data.field.description)
end

---@param parent_elem LuaGuiElement
---@param editor_data EditorData
local function create_mixed_values_label(parent_elem, editor_data, use_black_font)
  if not editor_data.mixed_values then return end
  editor_data.mixed_values_label = gui.create_elem(parent_elem, {
    type = "label",
    caption = "<mixed>",
    ignored_by_interaction = true,
    style_mods = {
      font = "default-semibold",
      font_color = use_black_font and {0, 0, 0} or nil,
    },
  })
end

---@param editor_data EditorData
local function get_tags_for_field_editor(editor_data)
  return {
    window = "inspector",
    editor_name = editor_data.field.name,
  }
end

---@param text string
---@return integer line_count
local function count_lines(text)
  local line_count = 1
  for _ in text:gmatch("\n") do
    line_count = line_count + 1
  end
  return line_count
end

---@param line_count integer
---@return integer pixels
local function calculate_text_box_height(line_count)
  return line_count * 20 + 8
end

---@param editor_data EditorData
local function update_string_editor(editor_data)
  local line_count = count_lines(editor_data.display_value or "") -- TODO: handle optional
  editor_data.wrap_elem.visible = line_count > 1
  editor_data.text_box_elem.style.height = calculate_text_box_height(line_count)
end

---@param player PlayerData
---@param editor_data EditorData
---@param is_node_included fun(node: Node):boolean?
---@param get_value fun(node: Node):any
local function eval_nodes_to_edit_and_display_value(player, editor_data, is_node_included, get_value)
  local nodes_to_edit = {}
  local display_value
  local first = true
  local mixed_values = false
  for node in pairs(player.selected_nodes) do
    if is_node_included(node) then
      nodes_to_edit[#nodes_to_edit+1] = node
      if not mixed_values then
        local value = get_value(node)
        if first then
          display_value = value
          first = false
        elseif value ~= display_value then
          display_value = nil
          mixed_values = true
        end
      end
    end
  end
  editor_data.nodes_to_edit = nodes_to_edit
  editor_data.display_value = display_value
  editor_data.mixed_values = mixed_values
end

---@param player PlayerData
---@param editor_data EditorData
local function eval_nodes_to_edit_and_display_value_for_field(player, editor_data)
  eval_nodes_to_edit_and_display_value(
    player,
    editor_data,
    function(node)
      return bit32.band(node.type_flag, editor_data.field.type_flags) ~= 0
    end,
    function(node)
      return node.elem_data[editor_data.field.name]
    end
  )
end

---@param player PlayerData
---@param tags any
---@param new_value any
local function on_editor_value_changed(player, tags, new_value)
  if tags.window == "inspector" then
    local editor_name = tags.editor_name
    local editor_data = player.inspector_editors[editor_name]
    if editor_data.mixed_values then
      editor_data.mixed_values = false
      editor_data.mixed_values_label.destroy()
      editor_data.mixed_values_label = nil
    end
    editor_data.display_value = new_value
    if editor_data.editor_type == "string" then
      update_string_editor(editor_data)
    end
    for _, node in pairs(editor_data.nodes_to_edit) do
      if editor_data.editor_type == "node_name" then
        node.node_name = new_value
        node.hierarchy_button.caption = new_value
      else
        node.elem_data[editor_name] = new_value
        if editor_data.requires_rebuild then
          -- NOTE: for multi editing this can be optimized
          nodes.rebuild_elem(node)
        else
          node.elem[editor_name] = new_value
        end
      end
    end
  end
end

local on_boolean_editor_state_changed = gui.register_handler(
  "on_boolean_editor_state_changed",
  ---@param player PlayerData
  ---@param tags any
  ---@param event EventData.on_gui_checked_state_changed
  function(player, tags, event)
    on_editor_value_changed(player, tags, event.element.state)
  end
)

---@param player PlayerData
---@param editor_data EditorData
local function boolean_editor(player, editor_data)
  local tab = create_editor_root_table(player.inspector_elem, 3)
  create_field_name_label(tab, editor_data)
  gui.create_elem(tab, {
    type = "checkbox",
    state = editor_data.display_value or false,
    tooltip = editor_data.field.description,
    enabled = editor_data.field.write,
    tags = get_tags_for_field_editor(editor_data),
    events = {[defines.events.on_gui_checked_state_changed] = on_boolean_editor_state_changed},
  })
  create_mixed_values_label(tab, editor_data, false)
end

local on_string_editor_text_changed = gui.register_handler(
  "on_string_editor_text_changed",
  ---@param player PlayerData
  ---@param tags any
  ---@param event EventData.on_gui_text_changed
  function(player, tags, event)
    on_editor_value_changed(player, tags, event.element.text)
  end
)

---@param player PlayerData
---@param editor_data EditorData
local function string_editor(player, editor_data)
  local tab = create_editor_root_table(player.inspector_elem, 2)
  create_field_name_label(tab, editor_data)
  editor_data.wrap_elem = gui.create_elem(tab, {
    type = "empty-widget",
  })
  editor_data.text_box_elem = gui.create_elem(tab, {
    type = "text-box",
    text = editor_data.display_value or "",
    tooltip = editor_data.field.description,
    elem_mods = {
      read_only = not editor_data.field.write,
    },
    style_mods = {
      width = 0,
      horizontally_stretchable = true,
    },
    tags = get_tags_for_field_editor(editor_data),
    events = {[defines.events.on_gui_text_changed] = on_string_editor_text_changed},
  })
  create_mixed_values_label(editor_data.text_box_elem, editor_data, true)
  update_string_editor(editor_data)
end

local on_direction_editor_selection_state_changed = gui.register_handler(
  "on_direction_editor_selection_state_changed",
  ---@param player PlayerData
  ---@param tags any
  ---@param event EventData.on_gui_selection_state_changed
  function(player, tags, event)
    local selected_index = event.element.selected_index
    if selected_index == 0 then return end
    on_editor_value_changed(player, tags, selected_index == 1 and "horizontal" or "vertical")
  end
)

---@param player PlayerData
---@param editor_data EditorData
local function direction_editor(player, editor_data)
  eval_nodes_to_edit_and_display_value_for_field(player, editor_data)
  local tab = create_editor_root_table(player.inspector_elem, 2)
  create_field_name_label(tab, editor_data)
  local drop_down = gui.create_elem(tab, {
    type = "drop-down",
    items = {"horizontal", "vertical"},
    selected_index = editor_data.mixed_values and 0
      or editor_data.display_value == "horizontal" and 1
      or 2,
    tooltip = editor_data.field.description,
    tags = get_tags_for_field_editor(editor_data),
    events = {[defines.events.on_gui_selection_state_changed] = on_direction_editor_selection_state_changed},
  })
  create_mixed_values_label(drop_down, editor_data, true)
  editor_data.requires_rebuild = true
end

---@param player PlayerData
---@param editor_data EditorData
local function missing_editor(player, editor_data)
  local tab = create_editor_root_table(player.inspector_elem, 2)
  create_field_name_label(tab, editor_data)
  local field = editor_data.field
  gui.create_elem(tab, {
    type = "label",
    caption = "[color=#cc0000]Missing editor for "
      ..(type(field.type) == "string" and field.type or "<complex_type> [img=info]")
      .."[/color]",
    tooltip = type(field.type) ~= "string" and serpent.block(field.type) or nil,
  })
end

---Indexed by field name
---@type table<string, function>
local special_editors = {
  ["direction"] = direction_editor,
}
---Indexed by field type
---@type table<string, function>
local general_editors = {
  ["boolean"] = boolean_editor,
  ["string"] = string_editor,
  ["LocalisedString"] = string_editor,
}

---@param player PlayerData
---@param field Field
local function create_inspector_field_editor(player, field)
  local editor_data = {
    field = field,
  }
  player.inspector_editors[field.name] = editor_data

  do
    local editor = special_editors[field.name]
    if editor then
      editor_data.editor_type = field.name
      editor(player, editor_data)
      return
    end
  end

  if not field.read then return end

  do
    local editor = type(field.type) == "string" and general_editors[field.type]
    if editor then
      editor_data.editor_type = field.type
      eval_nodes_to_edit_and_display_value_for_field(player, editor_data)
      editor(player, editor_data)
      return
    end
  end

  missing_editor(player, editor_data)
end

local on_node_name_editor_text_changed = gui.register_handler(
  "on_node_name_editor_text_changed",
  ---@param player PlayerData
  ---@param tags any
  ---@param event EventData.on_gui_text_changed
  function(player, tags, event)
    on_editor_value_changed(player, tags, event.element.text)
  end
)

---@param player PlayerData
local function node_name_editor(player)
  local editor_data = {editor_type = "node_name"}
  player.inspector_editors["node_name"] = editor_data
  eval_nodes_to_edit_and_display_value(
    player,
    editor_data,
    function()
      return true
    end,
    function(node)
      return node.node_name
    end
  )
  local tab = create_editor_root_table(player.inspector_elem, 2)
  create_editor_name_label(tab, "node_name")
  local textfield_elem = gui.create_elem(tab, {
    type = "textfield",
    text = editor_data.display_value,
    style_mods = {
      width = 0,
      horizontally_stretchable = true,
    },
    tags = {
      window = "inspector",
      editor_name = "node_name",
    },
    events = {[defines.events.on_gui_text_changed] = on_node_name_editor_text_changed},
  })
  create_mixed_values_label(textfield_elem, editor_data, true)
end

---@param player PlayerData
local function update_inspector(player)
  for _, child in pairs(player.inspector_elem.children) do
    child.destroy()
  end
  if not next(player.selected_nodes) then return end

  local selected_flags = 0
  local any_are_root = false
  for selected_node in pairs(player.selected_nodes) do
    selected_flags = bit32.bor(selected_flags, selected_node.type_flag)
    if nodes.is_root(selected_node) then
      any_are_root = true
    end
  end

  player.inspector_editors = {}

  node_name_editor(player)

  gui.create_elem(player.inspector_elem, {type = "line"})

  for _, field in pairs(util.all_used_fields) do
    if bit32.band(field.type_flags, selected_flags) ~= 0
      and (field.name ~= "auto_center" or any_are_root)
    then
      -- only create an editor if the field is used by any selected node
      -- and only create an editor for auto_center if any selected node is a root node
      create_inspector_field_editor(player, field)
    end
  end
end

---@param player PlayerData
local function create_inspector(player)
  local inspector_window_elem, inspector_inner = gui.create_elem(player.player.gui.screen, {
    type = "frame",
    direction = "horizontal",
    caption = "Inspector",
    children = {
      {
        type = "frame",
        direction = "vertical",
        name = "inspector",
        style = "inside_shallow_frame",
        style_mods = {
          horizontally_stretchable = true,
          vertically_stretchable = true,
          padding = 4,
        },
      },
    },
  })
  ---@cast inspector_inner -?

  player.inspector_window_elem = inspector_window_elem
  player.inspector_elem = inspector_inner.inspector
end

---@class __gui-editor__.inspector
return {
  update_inspector = update_inspector,
  create_inspector = create_inspector,
}
