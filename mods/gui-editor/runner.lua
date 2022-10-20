
---cSpell:ignore krunner
-- the name is inspired by `krunner` for the kde plasma desktop environment
-- a window where you enter some text and it searches for commands, open windows, applications, etc

---cSpell:ignore lualib
local util = require("__gui-editor__.util")
local gui = require("__gui-editor__.gui")
local window_manager = require("__gui-editor__.window_manager")

---@param window_state WindowState
---@param entry RunnerListEntry
local function perform_action_for_entry(window_state, entry)
  (({
    ["create_window"] = function()
      window_manager.create_window(window_state.player, entry.window_type)
    end,
    ["focus_window"] = function()
      window_manager.bring_to_front(entry.window_state_to_focus)
    end,
    ["push_onto_display"] = function()
      local other_window_state = window_state.player.window_list.first
      while other_window_state do
        window_manager.push_onto_display(other_window_state)
        window_manager.apply_location_and_size_changes(other_window_state)
        other_window_state = other_window_state.next
      end
    end,
  })[entry.entry_type] or function()
    error("Unknown entry type '"..entry.entry_type.."'.")
  end)()
end

local on_runner_list_entry_activated = gui.register_handler(
  "on_runner_list_entry_activated",
  ---@param event EventData.on_gui_click|EventData.on_gui_confirmed
  function(player, tags, event)
    local window_state = window_manager.get_window(player, tags.window_id)
    window_manager.close_window(window_state)
    perform_action_for_entry(window_state, window_state.shown_entries[tags.entry_index])
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
    ["focus_window"] = function()
      return "Focus "..entry.window_state_to_focus.display_title
    end,
    ["push_onto_display"] = function()
      return "Push windows onto display"
    end,
  })[entry.entry_type] or function()
    error("Not implemented entry type '"..entry.entry_type.."'.")
  end)()
end

---@param window_state WindowState
---@param entry RunnerListEntry
local function create_list_entry_button(window_state, entry)
  entry.button = gui.create_elem(window_state.list_flow, {
    type = "flow",
    direction = "vertical",
    style_mods = {vertical_spacing = 0},
    children = {
      {
        type = "button",
        caption = entry.display_text,
        style = "list_box_item",
        style_mods = {
          horizontally_stretchable = true,
        },
        tags = {
          window_id = window_state.id,
          entry_index = entry.index,
        },
        events = {[defines.events.on_gui_click] = on_runner_list_entry_activated},
      },
      {
        type = "textfield",
        style = "gui_editor_selection_textfield",
        style_mods = {
          top_margin = -28,
          height = 28,
          horizontally_stretchable = true,
        },
        ignored_by_interaction = true,
        tags = {
          window_id = window_state.id,
          entry_index = entry.index,
        },
        events = {[defines.events.on_gui_confirmed] = on_runner_list_entry_activated},
      },
    },
  })
end

---@param pattern string
local function escape_lua_pattern(pattern)
  return pattern:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", {
    ["^"] = "%^",
    ["$"] = "%$",
    ["("] = "%(",
    [")"] = "%)",
    ["%"] = "%%",
    ["."] = "%.",
    ["["] = "%[",
    ["]"] = "%]",
    ["*"] = "%*",
    ["+"] = "%+",
    ["-"] = "%-",
    ["?"] = "%?",
  })
end

---@param window_state WindowState
local function update_list(window_state)
  local shown_entries = window_state.shown_entries
  for i = 1, #shown_entries do
    shown_entries[i].button.destroy()
    shown_entries[i] = nil
  end

  -- TODO: refactor search algorithm

  local i = 1

  local text_start_matches = {}
  local word_start_matches = {}
  local other_matches = {}

  local query = escape_lua_pattern(window_state.query):lower()
  for term, entry_base in pairs(window_state.player.runner_search_terms) do
    if term:find("^"..query) then
      text_start_matches[term] = entry_base
    elseif term:find("%s"..query) then
      word_start_matches[term] = entry_base
    elseif term:find(query) then
      other_matches[term] = entry_base
    end
  end

  ---@param window_type_list RunnerListEntry[]
  local function create_entries(window_type_list)
    for _, entry_base in pairs(window_type_list) do
      local entry = util.shallow_copy(entry_base)
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
    local window_state = window_manager.get_window(player, tags.window_id)
    window_state.query = window_state.search_field.text
    update_list(window_state)
  end
)

