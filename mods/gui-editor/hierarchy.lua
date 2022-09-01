
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local nodes = depends("__gui-editor__.nodes")
local restart_manager = require("__gui-editor__.restart_manager")

---@param player PlayerData
local on_hierarchy_row_click = gui.register_handler(defines.events.on_gui_click, "on_hierarchy_row_click", function(player, tags)
  nodes.set_selected_node(player, player.nodes_by_id[tags.node_id])
end)

---@param player PlayerData
local function update_hierarchy(player)
  for _, child in pairs(player.hierarchy_elem.children) do
    child.destroy()
  end
  ---@param node Node
  ---@param depth integer
  local function create_row(node, depth)
    local _, inner = gui.create_elem(player.hierarchy_elem, {
      type = "flow",
      direction = "horizontal",
      style_mods = {padding = 0, margin = 0, left_padding = depth * 8},
      children = {
        {
          type = "button",
          name = "button",
          style = node == player.selected_node and "gui_editor_node_selected" or "gui_editor_node_normal",
          caption = node.node_name,
          style_mods = {horizontally_stretchable = true},
          tags = {node_id = node.id},
          events = {on_hierarchy_row_click},
        },
      },
    })
    ---@cast inner -?
    node.hierarchy_button = inner.button
    for _, child in pairs(node.children) do
      create_row(child, depth + 1)
    end
  end
  for _, root in pairs(player.roots) do
    create_row(root, 0)
  end
  gui.create_elem(player.hierarchy_elem, {
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
---@param _ any
---@param event EventData.on_gui_selection_state_changed
local on_new_drop_down = gui.register_handler(defines.events.on_gui_selection_state_changed, "on_new_drop_down", function(player, _, event)
  local index = event.element.selected_index
  if index == 0 then return end
  event.element.selected_index = 0
  local node
  local type = util.gui_elem_types[index]
  if player.selected_node then
    node = nodes.create_node(player, player.selected_node, type, type)
  else
    node = nodes.create_node_internal(player, player.player.gui.screen, type, type)
    player.roots[#player.roots+1] = node
  end
  nodes.set_selected_node(player, node)
end)

local on_restart_click = gui.register_handler(defines.events.on_gui_click, "on_restart_click", function(player)
  restart_manager.restart()
end)

---@param player PlayerData
local on_deselect_click = gui.register_handler(defines.events.on_gui_click, "on_deselect_click", function(player)
  nodes.set_selected_node(player, nil)
end)

---@param player PlayerData
local function create_hierarchy(player)
  local hierarchy_window_elem, hierarchy_inner = gui.create_elem(player.player.gui.screen, {
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
                items = util.gui_elem_types,
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
                    events = {on_deselect_click},
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

  player.hierarchy_window_elem = hierarchy_window_elem
  player.hierarchy_elem = hierarchy_inner.hierarchy
end

---@class __gui-editor__.hierarchy
return {
  update_hierarchy = update_hierarchy,
  create_hierarchy = create_hierarchy,
}
