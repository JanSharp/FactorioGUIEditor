
---@type Field[]
local fields = require("__gui-editor__.fields")

local gui_elem_types = {
  "button",
  "camera",
  "checkbox",
  "choose-elem-button",
  "drop-down",
  "empty-widget",
  "entity-preview",
  "flow",
  "frame",
  "label",
  "line",
  "list-box",
  "minimap",
  "progressbar",
  "radiobutton",
  "scroll-pane",
  "slider",
  "sprite-button",
  "sprite",
  "switch",
  "tab",
  "tabbed-pane",
  "table",
  "text-box",
  "textfield",
}

---@return PlayerData
local function get_player(event)
  return global.players[event.player_index]
end

---@generic T
---@param tab T[]
---@return table<T, true>
local function invert(tab)
  local lut = {}
  for _, value in pairs(tab) do
    lut[value] = true
  end
  return lut
end

---@generic T
---@param t T
---@return T
local function clear_table(t)
  for k in pairs(t) do
    -- removing while iterating, living life on the edge.
    -- but since nothing happens after the removal and I'm
    -- never going to step through this with the debugger,
    -- there won't be any incremental GC between the assignment
    -- of nil and the next `next` call
    t[k] = nil
  end
  return t
end

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

---@type table<string, Field[]>
local fields_for_type = {}

for _, type in pairs(gui_elem_types) do
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
  resize_to_sprite = {
    "sprite", -- NOTE: maybe clarify that this is only for sprites and not sprite-buttons in the docs
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

local ignored_fields = invert{
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
      -- NOTE: fix docs for these 2
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

---@class __gui-editor__.util
return {
  gui_elem_types = gui_elem_types,
  fields_for_type = fields_for_type,
  get_player = get_player,
  invert = invert,
  clear_table = clear_table,
}
