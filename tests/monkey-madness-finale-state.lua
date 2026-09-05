local config = {
  items = {
    monkey_dentures = 4006,
    amulet_mould = 4020,
    enchanted_bar = 4007,
    unstrung_amulet = 4022,
    mspeak_amulet = 4021,
    monkey_talisman = 4023,
    karamjan_greegree = 4031,
    karamjan_monkey_bones = 3183,
    karamjan_monkey_corpse = 3166,
    zoo_monkey = 4033,
    squad_sigil = 4035,
    ball_of_wool = 1759,
  },
  points = { ardougne_zoo_minder = { x = 2608, y = 3278, plane = 0 } },
  varbits = { caranock = 122, narnode = 121, daero = 123, garkor = 126 },
  ape_atoll_loadout = {},
  amulet_bar_loadout = {},
  amulet_crafting_loadout = {},
  greegree_loadout = {},
  zoo_loadout = {},
  demon_loadout = {},
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
    monkey_pen_west = { x1 = 2598, x2 = 2600, y1 = 3274, y2 = 3278, plane = 0 },
    monkey_pen_east = { x1 = 2605, x2 = 2606, y1 = 3277, y2 = 3281, plane = 0 },
    monkey_pen_middle = { x1 = 2600, x2 = 2604, y1 = 3276, y2 = 3282, plane = 0 },
    ape_atoll_bridge = { x1 = 2712, x2 = 2730, y1 = 2765, y2 = 2767, plane = 2 },
    ape_atoll_over_bridge = { x1 = 2726, x2 = 2733, y1 = 2751, y2 = 2769, plane = 0 },
    throne_room_west = { x1 = 2796, x2 = 2798, y1 = 2763, y2 = 2765, plane = 0 },
    throne_room_entry = { x1 = 2798, x2 = 2799, y1 = 2762, y2 = 2763, plane = 0 },
    throne_room = { x1 = 2800, x2 = 2805, y1 = 2759, y2 = 2766, plane = 0 },
    jungle_demon_room_ground = { x1 = 2671, x2 = 2749, y1 = 9151, y2 = 9214, plane = 0 },
    jungle_demon_room_platform = { x1 = 2671, x2 = 2749, y1 = 9151, y2 = 9214, plane = 1 },
  },
}

local loadouts = {}
function loadouts.matches_carried(state) return state.matches == true end
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

local function state(varp, items, world, matches)
  return {
    varp = varp,
    varbits = { [121] = 7, [122] = 3, [123] = 7, [126] = 3 },
    quests = { monkey_madness_i = { state = "in_progress" } },
    skills = { prayer = { level = 43 } },
    player = { world = world },
    inventory = { items = items or {} },
    equipment = { items = {} },
    bank = { items = {} },
    matches = matches,
  }
end

local mainland = { x = 2440, y = 3089, plane = 0 }
local zoo = { x = 2608, y = 3278, plane = 0 }
local pen = { x = 2602, y = 3278, plane = 0 }
local ape = { x = 2807, y = 2762, plane = 0 }
local demon = { x = 2715, y = 9180, plane = 1 }
local monkey = { id = 4033, quantity = 1 }
local sigil = { id = 4035, quantity = 1 }

assert(resolver.resolve(state(4, {}, mainland, false)) == "zoo_loadout_required")
assert(resolver.resolve(state(4, {}, mainland, true)) == "obtain_zoo_monkey")
assert(resolver.resolve(state(4, {}, zoo, false)) == "obtain_zoo_monkey")
assert(resolver.resolve(state(4, { monkey }, pen, false)) == "exit_zoo_with_monkey")
assert(resolver.resolve(state(4, { monkey }, mainland, false)) == "carry_monkey_to_ape_atoll")
assert(resolver.resolve(state(4, { monkey }, ape, false)) == "secure_awowogei_favor")
assert(resolver.resolve(state(4, {}, ape, false)) == "obtain_squad_sigil")
assert(resolver.resolve(state(5, {}, ape, false)) == "obtain_squad_sigil")
local cold_bank_after_sigil = state(5, {}, mainland, false)
cold_bank_after_sigil.varbits[126] = 6
assert(resolver.resolve(cold_bank_after_sigil) == "demon_loadout_required")
assert(resolver.resolve(state(5, { sigil }, mainland, false)) == "demon_loadout_required")
assert(resolver.resolve(state(5, { sigil }, mainland, true)) == "enter_jungle_demon_battle")
assert(resolver.resolve(state(5, { sigil }, demon, false)) == "defeat_jungle_demon")
assert(resolver.resolve(state(6, {}, mainland, false)) == "return_to_narnode")

print("monkey madness finale state tests passed")
