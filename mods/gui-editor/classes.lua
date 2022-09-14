
---@class GlobalData
---@field players table<integer, PlayerData>
---@field restart_tick integer?

---@class PlayerData
---@field player LuaPlayer
---@field hierarchy_window_elem LuaGuiElement
---@field inspector_window_elem LuaGuiElement
---@field hierarchy_elem LuaGuiElement
---@field inspector_elem LuaGuiElement
---@field active_editors table<string, table<string, EditorState>>
-- ---@field inspector_editors table<string, EditorData>
---@field main_node MainNode
---@field flat_nodes Node[] @ flat list of all nodes, generated by update_hierarchy
---@field selected_nodes table<Node, true> @ if there is any node in here there is also at least one cursor node
---@field cursor_nodes table<Node, true> @ all cursor nodes are also selected nodes
---@field dirty_selection boolean @ has selection been changed without updating the hierarchy and the inspector?
---@field nodes_by_id table<integer, Node>
---@field next_node_id integer

---@alias EditorType
---| "missing"
---| "string"
---| "drop_down"
---| "boolean"
---| "direction"
---| "node_name"

---100% static
---@class Editor
---@field editor_type EditorType
---@field create fun(editor_state: EditorState)
---@field read_display_value_from_gui fun(editor_state: EditorState)
---@field write_display_value_to_gui fun(editor_state: EditorState)
---@field get_mixed_display_value fun(editor_state: EditorState): any
---@field values_equal fun(editor_state: EditorState, left: any, right: any): boolean

---static per editor data
---@class EditorParams
---@field editor_type EditorType
---@field parent_elem LuaGuiElement
---@field window_name "inspector"|string
---@field name string
---@field description string?
---@field readonly boolean
---@field optional boolean
---@field can_error boolean
---@field missing_field Field @ used by missing editors
---@field drop_down_items string[] @ used by drop_down editors
---@field drop_down_values any[] @ used by drop_down editors, same length as `drop_down_items`

---mutable per editor data
---@class EditorState
---@field player PlayerData
---@field editor_params EditorParams
---@field editor_data EditorData
---@field display_value any
---@field mixed_values boolean?
---@field error_sprite LuaGuiElement?
---@field optional_switch LuaGuiElement?
---@field display_error_msg string?
---@field mixed_values_label LuaGuiElement
---@field wrap_elem LuaGuiElement? @ for string editors
---@field text_box_elem LuaGuiElement? @ for string editors
---@field check_box_elem LuaGuiElement? @ for boolean editors
---@field drop_down_elem LuaGuiElement? @ for drop_down editors

---static data structure describing what data is being edited
---@class EditorData
---@field data_type "missing"|"node_name"|"node_field"|"style_field"
---@field nodes_to_edit Node[]
---@field requires_rebuild boolean

---@class ExtendedLuaGuiElement.add_param : LuaGuiElement.add_param
---@field children ExtendedLuaGuiElement.add_param[]?
---@field style_mods LuaStyle?
---@field elem_mods LuaGuiElement?
---@field events table<defines.events, fun(player: PlayerData, tags: any, event: EventData)>

---@class Node
---@field id integer @ per player unique id
---@field type_flag integer
---@field is_main boolean?
---@field flat_index integer @ index in the `flat_nodes` list
---@field parent Node
---@field node_name string @ not empty, not unique, single line
---@field children NodeList
---@field elem LuaGuiElement
---@field elem_data LuaGuiElement @ isn't actually a LuaGuiElement, but has almost all of its fields
---@field errors_states table<string, {msg: string, pending_value: any?}> @ indexed by field name
---@field hierarchy_button LuaGuiElement
---@field deleted boolean? @ Deleted nodes should no longer be used anywhere, use this for cleanup
---@field prev Node?
---@field next Node?

---@class MainNode : Node
---@field is_main true @ There is only one main node. Root nodes are the children of this main node.
---@field flat_index nil
---@field parent nil
---@field node_name "root"
---@field elem_data nil
---@field hierarchy_button nil
---@field deleted nil
---@field prev nil
---@field next nil

---@class NodeList
---@field first Node?
---@field last Node?

---@class NodeLuaGuiElement.add_param : LuaGuiElement.add_param
---@field node_name string

---@class Field : ApiAttribute
---@field type_flags integer

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
