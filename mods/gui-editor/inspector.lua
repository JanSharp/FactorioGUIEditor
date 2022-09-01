
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local hierarchy = depends("__gui-editor__.hierarchy")
---@type ApiAttribute[]
local fields = require("__gui-editor__.fields")

-- numbers used to order these fields first in order
local fields_for_all_classes = {
  ["index"] = -8,
  ["type"] = -7,
  ["name"] = -6,
  ["visible"] = -5,
  ["enabled"] = -4,
  ["ignored_by_interaction"] = -3,
  ["tags"] = -2,
  ["tooltip"] = -1,
}

table.sort(fields, function(left, right)
  return (fields_for_all_classes[left.name] or left.order)
    < (fields_for_all_classes[right.name] or right.order)
end)

local fields_for_type = {}

for _, type in pairs(util.gui_elem_types) do
  fields_for_type[type] = {}
end

local hardcoded_subclasses = {
  caption = {
    "frame",
    "label",
    "button",
  },
  sprite = {
    "sprite-button",
    "sprite",
  },
  resize_to_sprite = { -- TODO: test because docs aren't clear if this is correct, at least for me
    "sprite-button",
    "sprite",
  },
  clicked_sprite = {
    "sprite-button",
  },
  selected_index = {
    "drop-down", -- NOTE: says `dropdown` in the description
    "list-box",
  },
  number = {
    "sprite-button",
  },
  show_percent_for_small_numbers = {
    "sprite-button",
  },
  position = {
    "camera",
    "minimap",
  },
  surface_index = {
    "camera",
    "minimap",
  },
  zoom = {
    "camera",
    "minimap",
  },
  force = {
    "minimap",
  },
  mouse_button_filter = {
    "button",
    "sprite-button",
  },
  entity = {
    "entity-preview",
    "camera",
    "minimap",
  },
}

local ignored_fields = util.invert{
  "gui",
  "parent",
  "children_names",
  "player_index",
  "children",
  "valid",
  "object_name",
}

for _, field in pairs(fields) do
  if fields_for_all_classes[field.name] then
    for _, fields_list in pairs(fields_for_type) do
      fields_list[#fields_list+1] = field
    end
    goto continue
  end

  if hardcoded_subclasses[field.name] or field.subclasses then
    for _, subclass in pairs(hardcoded_subclasses[field.name] or field.subclasses) do
      subclass = ({["CheckBox"] = "checkbox", ["RadioButton"] = "radiobutton"})[subclass] or subclass
      fields_for_type[subclass][#fields_for_type[subclass]+1] = field
    end
    goto continue
  end

  if ignored_fields[field.name] then
    goto continue
  end

  print("Unhandled field name: "..field.name)
  ::continue::
end

---@param player PlayerData
local on_inspector_name_text_changed = gui.register_handler(defines.events.on_gui_text_changed, "on_inspector_name_text_changed", function(player, _, event)
  player.selected_node.node_name = event.element.text
  player.selected_node.hierarchy_label.caption = hierarchy.get_hierarchy_label_caption(player, player.selected_node)
end)

---@param player PlayerData
---@param tags any
---@param checkbox_elem LuaGuiElement
local function on_boolean_editor_state_changed_internal(player, tags, checkbox_elem)
  ---@diagnostic disable-next-line: assign-type-mismatch
  player.nodes_by_id[tags.node_id].elem[tags.field_name] = checkbox_elem.state
end

---@param player PlayerData
---@param event EventData.on_gui_click
local on_boolean_editor_label_click = gui.register_handler(defines.events.on_gui_click, "on_boolean_editor_label_click", function(player, _, event)
  local checkbox_elem = event.element.parent.checkbox
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
        state = node.elem[field.name]--[[@as boolean]],
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
  ---@diagnostic disable-next-line: assign-type-mismatch
  player.nodes_by_id[tags.node_id].elem[tags.field_name] = event.element.text
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
        text = node.elem[field.name]--[[@as string]],
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

  for _, field in pairs(fields_for_type[node.elem.type]) do
    if node.elem.type and field.read and field.write then
      if field.type == "boolean" then
        boolean_editor(inspector, node, field)
      end
      if field.type == "string" or field.type == "LocalisedString" then
        string_editor(inspector, node, field)
      end
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
