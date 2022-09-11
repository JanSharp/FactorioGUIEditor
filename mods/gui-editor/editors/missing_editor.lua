
local editor_util = require("__gui-editor__.editor_util")
local gui = require("__gui-editor__.gui")

---@param editor_state EditorState
local function create(editor_state)
  local params = editor_state.editor_params
  params.readonly = false
  params.optional = false
  params.can_error = false
  local tab = editor_util.create_table_without_spacing(params.parent_elem, 2)
  editor_util.create_editor_name_label(tab, editor_state)
  local field = params.missing_field
  gui.create_elem(tab, {
    type = "label",
    caption = "[color=#cc0000]Missing editor for "
      ..(type(field.type) == "string" and field.type or "<complex_type> [img=info]")
      .."[/color]",
    tooltip = type(field.type) ~= "string" and serpent.block(field.type) or nil,
  })
  editor_state.mixed_values_label = {} -- dummy
end

---@param editor_state EditorState
local function read_display_value_from_gui(editor_state)
end

---@param editor_state EditorState
local function write_display_value_to_gui(editor_state)
end

---@param editor_state EditorState
local function get_mixed_display_value(editor_state)
end

editor_util.add_editor{
  editor_type = "missing",
  create = create,
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  get_mixed_display_value = get_mixed_display_value,
}
