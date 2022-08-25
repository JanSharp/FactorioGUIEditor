
local gui_elem_types = {
  "button",
  "sprite-button",
  "checkbox",
  "flow",
  "frame",
  "label",
  "line",
  "progressbar",
  "table",
  "textfield",
  "radiobutton",
  "sprite",
  "scroll-pane",
  "drop-down",
  "list-box",
  "camera",
  "choose-elem-button",
  "text-box",
  "slider",
  "minimap",
  "entity-preview",
  "empty-widget",
  "tabbed-pane",
  "tab",
  "switch",
}

---@return PlayerData
local function get_player(event)
  return global.players[event.player_index]
end

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
    local player = get_player(event)
    if not player then return end
    for handler_name in pairs(tag_data.handler_names) do
      local handler = handlers_by_name[gui_event_define] and handlers_by_name[gui_event_define][handler_name]
      if handler then
        handler(player, tag_data, event)
      end
    end
  end)
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

local update_hierarchy
local update_inspector

---@param player PlayerData
---@param node Node?
local function set_selected_node(player, node)
  if player.selected_node == node then return end
  player.selected_node = node
  update_hierarchy(player)
  update_inspector(player)
end

---@param player PlayerData
local on_hierarchy_row_click = register_handler(defines.events.on_gui_click, "on_hierarchy_row_click", function(player, tags)
  set_selected_node(player, player.nodes_by_id[tags.node_id])
end)

---@param player PlayerData
local on_deselect_widget_click = register_handler(defines.events.on_gui_click, "on_deselect_widget_click", function(player)
  set_selected_node(player, nil)
end)

---@param player PlayerData
---@param node Node
---@return string
local function get_hierarchy_label_caption(player, node)
  return node == player.selected_node and ("[font=default-bold]"..node.node_name.."[/font]") or node.node_name
end

---@param player PlayerData
function update_hierarchy(player)
  for _, child in pairs(player.hierarchy_elem.children) do
    child.destroy()
  end
  ---@param node Node
  ---@param depth integer
  local function create_row(node, depth)
    local _, inner = create_elem(player.hierarchy_elem, {
      type = "flow",
      direction = "horizontal",
      style_mods = {padding = 0, margin = 0, left_padding = depth * 8},
      children = {
        {
          type = "label",
          name = "label",
          caption = get_hierarchy_label_caption(player, node),
          tags = {node_id = node.id},
          events = {on_hierarchy_row_click},
        },
      },
    })
    ---@cast inner -?
    node.hierarchy_label = inner.label
    for _, child in pairs(node.children) do
      create_row(child, depth + 1)
    end
  end
  for _, root in pairs(player.roots) do
    create_row(root, 0)
  end
  create_elem(player.hierarchy_elem, {
    type = "empty-widget",
    style_mods = {
      horizontally_stretchable = true,
      height = 400,
    },
    elem_mods = {
      ignored_by_interaction = true,
    },
  })
end

---@param player PlayerData
local on_inspector_name_text_changed = register_handler(defines.events.on_gui_text_changed, "on_inspector_name_text_changed", function(player, _, event)
  player.selected_node.node_name = event.element.text
  player.selected_node.hierarchy_label.caption = get_hierarchy_label_caption(player, player.selected_node)
end)

---@param player PlayerData
---@param tags any
---@param checkbox_elem LuaGuiElement
local function on_boolean_editor_state_changed_internal(player, tags, checkbox_elem)
  ---@diagnostic disable-next-line: assign-type-mismatch
  player.nodes_by_id[tags.node_id].elem[tags.field_name] = checkbox_elem.state
end

---@param player PlayerData
---@param event EventData.on_gui_click
local on_boolean_editor_label_click = register_handler(defines.events.on_gui_click, "on_boolean_editor_label_click", function(player, _, event)
  local checkbox_elem = event.element.parent.checkbox
  checkbox_elem.state = not checkbox_elem.state
  on_boolean_editor_state_changed_internal(player, checkbox_elem.tags.__gui_editor, checkbox_elem)
end)

---@param player PlayerData
---@param tags any
---@param event EventData.on_gui_checked_state_changed
local on_boolean_editor_state_changed = register_handler(defines.events.on_gui_checked_state_changed, "on_boolean_editor_state_changed", function(player, tags, event)
  on_boolean_editor_state_changed_internal(player, tags, event.element)
end)

