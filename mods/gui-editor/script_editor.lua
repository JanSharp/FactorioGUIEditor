
local gui = require("__gui-editor__.gui")
local window_manager = require("__gui-editor__.window_manager")
local script_text_box = require("__gui-editor__.script_text_box")

window_manager.register_window{
  window_type = "script_editor",
  initial_title = "Script Editor",
  initial_size = {width = 600, height = 500},
  minimal_size = {width = 200, height = 200},

  ---@param window_state WindowState
  on_created = function(window_state)
    window_manager.set_resizing(window_state, true)

    local shallow_frame, inner = gui.create_elem(window_state.frame_elem, {
      type = "frame",
      direction = "vertical",
      style = "inside_shallow_frame",
      -- style_mods = {
      --   vertically_stretchable = false,
      -- },
      -- children = {
      --   {
      --     type = "scroll-pane",
      --     name = "scroll_pane",
      --     style = "naked_scroll_pane",
      --     style_mods = {
      --       padding = 8,
      --       -- vertically_stretchable = false,
      --     },
      --     -- vertical_scroll_policy = "never",
      --     horizontal_scroll_policy = "never",
      --   },
      -- },
    })
    local main_elem = inner and inner.scroll_pane or shallow_frame
    -- NOTE: the reference to the created stb should probably be stored on window_state once [...]
    -- it's all properly implemented.
    script_text_box.create(window_state.player, main_elem, {
      minimal_size = {width = 100, height = 100},
      maximal_size = {width = 2000, height = 0--[[340]]},
    })
    -- gui.create_elem(main_elem, {
    --   type = "label",
    --   caption = "foo bar baz",
    -- })

    -- gui.create_elem(window_state.frame_elem, {
    --   type = "flow",
    --   style_mods = {
    --     vertically_stretchable = true,
    --   },
    --   children = {
    --     {
    --       type = "flow",
    --       style_mods = {
    --         height = 50,
    --       },
    --       tooltip = "bye",
    --     },
    --     {
    --       type = "flow",
    --       style_mods = {
    --         vertically_stretchable = true,
    --       },
    --       tooltip = "hi",
    --     },
    --   },
    -- })
  end,
}
