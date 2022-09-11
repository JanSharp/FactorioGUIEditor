
local editor_util = require("__gui-editor__.editor_util")
local gui = require("__gui-editor__.gui")

local default_value = false

local on_state_changed = gui.register_handler(
  "on_boolean_editor_state_changed",
  ---@param event EventData.on_gui_checked_state_changed
  function(player, tags, event)
    editor_util.on_editor_gui_event(player, tags)
  end
)

---@param editor_state EditorState
local function create(editor_state)
  local params = editor_state.editor_params
  local tab = editor_util.create_table_without_spacing(params.parent_elem, 3)
  editor_util.create_editor_name_label(tab, editor_state)
  local cb_parent = tab
  if params.can_error or params.optional then
    cb_parent = gui.create_elem(tab, {
      type = "flow",
      direction = "horizontal",
      style_mods = {
        vertical_align = "center",
      },
    })
    if params.can_error then
      editor_util.create_error_sprite(cb_parent, editor_state)
    end
    if params.optional then
      editor_util.create_optional_switch(cb_parent, editor_state)
    end
  end
  editor_state.check_box_elem = gui.create_elem(cb_parent, {
    type = "checkbox",
    state = default_value,
    tooltip = params.description,
    enabled = not params.readonly,
    tags = editor_util.get_tags(editor_state),
    events = {[defines.events.on_gui_checked_state_changed] = on_state_changed},
  })
  editor_util.create_mixed_values_label(tab, editor_state, false)
end

---@param editor_state EditorState
local function read_display_value_from_gui(editor_state)
  editor_state.display_value = editor_state.check_box_elem.state
end

---@param editor_state EditorState
local function write_display_value_to_gui(editor_state)
  editor_state.check_box_elem.state = editor_state.display_value or default_value
end

---@param editor_state EditorState
local function get_mixed_display_value(editor_state)
  if editor_state.editor_params.optional then
    return nil
  else
    return default_value
  end
end

editor_util.add_editor{
  editor_type = "boolean",
  create = create,
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  get_mixed_display_value = get_mixed_display_value,
}
