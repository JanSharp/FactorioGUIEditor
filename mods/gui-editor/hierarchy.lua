
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local nodes = depends("__gui-editor__.nodes")
local restart_manager = require("__gui-editor__.restart_manager")

---@param player PlayerData
---@param tags any
---@param event EventData.on_gui_click
local on_hierarchy_row_click = gui.register_handler(defines.events.on_gui_click, "on_hierarchy_row_click", function(player, tags, event)
  local node = player.nodes_by_id[tags.node_id]
  if event.button == defines.mouse_button_type.left then
    -- shift
    if not event.control and event.shift and not event.alt then
      for cursor_node in pairs(player.cursor_nodes) do
        for i = node.flat_index, cursor_node.flat_index, node.flat_index < cursor_node.flat_index and 1 or -1 do
          nodes.add_selected_node(player, player.flat_nodes[i])
        end
      end
      nodes.clear_cursors(player)
      nodes.add_cursor_node(player, node)
    end
    -- control
    if event.control and not event.shift and not event.alt then
      if player.selected_nodes[node] then
        nodes.remove_selected_node(player, node)
        if next(player.selected_nodes) and not next(player.cursor_nodes) then
          nodes.add_cursor_node(player, next(player.selected_nodes))
        end
      else
        nodes.clear_cursors(player)
        nodes.add_cursor_node(player, node)
      end
    end
    -- no modifiers
    if not event.control and not event.shift and not event.alt then
      nodes.clear_selection(player)
      nodes.add_cursor_node(player, node)
    end
  elseif event.button == defines.mouse_button_type.right then
    -- TODO: move nodes
  end
  nodes.finish_changing_selection(player)
end)

---@param player PlayerData
local function update_hierarchy(player)
  for _, child in pairs(player.hierarchy_elem.children) do
    child.destroy()
  end
  local flat_index = 1
  local flat_nodes = {}
  player.flat_nodes = flat_nodes
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
          caption = node.node_name,
          tooltip = "left click:\n\z
            - no modifies: Select only this node.\n\z
            - ctrl: Add/Remove this node to/from the selection.\n\z
            - shift: Add all nodes from the last selected node up to this node.\n\z
            \n\z
            right click:\n\z
            - ctrl: Move selected nodes [font=default-bold]below[/font] this node.\n\z
            - ctrl + shift: Move selected nodes [font=default-bold]above[/font] this node.\n\z
            - ctrl + alt: Move selected nodes [font=default-bold]below the last child of[/font] this node.\n\z
            - ctrl + shift + alt: Move selected nodes [font=default-bold]above the first child of[/font] this node.",
          style = player.cursor_nodes[node] and "gui_editor_node_cursor"
            or player.selected_nodes[node] and "gui_editor_node_selected"
            or "gui_editor_node_normal",
          style_mods = {horizontally_stretchable = true},
          tags = {node_id = node.id},
          events = {on_hierarchy_row_click},
        },
      },
    })
    ---@cast inner -?
    node.hierarchy_button = inner.button
    node.flat_index = flat_index
    flat_nodes[flat_index] = node
    flat_index = flat_index + 1
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
  local type = util.gui_elem_types[index]
  if next(player.cursor_nodes) then
    local cursors = player.cursor_nodes
    player.cursor_nodes = {}
    -- clear will still flag selection as dirty because it has to clear the selected_nodes
    -- besides, adding cursors will also mark it as dirty so yea we're good
    nodes.clear_selection(player)
    for selected_node in pairs(cursors) do
      local node = nodes.create_node(player, selected_node, type, type)
      nodes.add_cursor_node(player, node)
    end
    nodes.finish_changing_selection(player)
  else
    -- no cursor nodes also means no selection
    local node = nodes.create_node_internal(player, player.player.gui.screen, type, type)
    player.roots[#player.roots+1] = node
    nodes.add_cursor_node(player, node)
    nodes.finish_changing_selection(player)
  end
end)

local on_restart_click = gui.register_handler(defines.events.on_gui_click, "on_restart_click", function(player)
  restart_manager.restart()
end)

---@param player PlayerData
local on_deselect_click = gui.register_handler(defines.events.on_gui_click, "on_deselect_click", function(player)
  nodes.clear_selection(player)
  nodes.finish_changing_selection(player)
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
            style_mods = {
              top_padding = 8,
              left_padding = 8,
              right_padding = 8,
            },
            children = {
              {
                type = "drop-down",
                items = util.gui_elem_types,
                style_mods = {horizontally_stretchable = true},
                events = {on_new_drop_down},
                children = {
                  {
                    type = "label",
                    caption = "[color=#000000][font=default-semibold]Create new ...[/font][/color]",
                    elem_mods = {ignored_by_interaction = true},
                  },
                },
              },
              {
                type = "sprite-button",
                sprite = "restart_required",
                style_mods = {
                  width = 28,
                  height = 28,
                },
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
