
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
---@field flat_nodes Node[] @ flat list of all nodes, generated by update_hierarchy
---@field selected_nodes table<Node, true> @ if there is any node in here there is also at least one cursor node
---@field cursor_nodes table<Node, true> @ all cursor nodes are also selected nodes
---@field dirty_selection boolean @ has selection been changed without updating the hierarchy and the inspector?
---@field nodes_by_id table<integer, Node>
---@field next_node_id integer

---@class ExtendedLuaGuiElement.add_param : LuaGuiElement.add_param
---@field children ExtendedLuaGuiElement.add_param[]?
---@field style_mods LuaStyle?
---@field elem_mods LuaGuiElement?
---@field events function[]?

---@class Node
---@field id integer @ per player unique id
---@field flat_index integer @ index in the `flat_nodes` list
---@field parent Node?
---@field node_name string
---@field children Node[]
---@field elem LuaGuiElement
---@field elem_data LuaGuiElement @ isn't actually a LuaGuiElement, but has almost all of its fields
---@field hierarchy_button LuaGuiElement

---@class NodeLuaGuiElement.add_param : LuaGuiElement.add_param
---@field node_name string

---@class Field : ApiAttribute

-- refer to https://lua-api.factorio.com/latest/json-docs.html

---@class ApiAttribute
---@field name string @ The name of the attribute.
---@field order number @ The order of the attribute as shown in the html.
---@field description string @ The text description of the attribute.
---@field notes string[]? @ A list of strings containing additional information about the attribute.
---@field examples string[]? @ A list of strings containing example code and explanations.
---@field raises ApiEventRaised[]? @ A list of events that this attribute might raise when written to.
---@field subclasses string[]? @ A list of strings specifying the sub-type (of the class) that the attribute applies to.
---@field type ApiType @ The type of the attribute.
---@field optional boolean @ Whether the attribute is optional or not.
---@field read boolean @ Whether the attribute can be read from.
---@field write boolean @ Whether the attribute can be written to.

---@class ApiEventRaised
---@field name string @ The name of the event being raised.
---@field order number @ The order of the member as shown in the html.
---@field description string @ The text description of the raised event.
---@field timeframe "instantly"|"current_tick"|"future_tick" @ The timeframe during which the event is raised. One of "instantly", "current_tick", or "future_tick".
---@field optional boolean @ Whether the event is always raised, or only dependant on a certain condition.

---@alias ApiType ApiBasicType|ApiComplexType
---@alias ApiBasicType string
---@class ApiComplexType
---@field complex_type "type"|"union"|"array"|"dictionary"|"LuaCustomTable"|"function"|"literal"|"LuaLazyLoadedValue"|"struct"|"table"|"tuple"
---@field value ApiType|string|number|boolean
---@field description string
---@field options ApiType[]
---@field full_format boolean
---@field key ApiType
---@field parameters ApiType[]|ApiParameter[]
---@field attributes ApiAttribute[]
---@field variant_parameter_groups ApiParameterGroup[]
---@field variant_parameter_description string

---@class ApiParameter
---@field name string @ The name of the parameter.
---@field order number @ The order of the parameter as shown in the html.
---@field description string @ The text description of the parameter.
---@field type ApiType @ The type of the parameter.
---@field optional boolean @ Whether the type is optional or not.

---@class ApiParameterGroup
---@field name string @ The name of the parameter group.
---@field order number @ The order of the parameter group as shown in the html.
---@field description string @ The text description of the parameter group.
---@field parameters ApiParameter[] @ The parameters that the group adds.
