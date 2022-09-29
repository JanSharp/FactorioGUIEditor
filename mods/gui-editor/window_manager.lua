
local gui = require("__gui-editor__.gui")
local util = require("__gui-editor__.util")
local ll = require("__gui-editor__.linked_list")

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
  local window_states = player.windows_by_type[window_type]
  if not window_states then
    window_states = {}
    player.windows_by_type[window_type] = window_states
  end
  return window_states
end

---@param window_state WindowState
local function position_invisible_frames(window_state)
  if not window_state.resizing then return end

  local location = window_state.location
  local size = window_state.size
  local scale = window_state.player.display_scale
  local offset = 10 * scale

  window_state.movement_frame.location = {
    x = location.x + offset,
    y = location.y + offset,
  }
  window_state.movement_frame.style.size = {
    size.width / scale - 20 - (24 + 4) * 2,
    28,
  }

  window_state.top_left_resize_frame.location = {
    x = location.x - offset,
    y = location.y - offset,
  }
  window_state.top_right_resize_frame.location = {
    x = location.x + size.width - offset,
    y = location.y - offset,
  }
  window_state.bottom_left_resize_frame.location = {
    x = location.x - offset,
    y = location.y + size.height - offset,
  }
  window_state.bottom_right_resize_frame.location = {
    x = location.x + size.width - offset,
    y = location.y + size.height - offset,
  }

  window_state.top_resize_frame.location = {
    x = location.x + offset,
    y = location.y - offset,
  }
  window_state.top_resize_frame.style.width = size.width / scale - 20

  window_state.left_resize_frame.location = {
    x = location.x - offset,
    y = location.y + offset,
  }
  window_state.left_resize_frame.style.height = size.height / scale - 20

  window_state.bottom_resize_frame.location = {
    x = location.x + offset,
    y = location.y + size.height - offset,
  }
  window_state.bottom_resize_frame.style.width = size.width / scale - 20

  window_state.right_resize_frame.location = {
    x = location.x + size.width - offset,
    y = location.y + offset,
  }
  window_state.right_resize_frame.style.height = size.height / scale - 20
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
  local scale = window_state.player.display_scale
  -- math.ceil because width should always be an integer
  width = math.max(width, math.ceil(window.minimal_size.width * scale))
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
  local scale = window_state.player.display_scale
  -- math.ceil because height should always be an integer
  height = math.max(height, math.ceil(window.minimal_size.height * scale))
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
---@param get_anchor_xy function @ `get_anchor_x` or `get_anchor_y`. The axis to snap
---@param get_anchor_yx function @ `get_anchor_y` or `get_anchor_x`. The other axis
---@param overlapping function @ `overlapping_vertically` or `overlapping_horizontally`
---@param anchor WindowAnchor
---@param snap_to_location fun(window_state: WindowState, xy: integer, anchor: WindowAnchor) @
---actual snap action. the anchor arg will be the same value as the anchor passed to this function.
---The xy value will be on the opposite side of the anchor
---@return boolean snapped @ returns true if it did snap or was already snapped
local function snap_axis_internal(
  window_state,
  get_anchor_xy,
  get_anchor_yx,
  overlapping,
  anchor,
  snap_to_location
)
  local opposite_anchor = opposite_anchors[anchor]
  -- main axis
  local this_anchor_xy = get_anchor_xy(window_state, opposite_anchor)
  -- other axis
  local side_one_yx = get_anchor_yx(window_state, anchor)
  local side_two_yx = get_anchor_yx(window_state, opposite_anchor)
  ---@param other_xy integer @ main axis of the other window
  local function try_snap_to(other_xy)
    if other_xy == this_anchor_xy then -- if it's touching, it's snapped already
      return true
    end
    if math.abs(other_xy - this_anchor_xy) <= 8 then -- not touching, but close. Snap to it
      snap_to_location(window_state, other_xy, anchor)
      return true
    end
  end
  for _, other in pairs(window_state.player.windows_by_id) do
    if overlapping(window_state, other) then
      -- check if the other window's edge is touching - or close to - this window's opposite edge
      if try_snap_to(get_anchor_xy(other, anchor)) then return true end
    -- check if the other axis's edges are touching
    elseif side_one_yx == get_anchor_yx(other, opposite_anchor)
      or side_two_yx == get_anchor_yx(other, anchor)
    then
      -- perform the same snapping logic as before, but this time with the same window side
      if try_snap_to(get_anchor_xy(other, opposite_anchor)) then return true end
    end
  end
  return false
end

---@param window_state WindowState
---@param anchor WindowAnchor
---@param snap_to_location fun(window_state: WindowState, x: integer, anchor: WindowAnchor) @
---actual snap action. the anchor arg will be the same value as the anchor passed to this function.
---The x value will be on the opposite side of the anchor
---@return boolean snapped @ returns true if it did snap or was already snapped
local function snap_horizontally(window_state, anchor, snap_to_location)
  return snap_axis_internal(
    window_state,
    get_anchor_x,
    get_anchor_y,
    overlapping_vertically,
    anchor,
    snap_to_location
  )
