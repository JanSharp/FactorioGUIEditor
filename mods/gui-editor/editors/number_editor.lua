
local editor_util = require("__gui-editor__.editor_util")
local gui = require("__gui-editor__.gui")

local on_text_changed = gui.register_handler(
  "on_number_editor_text_changed",
  ---@param event EventData.on_gui_text_changed
  function(player, tags, event)
    editor_util.on_editor_gui_event(player, tags)
  end
)

---@param editor_state EditorState
local function create(editor_state)
  local params = editor_state.editor_params
  local tab = editor_util.create_table_without_spacing(params.parent_elem, 2)
  editor_util.create_editor_name_label(tab, editor_state)
  local tb_parent = gui.create_elem(tab, {
    type = "flow",
    direction = "horizontal",
    style_mods = {
      vertical_align = "center",
    },
  })
  editor_util.create_error_sprite(tb_parent, editor_state)
  if params.optional then
    editor_util.create_optional_switch(tb_parent, editor_state)
  end
  editor_state.text_box_elem = gui.create_elem(tb_parent, {
    type = "textfield",
    tooltip = params.description,
    enabled = not params.readonly,
    style_mods = {
      width = 0,
      horizontally_stretchable = true,
    },
    tags = editor_util.get_tags(editor_state),
    events = {[defines.events.on_gui_text_changed] = on_text_changed},
  })
  editor_util.create_mixed_values_label(editor_state.text_box_elem, editor_state, true)
end

---@param editor_state EditorState
local function validate_display_value(editor_state)
  if tonumber(editor_state.display_value) then
    return true
  end
  return false, "'"..editor_state.display_value.."' is not a number."
end

---@param editor_state EditorState
---@param value number
local function value_to_display_value(editor_state, value)
  return tostring(value)
end

---@param editor_state EditorState
---@param display_value string
local function display_value_to_value(editor_state, display_value)
  return tonumber(display_value)
end

---@param editor_state EditorState
local function read_display_value_from_gui(editor_state)
  editor_state.display_value = editor_state.text_box_elem.text
end

---@param editor_state EditorState
local function write_display_value_to_gui(editor_state)
  editor_state.text_box_elem.text = editor_state.display_value
end

---@param editor_state EditorState
local function get_mixed_display_value(editor_state)
  return ""
end

---@param editor_state EditorState
---@param left number?
---@param right number?
local function values_equal(editor_state, left, right)
  return left == right
end

editor_util.add_editor{
  editor_type = "number",
  create = create,
  validate_display_value = validate_display_value,
  value_to_display_value = value_to_display_value,
  display_value_to_value = display_value_to_value,
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  get_mixed_display_value = get_mixed_display_value,
  values_equal = values_equal,
}
