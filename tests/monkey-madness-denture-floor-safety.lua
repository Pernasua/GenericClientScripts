local function point(x, y)
  return { x = x, y = y, plane = 0 }
end

local death_tiles = {
  point(2767, 2768),
  point(2766, 2768),
  point(2767, 2767),
  point(2766, 2767),
  point(2766, 2769),
}

local config = {
  zones = {
    denture_building = { x1 = 2759, x2 = 2770, y1 = 2764, y2 = 2772, plane = 0 },
    amulet_mould_room = { x1 = 2752, x2 = 2806, y1 = 9156, y2 = 9183, plane = 0 },
    ape_atoll_south = { x1 = 2687, x2 = 2820, y1 = 2687, y2 = 2737, plane = 0 },
    ape_atoll_south_corridor_wide = { x1 = 2713, x2 = 2737, y1 = 2738, y2 = 2743, plane = 0 },
    ape_atoll_south_corridor_narrow = { x1 = 2718, x2 = 2726, y1 = 2744, y2 = 2765, plane = 0 },
    ape_atoll_prison = { x1 = 2764, x2 = 2776, y1 = 2793, y2 = 2802, plane = 0 },
    prison_west_clear = { x1 = 2762, x2 = 2764, y1 = 2797, y2 = 2799, plane = 0 },
    prison_north_exit = { x1 = 2777, x2 = 2790, y1 = 2798, y2 = 2810, plane = 0 },
    ape_atoll_north = { x1 = 2682, x2 = 2816, y1 = 2766, y2 = 2817, plane = 0 },
    ape_atoll_north_west = { x1 = 2687, x2 = 2716, y1 = 2738, y2 = 2765, plane = 0 },
    ape_atoll_north_east = { x1 = 2735, x2 = 2815, y1 = 2730, y2 = 2765, plane = 0 },
  },
  routes = {
    denture_safe_approach = { destination = point(2768, 2769), within = 0, avoid_tiles = death_tiles },
    prison_to_dentures = { destination = point(2764, 2763), within = 1,
      via = { point(2784, 2806), point(2784, 2770), point(2780, 2763) } },
    garkor_to_dentures = { destination = point(2764, 2763), within = 1 },
  },
  points = {
    prison_clear = point(2762, 2804),
    denture_hole = point(2769, 2765),
    amulet_mould_crate = point(2782, 9172),
  },
  danger_tiles = { denture_light_floor = death_tiles },
  objects = {
    denture_building_door = 4710,
    denture_crate = 4715,
    denture_hole_crate = 4714,
    amulet_mould_crate = 4724,
  },
  items = { monkey_dentures = 4006, amulet_mould = 4020 },
}

local player = { world = point(2764, 2764) }
local has_dentures = false
local has_mould = false
local found_hole = false
local actions = {}
local force_capture = false

local function inventory()
  local items = {}
  if has_dentures then items[#items + 1] = { id = 4006, quantity = 1 } end
  if has_mould then items[#items + 1] = { id = 4020, quantity = 1 } end
  return { items = items }
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
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    if name == "shared_geometry" then return dofile("scripts/shared/geometry.lua") end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    if name == "monkey_madness_garkor" then
      return {
        settle_combat = function() return { status = "complete" } end,
        reach_prison = function() return { status = "complete" } end,
        escape_prison = function() return { status = "complete" } end,
        refresh_antipoison = function() return true end,
      }
    end
    if name == "monkey_madness_preparation" then
      return { arm_safety = function() return true end }
    end
    error("unexpected module " .. name)
  end,
  read = function(kind, query)
    if kind == "player" then return player end
    if kind == "inventory" then return inventory() end
    if kind == "runtime" then return { game_tick = 100 } end
    if kind == "dialogue" then return { type = "closed" } end
    if kind == "messages" then
      if not found_hole then return {} end
      return {
        { type = "mesbox", game_tick = 101, text = "You find a hole in the floor." },
        { type = "mesbox", game_tick = 102, text = "You begin to lower yourself." },
      }
    end
    if kind == "objects" then
      if query.id == 4715 then return { { id = 4715, world = point(2767, 2769) } } end
      if query.id == 4714 then return { { id = 4714, world = point(2769, 2765) } } end
      return {}
    end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event or request.ticks then return { status = "observed" } end
    local action = request.action
    actions[#actions + 1] = action
    if action.type == "walk.to" then
      if force_capture then
        player.world = point(2771, 2794)
        return { status = "interrupted", reason = "area", detail = "prison", continuation = "recaptured" }
      end
      player.world = action.destination
      return { status = "arrived", reached = action.destination }
    end
    if action.type == "object.interact" and action.id == 4715 then
      has_dentures = true
      return { status = "dispatched" }
    end
    if action.type == "object.interact" and action.id == 4714 then
      found_hole = true
      return { status = "dispatched" }
    end
    if action.type == "dialogue.choose" then
      player.world = point(2782, 9172)
      has_mould = true
      return { status = "dispatched" }
    end
    return { status = "dispatched" }
  end,
  activity = function() end,
}

local result = dofile("scripts/quest-runner/monkey_madness_i/infiltration.lua").execute()
assert(result.status == "complete", result.status)

local death_keys = {}
for _, tile in ipairs(death_tiles) do
  death_keys[tile.x .. "," .. tile.y] = true
end

local walks_before_dentures = {}
local denture_search
local hole_walk
local hole_search
for index, action in ipairs(actions) do
  if action.type == "walk.to" then
    assert(not death_keys[action.destination.x .. "," .. action.destination.y],
      "a scripted waypoint was placed on the light floor")
    assert(type(action.avoid_tiles) == "table" and #action.avoid_tiles == #death_tiles,
      "a denture-building walk omitted the Quest Helper death tiles")
    if not denture_search then walks_before_dentures[#walks_before_dentures + 1] = action end
    if action.destination.x == 2769 and action.destination.y == 2765 then hole_walk = index end
  elseif action.type == "object.interact" and action.id == 4715 then
    denture_search = { index = index, action = action }
  elseif action.type == "object.interact" and action.id == 4714 then
    hole_search = { index = index, action = action }
  end
end

assert(#walks_before_dentures == 1,
  "the safe-floor approach was still split into waypoint awaits")
assert(walks_before_dentures[1].destination.x == 2768 and
  walks_before_dentures[1].destination.y == 2769 and walks_before_dentures[1].within == 0,
  "the safe-floor approach lost its exact crate staging tile")
assert(denture_search and denture_search.action.within == 2,
  "the denture search could auto-path across the light floor")
assert(hole_walk and hole_search and hole_walk < hole_search.index and hole_search.action.within == 2,
  "the hole crate was not approached safely before interaction")

player.world = config.points.prison_clear
has_dentures, has_mould, found_hole = false, false, false
actions = {}
force_capture = true
local recaptured = dofile("scripts/quest-runner/monkey_madness_i/infiltration.lua").execute()
assert(recaptured.status == "monkey_madness_infiltration_recaptured", recaptured.status)
assert(#actions == 1 and actions[1].type == "walk.to" and #actions[1].via == 3,
  "safe-exit resume selected the wrong corridor or acted again after recapture")
assert(actions[1].interrupt_on.area.name == "prison", "infiltration did not declare its capture interruption")

print("monkey madness denture floor safety tests passed")
