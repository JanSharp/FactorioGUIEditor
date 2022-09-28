
local gui = require("__gui-editor__.gui")
local util = require("__gui-editor__.util")

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
local function get_windows(player, window_type)
  local window_states = player.windows[window_type]
  if not window_states then
    window_states = {}
    player.windows[window_type] = window_states
  end
  return window_states
end

---@param window_state WindowState
local function position_invisible_frames(window_state)
  local location = window_state.location
  local size = window_state.size

  window_state.movement_frame.location = {
    x = location.x + 10,
    y = location.y + 10,
  }
  window_state.movement_frame.style.size = {
    size.width - 20 - (24 + 4) * 2,
    28,
  }

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

---@enum WindowDirection
local directions = {
  none = 0,
  left = 1,
  right = 2,
  top = 4,
  bottom = 8,
  top_left = 1 + 4,
  top_right = 2 + 4,
  bottom_left = 1 + 8,
  bottom_right = 2 + 8,
}

---@param direction WindowDirection|WindowAnchor
local function get_horizontal_direction_multiplier(direction)
  return bit32.band(direction, directions.right) ~= 0 and 1 or -1
end

---@param direction WindowDirection|WindowAnchor
local function get_vertical_direction_multiplier(direction)
  return bit32.band(direction, directions.bottom) ~= 0 and 1 or -1
end

---@alias WindowAnchor WindowDirection

-- enum doesn't work with this, unfortunately
local anchors = {
  top_left = directions.top_left,
  top_right = directions.top_right,
  bottom_left = directions.bottom_left,
  bottom_right = directions.bottom_right,
}

---@type table<WindowAnchor, WindowAnchor>
local opposite_anchors = {
  [anchors.top_left] = anchors.bottom_right,
  [anchors.top_right] = anchors.bottom_left,
  [anchors.bottom_left] = anchors.top_right,
  [anchors.bottom_right] = anchors.top_left,
}

---@type table<WindowDirection, WindowAnchor>
local anchors_for_direction = {
  [directions.left] = anchors.top_right,
  [directions.right] = anchors.top_left,
  [directions.top] = anchors.bottom_left,
  [directions.bottom] = anchors.top_left,
  [directions.top_left] = anchors.bottom_right,
  [directions.top_right] = anchors.bottom_left,
  [directions.bottom_left] = anchors.top_right,
  [directions.bottom_right] = anchors.top_left,
}

---@param window_state WindowState
---@param anchor WindowAnchor
local function get_anchor_x(window_state, anchor)
  if bit32.band(anchor, directions.left) ~= 0 then
    return window_state.location.x
  else -- right
    return window_state.location.x + window_state.size.width
  end
end

---@param window_state WindowState
---@param anchor WindowAnchor
local function get_anchor_y(window_state, anchor)
  if bit32.band(anchor, directions.top) ~= 0 then
    return window_state.location.y
  else -- bottom
    return window_state.location.y + window_state.size.height
  end
end

---@param window_state WindowState
---@param anchor WindowAnchor
local function get_anchor(window_state, anchor)
  return {
    x = get_anchor_x(window_state, anchor),
    y = get_anchor_y(window_state, anchor),
  }
end

---@param window_state WindowState
---@param width integer
---@param anchor WindowAnchor
local function set_width(window_state, width, anchor)
  local window = windows[window_state.window_type]
  width = math.max(width, window.minimal_size.width)
  if bit32.band(anchor, directions.right) ~= 0 then
    window_state.location.x = get_anchor_x(window_state, anchor) - width
  end
  window_state.size.width = width
end

---@param window_state WindowState
---@param height integer
---@param anchor WindowAnchor
local function set_height(window_state, height, anchor)
  local window = windows[window_state.window_type]
  height = math.max(height, window.minimal_size.height)
  if bit32.band(anchor, directions.bottom) ~= 0 then
    window_state.location.y = get_anchor_y(window_state, anchor) - height
  end
  window_state.size.height = height
end

