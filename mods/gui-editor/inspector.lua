
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local hierarchy = depends("__gui-editor__.hierarchy")
local nodes = depends("__gui-editor__.nodes")

---Indexed by field name
---@type table<string, function>
local special_editors = {}
---Indexed by field type
---@type table<string, function>
local general_editors = {}

---@param player PlayerData
---@param tags any
---@param checkbox_elem LuaGuiElement
local function on_boolean_editor_state_changed_internal(player, tags, checkbox_elem)
  if tags.mixed_values then
    checkbox_elem.parent.mixed_values_label.visible = false
  end
  local value = checkbox_elem.state
  for _, node_id in pairs(tags.node_ids) do
    local node = player.nodes_by_id[node_id]
    ---@diagnostic disable-next-line: assign-type-mismatch
    node.elem[tags.field_name] = value
    ---@diagnostic disable-next-line: assign-type-mismatch
    node.elem_data[tags.field_name] = value
  end
end

---@param player PlayerData
---@param tags any
---@param event EventData.on_gui_checked_state_changed
local on_boolean_editor_state_changed = gui.register_handler(defines.events.on_gui_checked_state_changed, "on_boolean_editor_state_changed", function(player, tags, event)
  on_boolean_editor_state_changed_internal(player, tags, event.element)
end)

