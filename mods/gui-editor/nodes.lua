
local hierarchy = depends("__gui-editor__.hierarchy")
local inspector = depends("__gui-editor__.inspector")

---@param player PlayerData
---@param parent_elem LuaGuiElement
---@param args NodeLuaGuiElement.add_param
---@return Node
local function create_node_internal(player, parent_elem, args)
  local elem = parent_elem.add(args)
  local id = player.next_node_id
  player.next_node_id = id + 1
  local node = {
    id = id,
    node_name = args.node_name,
    elem = elem,
    children = {},
  }
  player.nodes_by_id[id] = node
  return node
end

---@param player PlayerData
---@param parent_node Node
---@param args NodeLuaGuiElement.add_param
---@return Node
local function create_node(player, parent_node, args)
  local node = create_node_internal(player, parent_node.elem, args)
  node.parent = parent_node
  parent_node.children[#parent_node.children+1] = node
  return node
end

---@param player PlayerData
---@param node Node?
local function set_selected_node(player, node)
  if player.selected_node == node then return end
  player.selected_node = node
  hierarchy.update_hierarchy(player)
  inspector.update_inspector(player)
end

---@class __gui-editor__.nodes
return {
  create_node_internal = create_node_internal,
  create_node = create_node,
  set_selected_node = set_selected_node,
}
