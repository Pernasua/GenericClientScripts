local function point(x, y)
  return { x = x, y = y, plane = 0 }
end

local safety_action

gc = {
  require = function(name)
    if name == "monkey_madness_config" then
      return {
        zones = {},
        items = {
          monkey_dentures = 4006,
          amulet_mould = 4020,
          enchanted_bar = 4007,
          unstrung_amulet = 4022,
          mspeak_amulet = 4021,
          monkey_talisman = 4023,
          karamjan_monkey_bones = 3183,
          karamjan_monkey_corpse = 3166,
          karamjan_greegree = 4031,
          zoo_monkey = 4033,
          squad_sigil = 4035,
        },
      }
    end
    if name == "monkey_madness_areas" then
      return dofile("scripts/quest-runner/monkey_madness_i/areas.lua")
    end
    if name == "shared_preparation" then return {} end
    if name == "shared_geometry" then
      return dofile("scripts/shared/geometry.lua")
    end
    if name == "shared_travel" then return {} end
    error("unexpected module " .. name)
  end,
  read = function(kind)
    if kind == "inventory" then return { items = { { id = 2552, quantity = 1 } } } end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    safety_action = request.action
    return { status = "complete" }
  end,
}

local preparation = dofile("scripts/quest-runner/monkey_madness_i/preparation.lua")
local armed = preparation.arm_safety(20)
assert(armed == true)
assert(safety_action.type == "safety.configure")
assert(safety_action.minimum_hitpoints == 20,
  "temple safety did not raise the emergency eating floor")

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
    prison_to_temple_entry = { destination = point(2787, 2787), within = 0 },
    temple_trapdoor_approach = { destination = point(2807, 2785), within = 2, ticks = 70,
      arrival_tiles = { point(2806, 2785), point(2806, 2784), point(2805, 2785), point(2807, 2784) } },
  },
  points = {
    temple_trapdoor = point(2807, 2785),
    temple_flame_staging = point(2811, 9208),
    temple_flame_edge = point(2811, 9209),
  },
  npcs = { temple_guards = { 5275, 5276 } },
  objects = {
    temple_trapdoor = 4879,
    temple_trapdoor_open = 4880,
    temple_flame = 4766,
    temple_rope = 4881,
  },
  items = {
    enchanted_bar = 4007,
    unstrung_amulet = 4022,
    mspeak_amulet = 4021,
    ball_of_wool = 1759,
  },
}

local player
local actions
local trapdoor_open
local block_first_approach
local refuse_threshold
local block_all_approaches

local function reset(world, block_first, refuse_entry)
  player = { world = world }
  actions = {}
  trapdoor_open = false
  block_first_approach = block_first
  refuse_threshold = refuse_entry
  block_all_approaches = false
end

local function inventory()
  return { items = {
    { id = 4007, quantity = 1 },
    { id = 4020, quantity = 1 },
    { id = 1759, quantity = 1 },
  } }
end

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then
      return dofile("scripts/quest-runner/monkey_madness_i/areas.lua")
    end
    if name == "monkey_madness_preparation" then
      return { arm_safety = function() return true end }
    end
    if name == "monkey_madness_garkor" then
      return {
        travel_interrupts = function() return {} end,
        maintain_stamina = function() return true end,
        refresh_antipoison = function() return { status = "unchanged" } end,
      }
    end
    if name == "shared_behaviors" then
      return dofile("scripts/shared/behaviors.lua")
    end
    if name == "shared_equipment" then return {} end
    if name == "shared_geometry" then
      return dofile("scripts/shared/geometry.lua")
    end
    if name == "shared_items" then
      return dofile("scripts/shared/items.lua")
    end
    if name == "shared_movement" then
      return dofile("scripts/shared/movement.lua")
    end
    if name == "shared_protection" then
      return {
        enable = function(style)
          local receipt = gc.await {
            action = {
              type = "prayer.set",
              prayer = "protect_from_" .. style,
              enabled = true,
            },
          }
          return true, receipt
        end,
        disable = function(style)
          local receipt = gc.await {
            action = {
              type = "prayer.set",
              prayer = "protect_from_" .. style,
              enabled = false,
            },
          }
          return true, receipt
        end,
      }
    end
    if name == "shared_travel" then return {} end
    error("unexpected module " .. name)
  end,
  read = function(kind, query)
    if kind == "player" then return player end
    if kind == "inventory" then return inventory() end
    if kind == "npcs" then
      if query.id == 5275 then
        return { { id = 5275,
          world = block_all_approaches and point(2805, 2783) or block_first_approach and point(2806, 2785) or point(2803, 2783),
          size = block_all_approaches and 4 or 2 } }
      end
      return {}
    end
    if kind == "objects" then
      if query.id == 4879 and not trapdoor_open and
        (query.action == nil or query.action == "Open") then
        return { { id = 4879, world = config.points.temple_trapdoor } }
      end
      if query.id == 4880 and trapdoor_open and query.action == "Climb-down" then
        return { { id = 4880, world = config.points.temple_trapdoor } }
      end
      return {}
    end
    if kind == "dialogue" then return { type = "closed" } end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event or request.ticks then return { status = "observed" } end
    local action = request.action
    action.await_timeout = request.timeout and request.timeout.game_ticks
    actions[#actions + 1] = action
    if action.type == "client.behaviors.configure" then return { status = "complete" } end
    if action.type == "prayer.set" then return { status = "set" } end
    if action.type == "walk.to" then
      if refuse_threshold and action.destination.x == 2787 and action.destination.y == 2787 then
        return { status = "arrived", reached = action.destination }
      end
      if action.arrival_tiles then
        for _, candidate in ipairs(action.arrival_tiles) do
          local occupied = false
          for _, avoided in ipairs(action.avoid_tiles or {}) do
            occupied = occupied or candidate.x == avoided.x and candidate.y == avoided.y and candidate.plane == avoided.plane
          end
          if not occupied then
            player.world = candidate
            action.observed_arrival = candidate
            return { status = "arrived", reached = candidate }
          end
        end
        return { status = "unreachable", reason = "all_arrival_tiles_blocked" }
      end
      player.world = action.destination
      return { status = "arrived", reached = action.destination }
    end
    if action.type == "object.interact" and action.action == "Open" then
      trapdoor_open = true
      return { status = "dispatched" }
    end
    if action.type == "object.interact" and action.action == "Climb-down" then
      player.world = point(2808, 9201)
      return { status = "dispatched" }
    end
    return { status = "dispatched" }
  end,
  activity = function() end,
}

