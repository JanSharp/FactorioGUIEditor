
---@class GlobalData
---@field players table<integer, PlayerData>
---@field restart_tick integer?

---@class PlayerData
---@field player LuaPlayer
---@field hierarchy_window_elem LuaGuiElement
---@field inspector_window_elem LuaGuiElement
---@field hierarchy_elem LuaGuiElement
---@field inspector_elem LuaGuiElement
---@field roots Node[]
---@field selected_node Node?
---@field nodes_by_id table<integer, Node>
---@field next_node_id integer

---@class ExtendedLuaGuiElement.add_param : LuaGuiElement.add_param
---@field children ExtendedLuaGuiElement.add_param[]?
---@field style_mods LuaStyle?
---@field elem_mods LuaGuiElement?
---@field events function[]?

---@class Node
---@field id integer @ per player unique id
---@field parent Node?
---@field node_name string
---@field children Node[]
---@field elem LuaGuiElement
---@field hierarchy_label LuaGuiElement

---@class NodeLuaGuiElement.add_param : LuaGuiElement.add_param
---@field node_name string