---@param player PlayerData
---@param nodes_to_edit table<Node, true>
---@param parent_elem LuaGuiElement
---@param field Field
general_editors["boolean"] = function(player, nodes_to_edit, parent_elem, field)
  -- TODO: remove duplication
  local node_ids = {}
  local display_value
  local mixed_values = false
  for node in pairs(nodes_to_edit) do
    if bit32.band(node.type_flag, field.type_flags) ~= 0 then
      node_ids[#node_ids+1] = node.id
      if not mixed_values then
        local value = node.elem_data[field.name]--[[@as boolean]]
        if display_value == nil then
          display_value = value
        elseif value ~= display_value then
          display_value = false
          mixed_values = true
        end
      end
    end
  end

  gui.create_elem(parent_elem,
  {
    type = "flow",
    direction = "horizontal",
    children = {
      {
        type = "checkbox",
        state = display_value,
        tooltip = field.description,
        tags = {
          node_ids = node_ids,
          field_name = field.name,
          mixed_values = mixed_values,
        },
        events = {on_boolean_editor_state_changed},
      },
      {
        -- TODO: remove duplication
        type = "label",
        name = "mixed_values_label",
        caption = "<mixed>",
        ignored_by_interaction = true,
        style_mods = {
          font = "default-semibold",
          -- font_color = {0, 0, 0},
        },
        visible = mixed_values,
      },
    },
  })
end

---@param player PlayerData
---@param tags any
---@param event EventData.on_gui_selection_state_changed
local on_direction_selected_state_changed = gui.register_handler(defines.events.on_gui_selection_state_changed, "on_direction_selected_state_changed", function(player, tags, event)
  if tags.mixed_values then
    if event.element.selected_index == 0 then return end
    event.element.mixed_values_label.visible = false
  end
  for _, node_id in pairs(tags.node_ids) do
    local node = player.nodes_by_id[node_id]
    local value = event.element.selected_index == 1 and "horizontal" or "vertical"
    if value ~= node.elem_data.direction then
      node.elem_data.direction = value
      nodes.rebuild_elem(node) -- NOTE: for multi editing this can be optimized
    end
  end
end)

---@param player PlayerData
---@param nodes_to_edit table<Node, true>
---@param parent_elem LuaGuiElement
---@param field Field
special_editors["direction"] = function(player, nodes_to_edit, parent_elem, field)
  -- TODO: remove duplication
  local node_ids = {}
  local display_value
  local mixed_values = false
  for node in pairs(nodes_to_edit) do
    if bit32.band(node.type_flag, field.type_flags) ~= 0 then
      node_ids[#node_ids+1] = node.id
      local value = node.elem_data[field.name]--[[@as string]]
      if not display_value then
        display_value = value
      elseif value ~= display_value then
        display_value = ""
        mixed_values = true
      end
    end
  end

  gui.create_elem(parent_elem, {
    type = "drop-down",
    items = {
      "horizontal",
      "vertical",
    },
    selected_index = display_value == "" and 0 or display_value == "horizontal" and 1 or 2,
    tooltip = field.description,
    tags = {
      node_ids = node_ids,
      mixed_values = mixed_values,
    },
    events = {on_direction_selected_state_changed},
    -- TODO: remove duplication
    children = {
      {
        type = "label",
        name = "mixed_values_label",
        caption = "<mixed>",
        ignored_by_interaction = true,
        style_mods = {
          font = "default-semibold",
          font_color = {0, 0, 0},
        },
        visible = mixed_values,
      },
    },
  })
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

---@param player PlayerData
---@param tags any
---@param event EventData.on_gui_text_changed
local on_string_editor_state_changed = gui.register_handler(defines.events.on_gui_text_changed, "on_string_editor_state_changed", function(player, tags, event)
  if tags.mixed_values then
    event.element.mixed_values_label.visible = false
    -- event.element.parent.mixed_values_sprite.visible = false
  end
  local text = event.element.text
  local line_count = count_lines(text)
  event.element.parent.parent.wrap_widget.visible = line_count > 1
  event.element.style.height = calculate_text_box_height(line_count)
  for _, node_id in pairs(tags.node_ids) do
    local node = player.nodes_by_id[node_id]
    local value = text
    ---@diagnostic disable-next-line: assign-type-mismatch
    node.elem[tags.field_name] = value
    ---@diagnostic disable-next-line: assign-type-mismatch
    node.elem_data[tags.field_name] = value
  end
end)

---@param player PlayerData
---@param nodes_to_edit table<Node, true>
---@param parent_elem LuaGuiElement
---@param field Field
local function string_editor(player, nodes_to_edit, parent_elem, field)
  local node_ids = {}
  local display_value
  local mixed_values = false
  for node in pairs(nodes_to_edit) do
    if bit32.band(node.type_flag, field.type_flags) ~= 0 then
      node_ids[#node_ids+1] = node.id
      local value = node.elem_data[field.name]--[[@as string]]
      if not display_value then
        display_value = value or ""
      elseif value ~= display_value then
        display_value = ""
        mixed_values = true
      end
    end
  end
  local line_count = count_lines(display_value)

  gui.create_elem(parent_elem, {
    type = "empty-widget",
    name = "wrap_widget",
    visible = line_count > 1,
  })
  gui.create_elem(parent_elem, {
    type = "flow",
    direction = "horizontal",
    children = {
      {
        type = "text-box",
        text = display_value,
        tooltip = field.description,
        style_mods = {
          horizontally_stretchable = true,
          width = 0,
          height = calculate_text_box_height(line_count),
        },
        elem_mods = {
          read_only = not field.write,
        },
        tags = {
          node_ids = node_ids,
          field_name = field.name,
          mixed_values = mixed_values,
        },
        events = {on_string_editor_state_changed},
        children = {
          {
            type = "label",
            name = "mixed_values_label",
            caption = "<mixed>",
            ignored_by_interaction = true,
            style_mods = {
              font = "default-semibold",
              font_color = {0, 0, 0},
            },
            visible = mixed_values,
          },
        },
      },
      -- {
      --   type = "sprite",
      --   name = "mixed_values_sprite",
      --   sprite = "utility/warning_icon",
      --   tooltip = "Selected nodes have different values for this field.",
      --   visible = mixed_values,
      --   style_mods = {size = 28},
      --   resize_to_sprite = false,
      -- },
    },
  })
end
general_editors["string"] = string_editor
general_editors["LocalisedString"] = string_editor

---@param player PlayerData
---@param nodes_to_edit table<Node, true>
---@param parent_elem LuaGuiElement
---@param field Field
local function missing_editor(player, nodes_to_edit, parent_elem, field)
  gui.create_elem(parent_elem, {
    type = "label",
    caption = "[color=#cc0000]Missing editor for "
      ..(type(field.type) == "string" and field.type or "<complex_type> [img=info]")
      .."[/color]",
    tooltip = type(field.type) ~= "string" and serpent.block(field.type) or nil,
  })
end

---@param player PlayerData
---@param field Field
local function create_editor(player, field)
  local editor = special_editors[field.name]
  if not editor then
    if not field.read then return end
    editor = type(field.type) == "string" and general_editors[field.type] or missing_editor
  end
  local table_elem = gui.create_elem(player.inspector_elem, {
    type = "table",
    column_count = 2,
    style_mods = {
      horizontal_spacing = 0,
    },
    children = {
      {
        type = "label",
        caption = field.name,
        tooltip = field.description,
        style_mods = {
          minimal_width = 92,
          right_margin = 8,
        },
      },
    },
  })
  editor(player, player.selected_nodes, table_elem, field)
end

-- ---@param player PlayerData
-- local on_inspector_name_text_changed = gui.register_handler(defines.events.on_gui_text_changed, "on_inspector_name_text_changed", function(player, _, event)
--   next(player.cursor_nodes).node_name = event.element.text
--   next(player.cursor_nodes).hierarchy_button.caption = event.element.text
-- end)

---@param player PlayerData
local function update_inspector(player)
  local inspector = player.inspector_elem
  for _, child in pairs(inspector.children) do
    child.destroy()
  end
  if not next(player.cursor_nodes) then return end
  -- TODO: node_name editor
  -- gui.create_elem(inspector, {
  --   type = "textfield",
  --   text = node.node_name,
  --   -- didn't do anything for some reason
  --   -- style_mods = {
  --   --   horizontally_stretchable = true,
  --   -- },
  --   events = {on_inspector_name_text_changed},
  -- })

  local selected_flags = 0
  local any_are_root = false
  for selected_node in pairs(player.selected_nodes) do
    selected_flags = bit32.bor(selected_flags, selected_node.type_flag)
    if nodes.is_root(selected_node) then
      any_are_root = true
    end
  end

  for _, field in pairs(util.all_used_fields) do
    if bit32.band(field.type_flags, selected_flags) ~= 0
      and (field.name ~= "auto_center" or any_are_root)
    then
      -- only create an editor if the field is used by any selected node
      -- and only create an editor for auto_center if any selected node is a root node
      create_editor(player, field)
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
