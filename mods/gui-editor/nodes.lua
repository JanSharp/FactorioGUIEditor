
local util = require("__gui-editor__.util")
local ll = require("__gui-editor__.linked_list")
local gui = require("__gui-editor__.gui")
local hierarchy = depends("__gui-editor__.hierarchy")
local inspector = depends("__gui-editor__.inspector")

---@param node Node
---@return boolean?
local function is_root(node)
  return not node.is_main and node.parent.is_main
end

---Also returns true if `node == parent_node`
---@param node Node
---@param parent_node Node
---@return boolean?
local function is_child_of(node, parent_node)
  while node do
    if node == parent_node then
      return true
    end
    node = node.parent
  end
end

---@param player PlayerData
---@param parent_node Node
---@param type string
---@param node_name string
---@return Node
local function create_node(player, parent_node, type, node_name)
  local args = {type = type}
  if args.type == "table" then
    args.column_count = 2
  elseif args.type == "checkbox" or args.type == "radiobutton" then
    args.state = false
  elseif args.type == "camera" then
    args.position = {0, 0}
  elseif args.type == "choose-elem-button" then
    args.elem_type = "item"
  end
  local elem = parent_node.elem.add(args)
  local elem_data = {}
  for _, field in pairs(util.fields_for_type[type]) do
    if field.name == "mouse_button_filter" then
      local mouse_button_filter = {}
      elem_data.mouse_button_filter = mouse_button_filter
      for filter in pairs(elem.mouse_button_filter) do
        mouse_button_filter[#mouse_button_filter+1] = filter
      end
    else
      elem_data[field.name] = elem[field.name]
    end
  end
  local id = player.next_node_id
  player.next_node_id = id + 1
  local node = {
    id = id,
    node_name = node_name,
    -- set in update_hierarchy
    -- flat_index = nil,
    elem = elem,
    elem_data = elem_data,
    children = ll.new_list(false),
  }
  player.nodes_by_id[id] = node
  node.parent = parent_node
  ll.append(parent_node.children, node)
  return node
end

---@param player PlayerData
local function clear_cursors(player)
  if not next(player.cursor_nodes) then return end
  player.dirty_selection = true
  util.clear_table(player.cursor_nodes)
end

---@param player PlayerData
local function clear_selection(player)
  if not next(player.selected_nodes) and not next(player.cursor_nodes) then return end
  player.dirty_selection = true
  util.clear_table(player.selected_nodes)
  util.clear_table(player.cursor_nodes)
end

---@param player PlayerData
---@param node Node
local function add_cursor_node(player, node)
  if player.cursor_nodes[node] then return end
  player.dirty_selection = true
  player.selected_nodes[node] = true
  player.cursor_nodes[node] = true
end

---@param player PlayerData
---@param node Node
local function add_selected_node(player, node)
  if player.selected_nodes[node] then return end
  player.dirty_selection = true
  player.selected_nodes[node] = true
end

---@param player PlayerData
---@param node Node
local function remove_cursor_node(player, node)
  if not player.cursor_nodes[node] then return end
  player.dirty_selection = true
  player.cursor_nodes[node] = nil
end

---@param player PlayerData
---@param node Node
local function remove_selected_node(player, node)
  if not player.selected_nodes[node] then return end
  player.dirty_selection = true
  player.selected_nodes[node] = nil
  player.cursor_nodes[node] = nil
end

---@param player PlayerData
local function ensure_valid_cursor(player)
  if next(player.selected_nodes) and not next(player.cursor_nodes) then
    add_cursor_node(player, next(player.selected_nodes))
  end
end

---@param player PlayerData
local function finish_changing_selection(player)
  if player.dirty_selection then
    if next(player.selected_nodes) and not next(player.cursor_nodes) then
      error("Invalid selection: When there are selected nodes there must be at least one cursor node.")
    end
    hierarchy.update_hierarchy(player)
    inspector.update_inspector(player)
    player.dirty_selection = false
  end
end

---@param node Node
---@param parent_elem LuaGuiElement
local function rebuild_elem_internal(node, parent_elem)
  local elem_data = node.elem_data
  local args = {type = elem_data.type}

  -- required, and some are read only after creation too
  if args.type == "table" then
    args.column_count = elem_data.column_count
  elseif args.type == "checkbox" or args.type == "radiobutton" then
    args.state = elem_data.state
  elseif args.type == "camera" then
    args.position = elem_data.position
  elseif args.type == "choose-elem-button" then
    args.elem_type = elem_data.elem_type
  end

  -- not required, but read only after creation
  if args.type == "flow" or args.type == "frame" then
    args.direction = elem_data.direction
  end

  local elem = gui.create_elem(parent_elem, args)

  if node.elem.valid then
    -- if the element still exists, retain index in parent and destroy the old element
    -- this is only ever true for the root element of whichever node is being rebuilt
    -- all children will be deleted by the time they are getting rebuilt
    assert(elem.get_index_in_parent() == #parent_elem.children)
    parent_elem.swap_children(node.elem.get_index_in_parent(), (#parent_elem.children)--[[@as uint]])
    node.elem.destroy()
  end
  node.elem = elem
  for _, field in pairs(util.fields_for_type[elem_data.type]) do
    if is_root(node) then
      -- root nodes cannot have `drag_target`
      if field.name == "drag_target" then
        goto continue
      end
    else
      -- non root nodes cannot have `auto_center`
      if field.name == "auto_center" then
        goto continue
      end
    end
    if field.write then
      -- BUG: position for mini-maps is nil in elem_data? encountered when trying to move it
      elem[field.name] = elem_data[field.name]
    end
    ::continue::
  end
  local child_node = node.children.first
  while child_node do
    rebuild_elem_internal(child_node, elem)
    child_node = child_node.next
  end
end

---@param node Node
local function rebuild_elem(node)
  rebuild_elem_internal(node, node.parent.elem)
end

---@param node Node
---@param new_parent Node
---@param prev_sibling Node? @ `nil` means "become the first child of the new_parent"
local function move_node(node, new_parent, prev_sibling)
  -- move the node before rebuilding it because rebuilding tests for a node being a root node
  ll.remove(node.parent.children, node)
  ll.insert_after(new_parent.children, prev_sibling, node)
  node.parent = new_parent
  node.elem.destroy() -- destroy before rebuild so it doesn't try to use the wrong index in parent
  rebuild_elem_internal(node, new_parent.elem)
  -- move the rebuilt element to the correct index in parent
  local other_node = new_parent.children.last
  local current_index = (#new_parent.elem.children)--[[@as uint]]
  ---@cast other_node -?
  while other_node ~= node do
    new_parent.elem.swap_children(current_index - 1, current_index)
    current_index = current_index - 1
    other_node = other_node.prev
  end
end

---@param player PlayerData
---@param node Node
---@param leave_dirty boolean? @ When `false` make sure to call `ensure_valid_cursor` and `finish_changing_selection` afterwards
local function delete_node(player, node, leave_dirty)
  if node.is_main then
    error("Attempt to delete the main node.")
  end
  ---@param current_node Node
  local function delete_recursive(current_node)
    remove_selected_node(player, current_node)
    player.nodes_by_id[current_node.id] = nil
    current_node.elem.destroy()
    current_node.deleted = true
    local child_node = current_node.children.first
    while child_node do
      delete_recursive(child_node)
      child_node = child_node.next
    end
  end
  delete_recursive(node)
  ll.remove(node.parent.children, node)
  if not leave_dirty then
    ensure_valid_cursor(player)
    finish_changing_selection(player)
  end
end

---@class __gui-editor__.nodes
return {
  is_root = is_root,
  is_child_of = is_child_of,
  create_node = create_node,
  clear_cursors = clear_cursors,
  clear_selection = clear_selection,
  add_cursor_node = add_cursor_node,
  add_selected_node = add_selected_node,
  remove_cursor_node = remove_cursor_node,
  remove_selected_node = remove_selected_node,
  ensure_valid_cursor = ensure_valid_cursor,
  finish_changing_selection = finish_changing_selection,
  rebuild_elem = rebuild_elem,
  move_node = move_node,
  delete_node = delete_node,
}