---@param window_state WindowState
---@param x integer
---@param anchor WindowAnchor
local function set_width_from_location(window_state, x, anchor)
  local width = get_anchor_x(window_state, anchor) - x
  -- don't think about it too much, just consider the fact that it needs to be inverted for one side
  width = width * get_horizontal_direction_multiplier(anchor)
  set_width(window_state, width, anchor)
end

---@param window_state WindowState
---@param y integer
---@param anchor WindowAnchor
local function set_height_from_location(window_state, y, anchor)
  local height = get_anchor_y(window_state, anchor) - y
  -- don't think about it too much, just consider the fact that it needs to be inverted for one side
  height = height * get_vertical_direction_multiplier(anchor)
  set_height(window_state, height, anchor)
end

---@param window_state WindowState
---@param location GuiLocation
---@param direction WindowDirection
local function set_size_from_location(window_state, location, direction)
  if bit32.band(direction, directions.left + directions.right) ~= 0 then
    set_width_from_location(window_state, location.x, anchors_for_direction[direction])
  end
  if bit32.band(direction, directions.top + directions.bottom) ~= 0 then
    set_height_from_location(window_state, location.y, anchors_for_direction[direction])
  end
end

---@param window_state WindowState
---@param x integer @ to match the behavior for resizing,
---this location is at the opposite side of the anchor
---@param anchor WindowAnchor
local function set_location_x_from_location(window_state, x, anchor)
  local current_x = get_anchor_x(window_state, opposite_anchors[anchor])
  local diff = x - current_x
  window_state.location.x = window_state.location.x + diff
end

---@param window_state WindowState
---@param y integer @ to match the behavior for resizing,
---this location is at the opposite side of the anchor
---@param anchor WindowAnchor
local function set_location_y_from_location(window_state, y, anchor)
  local current_y = get_anchor_y(window_state, opposite_anchors[anchor])
  local diff = y - current_y
  window_state.location.y = window_state.location.y + diff
end

---@param window_state WindowState
---@param other WindowState
local function overlapping_horizontally(window_state, other)
  return not (
    get_anchor_x(window_state, directions.right) <= get_anchor_x(other, directions.left)
      or get_anchor_x(window_state, directions.left) >= get_anchor_x(other, directions.right)
  )
end

---@param window_state WindowState
---@param other WindowState
local function overlapping_vertically(window_state, other)
  return not (
    get_anchor_y(window_state, directions.bottom) <= get_anchor_y(other, directions.top)
      or get_anchor_y(window_state, directions.top) >= get_anchor_y(other, directions.bottom)
  )
end

---@param window_state WindowState
---@param get_anchor_xy function @ `get_anchor_x` or `get_anchor_y`
---@param overlapping function @ `overlapping_horizontally` or `overlapping_vertically`
---@param anchor WindowAnchor
---@param snap_to_location fun(window_state: WindowState, location_xy: integer, anchor: WindowAnchor) @
---actual snap action. the anchor arg will be the same value as the anchor passed to this function
---@return boolean snapped @ returns true if it did snap or was already snapped
local function snap_axis(window_state, get_anchor_xy, overlapping, anchor, snap_to_location)
  local this_anchor_xy = get_anchor_xy(window_state, opposite_anchors[anchor])
  for _, other in pairs(window_state.player.windows_by_id) do
    if overlapping(window_state, other) then
      local other_xy = get_anchor_xy(other, anchor)
      if other_xy == this_anchor_xy then
        return true
      end
      if math.abs(other_xy - this_anchor_xy) <= 8 then
        snap_to_location(window_state, other_xy, anchor)
        return true
      end
    end
  end
  return false
end

---@param window_state WindowState
local function snap_movement(window_state)
  if not snap_axis(window_state, get_anchor_x, overlapping_vertically, anchors.top_left, set_location_x_from_location) then
    snap_axis(window_state, get_anchor_x, overlapping_vertically, anchors.top_right, set_location_x_from_location)
  end
  if not snap_axis(window_state, get_anchor_y, overlapping_horizontally, anchors.top_left, set_location_y_from_location) then
    snap_axis(window_state, get_anchor_y, overlapping_horizontally, anchors.bottom_left, set_location_y_from_location)
  end