local amulet = dofile("scripts/quest-runner/monkey_madness_i/amulet_crafting.lua")

reset(point(2764, 2806), true, false)
local entered = amulet.enter_temple()
assert(entered.status == "complete", entered.status)

local missiles_enabled
local threshold_walk
local melee_enabled
local interior_walks = {}
local opened
local climbed
for index, action in ipairs(actions) do
  if action.type == "prayer.set" and action.prayer == "protect_from_missiles" and action.enabled then
    missiles_enabled = index
  elseif action.type == "prayer.set" and action.prayer == "protect_from_melee" and action.enabled then
    melee_enabled = index
  elseif action.type == "walk.to" then
    if action.destination.x == 2787 and action.destination.y >= 2784 and action.destination.y <= 2789 then
      threshold_walk = index
      assert(action.within == 0, "the prayer boundary walk must reach the building threshold")
    elseif action.destination.x >= 2805 then
      interior_walks[#interior_walks + 1] = { index = index, action = action }
    end
  elseif action.type == "object.interact" and action.action == "Open" then
    opened = { index = index, action = action }
  elseif action.type == "object.interact" and action.action == "Climb-down" then
    climbed = { index = index, action = action }
  end
end

assert(missiles_enabled and threshold_walk and melee_enabled,
  "the outdoor-to-building prayer transition was incomplete")
assert(missiles_enabled < threshold_walk and threshold_walk < melee_enabled,
  "Protect from Melee must replace missiles only after crossing the building threshold")
assert(#interior_walks == 1 and melee_enabled < interior_walks[1].index,
  "trapdoor arrival alternatives became separate scripted walks")
local approach = interior_walks[1].action
assert(approach.arrival_tiles[1].x == 2806 and approach.arrival_tiles[1].y == 2785,
  "the west approach disappeared from the allowed arrival set")
assert(approach.observed_arrival.x ~= approach.arrival_tiles[1].x or
  approach.observed_arrival.y ~= approach.arrival_tiles[1].y,
  "the mocked blocked arrival did not choose another allowed tile")
assert(approach.await_timeout == 70, "the confined temple approach lost its bounded travel budget")
assert(type(interior_walks[1].action.avoid_tiles) == "table" and
  #interior_walks[1].action.avoid_tiles >= 4,
  "the trapdoor approach did not avoid the observed gorilla footprint")
assert(opened and climbed and opened.index < climbed.index,
  "the trapdoor was not opened before climbing down")
assert(opened.action.within == 2 and climbed.action.within == 2,
  "trapdoor interactions may not path through gorillas from a long radius")

reset(point(2804, 2777), false, false)
local resumed = amulet.enter_temple()
assert(resumed.status == "complete", resumed.status)
local first_prayer
local first_walk
for index, action in ipairs(actions) do
  if not first_prayer and action.type == "prayer.set" and action.enabled then first_prayer = action end
  if not first_walk and action.type == "walk.to" then first_walk = index end
  assert(not (action.type == "prayer.set" and action.prayer == "protect_from_missiles" and action.enabled),
    "resuming inside the gorilla building incorrectly re-enabled missiles")
end
assert(first_prayer and first_prayer.prayer == "protect_from_melee" and first_walk,
  "resuming inside the building did not establish melee protection before moving")

reset(point(2764, 2806), false, true)
local missed_threshold = amulet.enter_temple()
assert(missed_threshold.status == "monkey_madness_temple_melee_threshold_not_reached",
  "an arrival receipt without an observed threshold tile was accepted")
for _, action in ipairs(actions) do
  assert(not (action.type == "prayer.set" and action.prayer == "protect_from_melee" and action.enabled),
    "melee protection was enabled before the player was observed inside the building")
end

reset(point(2764, 2806), false, false)
block_all_approaches = true
local blocked = amulet.enter_temple()
assert(blocked.status == "monkey_madness_temple_gorilla_body_blocked", blocked.status)
for _, action in ipairs(actions) do
  assert(action.type ~= "object.interact", "an unreachable arrival set still interacted with the trapdoor")
end

print("monkey madness temple safety tests passed")
