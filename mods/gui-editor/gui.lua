
local util = require("__gui-editor__.util")

---@type table<function, string>
local handlers_by_func = {}
---@type table<string, function>
local handlers_by_name = {}

---@generic T
---@param event_define defines.events
---@param name string
---@param handler T
---@return T
local function register_handler(event_define, name, handler)
  handlers_by_func[handler] = name
  handlers_by_name[event_define] = handlers_by_name[event_define] or {}
  handlers_by_name[event_define][name] = handler
  return handler
end

---@param gui_event_define defines.events @ any gui event
local function handle_gui_event(gui_event_define)
  ---@param event EventData.on_gui_click @ any gui event
  script.on_event(gui_event_define, function(event)
    if not event.element then return end
    local tags = event.element.tags
    if not tags or not tags.__gui_editor then return end
    local tag_data = tags.__gui_editor
    if not tag_data.handler_names then return end
    local player = util.get_player(event)
    if not player then return end
    for handler_name in pairs(tag_data.handler_names) do
      local handler = handlers_by_name[gui_event_define] and handlers_by_name[gui_event_define][handler_name]
      if handler then
        handler(player, tag_data, event)
      end
    end
  end)
end

local function handle_all_gui_events()
  for name, id in pairs(defines.events) do
    if name:find("^on_gui") then
      handle_gui_event(id)
    end
  end
end

---@param parent_elem LuaGuiElement
---@param args ExtendedLuaGuiElement.add_param
---@param elems table<string, LuaGuiElement>?
---@return LuaGuiElement elem
---@return table<string, LuaGuiElement>? inner_elems
local function create_elem(parent_elem, args, elems)
  local children = args.children
  local style_mods = args.style_mods
  local elem_mods = args.elem_mods
  local events = args.events
  local tags = args.tags
  args.children = nil
  args.style_mods = nil
  args.elem_mods = nil
  args.events = nil
  if tags then
    args.tags = {__gui_editor = tags}
  end
  if events then
    local handler_names = {}
    for _, handler in pairs(events) do
      handler_names[handlers_by_func[handler]] = true
    end
    args.tags = args.tags or {__gui_editor = {}}
    args.tags.__gui_editor.handler_names = handler_names
  end
  local elem = parent_elem.add(args)
  if args.name then
    elems = elems or {}
    elems[args.name] = elem
  end
  if style_mods then
    local style = elem.style
    for k, v in pairs(style_mods) do
      style[k] = v
    end
  end
  if elem_mods then
    for k, v in pairs(elem_mods) do
      elem[k] = v
    end
  end
  if children then
    for _, child in pairs(children) do
      _, elems = create_elem(elem, child, elems)
    end
  end
  args.children = children
  args.style_mods = style_mods
  args.elem_mods = elem_mods
  args.events = events
  args.tags = tags
  if tags then
    tags.handler_names = nil
  end
  return elem, elems
end

---@class __gui-editor__.gui
return {
  register_handler = register_handler,
  handle_gui_event = handle_gui_event,
  handle_all_gui_events = handle_all_gui_events,
  create_elem = create_elem,
}
