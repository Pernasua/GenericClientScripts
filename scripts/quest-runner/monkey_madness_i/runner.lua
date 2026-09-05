local config = gc.require("monkey_madness_config")
local behaviors = gc.require("shared_behaviors")
local shared = gc.require("shared_state")
local state_module = gc.require("monkey_madness_state")
local quest = gc.require("monkey_madness_quest")

local function read()
  return shared.read(config.id)
end

local function terminal(status, state, receipt)
  if status == "complete" then
    gc.await { action = { type = "safety.clear" }, policy = { breaks = false, cursor_release = "none", fidget = "none" } }
  end
  gc.await { action = { type = "mouse.offscreen" }, policy = { breaks = false, cursor_release = "none", fidget = "none" } }
  local result = {
    status = status,
    quest = config.id,
    varp = state.varp,
    varbits = state.varbits,
    player = state.player,
    receipt = receipt,
  }
  if receipt then
    result.recovery_attempted = receipt.recovery_attempted == true
    result.recovery_completed = receipt.recovery_completed == true
  end
  return result
end

local function wait_for_phase_change(previous)
  for _ = 1, 60 do
    gc.await { event = "game.tick" }
    local state = read()
    local phase = state_module.resolve(state)
    if phase ~= previous then return state, phase end
  end
  return nil, previous
end

local function run(input)
  gc.await { event = "game.tick" }
  local configured, behavior_failure = behaviors.configure {
    auto_retaliate = true,
    emergency_escape = true,
    combat_prayer = false,
  }
  if not configured then
    return terminal("action_failed", read(), behavior_failure)
  end
  while true do
    local state = read()
    local phase = state_module.resolve(state)
    gc.state(phase)
    gc.overlay { { label = "Quest", value = config.label } }
    if phase == "complete" or phase == "unknown_stage" then
      return terminal(phase, state)
    end
    if input.scope == "prison_cell" then
      local receipt = quest.reach_prison_cell(input)
      if not receipt or receipt.status ~= "complete" then
        return terminal("action_failed", read(), receipt)
      end
      return terminal("escape_prison_for_amulet", read(), receipt)
    end
    local receipt = quest.execute(phase, input)
    if not receipt or receipt.status ~= "complete" then
      return terminal("action_failed", read(), receipt)
    end
    local next_state, next_phase = wait_for_phase_change(phase)
    if not next_state then return terminal("phase_timeout", read(), receipt) end
    if input.scope == "checkpoint" then
      return terminal(next_phase, next_state, receipt)
    end
  end
end

return { run = run }
