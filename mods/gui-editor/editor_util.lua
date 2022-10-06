
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local nodes = depends("__gui-editor__.nodes")
local scripting = depends("__gui-editor__.scripting")
local window_manager = depends("__gui-editor__.window_manager")

---@type table<EditorType, Editor>
local editors = {}

---@param editor Editor
local function add_editor(editor)
  if editors[editor.editor_type] then
    error("The editor type '"..editor.editor_type.."' has already been added.")
  end
  editors[editor.editor_type] = editor
end

---@param editor_state EditorState
local function get_editor(editor_state)
  return editors[editor_state.editor_params.editor_type]
end

---@param editor_state EditorState
local function get_tags(editor_state)
  return {
    window_id = editor_state.editor_params.window_state.id,
    editor_name = editor_state.editor_params.name,
  }
end

---@param player PlayerData
---@param tags any
local function get_editor_state_from_tags(player, tags)
  local window_state = window_manager.get_window(player, tags.window_id)
  return window_state.active_editors[tags.editor_name]
end

---@param parent_elem LuaGuiElement
---@param column_count uint
local function create_table_without_spacing(parent_elem, column_count)
  return gui.create_elem(parent_elem, {
    type = "table",
    column_count = column_count,
    style_mods = {
      horizontal_spacing = 0,
    },
  })
end

---@param parent_elem LuaGuiElement
---@param editor_state EditorState
local function create_editor_name_label(parent_elem, editor_state)
  return gui.create_elem(parent_elem, {
    type = "label",
    caption = editor_state.editor_params.name,
    tooltip = editor_state.editor_params.description,
    style_mods = {
      minimal_width = 92,
      right_margin = 8,
    },
  })
end

---@param parent_elem LuaGuiElement
---@param editor_state EditorState
---@param use_black_font boolean?
local function create_mixed_values_label(parent_elem, editor_state, use_black_font)
  editor_state.mixed_values_label = gui.create_elem(parent_elem, {
    type = "label",
    caption = "<mixed>",
    ignored_by_interaction = true,
    style_mods = {
      font = "default-semibold",
      font_color = use_black_font and {0, 0, 0} or nil,
    },
  })
end

---@param parent_elem LuaGuiElement
---@param editor_state EditorState
local function create_error_sprite(parent_elem, editor_state)
  editor_state.error_sprite = gui.create_elem(parent_elem, {
    type = "sprite",
    sprite = "warning-white",
    visible = false,
  })
end

local get_editor_data_count_lut = {
  ---@param data EditorData
  ["missing"] = function(data)
    return 1
  end,
  ---@param data EditorData
  ["node_name"] = function(data)
    return #data.nodes_to_edit
  end,
  ---@param data EditorData
  ["node_static_variables"] = function(data)
    return #data.nodes_to_edit
  end,
  ---@param data EditorData
  ["node_field"] = function(data)
    return #data.nodes_to_edit
  end,
}

---@param editor_data EditorData
local function get_editor_data_count(editor_data)
  local get = get_editor_data_count_lut[editor_data.data_type]
  if not get then
    error("getting the total count of selected data for the data type '"
      ..editor_data.data_type.."' is not implemented."
    )
  end
  return get(editor_data)
end

---@param editor_state EditorState
local function update_error_sprite(editor_state)
  if editor_state.error_count ~= 0 then
    local data = editor_state.editor_data
    local node_count = get_editor_data_count(data)
    if node_count > 1 then
      local msg_parts = {}
      local index = 2
      for msg in pairs(editor_state.error_msgs) do
        msg_parts[index] = msg
        index = index + 1
      end
      local unique_error_count = index - 2
      msg_parts[1] = editor_state.error_count.."/"..node_count.." assignments had errors. "
        ..unique_error_count.." unique error message"..(unique_error_count > 1 and "s:" or ":")
      editor_state.display_error_msg = table.concat(msg_parts, "\n\n")
    else
      editor_state.display_error_msg = next(editor_state.error_msgs)
    end
  else
    editor_state.display_error_msg = nil
  end
  editor_state.error_sprite.visible = editor_state.error_count ~= 0
  editor_state.error_sprite.tooltip = editor_state.display_error_msg
end

---@param editor_state EditorState
---@param error_msg string
local function add_error_msg(editor_state, error_msg)
  editor_state.error_count = editor_state.error_count + 1
  editor_state.error_msgs[error_msg] = (editor_state.error_msgs[error_msg] or 0) + 1
end

---@param editor_state EditorState
---@param error_msg string
local function remove_error_msg(editor_state, error_msg)
  editor_state.error_count = editor_state.error_count - 1
  local count = editor_state.error_msgs[error_msg] - 1
  editor_state.error_msgs[error_msg] = count ~= 0 and count or nil
