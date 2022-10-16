
local gui = require("__gui-editor__.gui")
local util = require("__gui-editor__.util")
local ll = require("__gui-editor__.linked_list")

-- TODO: add functions for centering horizontally and vertically
-- NOTE: maybe add quite a few functions for window resizing and movement, like move to a side [...]
-- of the screen (all 4), move to corner, snap (move and or resize) to window/screen edge in a
-- direction
-- TODO: make windows always draggable
-- TODO: use flags and safe old values for maximizing horizontally and vertically
-- NOTE: snapping logic currently snaps to window edges that are covered by other windows in front [...]
-- changing this isn't exactly straight forward however, and it's not a big deal. But still worth a note
-- TODO: add lock button to toggle resizing, so have a separate maximize button
-- TODO: add options for custom buttons in the title bar

---@type table<string, Window>
local windows = {}

---@alias WindowManagerEventHandler fun(window_state: WindowState)

---@type table<WindowManagerEventHandler, true>
local on_window_created_handlers = {}
---@type table<WindowManagerEventHandler, true>
local on_window_closed_handlers = {}
---@type table<WindowManagerEventHandler, true>
local on_display_title_changed_handlers = {}

---@param handler WindowManagerEventHandler
local function on_window_created(handler)
  on_window_created_handlers[handler] = true
end
---@param handler WindowManagerEventHandler
local function on_window_closed(handler)
  on_window_closed_handlers[handler] = true
end
---@param handler WindowManagerEventHandler
local function on_display_title_changed(handler)
  on_display_title_changed_handlers[handler] = true
end

---@param handlers table<WindowManagerEventHandler, true>
---@param window_state WindowState
local function raise_event(handlers, window_state)
  for handler in pairs(handlers) do
    handler(window_state)
  end
end

---@param window_state WindowState
local function raise_on_window_created(window_state)
  raise_event(on_window_created_handlers, window_state)
end
---@param window_state WindowState
local function raise_on_window_closed(window_state)
  raise_event(on_window_closed_handlers, window_state)
end
---@param window_state WindowState
local function raise_on_display_title_changed(window_state)
  raise_event(on_display_title_changed_handlers, window_state)
end

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

---@param player PlayerData
---@param window_id integer
local function get_window(player, window_id)
  return player.windows_by_id[window_id]
end

