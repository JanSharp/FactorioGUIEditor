
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local hierarchy = depends("__gui-editor__.hierarchy")
local nodes = depends("__gui-editor__.nodes")
local editors = require("__gui-editor__.editors")
local window_manager = require("__gui-editor__.window_manager")

local type_mapping = {
  ["boolean"] = "boolean",
  ["string"] = "string",
  ["LocalisedString"] = "string",
  ["double"] = "number",
  ["uint"] = "number",
  ["int"] = "number",
}

---@param window_state WindowState
---@param field Field
---@param editor_type EditorType
---@return EditorParams
local function get_base_params_for_field(window_state, field, editor_type)
  return {
    editor_type = editor_type,
    parent_elem = window_state.inspector_elem,
    window_state = window_state,
    name = field.name,
    description = field.description,
    readonly = not field.write,
    optional = field.optional,
    can_error = true, -- TODO: flag the proper fields for potentially erroring
  }
end

---@param window_state WindowState
---@param field Field
local function create_inspector_field_editor(window_state, field)
  local player = window_state.player
  local editor_type = type_mapping[field.type]
  if not editor_type then
    local params = get_base_params_for_field(window_state, field, "missing")
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
    local params = get_base_params_for_field(window_state, field, "drop_down")
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
    local params = get_base_params_for_field(window_state, field, "number")
    params.readonly = false
    params.can_error = false
    editors.create_editor(player, params, {
      data_type = "node_field",
      nodes_to_edit = nodes_to_edit,
      requires_rebuild = true,
    })
    return
  end

  editors.create_editor(player, get_base_params_for_field(window_state, field, editor_type), {
    data_type = "node_field",
    nodes_to_edit = nodes_to_edit,
    requires_rebuild = false,
  })
end

---@param player PlayerData
local function cleanup_stb_states(player)
  -- NOTE: stb_states_by_id cleanup can and should be implemented in a cleaner way
  local stb_states_by_id = player.stb_states_by_id
  for id, stb_state in pairs(stb_states_by_id) do
    if not stb_state.flow.valid then
      -- last instruction in the loop
      stb_states_by_id[id] = nil
    end
  end
end

---@param window_state WindowState
local function update_inspector(window_state)
  local player = window_state.player
  for _, child in pairs(window_state.inspector_elem.children) do
    child.destroy()
  end
  cleanup_stb_states(player)
  if not next(player.selected_nodes) then return end

  local selected_flags = 0
  local any_are_root = false
  for selected_node in pairs(player.selected_nodes) do
    selected_flags = bit32.bor(selected_flags, selected_node.type_flag)
    if nodes.is_root(selected_node) then
      any_are_root = true
    end
  end

  window_state.active_editors = {}

  do
    local all_nodes = {}
    for node in pairs(player.selected_nodes) do
      all_nodes[#all_nodes+1] = node
    end

    editors.create_editor(player, {
      editor_type = "string",
      parent_elem = window_state.inspector_elem,
      window_state = window_state,
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

    editors.create_editor(player, {
      editor_type = "variables",
      parent_elem = window_state.inspector_elem,
      window_state = window_state,
      name = "static_variables",
      description = nil,
      readonly = false,
      optional = false,
      can_error = false,
    }, {
      data_type = "node_static_variables",
      nodes_to_edit = all_nodes,
    })
  end

  gui.create_elem(window_state.inspector_elem, {
    type = "line",
    style_mods = {
      top_margin = 4,
      bottom_margin = 4,
    },
  })

  for _, field in pairs(util.all_used_fields) do
    if bit32.band(field.type_flags, selected_flags) ~= 0
      and (field.name ~= "auto_center" or any_are_root)
    then
      -- only create an editor if the field is used by any selected node
      -- and only create an editor for auto_center if any selected node is a root node
      create_inspector_field_editor(window_state, field)
    end
  end
end

---@param player PlayerData
local function update_inspectors(player)
  for _, window_state in pairs(window_manager.get_windows(player, "inspector")) do
    update_inspector(window_state)
  end
end

window_manager.register_window{
  window_type = "inspector",
  title = "Inspector",
  initial_size = {width = 300, height = 500},
  minimal_size = {width = 100, height = 100},

  ---@param window_state WindowState
  on_create = function(window_state)
    local _, inspector_inner = gui.create_elem(window_state.frame_elem, {
      type = "frame",
      direction = "vertical",
      style = "inside_shallow_frame",
      style_mods = {
        horizontally_stretchable = true,
        vertically_stretchable = true,
      },
      children = {
        {
          type = "scroll-pane",
          style_mods = {
            horizontally_stretchable = true,
            vertically_stretchable = true,
            padding = 4,
          },
          children = {
            {
              type = "flow",
              direction = "vertical",
              name = "inspector",
            },
          },
        },
      },
    })
    window_state.inspector_elem = inspector_inner.inspector
    -- doesn't need to be initialized because the function that creates editors for the inspector
    -- sets active_editors to `{}`
    -- window_state.active_editors = {}
  end,

  ---@param window_state WindowState
  on_close = function(window_state)
    cleanup_stb_states(window_state.player)
  end,
}

---@param player PlayerData
local function create_inspector(player)
  window_manager.create_window(player, "inspector")
end

---@class __gui-editor__.inspector
return {
  update_inspectors = update_inspectors,
  create_inspector = create_inspector,
}
