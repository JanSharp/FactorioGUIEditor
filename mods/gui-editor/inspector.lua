
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local hierarchy = depends("__gui-editor__.hierarchy")
local nodes = depends("__gui-editor__.nodes")

---@param player PlayerData
local on_inspector_name_text_changed = gui.register_handler(defines.events.on_gui_text_changed, "on_inspector_name_text_changed", function(player, _, event)
  player.selected_node.node_name = event.element.text
  player.selected_node.hierarchy_label.caption = hierarchy.get_hierarchy_label_caption(player, player.selected_node)
end)

---@param player PlayerData
---@param tags any
---@param event EventData.on_gui_selection_state_changed
local on_direction_selected_state_changed = gui.register_handler(defines.events.on_gui_selection_state_changed, "on_direction_selected_state_changed", function(player, tags, event)
  local node = player.nodes_by_id[tags.node_id]
  local value = event.element.selected_index == 1 and "horizontal" or "vertical"
  if value ~= node.elem_data.direction then
    node.elem_data.direction = value
    nodes.rebuild_elem(node)
  end
end)

---@param inspector LuaGuiElement
---@param node Node
---@param field ApiAttribute
local function direction_editor(inspector, node, field)
  gui.create_elem(inspector, {
    type = "flow",
    direction = "horizontal",
    children = {
      {
        type = "label",
        caption = field.name,
        tooltip = field.description,
      },
      {
        type = "empty-widget",
        style_mods = {horizontally_stretchable = true},
      },
      {
        type = "drop-down",
        items = {
          "horizontal",
          "vertical",
        },
        selected_index = node.elem_data.direction == "horizontal" and 1 or 2,
        tooltip = field.description,
        tags = {
          node_id = node.id,
        },
        events = {on_direction_selected_state_changed},
      },
    },
  })
end

---@param player PlayerData
---@param tags any
---@param checkbox_elem LuaGuiElement
local function on_boolean_editor_state_changed_internal(player, tags, checkbox_elem)
  local node = player.nodes_by_id[tags.node_id]
  local value = checkbox_elem.state
  ---@diagnostic disable-next-line: assign-type-mismatch
  node.elem[tags.field_name] = value
  ---@diagnostic disable-next-line: assign-type-mismatch
  node.elem_data[tags.field_name] = value
end

---@param player PlayerData
---@param event EventData.on_gui_click
local on_boolean_editor_label_click = gui.register_handler(defines.events.on_gui_click, "on_boolean_editor_label_click", function(player, _, event)
  local checkbox_elem = event.element.parent.checkbox
  ---@cast checkbox_elem -?
  checkbox_elem.state = not checkbox_elem.state
  on_boolean_editor_state_changed_internal(player, checkbox_elem.tags.__gui_editor, checkbox_elem)
end)

---@param player PlayerData
---@param tags any
---@param event EventData.on_gui_checked_state_changed
local on_boolean_editor_state_changed = gui.register_handler(defines.events.on_gui_checked_state_changed, "on_boolean_editor_state_changed", function(player, tags, event)
  on_boolean_editor_state_changed_internal(player, tags, event.element)
end)

---@param inspector LuaGuiElement
---@param node Node
---@param field ApiAttribute
local function boolean_editor(inspector, node, field)
  gui.create_elem(inspector, {
    type = "flow",
    direction = "horizontal",
    children = {
      {
        type = "label",
        caption = field.name,
        events = {on_boolean_editor_label_click},
        tooltip = field.description,
      },
      {
        type = "empty-widget",
        style_mods = {horizontally_stretchable = true},
      },
      {
        type = "checkbox",
        name = "checkbox",
        state = node.elem_data[field.name]--[[@as boolean]],
        tooltip = field.description,
        tags = {
          node_id = node.id,
          field_name = field.name,
        },
        events = {on_boolean_editor_state_changed},
      },
    },
  })
end

---@param player PlayerData
---@param tags any
---@param event EventData.on_gui_text_changed
local on_string_editor_state_changed = gui.register_handler(defines.events.on_gui_text_changed, "on_string_editor_state_changed", function(player, tags, event)
  local node = player.nodes_by_id[tags.node_id]
  local value = event.element.text
  ---@diagnostic disable-next-line: assign-type-mismatch
  node.elem[tags.field_name] = value
  ---@diagnostic disable-next-line: assign-type-mismatch
  node.elem_data[tags.field_name] = value
end)

---@param inspector LuaGuiElement
---@param node Node
---@param field ApiAttribute
local function string_editor(inspector, node, field)
  gui.create_elem(inspector, {
    type = "flow",
    direction = "horizontal",
    children = {
      {
        type = "label",
        caption = field.name,
        tooltip = field.description,
      },
      {
        type = "empty-widget",
        style_mods = {horizontally_stretchable = true},
      },
      {
        type = "textfield",
        text = node.elem_data[field.name]--[[@as string]],
        tooltip = field.description,
        tags = {
          node_id = node.id,
          field_name = field.name,
        },
        events = {on_string_editor_state_changed},
      },
    },
  })
end

---@param player PlayerData
local function update_inspector(player)
  local inspector = player.inspector_elem
  for _, child in pairs(inspector.children) do
    child.destroy()
  end
  local node = player.selected_node
  if not node then return end
  gui.create_elem(inspector, {
    type = "textfield",
    text = node.node_name,
    -- didn't do anything for some reason
    -- style_mods = {
    --   horizontally_stretchable = true,
    -- },
    events = {on_inspector_name_text_changed},
  })

  for _, field in pairs(util.fields_for_type[node.elem.type]) do
    if field.name == "auto_center" and node.parent then
      -- ignore auto_center for non root frames
      goto continue
    end
    if field.name == "direction" then
      direction_editor(inspector, node, field)
    end
    if field.read and field.write then
      if field.type == "boolean" then
        boolean_editor(inspector, node, field)
      end
      if field.type == "string" or field.type == "LocalisedString" then
        string_editor(inspector, node, field)
      end
    end
    ::continue::
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