local on_runner_search_field_confirmed = gui.register_handler(
  "on_runner_search_field_confirmed",
  ---@param event EventData.on_gui_confirmed
  function(player, tags, event)
    local window_state = window_manager.get_window(player, tags.window_id)
    local entry = window_state.shown_entries[1]
    if not entry then return end
    window_manager.close_window(window_state)
    perform_action_for_entry(window_state, entry)
  end
)

window_manager.register_window{
  window_type = "runner",
  initial_title = "Runner",
  initial_size = {width = 300, height = 500},
  minimal_size = {width = 200, height = 200},

  ---@param window_state WindowState
  on_created = function(window_state)
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
    window_state.query = ""
    update_list(window_state)

    window_state.search_field.focus()

    local top_center_location = window_manager.get_anchor_location(
      window_state.player.display_dummy,
      window_manager.anchors.top_center
    )
    window_manager.set_anchor_location(
      window_state,
      top_center_location,
      window_manager.anchors.top_center
    )
    window_manager.apply_location_and_size_changes(window_state)

    window_manager.set_resizing(window_state, true)
  end,

  ---@param window_state WindowState
  ---@param old_window_state WindowState
  on_recreated = function(window_state, old_window_state)
    window_state.query = old_window_state.query
    window_state.search_field.text = old_window_state.query
    update_list(window_state)
  end,

  ---@param window_state WindowState
  on_focus_gained = function(window_state)
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

local window_types = {
  "inspector",
  "hierarchy",
}
table.sort(window_types)

---@param player PlayerData
---@param entry RunnerListEntry
---@param allow_overwrite boolean?
local function add_search_term(player, entry, allow_overwrite)
  local display_text = get_display_text(entry)
  local key = display_text:lower()
  if not allow_overwrite and player.runner_search_terms[key] then
    error("Attempt to add search term '"..display_text.."' twice.")
  end
  entry.display_text = display_text
  player.runner_search_terms[key] = entry
end

---@param player PlayerData
---@param entry RunnerListEntry
local function remove_search_term(player, entry)
  local key = entry.display_text:lower()
  if player.runner_search_terms[key] == entry then
    player.runner_search_terms[key] = nil
  end
end

---@param player PlayerData
local function init_player(player)
  player.runner_search_terms = {}
  for _, window_type in pairs(window_types) do
    add_search_term(player, {
      entry_type = "create_window",
      window_type = window_type,
    })
  end
  add_search_term(player, {entry_type = "push_onto_display"})
end

---@param player PlayerData
local function update_list_if_there_is_a_runner(player)
  local windows = window_manager.get_windows(player, "runner")
  if windows[1] then
    update_list(windows[1])
  end
end

window_manager.on_window_created(function(window_state)
  if window_state.window_type == "runner" then return end
  local entry = {
    entry_type = "focus_window",
    window_state_to_focus = window_state,
  }
  window_state.runner_search_entry = entry
  add_search_term(window_state.player, entry)
  update_list_if_there_is_a_runner(window_state.player)
end)

window_manager.on_window_closed(function(window_state)
  if window_state.window_type == "runner" then return end
  remove_search_term(window_state.player, window_state.runner_search_entry)
  update_list_if_there_is_a_runner(window_state.player)
end)

window_manager.on_display_title_changed(function(window_state)
  if window_state.window_type == "runner" then return end
  remove_search_term(window_state.player, window_state.runner_search_entry)
  add_search_term(window_state.player, window_state.runner_search_entry, true)
  update_list_if_there_is_a_runner(window_state.player)
end)

---@class __gui-editor__.runner
return {
  activate_runner = activate_runner,
  add_search_term = add_search_term,
  remove_search_term = remove_search_term,
  init_player = init_player,
}