end

---@param window_state WindowState
---@param anchor WindowAnchor
---@param snap_to_location fun(window_state: WindowState, y: integer, anchor: WindowAnchor) @
---actual snap action. the anchor arg will be the same value as the anchor passed to this function.
---The y value will be on the opposite side of the anchor
---@return boolean snapped @ returns true if it did snap or was already snapped
local function snap_vertically(window_state, anchor, snap_to_location)
  return snap_axis_internal(
    window_state,
    get_anchor_y,
    get_anchor_x,
    overlapping_horizontally,
    anchor,
    snap_to_location
  )
end

---@param window_state WindowState
local function snap_movement(window_state)
  local function snap_x()
    return snap_horizontally(window_state, anchors.top_left, set_location_x_from_location)
      or snap_horizontally(window_state, anchors.top_right, set_location_x_from_location)
  end
  local snapped_x = snap_x()
  if (snap_vertically(window_state, anchors.top_left, set_location_y_from_location)
      or snap_vertically(window_state, anchors.bottom_left, set_location_y_from_location)
    )
    and not snapped_x
  then
    -- if y snapped, snap x again as long as x didn't already snap
    -- because vertically touching windows can snap horizontal edges to align with each other
    snap_x()
  end
end

---@param window_state WindowState
---@param direction WindowDirection
local function snap_resize(window_state, direction)
  local anchor = anchors_for_direction[direction]
  local function snap_x()
    return bit32.band(direction, directions.left + directions.right) ~= 0
      and snap_horizontally(window_state, anchor, set_width_from_location)
  end
  local snapped_x = snap_x()
  if bit32.band(direction, directions.top + directions.bottom) ~= 0
    and snap_vertically(window_state, anchor, set_height_from_location)
    and not snapped_x
  then
    -- if y snapped, snap x again as long as x didn't already snap
    -- because vertically touching windows can snap horizontal edges to align with each other
    snap_x()
  end
end

---@param window_state WindowState
local function apply_location_and_size_changes(window_state)
  window_state.frame_elem.location = window_state.location
  local scale = window_state.player.display_scale
  local style = window_state.frame_elem.style
  style.width = window_state.size.width / scale
  style.height = window_state.size.height / scale
end

---@param window_state WindowState
local function bring_to_front(window_state)
  local window_list = window_state.player.window_list
  if window_list.first ~= window_state then
    window_list.first.title_label.style.font_color = {0.6, 0.6, 0.6}
  end
  ll.remove(window_list, window_state)
  ll.prepend(window_list, window_state)
  if window_state.parent_window then
    ll.remove(window_state.parent_window.child_windows, window_state)
    ll.prepend(window_state.parent_window.child_windows, window_state)
  end
  -- NOTE: hardcoded heading_font_color, because setting to nil appears to simply get ignored
  window_state.title_label.style.font_color = {255, 230, 192}
  window_state.frame_elem.bring_to_front()
  if window_state.resizing then
    window_state.movement_frame.bring_to_front()
    window_state.left_resize_frame.bring_to_front()
    window_state.right_resize_frame.bring_to_front()
    window_state.top_resize_frame.bring_to_front()
    window_state.bottom_resize_frame.bring_to_front()
    window_state.top_left_resize_frame.bring_to_front()
    window_state.top_right_resize_frame.bring_to_front()
    window_state.bottom_left_resize_frame.bring_to_front()
    window_state.bottom_right_resize_frame.bring_to_front()
  end
  local child_window = window_state.child_windows.last
  while child_window do
    bring_to_front(child_window)
    child_window = child_window.prev_sibling
  end
end

