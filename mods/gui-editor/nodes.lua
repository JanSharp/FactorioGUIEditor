
local util = require("__gui-editor__.util")
local ll = require("__gui-editor__.linked_list")
local gui = require("__gui-editor__.gui")
local hierarchy = depends("__gui-editor__.hierarchy")
local inspector = depends("__gui-editor__.inspector")
local scripting = depends("__gui-editor__.scripting")

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
  local static_variables = scripting.create_script_variables("static_variables")
  local dynamic_variables = scripting.create_script_variables("dynamic_variables")
  ---@type table<string, NodeField>
  local node_fields = {
    node_name = {
      field_name = "node_name",
      value = node_name,
      display_value = node_name,
    },
    static_variables = static_variables,
    dynamic_variables = dynamic_variables,
  }
  for _, field in pairs(util.fields_for_type[type]) do
    if field.name == "mouse_button_filter" then
      local mouse_button_filter = {}
      node_fields.mouse_button_filter = {
        field_name = "mouse_button_filter",
        value = mouse_button_filter,
        display_value = mouse_button_filter,
      }
      for filter in pairs(elem.mouse_button_filter) do
        mouse_button_filter[#mouse_button_filter+1] = filter
      end
    else
      local value = elem[field.name]
      node_fields[field.name] = {
        field_name = field.name,
        value = value,
        display_value = value,
      }
    end
  end
  local id = player.next_node_id
  player.next_node_id = id + 1
  ---@type Node
  local node = {
    id = id,
    type_flag = util.gui_elem_type_flags[type],
    node_name = node_name,
    -- set in update_hierarchies
    -- flat_index = nil,
    elem = elem,
    node_fields = node_fields,
    children = ll.new_list(false),
    static_variables = static_variables,
    dynamic_variables = dynamic_variables,
  }
  static_variables.node = node
  dynamic_variables.node = node
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
    hierarchy.update_hierarchies(player)
    inspector.update_inspectors(player)
    player.dirty_selection = false
  end
end

---@param node Node
---@param parent_elem LuaGuiElement
local function rebuild_elem_internal(node, parent_elem)
  local node_fields = node.node_fields
  local args = {type = node_fields.type.value}

  -- required, and some are read only after creation too
  if args.type == "table" then
    args.column_count = node_fields.column_count.value
  elseif args.type == "checkbox" or args.type == "radiobutton" then
    args.state = node_fields.state.value
  elseif args.type == "camera" then
    args.position = node_fields.position.value
  elseif args.type == "choose-elem-button" then
    args.elem_type = node_fields.elem_type.value
  end

  -- not required, but read only after creation
  if args.type == "flow" or args.type == "frame" then
    args.direction = node_fields.direction.value
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
  for _, field in pairs(util.fields_for_type[node_fields.type.value]) do
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
      if field.name == "name" then
        local node_field = node_fields[field.name]
        local success, msg = xpcall(function()
          elem[field.name] = node_field.value
        end, function(msg)
          return msg
        end)--[[@as string]]
        if not success then
          -- if there is an editor for this node and this field at the moment
          -- it will not be updated. in this case the editor has to be rebuilt.
          -- We simply do not have the references necessary to find the editor_state from here,
          -- and it is not worth adding them just for this to update in real time,
          -- which will probably never even be needed
          node_field.error_msg = msg
          node_field.display_value = node_field.value
          -- reset elem data to default
          node_field.value = elem[field.name]
        end
      else
        -- BUG: position for mini-maps is nil in node_fields? encountered when trying to move it
        elem[field.name] = node_fields[field.name].value
      end
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
  -- TODO: somehow find all nodes with pending `name` changes in their error_state which can try
  -- using that name again now
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
local result = {
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
return result
