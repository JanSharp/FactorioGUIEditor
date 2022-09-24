
local gui = require("__gui-editor__.gui")

---@type table<string, Window>
local windows = {}

---@param window Window
local function register_window(window)
  if windows[window.window_type] then
    error("The window_type '"..window.window_type.."' already exists.")
  end
  windows[window.window_type] = window
end

---@param player PlayerData
---@param window_type string
local function create_window(player, window_type)
  local window = windows[window_type]
  local frame, inner = gui.create_elem(player.player.gui.screen, {
    type = "frame",
    direction = "vertical",
    style_mods = {
      width = window.initial_size.width,
      height = window.initial_size.height,
    },
    children = {
      {
        type = "flow",
        direction = "horizontal",
        name = "header_flow",
        children = {
          {
            type = "label",
            style = "frame_title",
            caption = window.title,
            ignored_by_interaction = true,
          },
          {
            type = "empty-widget",
            style = "draggable_space_header",
            ignored_by_interaction = true,
            style_mods = {
              height = 24,
              horizontally_stretchable = true,
              right_margin = 4,
            },
          },
          {
            type = "sprite-button",
            style = "frame_action_button",
            sprite = "utility/close_white",
            hovered_sprite = "utility/close_black",
            clicked_sprite = "utility/close_black",
          },
        },
      },
    },
  })
  ---@cast inner -nil
  inner.header_flow.drag_target = frame

  ---@type WindowState
  local window_state = {
    player = player,
    frame_elem = frame,
    header_elem = inner.header_flow,
  }

  local window_states = player.windows[window_type]
  if not window_states then
    window_states = {}
    player.windows[window_type] = window_states
  end
  window_states[#window_states+1] = window_state

  window.on_create(window_state)

  return window_state
end

return {
  register_window = register_window,
  create_window = create_window,
}