end

---@param window_state WindowState
---@param direction WindowDirection
local function snap_resize(window_state, direction)
  local anchor = anchors_for_direction[direction]
  if bit32.band(direction, directions.left + directions.right) ~= 0 then
    snap_axis(window_state, get_anchor_x, overlapping_vertically, anchor, set_width_from_location)
  end
  if bit32.band(direction, directions.top + directions.bottom) ~= 0 then
    snap_axis(window_state, get_anchor_y, overlapping_horizontally, anchor, set_height_from_location)
  end
end

---@param window_state WindowState
local function apply_location_and_size_changes(window_state)
  window_state.frame_elem.location = window_state.location
  window_state.frame_elem.style.size = window_state.size
end

local on_resize_frame_location_changed = gui.register_handler(
  "on_resize_frame_location_changed",
  ---@param event EventData.on_gui_location_changed
  function(player, tags, event)
    local window_state = player.windows_by_id[tags.window_id]
    local elem_location = event.element.location ---@cast elem_location -nil

    if tags.movement then
      window_state.location = {
        x = elem_location.x - 10,
        y = elem_location.y - 10,
      }
      snap_movement(window_state)
    else
      elem_location.x = elem_location.x + 10
      elem_location.y = elem_location.y + 10
      set_size_from_location(window_state, elem_location, tags.direction)
      snap_resize(window_state, tags.direction)
    end

    position_invisible_frames(window_state)
    apply_location_and_size_changes(window_state)
  end
)

-- https://unicode-table.com/en/sets/arrow-symbols/
local direction_arrows = {
  [directions.none] = nil,
  [directions.left] = "⬌", -- ⬄  [font=default-bold]←[/font]
  [directions.right] = "⬌", -- ⬄  [font=default-bold]→[/font]
  [directions.top] = "⬍", -- ⇳  [font=default-bold]↑[/font]
  [directions.bottom] = "⬍", -- ⇳  [font=default-bold]↓[/font]
  [directions.top_left] = "⬉",
  [directions.top_right] = "⬈",
  [directions.bottom_left] = "⬋",
  [directions.bottom_right] = "⬊",
}