end

---@param editor_state EditorState
---@param node_field NodeField
---@param error_msg string?
local function set_node_field_error_msg(editor_state, node_field, error_msg)
  local prev_error_msg = node_field.error_msg
  if error_msg == prev_error_msg then return end
  if prev_error_msg then
    remove_error_msg(editor_state, prev_error_msg)
  end
  if error_msg then
    add_error_msg(editor_state, error_msg)
  end
  node_field.error_msg = error_msg
end

---@param editor_state EditorState
local function read_node_fields(editor_state)
  local editor = get_editor(editor_state)
  local field_name = editor_state.editor_params.name
  local display_value
  local not_first
  local mixed = false

  for _, node in pairs(editor_state.editor_data.nodes_to_edit) do
    local node_field = node.node_fields[field_name]
    if node_field.error_msg then
      add_error_msg(editor_state, node_field.error_msg)
    end

    if not node_field.initialized_display_value then
      node_field.initialized_display_value = true
      node_field.display_value = editor.value_to_display_value(editor_state, node_field.value)
    end

    if not mixed then
      if not_first then
        if not editor.values_equal(editor_state, node_field.display_value, display_value) then
          display_value = editor.get_mixed_display_value(editor_state)
          mixed = true
        end
      else
        display_value = node_field.display_value
        not_first = true
      end
    end
  end

  editor_state.display_value = display_value
  editor_state.mixed_values = mixed
  update_error_sprite(editor_state)
end

local read_editor_data_lut = {
  ---@param editor_state EditorState
  ["missing"] = function(editor_state)
    editor_state.display_value = nil
    editor_state.mixed_values = false
  end,
  ---@param editor_state EditorState
  ["node_name"] = function(editor_state)
    read_node_fields(editor_state)
  end,
  ---@param editor_state EditorState
  ["node_static_variables"] = function(editor_state)
    read_node_fields(editor_state)
  end,
  ---@param editor_state EditorState
  ["node_field"] = function(editor_state)
    read_node_fields(editor_state)
  end,
}

---@param editor_state EditorState
local function read_editor_data(editor_state)
  local data_type = editor_state.editor_data.data_type
  local read = read_editor_data_lut[data_type]
  if not read then
    error("Not implemented '"..data_type.."' data type reader.")
  end
  read(editor_state)
end

---@param editor_state EditorState
---@param set_value fun(node: Node, value: any)
local function write_node_fields(editor_state, set_value)
  local field_name = editor_state.editor_params.name
  local display_value = editor_state.display_value
  local value = editor_state.valid_display_value
    and get_editor(editor_state).display_value_to_value(editor_state, display_value)
  for _, node in pairs(editor_state.editor_data.nodes_to_edit) do
    local node_field = node.node_fields[field_name]
    node_field.display_value = display_value
    if editor_state.valid_display_value then
      set_node_field_error_msg(editor_state, node_field, nil)
      set_value(node, value)
    else
      set_node_field_error_msg(editor_state, node_field, editor_state.validation_error_msg)
    end
  end
  update_error_sprite(editor_state)
end

local write_editor_data_lut = {
  ---@param editor_state EditorState
  ["missing"] = function(editor_state)
    -- do nothing
  end,
  ---@param editor_state EditorState
  ["node_name"] = function(editor_state)
    write_node_fields(editor_state, function(node, value)
      node.node_name = value
      node.node_fields.node_name.value = value
      node.hierarchy_button.caption = value
    end)
  end,
  ---@param editor_state EditorState
  ["node_static_variables"] = function(editor_state)
    write_node_fields(editor_state, function(node, value)
      local success, msg = scripting.compile_variables(
        editor_state.player,
        node.static_variables,
        editor_state.pre_compile_result
      )
      -- msg is either nil or an error_msg, which is prefect for this function call
      set_node_field_error_msg(editor_state, node.static_variables, msg)
    end)
  end,
  ---@param editor_state EditorState
  ["node_field"] = function(editor_state)
    local field_name = editor_state.editor_params.name
    local can_error = editor_state.editor_params.can_error
    local requires_rebuild = editor_state.editor_data.requires_rebuild
    write_node_fields(editor_state, function(node, value)
      local node_field = node.node_fields[field_name]
      if requires_rebuild then
        if can_error then
          error("A field that 'can_error' and 'requires_rebuild' is not supported.")
        end
        node_field.value = value
        nodes.rebuild_elem(node)
      else
        if can_error then
          local success, msg = xpcall(function()
            node.elem[field_name] = value
          end, function(msg)
            return msg
          end)--[[@as string?]]
          if success then
            node_field.value = value
          else
            -- not setting `node_field.value` to keep its old value
            set_node_field_error_msg(editor_state, node_field, msg or "No error message.")
          end
        else
          node_field.value = value
          node.elem[field_name] = value
        end
      end
    end)
  end,
}