local on_resize_frame_location_changed = gui.register_handler(
  "on_resize_frame_location_changed",
  ---@param event EventData.on_gui_location_changed
  function(player, tags, event)
    local window_state = player.windows_by_id[tags.window_id]
    local elem_location = event.element.location ---@cast elem_location -nil
    -- + 0.5 and then a floor to make it round instead of truncating
    local offset = math.floor(10 * player.display_scale + 0.5)

    if tags.movement then
      window_state.location = {
        x = elem_location.x - offset,
        y = elem_location.y - offset,
      }
      snap_movement(window_state)
    else
      elem_location.x = elem_location.x + offset
      elem_location.y = elem_location.y + offset
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
  window_state.resize_button.style = resizing
    and "gui_editor_selected_frame_action_button" or "frame_action_button"
  window_state.resize_button.sprite = resizing
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

local on_resize_button_click = gui.register_handler(
  "on_resize_button_click",
  ---@param event EventData.on_gui_click
  function(player, tags, event)
    if event.shift or event.alt then return end
    local window_state = player.windows_by_id[tags.window_id]
    if event.button == defines.mouse_button_type.left then
      if event.control then return end
      set_resizing(window_state, not window_state.resizing)
    elseif event.button == defines.mouse_button_type.right then
      if event.control then
        window_state.location.x = 0
        window_state.size.width = window_state.player.resolution.width
        position_invisible_frames(window_state)
        apply_location_and_size_changes(window_state)
      else
        window_state.location.y = 0
        window_state.size.height = window_state.player.resolution.height
        position_invisible_frames(window_state)
        apply_location_and_size_changes(window_state)
      end
    end
  end
)

local on_main_frame_location_changed = gui.register_handler(
  "on_main_frame_location_changed",
  ---@param event EventData.on_gui_location_changed
  function(player, tags, event)
    -- local window_state = player.windows_by_id[tags.window_id]
    -- window_state.location = window_state.frame_elem.location
    -- position_invisible_frames(window_state)
  end
)

---@param player PlayerData
---@param window_type string
---@param parent_window WindowState?
local function create_window(player, window_type, parent_window)
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
            name = "title_label",
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
            name = "resize_button",
            tooltip = "Resize/Move",
            sprite = "gui-editor-resize-white",
            hovered_sprite = "gui-editor-resize-black",
            clicked_sprite = "gui-editor-resize-black",
            tags = {window_id = window_id},
            events = {[defines.events.on_gui_click] = on_resize_button_click},
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
    title_label = inner.title_label,
    draggable_space = inner.draggable_space,
    resize_button = inner.resize_button,
    resizing = false,
    location = {x = 0, y = 0},
    size = {
      width = window.initial_size.width,
      height = window.initial_size.height,
    },
    parent_window = parent_window,
    child_windows = ll.new_list(false, "sibling")
  }

  if parent_window then
    ll.prepend(parent_window.child_windows, window_state)
  end

  player.windows_by_id[window_id] = window_state

  local window_states = get_windows(player, window_type)
  window_states[#window_states+1] = window_state

  ll.append(player.window_list, window_state)
  bring_to_front(window_state)

  window.on_create(window_state)

  return window_state
end

---@param event EventData.on_gui_click
local function on_gui_click(event)
  -- this finds the frame that is inside gui.screen and gets the window_state
  -- using the window_id in the tags of the found frame.
  -- Since both the main frame of windows and all invisible frames have said window_id
  -- this ends up handling all of them. No matter which element is clicked, the window
  -- will be moved to the front and and all invisible frames stay on top
  local player = util.get_player(event)
  if not player then return end
  local root = player.player.gui.screen
  local main_frame = event.element
  local parent = main_frame.parent
  ---@cast parent -nil
  while parent ~= root do
    main_frame = parent
    parent = parent.parent
  end
  local tags = gui.try_get_tags(main_frame)
  if not tags or not tags.window_id then return end
  local window_state = player.windows_by_id[tags.window_id]
  bring_to_front(window_state)
end

---@param player PlayerData
---@param scale_changed boolean
local function on_resolution_changed(player, scale_changed)
  local resolution = player.player.display_resolution
  local display_scale = player.player.display_scale
  player.resolution = resolution
  player.display_scale = display_scale

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
    if scale_changed and not window_state.is_window_edge then
      -- changing the scale affects the minimal_size, so we reapply width and height
      set_width(window_state, window_state.size.width, anchors.top_left)
      set_height(window_state, window_state.size.height, anchors.top_left)
      -- and applying size to the gui element depends scale regardless of size having changed
      apply_location_and_size_changes(window_state)
    end
    if window_state.resizing then
      set_resizing(window_state, false)
    end
  end
end

---@param event EventData.on_player_display_resolution_changed
local function on_player_display_resolution_changed(event)
  local player = util.get_player(event)
  if not player then return end
  on_resolution_changed(player, false)
end

---@param event EventData.on_player_display_scale_changed
local function on_player_display_scale_changed(event)
  local player = util.get_player(event)
  if not player then return end
  on_resolution_changed(player, true)
end

---@param player PlayerData
local function init_player(player)
  ---@param window_id integer
  local function make_dummy_window(window_id)
    return {
      window_id = window_id,
      location = {x = 0, y = 0},
      size = {width = 0, height = 0},
      is_window_edge = true,
    }
  end
  player.window_list = ll.new_list(false)
  player.windows_by_type = {}
  player.windows_by_id = {
    make_dummy_window(1), -- left
    make_dummy_window(2), -- right
    make_dummy_window(3), -- top
    make_dummy_window(4), -- bottom
  }
  player.next_window_id = 5

  on_resolution_changed(player, false)
end

return {
  register_window = register_window,
  get_windows = get_windows,
  bring_to_front = bring_to_front,
  create_window = create_window,
  on_gui_click = on_gui_click,
  on_player_display_resolution_changed = on_player_display_resolution_changed,
  on_player_display_scale_changed = on_player_display_scale_changed,
  init_player = init_player,
}
