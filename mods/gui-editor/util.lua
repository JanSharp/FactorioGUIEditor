
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

---@generic T
---@param tab T[]
---@return table<T, true>
local function invert(tab)
  local lut = {}
  for _, value in pairs(tab) do
    lut[value] = true
  end
  return lut
end

---@class __gui-editor__.util
return {
  gui_elem_types = gui_elem_types,
  get_player = get_player,
  invert = invert,
}
