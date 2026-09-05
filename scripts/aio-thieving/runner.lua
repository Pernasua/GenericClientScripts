local behaviors = gc.require("shared_behaviors")
local config = gc.require("config")
local progress = gc.require("progress")
local training = gc.require("training")
local travel = gc.require("travel")
local ui = gc.require("shared_ui")

local function terminal(status, target, start_xp, steals, receipt)
  local thieving = gc.read("skills").thieving
  local result = {
    status = status,
    target_level = target,
    start_xp = start_xp,
    final_level = thieving.level,
    final_xp = thieving.xp,
    gained_xp = math.max(0, thieving.xp - start_xp),
    steals = steals,
  }
  if receipt then result.receipt = receipt end
  ui.park_mouse()
  return result
end

local function run(target, method)
  gc.await { event = "game.tick" }
  local target_xp = config.target_xp[tostring(target)]
  local start = gc.read("skills").thieving
  progress.begin(start.xp)
  if start.xp >= target_xp or start.level >= target then
    progress.show(target, "Target met")
    return terminal("already_complete", target, start.xp, 0)
  end
  if start.level < 5 then
    return terminal("bakery_level_required", target, start.xp, 0)
  end

  local configured, behavior_error = behaviors.configure {
    auto_retaliate = false,
    combat_prayer = false,
    emergency_escape = true,
  }
  if not configured then
    return terminal("behavior_configuration_failed", target, start.xp, 0, behavior_error)
  end
  local safety = gc.await {
    action = {
      type = "safety.configure",
      minimum_hitpoints = 1,
      consumables = config.food,
      continue_after_consumable = true,
      escape = {
        type = "walk",
        x = config.bakery.bank.x,
        y = config.bakery.bank.y,
        plane = config.bakery.bank.plane,
        within = config.bakery.bank_within,
      },
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  }
  if safety.status ~= "complete" then
    return terminal("safety_configuration_failed", target, start.xp, 0, safety)
  end

  progress.show(target, "Travelling to bakery")
  local stall, travel_error = travel.position_safely()
  if not stall then
    return terminal("bakery_arrival_failed", target, start.xp, 0, travel_error)
  end
  gc.phase("thieving." .. method .. ".arrived", { activity = "skilling" })
  gc.activity("skilling")

  local steals = 0
  local stop_requested = false
  while true do
    local thieving = gc.read("skills").thieving
    if thieving.xp >= target_xp or thieving.level >= target then break end
    if gc.next_action() == "stop_after_steal" then stop_requested = true end
    if stop_requested then break end

    if training.inventory_used() >= 28 then
      progress.show(target, "Banking loot")
      local banked, bank_error = travel.bank_all()
      if not banked then
        return terminal("banking_failed", target, start.xp, steals, bank_error)
      end
      stall, travel_error = travel.position_safely()
      if not stall then
        return terminal("bakery_return_failed", target, start.xp, steals, travel_error)
      end
      gc.activity("skilling")
    end

    local stolen, steal_error = training.steal_once(target)
    if not stolen then
      return terminal("steal_failed", target, start.xp, steals, steal_error)
    end
    steals = steals + 1
  end

  progress.show(target, stop_requested and "Banking before stop" or "Banking final loot")
  local banked, bank_error = travel.bank_all()
  if not banked then
    return terminal("final_banking_failed", target, start.xp, steals, bank_error)
  end

  local final = gc.read("skills").thieving
  if stop_requested and final.xp < target_xp and final.level < target then
    progress.show(target, "Stopped")
    return terminal("stopped", target, start.xp, steals)
  end
  progress.show(target, "Complete")
  gc.phase("thieving.target_reached")
  local result = terminal("complete", target, start.xp, steals)
  gc.log("info", "thieving-complete", result)
  return result
end

return { run = run }
