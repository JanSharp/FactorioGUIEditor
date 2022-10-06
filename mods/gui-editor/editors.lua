
local editor_util = require("__gui-editor__.editor_util")
require("__gui-editor__.editors.missing_editor")
require("__gui-editor__.editors.boolean_editor")
require("__gui-editor__.editors.drop_down_editor")
require("__gui-editor__.editors.number_editor")
require("__gui-editor__.editors.string_editor")
require("__gui-editor__.editors.variables_editor")

---@param player PlayerData
---@param editor_params EditorParams
---@param editor_data EditorData
local function create_editor(player, editor_params, editor_data)
  ---@type EditorState
  local editor_state = {
    player = player,
    editor_params = editor_params,
    editor_data = editor_data,
    valid_display_value = true,
    error_count = 0,
    error_msgs = {},
  }

  editor_params.window_state.active_editors[editor_params.name] = editor_state

  local editor = editor_util.editors[editor_params.editor_type]
  editor.create(editor_state)
  editor_util.read_editor_data(editor_state)
  editor_util.write_display_value_to_gui(editor_state)
end

return {
  create_editor = create_editor,
}
