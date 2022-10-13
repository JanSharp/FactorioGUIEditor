
-- using a file level local just for the `print` will not cause a desync
local do_restart = false

local function restart()
  game.auto_save("gui-editor")
  game.tick_paused = false
  -- delay by 1 tick because it seems when the game is tick paused `game.tick` already reports the tick the next `on_tick` is going to get
  -- this ultimately makes me believe that when the game is tick paused it's paused somewhere close to the beginning of a tick
  -- which causes a problem here because the auto save happens at the end of the tick and we need to restart the game the next tick
  -- which means we have to ignore the first on_tick we get since that is still this tick before the auto save happened
  global.restart_tick = game.tick + 1
  do_restart = true
end

---@param event EventData.on_tick
local function on_tick(event)
  if event.tick == global.restart_tick then
    if do_restart then
      print("<>gui_editor:restart<>")
    end
    -- the fact that the game got set back to being tick paused does need to happen regardless of the game still running or loading the save
    -- so it must be outside of the `do_restart` if block
    game.tick_paused = true
  end
end

---@class __gui-editor__.restart_manager
return {
  restart = restart,
  on_tick = on_tick,
}
