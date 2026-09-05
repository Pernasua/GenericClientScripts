local config = {
  items = {
    mspeak_amulet = 4021,
    monkey_talisman = 4023,
    karamjan_monkey_bones = 3183,
    karamjan_monkey_corpse = 3166,
    karamjan_greegree = 4031,
    unstrung_amulet = 4022,
    enchanted_bar = 4007,
    monkey_dentures = 4006,
    amulet_mould = 4020,
    ball_of_wool = 1759,
  },
  varbits = { caranock = 122, narnode = 121, daero = 123, garkor = 126 },
  greegree_loadout = {},
  ape_atoll_loadout = {},
  amulet_bar_loadout = {},
  amulet_crafting_loadout = {},
  points = { monkey_child_staging = { x = 2746, y = 2799, plane = 0 } },
  zones = {
    ape_atoll_south = { x1 = 2687, x2 = 2820, y1 = 2687, y2 = 2737, plane = 0 },
    ape_atoll_south_corridor_wide = { x1 = 2713, x2 = 2737, y1 = 2738, y2 = 2743, plane = 0 },
    ape_atoll_south_corridor_narrow = { x1 = 2718, x2 = 2726, y1 = 2744, y2 = 2765, plane = 0 },
    ape_atoll_prison = { x1 = 2764, x2 = 2776, y1 = 2793, y2 = 2802, plane = 0 },
    prison_west_clear = { x1 = 2762, x2 = 2764, y1 = 2797, y2 = 2799, plane = 0 },
    ape_atoll_north = { x1 = 2682, x2 = 2816, y1 = 2766, y2 = 2817, plane = 0 },
    ape_atoll_north_west = { x1 = 2687, x2 = 2716, y1 = 2738, y2 = 2765, plane = 0 },
    ape_atoll_north_east = { x1 = 2735, x2 = 2815, y1 = 2730, y2 = 2765, plane = 0 },
    denture_building = { x1 = 2759, x2 = 2770, y1 = 2764, y2 = 2772, plane = 0 },
    amulet_mould_room = { x1 = 2752, x2 = 2806, y1 = 9156, y2 = 9183, plane = 0 },
    zooknock_dungeon = { x1 = 2690, x2 = 2813, y1 = 9088, y2 = 9149, plane = 0 },
    temple_dungeon = { x1 = 2777, x2 = 2818, y1 = 9185, y2 = 9219, plane = 0 },
  },
}

local loadouts = {}
function loadouts.matches_carried(state)
  return state.matches == true
end
function loadouts.missing_carried() return {} end

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then
      return dofile("scripts/quest-runner/monkey_madness_i/areas.lua")
    end
    if name == "shared_geometry" then
      return dofile("scripts/shared/geometry.lua")
    end
    if name == "shared_items" then
      return dofile("scripts/shared/items.lua")
    end
    if name == "shared_loadouts" then return loadouts end
    error("unexpected module " .. name)
  end,
}

local resolver = dofile("scripts/quest-runner/monkey_madness_i/state.lua")

local function state(items, world, matches)
  return {
    varp = 3,
    varbits = { [121] = 7, [122] = 3, [123] = 7, [126] = 2 },
    quests = { monkey_madness_i = { state = "in_progress" } },
    skills = { prayer = { level = 43 } },
    player = { world = world },
    inventory = { items = items },
    equipment = { items = {} },
    bank = { items = {} },
    matches = matches,
  }
end

local north = { x = 2762, y = 2804, plane = 0 }
local prison_safe = { x = 2769, y = 2795, plane = 0 }
local child_staging = { x = 2746, y = 2799, plane = 0 }
local south = { x = 2802, y = 2707, plane = 0 }
local dungeon = { x = 2805, y = 9143, plane = 0 }
local mainland = { x = 3165, y = 3491, plane = 0 }
local amulet = { id = 4021, quantity = 1 }
local talisman = { id = 4023, quantity = 1 }
local bones = { id = 3183, quantity = 1 }
local greegree = { id = 4031, quantity = 1 }

assert(resolver.resolve(state({ amulet }, north)) == "leave_temple_with_amulet")
assert(resolver.resolve(state({ amulet }, prison_safe)) == "obtain_monkey_talisman",
  "a carried amulet inside prison must use the primed prison escape")
assert(resolver.resolve(state({ amulet }, child_staging)) == "obtain_monkey_talisman")
assert(resolver.resolve(state({ amulet, talisman }, north)) ==
  "greegree_loadout_required",
  "missing monkey bones must be acquired with the normal GE loadout")
assert(resolver.resolve(state({ amulet, talisman, bones }, mainland, false)) ==
  "greegree_loadout_required")
assert(resolver.resolve(state({ amulet, talisman, bones }, mainland, true)) ==
  "reach_ape_atoll_for_greegree")
assert(resolver.resolve(state({ amulet, talisman, bones }, south, true)) ==
  "reach_zooknock_for_greegree")
assert(resolver.resolve(state({ amulet, talisman, bones }, dungeon, true)) ==
  "make_karamjan_greegree")
assert(resolver.resolve(state({ amulet, greegree }, mainland, true)) ==
  "sync_karamjan_greegree")

local stale_garkor = state({ amulet }, child_staging)
stale_garkor.varbits[126] = 0
assert(resolver.resolve(stale_garkor) == "obtain_monkey_talisman",
  "advanced quest items must outrank a transient stale Garkor varbit")

local acquired_in_dungeon = state({ amulet, greegree }, dungeon, true)
acquired_in_dungeon.varp = 4
assert(resolver.resolve(acquired_in_dungeon) == "sync_karamjan_greegree",
  "an acquired greegree must not skip the unfinished dungeon exit")

print("monkey madness disguise state tests passed")