---@param window_state WindowState
local function position_invisible_frames(window_state)
  if not window_state.resizing then return end

  local location = window_state.location
  local size = window_state.size
  local scale = window_state.player.display_scale
  local offset = math.floor(10 * scale)
  -- as described in `apply_location_and_size_changes_internal`, there are some widths and heights
  -- that we cannot represent at scales > 1, so we are adding 1 pixel for both width and height
  -- because 1 pixel overlap is better than 1 pixel gap
  local scaled_width = math.ceil(size.width / scale) + 1
  local scaled_height = math.ceil(size.height / scale) + 1

  window_state.movement_frame.location = {
    x = location.x + offset,
    y = location.y + offset,
  }
  window_state.movement_frame.style.size = {
    scaled_width - 20 - (24 + 4) * 2,
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
  window_state.top_resize_frame.style.width = scaled_width - 20

  window_state.left_resize_frame.location = {
    x = location.x - offset,
    y = location.y + offset,
  }
  window_state.left_resize_frame.style.height = scaled_height - 20

  window_state.bottom_resize_frame.location = {
    x = location.x + offset,
    y = location.y + size.height - offset,
  }
  window_state.bottom_resize_frame.style.width = scaled_width - 20

  window_state.right_resize_frame.location = {
    x = location.x + size.width - offset,
    y = location.y + offset,
  }
  window_state.right_resize_frame.style.height = scaled_height - 20
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
  window_state.size_before_rescale = nil
  window_state.resolution_for_size_before_rescale = nil
  local window = windows[window_state.window_type]
  local scale = window_state.player.display_scale
  -- math.ceil because width should always be an integer
  width = math.max(width, math.ceil(window.minimal_size.width * scale))
  if bit32.band(anchor, directions.right) ~= 0 then
    window_state.location_before_rescale = nil
    window_state.resolution_for_location_before_rescale = nil
    window_state.location.x = get_anchor_x(window_state, anchor) - width
  end
  window_state.size.width = width
end

---@param window_state WindowState
---@param height integer
---@param anchor WindowAnchor
local function set_height(window_state, height, anchor)
  window_state.size_before_rescale = nil
  window_state.resolution_for_size_before_rescale = nil
  local window = windows[window_state.window_type]
  local scale = window_state.player.display_scale
  -- math.ceil because height should always be an integer
  height = math.max(height, math.ceil(window.minimal_size.height * scale))
  if bit32.band(anchor, directions.bottom) ~= 0 then
    window_state.location_before_rescale = nil
    window_state.resolution_for_location_before_rescale = nil
    window_state.location.y = get_anchor_y(window_state, anchor) - height
  end
  window_state.size.height = height
end

---@param window_state WindowState
---@param size Size
---@param anchor WindowAnchor
local function set_size(window_state, size, anchor)
  set_width(window_state, size.width, anchor)
  set_height(window_state, size.height, anchor)
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
---@param anchor WindowAnchor
local function set_size_from_location(window_state, location, anchor)
  set_width_from_location(window_state, location.x, anchor)
  set_height_from_location(window_state, location.y, anchor)
end

---@param window_state WindowState
---@param location GuiLocation
---@param direction WindowDirection
local function set_size_from_location_and_direction(window_state, location, direction)
  if bit32.band(direction, directions.left + directions.right) ~= 0 then
    set_width_from_location(window_state, location.x, anchors_for_direction[direction])
  end
  if bit32.band(direction, directions.top + directions.bottom) ~= 0 then
    set_height_from_location(window_state, location.y, anchors_for_direction[direction])
  end
end

---@param window_state WindowState
---@param x integer
local function set_location_x(window_state, x)
  window_state.location_before_rescale = nil
  window_state.resolution_for_location_before_rescale = nil
  window_state.location.x = x
end

---@param window_state WindowState
---@param y integer
local function set_location_y(window_state, y)
  window_state.location_before_rescale = nil
  window_state.resolution_for_location_before_rescale = nil
  window_state.location.y = y
end

---@param window_state WindowState
---@param location GuiLocation
local function set_location(window_state, location)
  window_state.location_before_rescale = nil
  window_state.resolution_for_location_before_rescale = nil
  window_state.location = location
end

---@param window_state WindowState
---@param x integer @ to match the behavior for resizing,
---this location is at the opposite side of the anchor
---@param anchor WindowAnchor
local function set_location_x_from_location(window_state, x, anchor)
  local current_x = get_anchor_x(window_state, opposite_anchors[anchor])
  local diff = x - current_x
  set_location_x(window_state, window_state.location.x + diff)
end

---@param window_state WindowState
---@param y integer @ to match the behavior for resizing,
---this location is at the opposite side of the anchor
---@param anchor WindowAnchor
local function set_location_y_from_location(window_state, y, anchor)
  local current_y = get_anchor_y(window_state, opposite_anchors[anchor])
  local diff = y - current_y
  set_location_y(window_state, window_state.location.y + diff)
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
  local other = window_state.player.window_list.first
  while other do
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
    other = other.next
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
local function apply_location_and_size_changes_internal(window_state)
  window_state.frame_elem.location = window_state.location
  local scale = window_state.player.display_scale
  local style = window_state.frame_elem.style
  -- math.ceil appears to match the game pretty well. Scale 0.75 does not jiggle the window
  -- by 1 pixel when resizing the top left. Scales > 1 do still jiggle because the location
  -- of the window as well as the size would have to change in order for the bottom and right
  -- sides to remain at the same pixel while resizing. For example at 1.5 scale, going from
  -- 5 internal width to 6 results in 4 actual width to 4, so unchanged, however the location
  -- of the window did change by 1 pixel. In that case the window would have to be offset
  -- by 1 pixel to the right to keep the right side at the same location
  local width = math.ceil(window_state.size.width / scale)
  local height = math.ceil(window_state.size.height / scale)
  window_state.actual_size.width = width
  window_state.actual_size.height = height
  style.width = width
  style.height = height
end

---@param window_state WindowState
local function apply_location_and_size_changes(window_state)
  apply_location_and_size_changes_internal(window_state)
  local window = windows[window_state.window_type]
  if window.on_location_and_size_applied then
    window.on_location_and_size_applied(window_state)
  end
end

---@param window_state WindowState
local function bring_elems_to_front(window_state)
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
end

---@param window_state WindowState
local function bring_to_front_recursive(window_state)
  local window_list = window_state.player.window_list
  ll.remove(window_list, window_state)
  ll.prepend(window_list, window_state)
  if window_state.parent_window then
    ll.remove(window_state.parent_window.child_windows, window_state)
    ll.prepend(window_state.parent_window.child_windows, window_state)
  end
  bring_elems_to_front(window_state)
  local child_window = window_state.child_windows.last
  while child_window do
    bring_to_front_recursive(child_window)
    child_window = child_window.prev_sibling
  end
end

---@param player PlayerData
local function lose_focus(player)
  if player.focused_window and not player.focused_window.closed then
    player.focused_window.title_label.style.font_color = {0.6, 0.6, 0.6}
    local focused_window = windows[player.focused_window.window_type]
    if focused_window.on_focus_lost then
      focused_window.on_focus_lost(player.focused_window)
    end
  end
  player.focused_window = nil
end

---@param window_state WindowState
---@return boolean active_window_changed
local function bring_to_front_internal(window_state)
  bring_to_front_recursive(window_state)
  local front_window = window_state.player.window_list.first ---@cast front_window -nil
  if front_window == window_state.player.focused_window then return false end
  -- NOTE: hardcoded heading_font_color, because setting to nil appears to simply get ignored
  front_window.title_label.style.font_color = {255, 230, 192}
  lose_focus(window_state.player)
  window_state.player.focused_window = front_window
  return true
end

---@param window_state WindowState
local function bring_to_front(window_state)
  if not bring_to_front_internal(window_state) then return end
  local focused_window = window_state.player.focused_window ---@cast focused_window -nil
  local window = windows[focused_window.window_type]
  if window.on_focus_gained then
    window.on_focus_gained(focused_window)
  end
end

---@param player PlayerData
local function restore_back_to_front(player)
  local window_state = player.window_list.last
  while window_state do
    bring_elems_to_front(window_state)
    window_state = window_state.prev
  end
end

---@param window_state WindowState
---@param display_title string
local function set_display_title(window_state, display_title)
  if window_state.display_title == display_title then return end
  local do_raise = not not window_state.display_title
  window_state.display_title = display_title
  window_state.title_label.caption = display_title
  if do_raise then
    raise_on_display_title_changed(window_state)
  end
end

---@param window_states WindowState
---@param title string
local function update_all_display_titles_for_list(window_states, title)
  local i = 1
  for _, other_window in pairs(window_states) do
    set_display_title(other_window, title.." ("..i..")")
    i = i + 1
  end
end

---@param window_state WindowState
local function remove_from_windows_by_title(window_state)
  local windows_by_title = window_state.player.windows_by_title
  local title = window_state.title
  local window_states_list = windows_by_title[title]
  window_states_list.size = window_states_list.size - 1
  if window_states_list.size == 0 then
    windows_by_title[title] = nil
    return
  end
  window_states_list.window_states[window_state.id] = nil
  if window_states_list.size == 1 then
    local _, last_window_state = next(window_states_list.window_states)
    set_display_title(last_window_state, title)
    return
  end
  update_all_display_titles_for_list(window_states_list.window_states, title)
end

---@param window_state WindowState
local function add_to_windows_by_title(window_state)
  local windows_by_title = window_state.player.windows_by_title
  local title = window_state.title
  local window_states_list = windows_by_title[title]
  if not window_states_list then
    windows_by_title[title] = {size = 1, window_states = {[window_state.id] = window_state}}
    set_display_title(window_state, title)
    return
  end
  window_states_list.size = window_states_list.size + 1
  window_states_list.window_states[window_state.id] = window_state
  update_all_display_titles_for_list(window_states_list.window_states, title)
end

---@param window_state WindowState
---@param title string
local function set_title(window_state, title)
  if window_state.title == title then return end
  remove_from_windows_by_title(window_state)
  window_state.title = title
  add_to_windows_by_title(window_state)
end

---@param window_state WindowState
local function destroy_invisible_frames(window_state)
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

---@param window_state WindowState
---@return boolean closed_successfully @ closing the window might be cancelled, making this `false`
local function close_window_internal(window_state)
  local window = windows[window_state.window_type]
  if window.on_pre_close and window.on_pre_close(window_state) then
    return false
  end

  local child_window = window_state.child_windows.first
  while child_window do
    if not close_window_internal(child_window) then
      -- instantly return, parent windows behind the window that didn't close also stay open
      return false
    end
    child_window = child_window.next_sibling
  end

  if window_state.parent_window then
    ll.remove(window_state.parent_window.child_windows, window_state)
  end
  ll.remove(window_state.player.window_list, window_state)
  local windows_by_type = window_state.player.windows_by_type[window_state.window_type]
  util.remove_from_array(windows_by_type, window_state)
  window_state.player.windows_by_id[window_state.id] = nil
  remove_from_windows_by_title(window_state)

  if window_state.resizing then
    destroy_invisible_frames(window_state)
  end
  window_state.frame_elem.destroy()

  if window.on_closed then
    window.on_closed(window_state)
  end
  raise_on_window_closed(window_state)
  window_state.closed = true
  return true
end

---@param window_state WindowState
---@return boolean closed_successfully @ closing the window might be cancelled, making this `false`
local function close_window(window_state)
  local result = close_window_internal(window_state)
  local new_front = window_state.player.window_list.first
  if new_front then
    bring_to_front(new_front)
  end
  return result
end

local on_resize_frame_location_changed = gui.register_handler(
  "on_resize_frame_location_changed",
  ---@param event EventData.on_gui_location_changed
  function(player, tags, event)
    local window_state = player.windows_by_id[tags.window_id]
    local elem_location = event.element.location ---@cast elem_location -nil
    -- matching the math in `position_invisible_frames`
    local offset = math.floor(10 * player.display_scale)

    if tags.movement then
      set_location(window_state, {
        x = elem_location.x - offset,
        y = elem_location.y - offset,
      })
      snap_movement(window_state)
    else
      elem_location.x = elem_location.x + offset
      elem_location.y = elem_location.y + offset
      set_size_from_location_and_direction(window_state, elem_location, tags.direction)
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
    destroy_invisible_frames(window_state)
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
        set_location_x(window_state, 0)
        set_width(window_state, window_state.player.resolution.width, anchors.top_left)
        position_invisible_frames(window_state)
        apply_location_and_size_changes(window_state)
      else
        set_location_y(window_state, 0)
        set_height(window_state, window_state.player.resolution.height, anchors.top_left)
        position_invisible_frames(window_state)
        apply_location_and_size_changes(window_state)
      end
    end
  end
)

local on_close_button_click = gui.register_handler(
  "on_close_button_click",
  ---@param event EventData.on_gui_click
  function(player, tags, event)
    close_window(player.windows_by_id[tags.window_id])
  end
)

---@param window_state WindowState
local function create_window_elements(window_state)
  local frame, inner = gui.create_elem(window_state.player.player.gui.screen, {
    type = "frame",
    direction = "vertical",
    -- needs the window_id for the generic "bring clicked window to the front" logic
    tags = {window_id = window_state.id},
    -- no event handler for on_location_changed because on location changed fires before
    -- the resolution and scale changing events. The resolution shrinking ends up
    -- moving the frames, which - if on location changed changed was registered - would
    -- cause the windows to actually change their window_state.location, which then
    -- causes the window scaling logic in on resolution changed, which in this case would
    -- make the window smaller create a gap from the window to the screen edge.
    -- As long as resolution and scale changing is the only way for the frame to move on its own,
    -- not listening to the location changed event makes for a much smoother experience.
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
            tags = {window_id = window_state.id},
            events = {[defines.events.on_gui_click] = on_resize_button_click},
          },
          {
            type = "sprite-button",
            style = "frame_action_button",
            tooltip = "Close",
            sprite = "utility/close_white",
            hovered_sprite = "utility/close_black",
            clicked_sprite = "utility/close_black",
            tags = {window_id = window_state.id},
            events = {[defines.events.on_gui_click] = on_close_button_click},
          },
        },
      },
    },
  })

  window_state.frame_elem = frame
  window_state.header_elem = inner.header_flow
  window_state.title_label = inner.title_label
  window_state.draggable_space = inner.draggable_space
  window_state.resize_button = inner.resize_button

  set_size(window_state, window_state.size, anchors.top_left)
  apply_location_and_size_changes_internal(window_state)