---@param inspector LuaGuiElement
---@param node Node
---@param field_name string
local function boolean_editor(inspector, node, field_name)
  local success, value = pcall(function() return node.elem[field_name] end)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast value boolean
  if not success then return end

  create_elem(inspector, {
    type = "flow",
    direction = "horizontal",
    children = {
      {
        type = "label",
        caption = field_name,
        events = {on_boolean_editor_label_click},
      },
      {
        type = "empty-widget",
        style_mods = {horizontally_stretchable = true},
      },
      {
        type = "checkbox",
        name = "checkbox",
        state = value,
        tags = {
          node_id = node.id,
          field_name = field_name,
        },
        events = {on_boolean_editor_state_changed},
      },
    },
  })
end

---@param player PlayerData
---@param tags any
---@param event EventData.on_gui_text_changed
local on_string_editor_state_changed = register_handler(defines.events.on_gui_text_changed, "on_string_editor_state_changed", function(player, tags, event)
  ---@diagnostic disable-next-line: assign-type-mismatch
  player.nodes_by_id[tags.node_id].elem[tags.field_name] = event.element.text
end)

---@param inspector LuaGuiElement
---@param node Node
---@param field_name string
local function string_editor(inspector, node, field_name)
  local success, value = pcall(function() return node.elem[field_name] end)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast value string
  if not success then return end

  create_elem(inspector, {
    type = "flow",
    direction = "horizontal",
    children = {
      {
        type = "label",
        caption = field_name,
      },
      {
        type = "empty-widget",
        style_mods = {horizontally_stretchable = true},
      },
      {
        type = "textfield",
        text = value,
        tags = {
          node_id = node.id,
          field_name = field_name,
        },
        events = {on_string_editor_state_changed},
      },
    },
  })
end

---@param player PlayerData
function update_inspector(player)
  local inspector = player.inspector_elem
  for _, child in pairs(inspector.children) do
    child.destroy()
  end
  local node = player.selected_node
  if not node then return end
  create_elem(inspector, {
    type = "textfield",
    text = node.node_name,
    -- didn't do anything for some reason
    -- style_mods = {
    --   horizontally_stretchable = true,
    -- },
    events = {on_inspector_name_text_changed},
  })
  string_editor(inspector, node, "caption")
  boolean_editor(inspector, node, "enabled")
  boolean_editor(inspector, node, "visible")
  boolean_editor(inspector, node, "ignored_by_interaction")
  string_editor(inspector, node, "text")
end

