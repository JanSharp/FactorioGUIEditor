
-- using a file level local just for the `print` will not cause a desync
local restart_tick

local function restart()
  game.auto_save("gui-editor")
  -- delay by 1 tick because it seems when the game is tick paused `game.tick` already reports the
  -- tick the next `on_tick` is going to get. this ultimately makes me believe that when the game is
  -- tick paused it's paused somewhere close to the beginning of a tick which causes a problem here
  -- because the auto save happens at the end of the tick and we need to restart the game the next
  -- tick which means we have to ignore the first on_tick we get since that is still this tick
  -- before the auto save happened.
  -- while `game.tick_paused` is no longer used by the gui editor at all anymore, I kept the delay.
  -- There really isn't a reason to remove it that I can think of
  restart_tick = game.tick + 1
end

---@param event EventData.on_tick
local function on_tick(event)
  if event.tick == restart_tick then
    print("<>gui_editor:restart<>")
  end
end

---@class __gui-editor__.restart_manager
local result = {
  restart = restart,
  on_tick = on_tick,
}
return result