end

---@param player PlayerData
---@param window_type WindowType
---@param parent_window WindowState?
local function create_window(player, window_type, parent_window)
  local window = windows[window_type]
  local window_id = player.next_window_id
  player.next_window_id = window_id + 1
  ---@type WindowState
  local window_state = {
    player = player,
    window_type = window_type,
    id = window_id,
    -- frame_elem = frame,
    -- header_elem = inner.header_flow,
    -- title_label = inner.title_label,
    title = window.initial_title,
    -- draggable_space = inner.draggable_space,
    -- resize_button = inner.resize_button,
    resizing = false,
    location = {x = 0, y = 0},
    size = {
      width = window.initial_size.width,
      height = window.initial_size.height,
    },
    actual_size = { -- initialized using `apply_location_and_size_changes_internal`
      width = -1,
      height = -1,
    },
    parent_window = parent_window,
    child_windows = ll.new_list(false, "sibling"),
  }
  create_window_elements(window_state)

  add_to_windows_by_title(window_state)

  if parent_window then
    ll.prepend(parent_window.child_windows, window_state)
  end

  player.windows_by_id[window_id] = window_state

  local window_states = get_windows(player, window_type)
  window_states[#window_states+1] = window_state

  ll.append(player.window_list, window_state)
  bring_to_front_internal(window_state)

  if window.on_created then
    window.on_created(window_state)
  end

  raise_on_window_created(window_state)
end

---@param window_state WindowState
local function recreate_window(window_state)
  local old_window_state = util.shallow_copy(window_state)
  util.clear_table(window_state)
  window_state.player = old_window_state.player
  window_state.window_type = old_window_state.window_type
  window_state.id = old_window_state.id
  window_state.title = old_window_state.title
  window_state.display_title = old_window_state.display_title
  window_state.resizing = false
  window_state.location = {x = 0, y = 0}
  window_state.location = util.shallow_copy(old_window_state.location)
  window_state.size = util.shallow_copy(old_window_state.size)
  window_state.actual_size = util.shallow_copy(old_window_state.actual_size)
  window_state.location_before_rescale = util.shallow_copy(old_window_state.location_before_rescale)
  window_state.resolution_for_location_before_rescale
    = util.shallow_copy(old_window_state.resolution_for_location_before_rescale)
  window_state.size_before_rescale = util.shallow_copy(old_window_state.size_before_rescale)
  window_state.resolution_for_size_before_rescale
    = util.shallow_copy(old_window_state.resolution_for_size_before_rescale)
  window_state.parent_window = old_window_state.parent_window
  window_state.child_windows = old_window_state.child_windows
  window_state.prev_sibling = old_window_state.prev_sibling
  window_state.next_sibling = old_window_state.next_sibling
  window_state.prev = old_window_state.prev
  window_state.next = old_window_state.next
  create_window_elements(window_state)
  window_state.title_label.caption = window_state.display_title

  if old_window_state.resizing then
    destroy_invisible_frames(old_window_state)
    set_resizing(window_state, true)
  end

  -- restore back to front after setting resizing because the invisible frames also have to be in
  -- the correct "layer"
  restore_back_to_front(window_state.player)

  local window = windows[window_state.window_type]
  if window.on_created then
    window.on_created(window_state)
  end
  if window.on_recreated then
    window.on_recreated(window_state, old_window_state)
  end
end

---NOTE: `ensure_valid` is fully functional, but for it to really make sense basically every [...]
---function in the window_manager would have to call `ensure_valid` before interacting with it,
---and I really don't think that's worth it. Those other mods that destroy my windows without using
---a remote interface (that I'm probably going to make, if this ever becomes its own mod) then
---that's on them. #not_my_problem
---@param window_state WindowState
local function ensure_valid(window_state)
  if window_state.closed then
    error("Attempt to ensure a window_state is valid when it was already closed.")
  end
  if window_state.frame_elem.valid then return end
  recreate_window(window_state)
end

---@param player PlayerData
local function update_empty_widget_covering_the_entire_screen(player)
  local elem = player.empty_widget_covering_the_entire_screen
  if not elem then return end
  local resolution = player.resolution
  elem.style.size = {
    width = resolution.width / player.display_scale,
    height = resolution.height / player.display_scale,
  }
end

local on_empty_widget_covering_the_entire_screen_click = gui.register_handler(
  "on_empty_widget_covering_the_entire_screen_click",
  ---@param event EventData.on_gui_click
  function(player, tags, event)
    lose_focus(player)
  end
)

---@param player PlayerData
local function enable_click_outside_of_window_detection(player)
  if player.empty_widget_covering_the_entire_screen then return end
  player.empty_widget_covering_the_entire_screen = gui.create_elem(player.player.gui.screen, {
    type = "empty-widget",
    events = {[defines.events.on_gui_click] = on_empty_widget_covering_the_entire_screen_click},
  })
  update_empty_widget_covering_the_entire_screen(player)
end

---@param player PlayerData
local function disable_click_outside_of_window_detection(player)
  if not player.empty_widget_covering_the_entire_screen then return end
  player.empty_widget_covering_the_entire_screen.destroy()
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
  local main_elem = event.element
  local parent = main_elem.parent
  -- just in case there is some way for the root LuaGuiElements to be clickable
  if not parent then return end
  local grand_parent = parent.parent
  while grand_parent do
    main_elem = parent
    parent = grand_parent
    grand_parent = grand_parent.parent
  end
  local tags = gui.try_get_tags(main_elem)
  if not tags or not tags.window_id then return end
  local window_state = player.windows_by_id[tags.window_id]
  bring_to_front(window_state)
end

---@param player PlayerData
local function update_screen_edge_windows(player)
  local resolution = player.resolution
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
end

---@param event EventData.on_player_display_resolution_changed
local function on_player_display_resolution_changed(event)
  local player = util.get_player(event)
  if not player then return end
  local resolution = player.player.display_resolution
  player.resolution = resolution
  update_screen_edge_windows(player)
  update_empty_widget_covering_the_entire_screen(player)
  for _, window_state in pairs(player.windows_by_id) do
    if not window_state.is_window_edge then
      -- stop all resizing because window scaling is handled differently
      -- unfortunately the location changed events for the resize frames happen before this event
      -- so there will be a gap round this window and the screen edge if resizing was enabled
      if window_state.resizing then
        set_resizing(window_state, false)
      end

      if not window_state.location_before_rescale then
        window_state.location_before_rescale = {
          x = window_state.location.x,
          y = window_state.location.y,
        }
        window_state.resolution_for_location_before_rescale = event.old_resolution
      end

      if not window_state.size_before_rescale then
        window_state.size_before_rescale = {
          width = window_state.size.width,
          height = window_state.size.height,
        }
        window_state.resolution_for_size_before_rescale = event.old_resolution
      end

      local size = window_state.size_before_rescale
      local resolution_for_size_before_rescale = window_state.resolution_for_size_before_rescale
      ---@cast size -nil
      ---@cast resolution_for_size_before_rescale -nil
      local x_multiplier = (resolution.width / resolution_for_size_before_rescale.width)
      local y_multiplier = (resolution.height / resolution_for_size_before_rescale.height)
      set_width(window_state, math.floor(0.5 + size.width * x_multiplier), anchors.top_left)
      set_height(window_state, math.floor(0.5 + size.height * y_multiplier), anchors.top_left)
      window_state.size_before_rescale = size
      window_state.resolution_for_size_before_rescale = resolution_for_size_before_rescale

      local location_before_rescale = window_state.location_before_rescale
      local resolution_for_location_before_rescale = window_state.resolution_for_size_before_rescale
      ---@cast location_before_rescale -nil
      ---@cast resolution_for_location_before_rescale -nil
      x_multiplier = (resolution.width / resolution_for_location_before_rescale.width)
      y_multiplier = (resolution.height / resolution_for_location_before_rescale.height)
      set_location_x(window_state, math.floor(0.5 + location_before_rescale.x * x_multiplier))
      set_location_y(window_state, math.floor(0.5 + location_before_rescale.y * y_multiplier))
      window_state.location_before_rescale = location_before_rescale
      window_state.resolution_for_location_before_rescale = resolution_for_location_before_rescale

      apply_location_and_size_changes(window_state)
    end
  end
end

---@param event EventData.on_player_display_scale_changed
local function on_player_display_scale_changed(event)
  local player = util.get_player(event)
  if not player then return end
  player.display_scale = player.player.display_scale
  update_empty_widget_covering_the_entire_screen(player)
  for _, window_state in pairs(player.windows_by_id) do
    if not window_state.is_window_edge then
      -- changing the scale affects the minimal_size, so we reapply width and height
      set_size(window_state, window_state.size, anchors.top_left)
      -- and applying size to the gui element depends on scale regardless of size having changed
      apply_location_and_size_changes(window_state)
      if window_state.resizing then
        position_invisible_frames(window_state)
      end
    end
  end
end

local just_loaded_save = false
local loading_one_tick_delay = true

---@param event EventData.on_tick
local function on_tick(event)
  if just_loaded_save then
    if loading_one_tick_delay then
      loading_one_tick_delay = false
    else
      just_loaded_save = false
      for _, player in pairs(global.players) do
        restore_back_to_front(player)
      end
    end
  end
end

local function on_load()
  just_loaded_save = true
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
  player.resolution = player.player.display_resolution
  player.display_scale = player.player.display_scale
  player.windows_by_title = {}
  update_screen_edge_windows(player)
end

---@class __gui-editor__.window_manager
return {
  on_window_created = on_window_created,
  on_window_closed = on_window_closed,
  on_display_title_changed = on_display_title_changed,
  register_window = register_window,
  get_windows = get_windows,
  get_window = get_window,
  position_invisible_frames = position_invisible_frames,
  directions = directions,
  get_horizontal_direction_multiplier = get_horizontal_direction_multiplier,
  get_vertical_direction_multiplier = get_vertical_direction_multiplier,
  anchors = anchors,
  opposite_anchors = opposite_anchors,
  anchors_for_direction = anchors_for_direction,
  get_anchor_x = get_anchor_x,
  get_anchor_y = get_anchor_y,
  get_anchor = get_anchor,
  set_width = set_width,
  set_height = set_height,
  set_size = set_size,
  set_width_from_location = set_width_from_location,
  set_height_from_location = set_height_from_location,
  set_size_from_location = set_size_from_location,
  set_size_from_location_and_direction = set_size_from_location_and_direction,
  set_location_x = set_location_x,
  set_location_y = set_location_y,
  set_location = set_location,
  set_location_x_from_location = set_location_x_from_location,
  set_location_y_from_location = set_location_y_from_location,
  overlapping_horizontally = overlapping_horizontally,
  overlapping_vertically = overlapping_vertically,
  snap_horizontally = snap_horizontally,
  snap_vertically = snap_vertically,
  snap_movement = snap_movement,
  snap_resize = snap_resize,
  apply_location_and_size_changes = apply_location_and_size_changes,
  bring_to_front = bring_to_front,
  close_window = close_window,
  set_resizing = set_resizing,
  set_title = set_title,
  create_window = create_window,
  ensure_valid = ensure_valid,
  enable_click_outside_of_window_detection = enable_click_outside_of_window_detection,
  disable_click_outside_of_window_detection = disable_click_outside_of_window_detection,
  on_gui_click = on_gui_click,
  on_player_display_resolution_changed = on_player_display_resolution_changed,
  on_player_display_scale_changed = on_player_display_scale_changed,
  on_tick = on_tick,
  on_load = on_load,
  init_player = init_player,
}
