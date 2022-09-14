
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
  local dd_parent = tab
  if params.can_error or params.optional then
    dd_parent = gui.create_elem(tab, {
      type = "flow",
      direction = "horizontal",
      style_mods = {
        vertical_align = "center",
      },
    })
    if params.can_error then
      editor_util.create_error_sprite(dd_parent, editor_state)
    end
    if params.optional then
      editor_util.create_optional_switch(dd_parent, editor_state)
    end
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
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  get_mixed_display_value = get_mixed_display_value,
  values_equal = values_equal,
}
