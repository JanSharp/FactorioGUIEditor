
local editor_util = require("__gui-editor__.editor_util")
local gui = require("__gui-editor__.gui")

local on_selection_state_changed = gui.register_handler(
  "on_drop_down_editor_selection_state_changed",
  ---@param event EventData.on_gui_selection_state_changed
  function(player, tags, event)
    editor_util.on_editor_gui_event(player, tags)
  end
)

---@param editor_state EditorState
local function create(editor_state)
  local params = editor_state.editor_params
  local tab = editor_util.create_table_without_spacing(params.parent_elem, 2)
  editor_util.create_editor_name_label(tab, editor_state)
  local dd_parent = gui.create_elem(tab, {
    type = "flow",
    direction = "horizontal",
    style_mods = {
      vertical_align = "center",
    },
  })
  editor_util.create_error_sprite(dd_parent, editor_state)
  if params.optional then
    editor_util.create_optional_switch(dd_parent, editor_state)
  end
  editor_state.drop_down_elem = gui.create_elem(dd_parent, {
    type = "drop-down",
    items = params.drop_down_items,
    tooltip = params.description,
    enabled = not params.readonly,
    tags = editor_util.get_tags(editor_state),
    events = {[defines.events.on_gui_selection_state_changed] = on_selection_state_changed},
  })
  editor_util.create_mixed_values_label(editor_state.drop_down_elem, editor_state, true)
end

---@param editor_state EditorState
local function validate_display_value(editor_state)
  return true
end

-- TODO: impl display_value being the selected_index, not the actual value

---@param editor_state EditorState
---@param value any
local function value_to_display_value(editor_state, value)
  return value
end

---@param editor_state EditorState
---@param display_value string
local function display_value_to_value(editor_state, display_value)
  return display_value
end

---@param editor_state EditorState
local function read_display_value_from_gui(editor_state)
  editor_state.display_value
    = editor_state.editor_params.drop_down_values[editor_state.drop_down_elem.selected_index]
end

---@param editor_state EditorState
local function write_display_value_to_gui(editor_state)
  local index
  for i, value in pairs(editor_state.editor_params.drop_down_values) do
    if editor_state.display_value == value then
      index = i
      break
    end
  end
  editor_state.drop_down_elem.selected_index = index or 0
end

---@param editor_state EditorState
local function get_mixed_display_value(editor_state)
  do return nil end
  if editor_state.editor_params.optional then
    return nil
  else
    return editor_state.editor_params.drop_down_values[1]
  end
end

---@param editor_state EditorState
---@param left string?
---@param right string?
local function values_equal(editor_state, left, right)
  return left == right
end

editor_util.add_editor{
  editor_type = "drop_down",
  create = create,
  validate_display_value = validate_display_value,
  value_to_display_value = value_to_display_value,
  display_value_to_value = display_value_to_value,
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  get_mixed_display_value = get_mixed_display_value,
  values_equal = values_equal,
}
