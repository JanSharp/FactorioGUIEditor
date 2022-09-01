
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local hierarchy = depends("__gui-editor__.hierarchy")
local inspector = depends("__gui-editor__.inspector")

---@param player PlayerData
---@param parent_elem LuaGuiElement
---@param type string
---@param node_name string
---@return Node
local function create_node_internal(player, parent_elem, type, node_name)
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
  local elem = parent_elem.add(args)
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
    children = {},
  }
  player.nodes_by_id[id] = node
  return node
end

---@param player PlayerData
---@param parent_node Node
---@param type string
---@param node_name string
---@return Node
local function create_node(player, parent_node, type, node_name)
  local node = create_node_internal(player, parent_node.elem, type, node_name)
  node.parent = parent_node
  parent_node.children[#parent_node.children+1] = node
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
    if node.parent then
      -- non root nodes cannot have `auto_center`
      if field.name == "auto_center" then
        goto continue
      end
    else
      -- root nodes cannot have `drag_target`
      if field.name == "drag_target" then
        goto continue
      end
    end
    if field.write then
      elem[field.name] = elem_data[field.name]
    end
    ::continue::
  end
  for _, child_node in pairs(node.children) do
    rebuild_elem_internal(child_node, elem)
  end
end

---@param node Node
local function rebuild_elem(node)
  rebuild_elem_internal(node, node.elem.parent)
end

---@class __gui-editor__.nodes
return {
  create_node_internal = create_node_internal,
  create_node = create_node,
  clear_cursors = clear_cursors,
  clear_selection = clear_selection,
  add_cursor_node = add_cursor_node,
  add_selected_node = add_selected_node,
  remove_cursor_node = remove_cursor_node,
  remove_selected_node = remove_selected_node,
  finish_changing_selection = finish_changing_selection,
  rebuild_elem = rebuild_elem,
}