---@param player PlayerData
---@param _ any
---@param event EventData.on_gui_selection_state_changed
local on_new_drop_down = register_handler(defines.events.on_gui_selection_state_changed, "on_new_drop_down", function(player, _, event)
  local index = event.element.selected_index
  if index == 0 then return end
  event.element.selected_index = 0
  local node
  if player.selected_node then
    node = create_node(player, player.selected_node, {
      type = gui_elem_types[index],
      node_name = "child "..gui_elem_types[index],
      caption = "child "..gui_elem_types[index],
    })
  else
    node = create_node_internal(player, player.player.gui.screen, {
      type = gui_elem_types[index],
      node_name = "root "..gui_elem_types[index],
      caption = "root "..gui_elem_types[index],
    })
    player.roots[#player.roots+1] = node
  end
  set_selected_node(player, node)
end)

-- using a file level local just for the `print` will not cause a desync
local do_restart = false
local on_restart_click = register_handler(defines.events.on_gui_click, "on_restart_click", function(player)
  game.auto_save("gui-editor")
  game.tick_paused = false
  -- delay by 1 tick because it seems when the game is tick paused `game.tick` already reports the tick the next `on_tick` is going to get
  -- this ultimately makes me believe that when the game is tick paused it's paused somewhere close to the beginning of a tick
  -- which causes a problem here because the auto save happens at the end of the tick and we need to restart the game the next tick
  -- which means we have to ignore the first on_tick we get since that is still this tick before the auto save happened
  global.restart_tick = game.tick + 1
  do_restart = true
end)

script.on_event(defines.events.on_tick, function(event)
  if event.tick == global.restart_tick then
    if do_restart then
      print("<>gui_editor:restart<>")
    end
    -- the fact that the game got set back to being tick paused does need to happen regardless of the game still running or loading the save
    -- so it must be outside of the `do_restart` if block
    game.tick_paused = true
  end
end)

---@param player PlayerData
local function update_window_sizes(player)
  local resolution = player.player.display_resolution
  local height = resolution.height
  player.inspector_window_elem.style.height = height
  player.hierarchy_window_elem.style.height = height
  local inspector_width = math.floor(resolution.width * 0.3)
  player.inspector_window_elem.style.width = inspector_width
  player.inspector_window_elem.location = {resolution.width - inspector_width, 0}
  local hierarchy_width = math.floor((inspector_width / 0.3) * 0.2)
  player.hierarchy_window_elem.style.width = hierarchy_width
  player.hierarchy_window_elem.location = {resolution.width - inspector_width - hierarchy_width, 0}
end

script.on_event(defines.events.on_player_display_resolution_changed, function(event)
  local player = get_player(event)
  if not player then return end
  update_window_sizes(player)
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  local gvs = player.game_view_settings
  gvs.show_controller_gui = false
  gvs.show_minimap = false
  gvs.show_research_info = false
  gvs.show_entity_info = false
  gvs.show_alert_gui = false
  gvs.update_entity_selection = false
  gvs.show_rail_block_visualisation = false
  gvs.show_side_menu = false
  gvs.show_map_view_options = false
  gvs.show_quickbar = false
  gvs.show_shortcut_bar = false

  local hierarchy_window_elem, hierarchy_inner = create_elem(player.gui.screen, {
    type = "frame",
    direction = "vertical",
    caption = "Hierarchy",
    children = {
      {
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame",
        style_mods = {
          horizontally_stretchable = true,
          vertically_stretchable = true,
        },
        children = {
          {
            type = "flow",
            direction = "horizontal",
            children = {
              {
                type = "drop-down",
                items = gui_elem_types,
                style_mods = {horizontally_stretchable = true},
                events = {on_new_drop_down},
                children = {
                  {
                    type = "label",
                    caption = "[color=#000000]Create new ...[/color]",
                    elem_mods = {ignored_by_interaction = true},
                  },
                },
              },
              {
                type = "sprite-button",
                sprite = "restart_required",
                tooltip = {"gui.restart"},
                events = {on_restart_click},
              },
            },
          },
          {
            type = "empty-widget",
            style_mods = {height = 6};
          },
          {
            type = "frame",
            direction = "vertical",
            style = "inside_deep_frame",
            style_mods = {
              horizontally_stretchable = true,
              vertically_stretchable = true,
            },
            children = {
              {
                type = "scroll-pane",
                style_mods = {
                  horizontally_stretchable = true,
                  vertically_stretchable = true,
                  padding = 4,
                },
                children = {
                  {
                    type = "flow",
                    direction = "vertical",
                    name = "hierarchy",
                    style_mods = {
                      vertical_spacing = 0,
                    },
                    events = {on_deselect_widget_click},
                  },
                },
              },
            },
          },
        },
      },
    },
  })
  ---@cast hierarchy_inner -?

  local inspector_window_elem, inspector_inner = create_elem(player.gui.screen, {
    type = "frame",
    direction = "horizontal",
    caption = "Inspector",
    children = {
      {
        type = "frame",
        direction = "vertical",
        name = "inspector",
        style = "inside_shallow_frame",
        style_mods = {
          horizontally_stretchable = true,
          vertically_stretchable = true,
          padding = 4,
        },
      },
    },
  })
  ---@cast inspector_inner -?

  ---@type PlayerData
  local player_data = {
    player = player,
    hierarchy_window_elem = hierarchy_window_elem,
    inspector_window_elem = inspector_window_elem,
    roots = {},
    hierarchy_elem = hierarchy_inner.hierarchy,
    inspector_elem = inspector_inner.inspector,
    selected_node = nil,
    nodes_by_id = {},
    next_node_id = 0,
  }
  global.players[event.player_index] = player_data
  update_window_sizes(player_data)
end)

script.on_init(function()
  global.players = {}
  game.tick_paused = true
end)

for name, id in pairs(defines.events) do
  if name:find("^on_gui") then
    handle_gui_event(id)
  end
end
