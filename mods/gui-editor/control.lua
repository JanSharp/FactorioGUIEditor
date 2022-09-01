
require("__gui-editor__.depends")

local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local nodes = require("__gui-editor__.nodes")
local hierarchy = require("__gui-editor__.hierarchy")
local inspector = require("__gui-editor__.inspector")
local restart_manager = require("__gui-editor__.restart_manager")

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
  local player = util.get_player(event)
  if not player then return end
  update_window_sizes(player)
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  ---@cast player -?
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

  ---@type PlayerData
  local player_data = {
    player = player,
    -- set by the create calls below
    -- hierarchy_window_elem = nil,
    -- inspector_window_elem = nil,
    -- hierarchy_elem = nil,
    -- inspector_elem = nil,
    roots = {},
    selected_node = nil,
    nodes_by_id = {},
    next_node_id = 0,
  }
  global.players[event.player_index] = player_data

  hierarchy.create_hierarchy(player_data)
  inspector.create_inspector(player_data)
  update_window_sizes(player_data)
end)

script.on_init(function()
  global.players = {}
  game.tick_paused = true
end)

script.on_event(defines.events.on_tick, restart_manager.on_tick)

gui.handle_all_gui_events()
