local function point(x, y)
  return { x = x, y = y, plane = 0 }
end

local child_route = {
  point(2806, 2785),
  point(2784, 2787),
  point(2784, 2806),
  point(2764, 2806),
  point(2749, 2804),
  point(2749, 2802),
  point(2746, 2802),
  point(2746, 2799),
}

local config = {
  zones = {
    ape_atoll_south = { x1 = 2687, x2 = 2820, y1 = 2687, y2 = 2737, plane = 0 },
    ape_atoll_south_corridor_wide = { x1 = 2713, x2 = 2737, y1 = 2738, y2 = 2743, plane = 0 },
    ape_atoll_south_corridor_narrow = { x1 = 2718, x2 = 2726, y1 = 2744, y2 = 2765, plane = 0 },
    ape_atoll_prison = { x1 = 2764, x2 = 2776, y1 = 2793, y2 = 2802, plane = 0 },
    prison_west_clear = { x1 = 2762, x2 = 2764, y1 = 2797, y2 = 2799, plane = 0 },
    ape_atoll_north = { x1 = 2682, x2 = 2816, y1 = 2766, y2 = 2817, plane = 0 },
    ape_atoll_north_west = { x1 = 2687, x2 = 2716, y1 = 2738, y2 = 2765, plane = 0 },
    ape_atoll_north_east = { x1 = 2735, x2 = 2815, y1 = 2730, y2 = 2765, plane = 0 },
    temple_melee_threshold = { x1 = 2787, x2 = 2787, y1 = 2784, y2 = 2789, plane = 0 },
    temple_guard_building = { x1 = 2787, x2 = 2808, y1 = 2773, y2 = 2793, plane = 0 },
    temple_dungeon = { x1 = 2777, x2 = 2818, y1 = 9185, y2 = 9219, plane = 0 },
  },
  routes = {
    prison_to_temple_entry = {},
    temple_trapdoor_approach = {},
    temple_to_monkey_child = { destination = child_route[#child_route], within = 0,
      via = { table.unpack(child_route, 1, #child_route - 1) } },
  },
  points = {
    temple_trapdoor = point(2807, 2785),
    temple_flame_staging = point(2811, 9208),
    temple_flame_edge = point(2811, 9209),
    monkey_child_staging = point(2746, 2799),
    monkey_child = point(2743, 2794),
    monkey_aunt_south_crossing = point(2743, 2791),
    prison_clear = point(2762, 2804),
  },
  npcs = {
    temple_guards = { 5275, 5276 },
    monkey_aunt = 5270,
    monkey_child = 5268,
  },
  objects = {
    temple_trapdoor = 4879,
    temple_trapdoor_open = 4880,
    temple_flame = 4766,
    temple_rope = 4881,
    banana_trees = {},
  },
  items = {
    enchanted_bar = 4007,
    amulet_mould = 4020,
    unstrung_amulet = 4022,
    mspeak_amulet = 4021,
    ball_of_wool = 1759,
    monkey_talisman = 4023,
    banana = 1963,
  },
}

local player
local carried
local equipped
local prayer_points
local actions
local safety_minimum
local banana_tree_available
local banana_search_mode
local banana_search_attempts
local aunt_index
local aunt_path = {
  point(2743, 2792),
  point(2743, 2791),
  point(2733, 2788),
  point(2743, 2792),
}

local function reset()
  player = { world = point(2801, 9213) }
  carried = {
    [4007] = 1,
    [4020] = 1,
    [1759] = 1,
  }
  equipped = {}
  prayer_points = 16
  actions = {}
  safety_minimum = false
  banana_tree_available = false
  banana_search_mode = "failure"
  banana_search_attempts = 0
  aunt_index = 1
end

local function items(values)
  local result = {}
  for id, quantity in pairs(values) do
    if quantity > 0 then result[#result + 1] = { id = id, quantity = quantity } end
  end
  return { items = result }
end

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then
      return dofile("scripts/quest-runner/monkey_madness_i/areas.lua")
    end
    if name == "shared_behaviors" then
      return { configure = function() return true, { status = "complete" } end }
    end
    if name == "shared_equipment" then return dofile("scripts/shared/equipment.lua") end
    if name == "shared_geometry" then return dofile("scripts/shared/geometry.lua") end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    if name == "shared_wait" then return dofile("scripts/shared/wait.lua") end
    if name == "monkey_madness_preparation" then
      return {
        arm_safety = function(minimum_hitpoints)
          safety_minimum = minimum_hitpoints
          return true
        end,
      }
    end
    if name == "monkey_madness_garkor" then
      return {
        travel_interrupts = function() return {} end,
        maintain_stamina = function() return true end,
        refresh_antipoison = function() return true end,
        escape_prison = function()
          player.world = config.points.prison_clear
          return { status = "complete", result = "ape_atoll_prison_exited" }
        end,
      }
    end
    if name == "monkey_madness_navigation" or name == "monkey_madness_amulet" then
      return {}
    end
    if name == "shared_protection" then return dofile("scripts/shared/protection.lua") end
    if name == "shared_travel" then
      return {
        teleport_to_castle_wars = function()
          error("ordinary amulet checkpoint failure attempted a teleport")
        end,
      }
    end
    error("unexpected module " .. name)
  end,
  read = function(kind, query)
    if kind == "player" then return player end
    if kind == "skills" then
      return { prayer = { level = 43, boosted_level = prayer_points } }
    end
    if kind == "inventory" then return items(carried) end
    if kind == "equipment" then return items(equipped) end
    if kind == "npcs" then
      if query and query.id == config.npcs.monkey_aunt then
        return { { id = config.npcs.monkey_aunt, world = aunt_path[aunt_index] } }
      end
      return {}
    end
    if kind == "dialogue" then return { type = "closed" } end
    if kind == "objects" then
      if query.id == 4749 and query.action == "Search" and banana_tree_available then
        return { { id = 4749, world = point(2744, 2796) } }
      end
      if query.id == 4766 then
        return {
          { id = 4766, world = point(2810, 9209) },
          { id = 4766, world = config.points.temple_flame_edge },
        }
      end
      if query.id == 4881 and query.action == "Climb" then
        return { { id = 4881, world = point(2808, 9201) } }
      end
      return {}
    end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event or request.ticks then
      aunt_index = aunt_index % #aunt_path + 1
      return { status = "observed" }
    end
    local action = request.action
    actions[#actions + 1] = action
    if action.type == "prayer.set" then return { status = "set" } end
    if action.type == "walk.to" then
      player.world = action.destination
      if action.destination.x == config.points.monkey_child.x and
        action.destination.y == config.points.monkey_child.y then
        aunt_index = aunt_index % #aunt_path + 1
      end
      return { status = "arrived", reached = action.destination }
    end
    if action.type == "walk.click" then
      player.world = action.destination
      return { status = "dispatched", result = "one_shot_tile_click" }
    end
    if action.type == "item.use_on_object" then
      carried[4007] = 0
      carried[4022] = 1
      return { status = "dispatched" }
    end
    if action.type == "item.use_on_item" then
      carried[1759] = 0
      carried[4022] = 0
      carried[4021] = 1
      return { status = "dispatched" }
    end
    if action.type == "item.interact" and action.id == 4021 and action.action == "Wear" then
      carried[4021] = 0
      equipped[4021] = 1
      return { status = "dispatched" }
    end
    if action.type == "object.interact" and action.id == 4881 and action.action == "Climb" then
      player.world = point(2805, 2783)
      return { status = "dispatched" }
    end
    if action.type == "object.interact" and action.id == 4749 then
      banana_search_attempts = banana_search_attempts + 1
      player.world = point(2744, 2796)
      if banana_search_mode == "transient_once" and banana_search_attempts > 1 then
        carried[1963] = (carried[1963] or 0) + 1
        return { status = "dispatched", result = "object_interaction_dispatched" }
      end
      if banana_search_mode == "transient_once" then
        return { status = "rejected", result = "mouse_missed_target" }
      end
      return { status = "rejected", result = "test_banana_search_failure" }
    end
    error("unexpected action " .. action.type)
  end,
  activity = function() end,
}

reset()
local amulet_crafting = dofile("scripts/quest-runner/monkey_madness_i/amulet_crafting.lua")
local result = amulet_crafting.make()
assert(result.status == "complete", result.status)
assert(result.result == "mspeak_amulet_checkpoint_reached")
assert(safety_minimum == nil,
  "amulet travel configured an ordinary-damage teleport floor")
assert(equipped[4021] == 1 and (carried[4021] or 0) == 0,
  "M'speak amulet was not equipped before leaving")
assert(player.world.x == 2746 and player.world.y == 2799,
  "checkpoint did not stop at the monkey-child staging tile")

local melee
local flame
local flame_action
local flame_staging_walk
local wool
local wear
local climb
local surface_walks = {}
for index, action in ipairs(actions) do
  if action.type == "prayer.set" then
    assert(action.enabled and action.prayer == "protect_from_melee",
      "Protect from Melee was changed before the child staging tile")
    if not melee then melee = index end
  elseif action.type == "item.use_on_object" then
    flame = index
    flame_action = action
  elseif action.type == "item.use_on_item" then
    wool = index
  elseif action.type == "item.interact" and action.action == "Wear" then
    wear = index
  elseif action.type == "object.interact" and action.action == "Climb" then
    climb = index
  elseif action.type == "walk.to" and climb then
    surface_walks[#surface_walks + 1] = action
  elseif action.type == "walk.to" and action.destination.x == 2811 and
    action.destination.y == 9208 then
    flame_staging_walk = action
  end
  assert(not (action.type == "item.interact" and action.action == "Rub"),
    "the checkpoint attempted a non-emergency ring retreat")
end

assert(melee and flame and wool and wear and climb and
  melee < flame and flame < wool and wool < wear and wear < climb,
  "amulet checkpoint actions ran out of order")
assert(flame_action.world.x == 2811 and flame_action.world.y == 9209,
  "the enchanted bar did not target the accessible south-center flame edge")
assert(flame_staging_walk and flame_staging_walk.within == 0 and flame_action.within == 2,
  "the flame edge was not used from its exact adjacent staging tile")
assert(#surface_walks == 1, "the child corridor was split into separate awaits")
assert(surface_walks[1].within == 0 and #surface_walks[1].via == #child_route - 1,
  "the child corridor lost its exact final tile or required pass-through points")
for index = 1, #child_route - 1 do
  local actual, expected = surface_walks[1].via[index], child_route[index]
  assert(actual.x == expected.x and actual.y == expected.y, "child corridor constraint changed")
end
assert(surface_walks[#surface_walks].within == 0,
  "the checkpoint can stop short of the child-house staging tile")

reset()
player.world = point(2806, 2777)
carried = { [4020] = 1 }
equipped = { [4021] = 1 }
actions = {}
local resumed = amulet_crafting.finish()
assert(resumed.status == "complete", resumed.status)
assert(player.world.x == 2746 and player.world.y == 2799,
  "an equipped-amulet resume did not continue through the child route")
for _, action in ipairs(actions) do
  assert(action.type ~= "item.use_on_object" and action.type ~= "item.use_on_item",
    "an equipped-amulet resume replayed completed crafting")
end

reset()
player.world = point(2769, 2795)
carried = { [4021] = 1 }
equipped = {}
actions = {}
local disguise = dofile("scripts/quest-runner/monkey_madness_i/disguise.lua")
local child_attempt = disguise.obtain_talisman()
assert(child_attempt.status == "monkey_madness_banana_tree_not_observed",
  child_attempt.status)
local first_child_walk
for _, action in ipairs(actions) do
  if action.type == "walk.to" then
    first_child_walk = action
    break
  end
end
assert(first_child_walk and
  first_child_walk.destination.x == config.points.monkey_child_staging.x and
  first_child_walk.destination.y == config.points.monkey_child_staging.y and first_child_walk.within == 0,
  "prison escape did not use one exact journey to the child safe spot")

reset()
player.world = point(2746, 2799)
carried = { [4021] = 1 }
equipped = {}
config.objects.banana_trees = { 4749 }
banana_tree_available = true
local failed_search = disguise.obtain_talisman()
assert(failed_search.status == "rejected" and
  failed_search.result == "test_banana_search_failure")
local searched
for _, action in ipairs(actions) do
  if action.type == "object.interact" and action.id == 4749 then searched = action end
end
assert(searched and searched.action == "Search",
  "banana collection did not use the live Search action")
assert(player.world.x == config.points.monkey_child_staging.x and
  player.world.y == config.points.monkey_child_staging.y,
  "banana failure left the player exposed to the monkey's aunt")

reset()
player.world = point(2746, 2799)
carried = { [4021] = 1, [1963] = 4 }
equipped = {}
config.objects.banana_trees = { 4749 }
banana_tree_available = true
banana_search_mode = "transient_once"
local retried_search = disguise.obtain_talisman()
assert(retried_search.status == "monkey_madness_monkey_child_not_observed",
  retried_search.status)
assert(banana_search_attempts == 2,
  "transient banana click was not retried exactly once")
assert(player.world.x == config.points.monkey_child_staging.x and
  player.world.y == config.points.monkey_child_staging.y,
  "post-retry child failure did not return to the safe passage")

print("monkey madness amulet checkpoint tests passed")
