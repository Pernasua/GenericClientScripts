local function point(x, y)
  return { x = x, y = y, plane = 0 }
end

local config = {
  varbits = { zooknock = 127, stamina_active = 25, protect_from_melee = 4118 },
  checkpoints = { zooknock_dungeon_route = "monkey_madness_i.zooknock_dungeon_route" },
  points = { zooknock_dungeon_entrance = point(2763, 2703) },
  routes = {
    zooknock_dungeon = { destination = point(2799, 9138), within = 3 },
  },
  zones = {
    zooknock_dungeon = { x1 = 2690, x2 = 2813, y1 = 9088, y2 = 9149, plane = 0 },
  },
  objects = { zooknock_dungeon_entrance = 4780 },
  npcs = { zooknock = 7170 },
  items = { lobster = 379 },
}

local player
local events
local fail_route
local teleports
local active_attacker
local checkpoints
local checkpoint_clears
local food_quantity
local next_interrupt
local prayer_points

local function reset(world, should_fail_route, should_have_active_attacker)
  player = { name = "genericBoss", world = world, interacting = nil }
  events = {}
  fail_route = should_fail_route
  teleports = 0
  active_attacker = should_have_active_attacker == true
  checkpoints = {}
  checkpoint_clears = 0
  food_quantity = 12
  next_interrupt = nil
  prayer_points = 30
end

