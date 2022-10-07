
---cSpell:ignore krunner
-- the name is inspired by `krunner` for the kde plasma desktop environment
-- a window where you enter some text and it searches for commands, open windows, applications, etc

---cSpell:ignore lualib
local factorio_util = require("__core__.lualib.util")
local gui = require("__gui-editor__.gui")
local window_manager = require("__gui-editor__.window_manager")

---@param window_state WindowState
---@param entry RunnerListEntry
local function perform_action_for_entry(window_state, entry)
  (({
    ["create_window"] = function()
      window_manager.create_window(window_state.player, entry.window_type)
    end,
  })[entry.entry_type] or function()
    error("Unknown entry type '"..entry.entry_type.."'.")
  end)()
end

local on_runner_list_entry_click = gui.register_handler(
  "on_runner_list_entry_click",
  ---@param event EventData.on_gui_click
  function(player, tags, event)
    local window_state = window_manager.get_window(player, tags.window_id)
    perform_action_for_entry(window_state, window_state.shown_entries[tags.entry_index])
    window_manager.close_window(window_state)
  end
)

local char_to_upper_lut = {}
do
  local lower_a = string.byte("a")
  local upper_a = string.byte("A")
  for i = 0, 25 do
    char_to_upper_lut[string.char(lower_a + i)] = string.char(upper_a + i)
  end
end

---@param str string
local function capitalize_words(str)
  return str:gsub("%f[a-z](.)", char_to_upper_lut)
end

---@param entry RunnerListEntry
local function get_display_text(entry)
  return (({
    ["create_window"] = function()
      return "New "..capitalize_words(entry.window_type)
    end,
  })[entry.entry_type] or function()
    error("Not implemented entry type '"..entry.entry_type.."'.")
  end)()
end

---@param window_state WindowState
---@param entry RunnerListEntry
local function create_list_entry_button(window_state, entry)
  entry.button = gui.create_elem(window_state.list_flow, {
    type = "button",
    caption = get_display_text(entry),
    style = "list_box_item",
    style_mods = {
      horizontally_stretchable = true,
    },
    tags = {
      window_id = window_state.id,
      entry_index = entry.index,
    },
    events = {[defines.events.on_gui_click] = on_runner_list_entry_click},
  })
end

---@type table<string, RunnerListEntry>
local search_terms = {}
do
  local window_types = {
    "inspector",
    "hierarchy",
  }
  table.sort(window_types)
  for _, window_type in pairs(window_types) do
    ---@type RunnerListEntry
    local entry = {
      entry_type = "create_window",
      window_type = window_type,
    }
    search_terms[get_display_text(entry):lower()] = entry
  end
end

---@param window_state WindowState
local function update_list(window_state)
  local shown_entries = window_state.shown_entries
  for i = 1, #shown_entries do
    shown_entries[i].button.destroy()
    shown_entries[i] = nil
  end

  local i = 1

  local text_start_matches = {}
  local word_start_matches = {}
  local other_matches = {}

  -- TODO: escape input string so it's not a pattern
  local query = window_state.search_field.text:lower()
  for term, entry_base in pairs(search_terms) do
    if term:find("^"..query) then
      text_start_matches[term] = entry_base
    elseif term:find("%s"..query) then
      word_start_matches[term] = entry_base
    elseif term:find(query) then
      other_matches[term] = entry_base
    end
  end

  local function create_entries(window_type_list)
    for _, entry_base in pairs(window_type_list) do
      ---@type RunnerListEntry
      local entry = factorio_util.copy(entry_base)
      entry.index = i
      shown_entries[i] = entry
      i = i + 1
      create_list_entry_button(window_state, entry)
    end
  end

  create_entries(text_start_matches)
  create_entries(word_start_matches)
  create_entries(other_matches)
end

local on_runner_search_field_text_changed = gui.register_handler(
  "on_runner_search_field_text_changed",
  ---@param event EventData.on_gui_text_changed
  function(player, tags, event)
    update_list(window_manager.get_window(player, tags.window_id))
  end
)

local on_runner_search_field_confirmed = gui.register_handler(
  "on_runner_search_field_confirmed",
  ---@param event EventData.on_gui_confirmed
  function(player, tags, event)
    local window_state = window_manager.get_window(player, tags.window_id)
    local entry = window_state.shown_entries[1]
    if not entry then return end
    perform_action_for_entry(window_state, entry)
    window_manager.close_window(window_state)
  end
)

window_manager.register_window{
  window_type = "runner",
  title = "Runner",
  initial_size = {width = 300, height = 500},
  minimal_size = {width = 200, height = 200},

  ---@param window_state WindowState
  on_create = function(window_state)
    local _, inner = gui.create_elem(window_state.frame_elem, {
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      style_mods = {
        horizontally_stretchable = true,
        vertically_stretchable = true,
      },
      children = {
        {
          type = "flow",
          direction = "vertical",
          style_mods = {
            horizontally_stretchable = true,
            vertically_stretchable = true,
          },
          children = {
            {
              type = "textfield",
              name = "search_field",
              style_mods = {
                width = 0,
                horizontally_stretchable = true,
                bottom_margin = 8,
              },
              tags = {window_id = window_state.id},
              events = {
                [defines.events.on_gui_text_changed] = on_runner_search_field_text_changed,
                [defines.events.on_gui_confirmed] = on_runner_search_field_confirmed,
              },
            },
            {
              type = "frame",
              style = "deep_frame_in_shallow_frame",
              style_mods = {
                horizontally_stretchable = true,
                vertically_stretchable = true,
              },
              children = {
                {
                  type = "scroll-pane",
                  -- style = "list_box_in_shallow_frame_scroll_pane",
                  style = "gui_editor_list_box_scroll_pane",
                  style_mods = {
                    horizontally_stretchable = true,
                    vertically_stretchable = true,
                  },
                  horizontal_scroll_policy = "never",
                  children = {
                    {
                      type = "flow",
                      name = "list_flow",
                      direction = "vertical",
                      style_mods = {
                        horizontally_stretchable = true,
                        vertically_stretchable = true,
                        vertical_spacing = 0,
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    })

    window_state.search_field = inner.search_field
    window_state.list_flow = inner.list_flow
    window_state.shown_entries = {}
    update_list(window_state)

    window_state.search_field.focus()
  end,
}

---@param player PlayerData
local function activate_runner(player)
  local windows = window_manager.get_windows(player, "runner")
  if windows[1] then
    window_manager.bring_to_front(windows[1])
    windows[1].search_field.focus()
  else
    window_manager.create_window(player, "runner")
  end
end

---@class __gui-editor__.runner
return {
  activate_runner = activate_runner,
}
