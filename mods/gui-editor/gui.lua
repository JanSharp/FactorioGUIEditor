
local util = require("__gui-editor__.util")

---@type table<function, string>
local handlers_by_func = {}
---@type table<string, function>
local handlers_by_name = {}

---@type table<defines.events, string>
local event_id_to_name = {}
for name, id in pairs(defines.events) do
  if name:find("^on_gui") then
    event_id_to_name[id] = name
  end
end

---@generic T
---@param name string
---@param handler fun(player: PlayerData, tags: any, event: T)
local function register_handler(name, handler)
  handlers_by_func[handler] = name
  handlers_by_name[name] = handler
  return handler
end

---@param element LuaGuiElement
---@return any?
local function try_get_tags(element)
  local tags = element.tags
  if not tags or not tags.__gui_editor then return end
  local tag_data = tags.__gui_editor
  return tag_data
end

---@param event EventData.on_gui_click @ any gui event
local function handle_gui_event(event)
  if not event.element then return end
  local tags = event.element.tags
  if not tags or not tags.__gui_editor then return end
  local tag_data = tags.__gui_editor
  local handler_names = tag_data.handlers and tag_data.handlers[event_id_to_name[event.name]]
  if not handler_names then return end
  local player = util.get_player(event)
  if not player then return end
  for handler_name in pairs(handler_names) do
    local handler = handlers_by_name[handler_name]
    if handler then
      handler(player, tag_data, event)
    end
  end
end

---@param gui_event_define defines.events @ any gui event
local function register_for_gui_event(gui_event_define)
  script.on_event(gui_event_define, handle_gui_event)
end

local function register_for_all_gui_events()
  for name, id in pairs(defines.events) do
    if name:find("^on_gui") then
      register_for_gui_event(id)
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
    local handlers = {}
    for event_id, handler in pairs(events) do
      local event_name = event_id_to_name[event_id]
      handlers[event_name] = handlers[event_name] or {}
      handlers[event_name][handlers_by_func[handler]] = true
    end
    args.tags = args.tags or {__gui_editor = {}}
    args.tags.__gui_editor.handlers = handlers
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
  try_get_tags = try_get_tags,
  handle_gui_event = handle_gui_event,
  register_for_gui_event = register_for_gui_event,
  register_for_all_gui_events = register_for_all_gui_events,
  create_elem = create_elem,
}