local protection = {
  enable = function(style, minimum_points)
    events[#events + 1] = {
      type = "protection.enable",
      style = style,
      minimum_points = minimum_points,
    }
    prayer_points = math.max(prayer_points, minimum_points)
    return true, { status = "complete", style = style }
  end,
}

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "shared_behaviors" then
      return { configure = function()
        events[#events + 1] = { type = "behaviors.configure" }
        return true, { status = "complete" }
      end }
    end
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    if name == "shared_geometry" then return dofile("scripts/shared/geometry.lua") end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    if name == "shared_consumables" then return dofile("scripts/shared/consumables.lua") end
    if name == "monkey_madness_preparation" then return {} end
    if name == "shared_protection" then return protection end
    if name == "shared_travel" then
      return {
        teleport_to_castle_wars = function()
          teleports = teleports + 1
          return { status = "complete" }
        end,
      }
    end
    error("unexpected module " .. name)
  end,
  read = function(kind, query)
    if kind == "player" then return player end
    if kind == "inventory" then
      return { items = { { id = 379, quantity = food_quantity } } }
    end
    if kind == "skills" then return { prayer = { boosted_level = prayer_points } } end
    if kind == "vars" then
      return { varbits = { [25] = 1, [127] = 5 } }
    end
    if kind == "objects" then
      if query.id == 4780 and query.action == "Climb-down" then
        return { { id = 4780, world = config.points.zooknock_dungeon_entrance } }
      end
      return {}
    end
    if kind == "npcs" then
      if query and query.id == 7170 and
        player.world.x == 2799 and player.world.y == 9138 then
        return { { id = 7170, index = 1, world = point(2805, 9143), dead = false } }
      end
      if active_attacker and (not query or not query.id) then
        return {
          {
            id = 5237,
            index = 2,
            name = "Skeleton",
            world = point(2798, 9138),
            interacting = player.name,
            dead = false,
            actions = { "Attack" },
          },
        }
      end
      return {}
    end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event == "game.tick" then return { status = "observed" } end
    local action = request.action
    action.policy = request.policy
    events[#events + 1] = action
    if action.type == "client.behaviors.configure" then return { status = "complete" } end
    if action.type == "consumable.cure_poison" then
      return { status = "unchanged", result = "poison_not_active" }
    end
    if action.type == "walk.to" then
      if next_interrupt and player.world.y >= 9088 then
        local receipt = next_interrupt
        next_interrupt = nil
        if receipt.reason == "inventory_below" then food_quantity = 3 end
        if receipt.reason == "skill_below" then prayer_points = 3 end
        return receipt
      end
      if fail_route and player.world.y >= 9088 then
        return { status = "unreachable", result = "test_route_failure" }
      end
      player.world = action.destination
      return { status = "arrived", reached = action.destination }
    end
    if action.type == "object.interact" and action.action == "Climb-down" then
      player.world = point(2765, 9100)
      return { status = "dispatched" }
    end
    error("unexpected action " .. action.type)
  end,
  activity = function() end,
  checkpoint = function(key, value)
    if value ~= nil then checkpoints[key] = value end
    return checkpoints[key]
  end,
  clear_checkpoint = function(key)
    checkpoints[key] = nil
    checkpoint_clears = checkpoint_clears + 1
  end,
}

reset(point(2800, 2707), false)
local amulet = dofile("scripts/quest-runner/monkey_madness_i/amulet.lua")
local reached = amulet.reach_zooknock()
assert(reached.status == "complete", reached.status)

local first_protection
local first_walk
local poison_checks = 0
for index, event in ipairs(events) do
  if not first_protection and event.type == "protection.enable" then
    first_protection = index
    assert(event.style == "melee" and event.minimum_points == 12,
      "Ape Atoll return did not establish the required melee protection")
  elseif not first_walk and event.type == "walk.to" then
    first_walk = index
  end
  if event.type == "consumable.cure_poison" then
    poison_checks = poison_checks + 1
    assert(event.policy.breaks == false and event.policy.fidget == "none",
      "generic poison cure allowed a hazardous-travel break")
  end
end
assert(first_protection and first_walk and first_protection < first_walk,
  "Protect from Melee was not enabled before moving on Ape Atoll")
assert(poison_checks >= 2,
  "the hazardous cave route did not re-check the generic poison cure")
assert(teleports == 0, "successful cave travel used an escape teleport")
assert(checkpoint_clears == 0,
  "destination travel still mutates legacy route checkpoints")

reset(point(2765, 9100), true)
amulet = dofile("scripts/quest-runner/monkey_madness_i/amulet.lua")
local failed = amulet.reach_zooknock()
assert(failed.status == "monkey_madness_zooknock_route_failed", failed.status)
assert(teleports == 0,
  "ordinary cave pathfinding failure consumed an emergency teleport")
assert(player.world.x == 2765 and player.world.y == 9100,
  "ordinary cave pathfinding failure moved the player after failing")

reset(point(2765, 9100), false, true)
amulet = dofile("scripts/quest-runner/monkey_madness_i/amulet.lua")
local reached_while_attacked = amulet.reach_zooknock()
assert(reached_while_attacked.status == "complete", reached_while_attacked.status)
for _, event in ipairs(events) do
  assert(not (event.type == "npc.interact" and event.action == "Attack"),
    "Zooknock arrival stopped quest progress to fight an active attacker")
end

reset(point(2763, 9141), false)
checkpoints[config.checkpoints.zooknock_dungeon_route] = 2
amulet = dofile("scripts/quest-runner/monkey_madness_i/amulet.lua")
local from_current_position = amulet.reach_zooknock()
assert(from_current_position.status == "complete", from_current_position.status)
local walks = {}
for _, event in ipairs(events) do
  if event.type == "walk.to" then walks[#walks + 1] = event end
end
assert(#walks == 1 and walks[1].destination.x == 2799 and walks[1].destination.y == 9138,
  "dungeon travel did not use one destination from the current position")
assert(checkpoints[config.checkpoints.zooknock_dungeon_route] == 2,
  "destination travel rewrote a legacy route cursor")
local conditions = walks[1].interrupt_on
assert(conditions.poisoned and conditions.inventory_below[1].quantity == 4 and
  conditions.skill_below.prayer == 12 and #conditions.varbit_equals == 2,
  "dungeon journey omitted continuous upkeep conditions")

reset(point(2765, 9100), false)
next_interrupt = { status = "interrupted", reason = "skill_below", continuation = "dungeon-resume" }
amulet = dofile("scripts/quest-runner/monkey_madness_i/amulet.lua")
local restored = amulet.reach_zooknock()
assert(restored.status == "complete" and prayer_points >= 12, "prayer interruption was not handled")
walks = {}
for _, event in ipairs(events) do
  if event.type == "walk.to" then walks[#walks + 1] = event end
end
assert(#walks == 2 and walks[2].resume == "dungeon-resume", "upkeep lost its journey continuation")
assert(teleports == 0, "successful upkeep consumed an escape teleport")

reset(point(2765, 9100), false)
next_interrupt = { status = "interrupted", reason = "inventory_below", continuation = "food-reserve" }
amulet = dofile("scripts/quest-runner/monkey_madness_i/amulet.lua")
local restock = amulet.reach_zooknock()
assert(restock.status == "monkey_madness_dungeon_restock_required" and teleports == 1,
  "food reserve interruption did not preserve the existing retreat handler")

reset(point(2765, 9100), false)
next_interrupt = { status = "interrupted", reason = "poisoned" }
amulet = dofile("scripts/quest-runner/monkey_madness_i/amulet.lua")
local unresumable = amulet.reach_zooknock()
assert(unresumable.status == "monkey_madness_zooknock_route_failed" and teleports == 0,
  "unresumable interruption started an unqualified replacement journey")

print("monkey madness dungeon safety tests passed")
