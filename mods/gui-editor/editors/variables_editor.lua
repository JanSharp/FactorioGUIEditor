
local editor_util = require("__gui-editor__.editor_util")
local gui = require("__gui-editor__.gui")
local scripting = depends("__gui-editor__.scripting")
local script_text_box = require("__gui-editor__.script_text_box")

local default_value = ""

---@param editor_state EditorState
local function update_wrap_elem(editor_state)
  local value = editor_state.display_value
  editor_state.wrap_elem.visible = not not (value and value:find("\n", 1, true))
end

---@param editor_state EditorState
local function update_colored_code_elem(editor_state)
  local unnamed = editor_state.pre_compile_result or editor_state.editor_data.nodes_to_edit[1]
    .node_fields[editor_state.editor_params.name]--[[@as ScriptVariables]]
  script_text_box.set_ast(editor_state.stb_state, unnamed.ast, unnamed.error_code_instances)
end

local on_variables_editor_text_changed = gui.register_handler(
  "on_variables_editor_text_changed",
  ---@param event EventData.on_gui_text_changed
  function(player, tags, event)
    editor_util.on_editor_gui_event(player, tags)
    update_wrap_elem(editor_util.get_editor_state_from_tags(player, tags))
  end
)

---@param line_count integer
---@return integer pixels
local function calculate_text_box_height(line_count)
  return line_count * 20 + 8
end

---@param editor_state EditorState
local function create(editor_state)
  local params = editor_state.editor_params
  local tab = editor_util.create_table_without_spacing(params.parent_elem, 2)

  editor_util.create_editor_name_label(tab, editor_state)
  editor_state.wrap_elem = gui.create_elem(tab, {
    type = "empty-widget",
    visible = false,
  })
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
  editor_state.stb_state = script_text_box.create(editor_state.player, tb_parent, {
    tooltip = params.description,
    tags = editor_util.get_tags(editor_state),
    on_text_changed = on_variables_editor_text_changed,
    read_only = params.readonly,
    minimal_size = {width = 100, height = 28},
    maximal_size = {width = 2000, height = calculate_text_box_height(16) + 12},
  })
  editor_util.create_mixed_values_label(
    editor_state.stb_state.main_tb,
    editor_state,
    true
  )
  update_colored_code_elem(editor_state)
end

---@param editor_state EditorState
local function validate_display_value(editor_state)
  return true
end

---@param editor_state EditorState
local function pre_process_display_value(editor_state)
  editor_state.pre_compile_result = scripting.pre_compile(
    editor_state.display_value,
    "=("..editor_state.editor_params.name..")"
  )
  update_colored_code_elem(editor_state)
end

---@param editor_state EditorState
---@param value string
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
  editor_state.display_value = editor_state.stb_state.text
end

---@param editor_state EditorState
local function write_display_value_to_gui(editor_state)
  script_text_box.set_text(editor_state.stb_state, editor_state.display_value or default_value)
  update_wrap_elem(editor_state)
end

---@param editor_state EditorState
local function get_mixed_display_value(editor_state)
  return not editor_state.editor_params.optional and default_value or nil
end

---@param editor_state EditorState
---@param left string?
---@param right string?
local function values_equal(editor_state, left, right)
  return left == right
end

editor_util.add_editor{
  editor_type = "variables",
  create = create,
  validate_display_value = validate_display_value,
  pre_process_display_value = pre_process_display_value,
  value_to_display_value = value_to_display_value,
  display_value_to_value = display_value_to_value,
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  get_mixed_display_value = get_mixed_display_value,
  values_equal = values_equal,
}
