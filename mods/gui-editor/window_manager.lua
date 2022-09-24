
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

---@param window_state WindowState
local function snap_resize_frames(window_state)
  local location = window_state.frame_elem.location
  ---@cast location -nil
  local size = window_state.size

  window_state.top_left_resize_frame.location = {
    x = location.x - 10,
    y = location.y - 10,
  }
  window_state.top_right_resize_frame.location = {
    x = location.x + size.width - 10,
    y = location.y - 10,
  }
  window_state.bottom_left_resize_frame.location = {
    x = location.x - 10,
    y = location.y + size.height - 10,
  }
  window_state.bottom_right_resize_frame.location = {
    x = location.x + size.width - 10,
    y = location.y + size.height - 10,
  }

  window_state.top_resize_frame.location = {
    x = location.x + 10,
    y = location.y - 10,
  }
  window_state.top_resize_frame.style.width = size.width - 20

  window_state.left_resize_frame.location = {
    x = location.x - 10,
    y = location.y + 10,
  }
  window_state.left_resize_frame.style.height = size.height - 20

  window_state.bottom_resize_frame.location = {
    x = location.x + 10,
    y = location.y + size.height - 10,
  }
  window_state.bottom_resize_frame.style.width = size.width - 20

  window_state.right_resize_frame.location = {
    x = location.x + size.width - 10,
    y = location.y + 10,
  }
  window_state.right_resize_frame.style.height = size.height - 20
end

local on_resize_frame_location_changed = gui.register_handler(
  "on_resize_frame_location_changed",
  ---@param player PlayerData
  ---@param tags any
  ---@param event EventData.on_gui_location_changed
  function(player, tags, event)
    local window_state = player.windows_by_id[tags.window_id]
    if tags.right then
      window_state.size.width = event.element.location.x + 10 - window_state.frame_elem.location.x
      window_state.frame_elem.style.width = window_state.size.width
    elseif tags.left then
      window_state.size.width = window_state.frame_elem.location.x + window_state.size.width - (event.element.location.x + 10)
      window_state.frame_elem.style.width = window_state.size.width
      window_state.frame_elem.location = {
        x = event.element.location.x + 10,
        y = window_state.frame_elem.location.y,
      }
    end
    if tags.bottom then
      window_state.size.height = event.element.location.y + 10 - window_state.frame_elem.location.y
      window_state.frame_elem.style.height = window_state.size.height
    elseif tags.top then
      window_state.size.height = window_state.frame_elem.location.y + window_state.size.height - (event.element.location.y + 10)
      window_state.frame_elem.style.height = window_state.size.height
      window_state.frame_elem.location = {
        x = window_state.frame_elem.location.x,
        y = event.element.location.y + 10,
      }
    end
    snap_resize_frames(window_state)
  end
)

---@param window_state WindowState
local function create_invisible_frame(window_state, directions)
  directions.window_id = window_state.id
  local frame, inner = gui.create_elem(window_state.player.player.gui.screen, {
    type = "frame",
    style = "gui_editor_invisible_frame",
    style_mods = {
      width = 20,
      height = 20,
    },
    tags = directions,
    events = {[defines.events.on_gui_location_changed] = on_resize_frame_location_changed},
    children = {
      {
        type = "empty-widget",
        name = "drag_elem",
        style_mods = {
          horizontally_stretchable = true,
          vertically_stretchable = true,
        },
      },
    },
  })
  ---@cast inner -nil
  inner.drag_elem.drag_target = frame
  return frame
end

local on_resize_toggle_click = gui.register_handler(
  "on_resize_toggle_click",
  ---@param player PlayerData
  ---@param tags any
  ---@param event EventData.on_gui_click
  function(player, tags, event)
    local window_state = player.windows_by_id[tags.window_id]
    window_state.resizing = not window_state.resizing
    window_state.toggle_resize_button.tooltip = window_state.resizing
      and "stop resizing" or "start resizing" -- TODO: add proper styling to this button
    window_state.draggable_space.style = window_state.resizing
      and "draggable_space_header" or "empty_widget"
    local draggable_space_style = window_state.draggable_space.style
    draggable_space_style.height = 24
    draggable_space_style.horizontally_stretchable = true
    draggable_space_style.right_margin = 4

    if window_state.resizing then
      window_state.left_resize_frame = create_invisible_frame(window_state, {left = true})
      window_state.right_resize_frame = create_invisible_frame(window_state, {right = true})
      window_state.top_resize_frame = create_invisible_frame(window_state, {top = true})
      window_state.bottom_resize_frame = create_invisible_frame(window_state, {bottom = true})
      window_state.top_left_resize_frame = create_invisible_frame(window_state, {top = true, left = true})
      window_state.top_right_resize_frame = create_invisible_frame(window_state, {top = true, right = true})
      window_state.bottom_left_resize_frame = create_invisible_frame(window_state, {bottom = true, left = true})
      window_state.bottom_right_resize_frame = create_invisible_frame(window_state, {bottom = true, right = true})
      snap_resize_frames(window_state)
    else
      window_state.left_resize_frame.destroy()
      window_state.right_resize_frame.destroy()
      window_state.top_resize_frame.destroy()
      window_state.bottom_resize_frame.destroy()
      window_state.top_left_resize_frame.destroy()
      window_state.top_right_resize_frame.destroy()
      window_state.bottom_left_resize_frame.destroy()
      window_state.bottom_right_resize_frame.destroy()
    end
  end
)

---@param player PlayerData
---@param window_type string
local function create_window(player, window_type)
  local window = windows[window_type]
  local window_id = player.next_window_id
  player.next_window_id = window_id + 1

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
          },
          {
            type = "empty-widget",
            style = "empty_widget", -- draggable_space_header
            name = "draggable_space",
            style_mods = {
              height = 24,
              horizontally_stretchable = true,
              right_margin = 4,
            },
          },
          {
            type = "sprite-button",
            style = "frame_action_button",
            name = "toggle_resize_button",
            tooltip = "start resizing",
            -- sprite = "utility/close_white",
            -- hovered_sprite = "utility/close_black",
            -- clicked_sprite = "utility/close_black",
            tags = {window_id = window_id},
            events = {[defines.events.on_gui_click] = on_resize_toggle_click},
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

  ---@type WindowState
  local window_state = {
    player = player,
    id = window_id,
    frame_elem = frame,
    header_elem = inner.header_flow,
    draggable_space = inner.draggable_space,
    toggle_resize_button = inner.toggle_resize_button,
    resizing = false,
    size = {
      width = window.initial_size.width,
      height = window.initial_size.height,
    },
  }

  player.windows_by_id[window_id] = window_state

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