---@param editor_state EditorState
local function write_editor_data(editor_state)
  local data_type = editor_state.editor_data.data_type
  local write = write_editor_data_lut[data_type]
  if not write then
    error("Not implemented '"..data_type.."' data type writer.")
  end
  write(editor_state)
end

---@param editor_state EditorState
local function read_display_value_from_gui(editor_state)
  if editor_state.editor_params.optional
    and editor_state.optional_switch.switch_state == "left"
  then
    editor_state.display_value = nil
    return
  end
  get_editor(editor_state).read_display_value_from_gui(editor_state)
end

---@param editor_state EditorState
local function set_optional_switch_state_based_on_display_value(editor_state)
  if editor_state.editor_params.optional then
    local optional_switch = editor_state.optional_switch
    optional_switch.switch_state = editor_state.display_value == nil and "left" or "right"
    optional_switch.allow_none_state = editor_state.mixed_values
    if editor_state.mixed_values then
      optional_switch.switch_state = "none"
    end
  end
end

---@param editor_state EditorState
local function write_display_value_to_gui(editor_state)
  editor_state.mixed_values_label.visible = editor_state.mixed_values
  set_optional_switch_state_based_on_display_value(editor_state)
  get_editor(editor_state).write_display_value_to_gui(editor_state)
end

---@param editor_state EditorState
local function validate_display_value(editor_state)
  local success, error_msg = get_editor(editor_state).validate_display_value(editor_state)
  if success then
    if not editor_state.valid_display_value then
      editor_state.valid_display_value = true
      editor_state.validation_error_msg = nil
      update_error_sprite(editor_state)
    end
  else
    editor_state.valid_display_value = false
    error_msg = "Invalid input: "..(error_msg or "No error message.")
    if error_msg ~= editor_state.validation_error_msg then
      editor_state.validation_error_msg = error_msg
      update_error_sprite(editor_state)
    end
  end
end

---@param editor_state EditorState
local function on_editor_gui_event_internal(editor_state)
  read_display_value_from_gui(editor_state)
  validate_display_value(editor_state)
  local editor = editors[editor_state.editor_params.editor_type]
  if editor.pre_process_display_value then
    editor.pre_process_display_value(editor_state)
  end
  write_editor_data(editor_state)
  editor_state.mixed_values_label.visible = false
end

---@param player PlayerData
---@param tags any
local function on_editor_gui_event(player, tags)
  local editor_state = get_editor_state_from_tags(player, tags)
  editor_state.mixed_values = false
  if editor_state.editor_params.optional then
    editor_state.optional_switch.switch_state = "right"
    editor_state.optional_switch.allow_none_state = false
  end
  on_editor_gui_event_internal(editor_state)
end

local on_optional_switch_state_changed = gui.register_handler(
  "on_optional_switch_state_changed",
  ---@param event EventData.on_gui_switch_state_changed
  function(player, tags, event)
    local editor_state = get_editor_state_from_tags(player, tags)
    -- ultimately `read_display_value_from_gui` may set `display_value` to `nil` ...
    on_editor_gui_event_internal(editor_state)
    -- ... so here we're updating the gui to match the `display_value`
    get_editor(editor_state).write_display_value_to_gui(editor_state)
    if editor_state.mixed_values and editor_state.editor_params.optional then
      editor_state.mixed_values = false
      if editor_state.optional_switch.switch_state == "none" then
        editor_state.optional_switch.switch_state = "left"
      end
      editor_state.optional_switch.allow_none_state = false
    end
  end
)

---@param parent_elem LuaGuiElement
---@param editor_state EditorState
local function create_optional_switch(parent_elem, editor_state)
  editor_state.optional_switch = gui.create_elem(parent_elem, {
    type = "switch",
    left_label_caption = "nil",
    tags = get_tags(editor_state),
    events = {[defines.events.on_gui_switch_state_changed] = on_optional_switch_state_changed},
  })
end

---@class __gui-editor__.editor_util
return {
  editors = editors,
  add_editor = add_editor,
  get_editor = get_editor,
  get_tags = get_tags,
  get_editor_state_from_tags = get_editor_state_from_tags,
  create_table_without_spacing = create_table_without_spacing,
  create_editor_name_label = create_editor_name_label,
  create_mixed_values_label = create_mixed_values_label,
  create_error_sprite = create_error_sprite,
  create_optional_switch = create_optional_switch,
  read_editor_data = read_editor_data,
  write_editor_data = write_editor_data,
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  on_editor_gui_event = on_editor_gui_event,
}