---@param window_state WindowState
local function create_invisible_frame(window_state, direction, movement)
  local frame, inner = gui.create_elem(window_state.player.player.gui.screen, {
    type = "frame",
    style = "gui_editor_invisible_frame",
    style_mods = {
      width = 20,
      height = 20,
    },
    tags = {
      window_id = window_state.id,
      direction = direction,
      movement = movement,
    },
    events = {[defines.events.on_gui_location_changed] = on_resize_frame_location_changed},
    children = {
      {
        type = "empty-widget",
        name = "drag_elem",
        tooltip = direction_arrows[direction],
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

---@param window_state WindowState
---@param resizing boolean
local function set_resizing(window_state, resizing)
  if window_state.resizing == resizing then return end
  window_state.resizing = resizing
  window_state.toggle_resize_button.style = resizing
    and "gui_editor_selected_frame_action_button" or "frame_action_button"
  window_state.toggle_resize_button.sprite = resizing
    and "gui-editor-resize-black" or "gui-editor-resize-white"
  window_state.draggable_space.style = resizing
    and "draggable_space_header" or "empty_widget"
  local draggable_space_style = window_state.draggable_space.style
  draggable_space_style.height = 24
  draggable_space_style.horizontally_stretchable = true
  draggable_space_style.right_margin = 4

  if resizing then
    local create = create_invisible_frame
    window_state.movement_frame = create(window_state, directions.none, true)
    window_state.left_resize_frame = create(window_state, directions.left)
    window_state.right_resize_frame = create(window_state, directions.right)
    window_state.top_resize_frame = create(window_state, directions.top)
    window_state.bottom_resize_frame = create(window_state, directions.bottom)
    window_state.top_left_resize_frame = create(window_state, directions.top_left)
    window_state.top_right_resize_frame = create(window_state, directions.top_right)
    window_state.bottom_left_resize_frame = create(window_state, directions.bottom_left)
    window_state.bottom_right_resize_frame = create(window_state, directions.bottom_right)
    position_invisible_frames(window_state)
  else
    window_state.movement_frame.destroy()
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

local on_resize_toggle_click = gui.register_handler(
  "on_resize_toggle_click",
  ---@param event EventData.on_gui_click
  function(player, tags, event)
    local window_state = player.windows_by_id[tags.window_id]
    set_resizing(window_state, not window_state.resizing)
  end
)

local on_main_frame_location_changed = gui.register_handler(
  "on_main_frame_location_changed",
  ---@param event EventData.on_gui_location_changed
  function(player, tags, event)
    local window_state = player.windows_by_id[tags.window_id]
    window_state.location = window_state.frame_elem.location
    if window_state.resizing then
      position_invisible_frames(window_state)
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
    tags = {window_id = window_id},
    events = {[defines.events.on_gui_location_changed] = on_main_frame_location_changed},
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
            tooltip = "Resize/Move",
            sprite = "gui-editor-resize-white",
            hovered_sprite = "gui-editor-resize-black",
            clicked_sprite = "gui-editor-resize-black",
            tags = {window_id = window_id},
            events = {[defines.events.on_gui_click] = on_resize_toggle_click},
          },
          {
            type = "sprite-button",
            style = "frame_action_button",
            tooltip = "Close",
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
    window_type = window_type,
    id = window_id,
    frame_elem = frame,
    header_elem = inner.header_flow,
    draggable_space = inner.draggable_space,
    toggle_resize_button = inner.toggle_resize_button,
    resizing = false,
    location = {x = 0, y = 0},
    size = {
      width = window.initial_size.width,
      height = window.initial_size.height,
    },
  }

  player.windows_by_id[window_id] = window_state

  local window_states = get_windows(player, window_type)
  window_states[#window_states+1] = window_state

  window.on_create(window_state)

  return window_state
end

---@param event EventData.on_player_display_resolution_changed
local function on_player_display_resolution_changed(event)
  local player = util.get_player(event)
  if not player then return end

  local resolution = player.player.display_resolution
  player.resolution = resolution

  -- left
  player.windows_by_id[1].size.height = resolution.height
  -- right
  player.windows_by_id[2].location.x = resolution.width
  player.windows_by_id[2].size.height = resolution.height
  -- top
  player.windows_by_id[3].size.width = resolution.width
  -- bottom
  player.windows_by_id[4].location.y = resolution.height
  player.windows_by_id[4].size.width = resolution.width

  -- stop all resizing because window scaling when changing resolution will be handled differently
  for _, window_state in pairs(player.windows_by_id) do
    if window_state.resizing then
      set_resizing(window_state, false)
    end
  end
end

---@param player PlayerData
local function init_player(player)
  local resolution = player.player.display_resolution

  player.windows = {}
  player.windows_by_id = {
    { -- left
      window_id = 1,
      location = {x = 0, y = 0},
      size = {width = 0, height = resolution.height},
      is_window_edge = true,
    },
    { -- right
      window_id = 2,
      location = {x = resolution.width, y = 0},
      size = {width = 0, height = resolution.height},
      is_window_edge = true,
    },
    { -- top
      window_id = 3,
      location = {x = 0, y = 0},
      size = {width = resolution.width, height = 0},
      is_window_edge = true,
    },
    { -- bottom
      window_id = 4,
      location = {x = 0, y = resolution.height},
      size = {width = resolution.width, height = 0},
      is_window_edge = true,
    },
  }
  player.next_window_id = 5
end

return {
  register_window = register_window,
  get_windows = get_windows,
  create_window = create_window,
  on_player_display_resolution_changed = on_player_display_resolution_changed,
  init_player = init_player,
}
