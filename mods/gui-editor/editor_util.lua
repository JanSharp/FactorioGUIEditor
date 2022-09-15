
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local nodes = depends("__gui-editor__.nodes")

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
    window_name = editor_state.editor_params.window_name,
    editor_name = editor_state.editor_params.name,
  }
end

---@param player PlayerData
---@param tags any
local function get_editor_state_from_tags(player, tags)
  return player.active_editors[tags.window_name][tags.editor_name]
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

---@param editor_state EditorState
local function update_error_sprite(editor_state)
  if not editor_state.editor_params.can_error then
    if editor_state.error_count ~= 0 then
      error("Created an editor with 'can_error' set to false while the current state for the data \z
        said editor is editing has errors."
      )
    end
    return
  end

  if editor_state.error_count ~= 0 then
    local data = editor_state.editor_data
    local node_count
    if data.data_type == "node_name" or data.data_type == "node_field" then
      node_count = #data.nodes_to_edit
    else
      error("getting the total count of selected data for the data type '"..data.data_type.."' is \z
        not implemented."
      )
    end

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
local function add_error_state(editor_state, error_msg)
  editor_state.error_count = editor_state.error_count + 1
  editor_state.error_msgs[error_msg] = (editor_state.error_msgs[error_msg] or 0) + 1
end

---@param editor_state EditorState
---@param error_msg string
local function remove_error_state(editor_state, error_msg)
  editor_state.error_count = editor_state.error_count - 1
  local count = editor_state.error_msgs[error_msg] - 1
  editor_state.error_msgs[error_msg] = count ~= 0 and count or nil
end

---@param editor_state EditorState
---@param node Node
---@param field_name string
---@param error_msg string?
local function set_single_error_state(editor_state, node, field_name, error_msg)
  local node_field = node.node_fields[field_name]
  local prev_error_msg = node_field.error_msg
  if error_msg == prev_error_msg then return end
  if prev_error_msg then
    remove_error_state(editor_state, prev_error_msg)
  end
  if error_msg then
    add_error_state(editor_state, error_msg)
  end
  node_field.error_msg = error_msg
end

-- ---This generally indicates that there is something similar to an input validation error
-- ---for this editor. However it will still save this invalid state
-- ---@param editor_state EditorState
-- ---@param error_state ErrorState?
-- local function set_error_state(editor_state, error_state)
--   local data = editor_state.editor_data

--   if data.data_type == "missing" then
--     error("Attempt to set_error_state for an editor which is editing missing data. \z
--       This makes no sense."
--     )
--   end

--   if data.data_type == "node_name" or data.data_type == "node_field" then
--     local field_name = editor_state.editor_params.name
--     for _, node in pairs(data.nodes_to_edit) do
--       set_single_error_state(editor_state, node, field_name, error_state)
--     end
--     update_error_sprite(editor_state)
--     return
--   end

--   error("Not implemented set_error_state for data type '"..data.data_type.."'.")
-- end

---@param editor_state EditorState
local function read_editor_data(editor_state)
  local data = editor_state.editor_data
  local editor = get_editor(editor_state)

  if data.data_type == "missing" then
    editor_state.display_value = nil
    editor_state.mixed_values = false
    return
  end

  if data.data_type == "node_name" or data.data_type == "node_field" then
    local field_name = editor_state.editor_params.name
    local value
    local not_first
    local mixed = false

    for _, node in pairs(data.nodes_to_edit) do
      local node_field = node.node_fields[field_name]
      if node_field.error_msg then
        add_error_state(editor_state, node_field.error_msg)
      end

      if not mixed then
        if not_first then
          if not editor.values_equal(editor_state, node_field.display_value, value) then
            value = editor.get_mixed_display_value(editor_state)
            mixed = true
          end
        else
          value = node_field.display_value
          not_first = true
        end
      end
    end

    editor_state.display_value = value
    editor_state.mixed_values = mixed
    update_error_sprite(editor_state)

    return
  end

  error("Not implemented '"..data.data_type.."' data type reader.")
end

---@param editor_state EditorState
local function write_editor_data(editor_state)
  local data = editor_state.editor_data
  if data.data_type == "missing" then return end

  if data.data_type == "node_name" or data.data_type == "node_field" then
    local set_value
    local can_error = editor_state.editor_params.can_error
    if data.data_type == "node_name" then
      if can_error then
        error("Setting 'node_name' cannot error but the 'can_error' flag is set.")
      end
      ---@param node Node
      ---@param value any
      function set_value(node, value)
        -- TODO: support error states
        node.node_name = value
        local node_field = node.node_fields.node_name
        node_field.value = value
        node_field.display_value = value
        node.hierarchy_button.caption = value
      end
    else
      local field_name = editor_state.editor_params.name
      ---@param node Node
      ---@param value any
      function set_value(node, value)
        local node_field = node.node_fields[field_name]
        node_field.display_value = value
        if data.requires_rebuild then
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
              set_single_error_state(editor_state, node, field_name, nil)
            else
              -- not setting `node_field.value` to keep it the same
              set_single_error_state(editor_state, node, field_name, msg or "No error message.")
            end
          else
            node_field.value = value
            node.elem[field_name] = value
          end
        end
      end
    end

    for _, node in pairs(data.nodes_to_edit) do
      set_value(node, editor_state.display_value)
    end

    update_error_sprite(editor_state)
    return
  end
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
local function on_editor_gui_event_internal(editor_state)
  read_display_value_from_gui(editor_state)
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
  -- set_error_state = set_error_state,
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  on_editor_gui_event = on_editor_gui_event,
}
