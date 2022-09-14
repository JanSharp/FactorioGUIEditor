
local editor_util = require("__gui-editor__.editor_util")
local gui = require("__gui-editor__.gui")

local default_value = ""

---@param text string
---@return integer line_count
local function count_lines(text)
  local line_count = 1
  for _ in text:gmatch("\n") do
    line_count = line_count + 1
  end
  return line_count
end

---@param line_count integer
---@return integer pixels
local function calculate_text_box_height(line_count)
  return line_count * 20 + 8
end

---@param editor_state EditorState
local function update_string_editor(editor_state)
  local line_count = count_lines(editor_state.display_value or default_value)
  editor_state.wrap_elem.visible = line_count > 1
  editor_state.text_box_elem.style.height = calculate_text_box_height(line_count)
end

local on_text_changed = gui.register_handler(
  "on_string_editor_text_changed",
  ---@param event EventData.on_gui_text_changed
  function(player, tags, event)
    editor_util.on_editor_gui_event(player, tags)
    update_string_editor(editor_util.get_editor_state_from_tags(player, tags))
  end
)

---@param editor_state EditorState
local function create(editor_state)
  local params = editor_state.editor_params
  local tab = editor_util.create_table_without_spacing(params.parent_elem, 2)
  editor_util.create_editor_name_label(tab, editor_state)
  editor_state.wrap_elem = gui.create_elem(tab, {
    type = "empty-widget",
    visible = false,
  })
  local tb_parent = tab
  if params.can_error or params.optional then
    tb_parent = gui.create_elem(tab, {
      type = "flow",
      direction = "horizontal",
      style_mods = {
        vertical_align = "center",
      },
    })
    if params.can_error then
      editor_util.create_error_sprite(tb_parent, editor_state)
    end
    if params.optional then
      editor_util.create_optional_switch(tb_parent, editor_state)
    end
  end
  editor_state.text_box_elem = gui.create_elem(tb_parent, {
    type = "text-box",
    tooltip = params.description,
    elem_mods = {
      read_only = params.readonly,
    },
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
local function read_display_value_from_gui(editor_state)
  editor_state.display_value = editor_state.text_box_elem.text
end

---@param editor_state EditorState
local function write_display_value_to_gui(editor_state)
  editor_state.text_box_elem.text = editor_state.display_value or default_value
  update_string_editor(editor_state)
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
  editor_type = "string",
  create = create,
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  get_mixed_display_value = get_mixed_display_value,
  values_equal = values_equal,
}
