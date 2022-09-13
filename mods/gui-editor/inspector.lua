
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local hierarchy = depends("__gui-editor__.hierarchy")
local nodes = depends("__gui-editor__.nodes")
local editors = require("__gui-editor__.editors")

local type_mapping = {
  ["boolean"] = "boolean",
  ["string"] = "string",
  ["LocalisedString"] = "string",
  ["double"] = "number",
  ["uint"] = "number",
  ["int"] = "number",
}

---@param player PlayerData
---@param field Field
---@param editor_type EditorType
---@return EditorParams
local function get_base_params_for_field(player, field, editor_type)
  return {
    editor_type = editor_type,
    parent_elem = player.inspector_elem,
    window_name = "inspector",
    name = field.name,
    description = field.description,
    readonly = not field.write,
    optional = field.optional,
    can_error = true, -- TODO: flag the proper fields for potentially erroring
  }
end

---@param player PlayerData
---@param field Field
local function create_inspector_field_editor(player, field)
  local editor_type = type_mapping[field.type]
  if not editor_type then
    local params = get_base_params_for_field(player, field, "missing")
    params.missing_field = field
    editors.create_editor(player, params, {data_type = "missing"})
    return
  end

  local nodes_to_edit = {}
  for node in pairs(player.selected_nodes) do
    if bit32.band(node.type_flag, field.type_flags) ~= 0 then
      nodes_to_edit[#nodes_to_edit+1] = node
    end
  end

  if field.name == "direction" then
    local params = get_base_params_for_field(player, field, "drop_down")
    params.readonly = false
    params.can_error = false
    params.drop_down_items = {"horizontal", "vertical"}
    params.drop_down_values = {"horizontal", "vertical"}
    editors.create_editor(player, params, {
      data_type = "node_field",
      nodes_to_edit = nodes_to_edit,
      requires_rebuild = true,
    })
    return
  end

  if field.name == "column_count" then
    local params = get_base_params_for_field(player, field, "number")
    params.readonly = false
    params.can_error = false
    editors.create_editor(player, params, {
      data_type = "node_field",
      nodes_to_edit = nodes_to_edit,
      requires_rebuild = true,
    })
    return
  end

  editors.create_editor(player, get_base_params_for_field(player, field, editor_type), {
    data_type = "node_field",
    nodes_to_edit = nodes_to_edit,
    requires_rebuild = false,
  })
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

  player.active_editors = {}

  do
    local all_nodes = {}
    for node in pairs(player.selected_nodes) do
      all_nodes[#all_nodes+1] = node
    end
    editors.create_editor(player, {
      editor_type = "string",
      parent_elem = player.inspector_elem,
      window_name = "inspector",
      name = "node_name",
      description = nil,
      readonly = false,
      optional = false,
      can_error = false,
    }, {
      data_type = "node_name",
      nodes_to_edit = all_nodes,
      requires_rebuild = false,
    })
  end

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
