
local editor_util = require("__gui-editor__.editor_util")
require("__gui-editor__.editors.missing_editor")
require("__gui-editor__.editors.boolean_editor")
require("__gui-editor__.editors.drop_down_editor")
require("__gui-editor__.editors.string_editor")

---@param player PlayerData
---@param editor_params EditorParams
---@param editor_data EditorData
local function create_editor(player, editor_params, editor_data)
  local editor_state = {
    player = player,
    editor_params = editor_params,
    editor_data = editor_data,
  }

  local active_editors = player.active_editors[editor_params.window_name]
  if not active_editors then
    active_editors = {}
    player.active_editors[editor_params.window_name] = active_editors
  end
  active_editors[editor_params.name] = editor_state

  local editor = editor_util.editors[editor_params.editor_type]
  editor.create(editor_state)
  editor_util.read_editor_data(editor_state)
  editor_util.write_display_value_to_gui(editor_state)
end

return {
  create_editor = create_editor,
}
