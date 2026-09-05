local prayer_points = 30
local potion_quantity = 1
local pending_restore = false
local restore_amount = 30
local ignore_next_restore = false
local actions = {}
local action_ticks = {}
local game_tick = 0

gc = {
  require = function(name)
    if name == "shared_items" then
      return dofile("scripts/shared/items.lua")
    end
    error("unexpected module " .. name)
  end,
  read = function(kind)
    if kind == "skills" then
      return { prayer = { level = 77, boosted_level = prayer_points } }
    end
    if kind == "inventory" then
      local items = {}
      if potion_quantity > 0 then items[1] = { id = 2434, quantity = potion_quantity } end
      return { items = items }
    end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event == "game.tick" then
      game_tick = game_tick + 1
      if pending_restore then
        prayer_points = prayer_points + restore_amount
        pending_restore = false
      end
      return { status = "observed" }
    end
    local action = request.action
    actions[#actions + 1] = action
    action_ticks[#action_ticks + 1] = game_tick
    if action.type == "item.interact" then
      if ignore_next_restore then
        ignore_next_restore = false
        return { status = "dispatched" }
      end
      potion_quantity = potion_quantity - 1
      pending_restore = true
      return { status = "dispatched" }
    end
    if action.type == "prayer.set" then return { status = "set" } end
    error("unexpected action " .. action.type)
  end,
}

local protection = dofile("scripts/shared/protection.lua")

local magic = protection.enable("magic", 20)
assert(magic == true)
assert(#actions == 1 and actions[1].prayer == "protect_from_magic")

prayer_points = 0
actions = {}
local melee = protection.enable("melee", 12)
assert(melee == true)
assert(actions[1].type == "item.interact", "low prayer did not drink a potion")
assert(actions[2].type == "prayer.set" and actions[2].prayer == "protect_from_melee",
  "melee protection did not use the shared prayer selector")

actions = {}
local disabled = protection.disable("melee")
assert(disabled == true)
assert(#actions == 1 and actions[1].enabled == false,
  "disabling protection consumed supplies or issued extra actions")

prayer_points = 0
potion_quantity = 2
restore_amount = 20
actions = {}
action_ticks = {}
local fully_restored = protection.enable("magic", 35)
assert(fully_restored == true)
assert(#actions == 3 and actions[1].type == "item.interact" and
  actions[2].type == "item.interact" and actions[3].prayer == "protect_from_magic",
  "protection was enabled before the requested prayer threshold was reached")
assert(action_ticks[2] - action_ticks[1] >= 3,
  "successive prayer doses ignored the potion action delay")

prayer_points = 0
potion_quantity = 1
restore_amount = 20
ignore_next_restore = true
actions = {}
action_ticks = {}
local retried_restore = protection.enable("melee", 12)
assert(retried_restore == true)
assert(#actions == 3 and actions[1].type == "item.interact" and
  actions[2].type == "item.interact" and actions[3].prayer == "protect_from_melee",
  "an unobserved potion click was not re-resolved and retried")

local supported, failure = protection.enable("summoning", 1)
assert(supported == nil and failure.status == "unsupported_protection_style")

print("shared protection tests passed")
