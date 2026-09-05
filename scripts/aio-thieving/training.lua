local config = gc.require("config")
local progress = gc.require("progress")
local travel = gc.require("travel")

local bakery = config.bakery

local function inventory_used()
  return gc.read("inventory").occupied_slots or 0
end

local function dismiss_dialogue()
  local dialogue = gc.read("dialogue")
  if dialogue.type ~= "continue" then return true end
  local receipt = gc.await {
    action = { type = "dialogue.continue" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  if receipt.status ~= "dispatched" then
    return nil, { status = "thieving_dialogue_failed", receipt = receipt }
  end
  gc.await { event = "game.tick" }
  return true
end

local function wait_for_stall()
  for _ = 1, 16 do
    local stall = travel.resolve_stall(4)
    if stall then return stall end
    gc.await { event = "game.tick" }
  end
  return nil
end

local function steal_once(target)
  local dismissed, dialogue_error = dismiss_dialogue()
  if not dismissed then return nil, dialogue_error end
  local stall = wait_for_stall()
  if not stall then
    return nil, {
      status = "bakery_stall_respawn_timeout",
      player = gc.read("player"),
      stall_id = bakery.stall_id,
    }
  end

  local before_xp = gc.read("skills").thieving.xp
  local before_used = inventory_used()
  progress.show(target, "Stealing baked goods")
  local receipt = gc.await {
    action = {
      type = "object.interact",
      id = stall.id,
      action = bakery.action,
      world = stall.world,
      within = 4,
    },
    activity = "skilling",
    timeout = { game_ticks = 30 },
  }
  if receipt.status ~= "dispatched" then
    return nil, { status = "bakery_steal_failed", stall = stall, receipt = receipt }
  end

  for _ = 1, 12 do
    gc.await { event = "game.tick" }
    local xp = gc.read("skills").thieving.xp
    local used = inventory_used()
    if xp > before_xp and used > before_used then
      return {
        status = "complete",
        xp_gained = xp - before_xp,
        inventory_slots_gained = used - before_used,
        receipt = receipt,
      }
    end
  end
  return nil, {
    status = "bakery_steal_unverified",
    before_xp = before_xp,
    current_xp = gc.read("skills").thieving.xp,
    before_inventory_used = before_used,
    current_inventory_used = inventory_used(),
    receipt = receipt,
  }
end

return { inventory_used = inventory_used, steal_once = steal_once }
