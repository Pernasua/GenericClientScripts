local player = { world = { x = 3267, y = 3227, plane = 0 } }
local ring_id = 2556
local teleport_count = 0
local wealth_teleport_count = 0
local walks = {}
local purchased = false
local loadout_prepared = false

local loadout = {
  { id = 2448, name = "Superantipoison(4)", quantity = 1 },
}

local function total_owned(_, id)
  if id == ring_id or id == 995 or id == 2448 then return 1 end
  return 0
end

local modules = {
  shared_bank = {
    open = function() return { available = true, open = true, items = {} } end,
  },
  shared_exchange = {
    maximum_spend = function() return 1000 end,
    buy = function()
      purchased = true
      return true
    end,
  },
  shared_state = {
    read = function()
      return {
        player = player,
        inventory = {
          items = {
            { id = ring_id, quantity = 1, tradeable = true },
          },
        },
        bank = { available = true, items = {} },
      }
    end,
  },
  shared_geometry = dofile("scripts/shared/geometry.lua"),
  shared_items = { total_owned = total_owned },
  shared_loadouts = {
    missing_carried = function()
      return loadout_prepared and {} or loadout
    end,
    matches_carried = function() return loadout_prepared end,
    missing = function() return purchased and {} or loadout end,
  },
  shared_travel = {
    has_necklace = function() return false end,
    has_wealth_ring = function() return true end,
    has_dueling_ring = function() return true end,
    teleport_to_grand_exchange = function()
      wealth_teleport_count = wealth_teleport_count + 1
      player.world = { x = 3163, y = 3478, plane = 0 }
      return { status = "complete" }
    end,
    teleport_to_emirs_arena = function()
      teleport_count = teleport_count + 1
      player.world = { x = 3315, y = 3235, plane = 0 }
      return { status = "complete" }
    end,
  },
}

for _, name in ipairs({
  "witch_config",
  "waterfall_config",
  "tree_gnome_config",
  "fight_arena_config",
  "grand_tree_config",
  "monkey_madness_config",
}) do
  modules[name] = { label = name }
end

gc = {
  require = function(name)
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    assert(modules[name], "unexpected module " .. name)
    return modules[name]
  end,
  read = function(subject)
    if subject == "player" then return player end
    error("unexpected read " .. subject)
  end,
  overlay = function() end,
  await = function(request)
    local action = request.action
    if action.type == "walk.to" then
      walks[#walks + 1] = action.destination
      player.world = {
        x = action.destination.x,
        y = action.destination.y,
        plane = action.destination.plane,
      }
      return { status = "arrived" }
    end
    if action.type == "bank.loadout" then
      if action.minimum_free_slots ~= 20 then loadout_prepared = true end
      return { status = "complete" }
    end
    error("unexpected action " .. action.type)
  end,
}

local preparation = dofile("scripts/quest-runner/shared/preparation.lua")
local complete, failure = preparation.prepare_items(
  "monkey_madness_i",
  "ge",
  loadout,
  true,
  4)

assert(complete, failure and failure.status or "preparation failed")
assert(wealth_teleport_count == 1, "charged wealth ring was not preferred for direct GE travel")
assert(teleport_count == 0, "GE travel wasted a dueling-ring charge despite a wealth ring")
assert(#walks == 1 and walks[1].x == 3165 and walks[1].y == 3491,
	"GE preparation inserted hand-authored Varrock detours")
assert(purchased, "expected missing supplies to be purchased")

player.world = { x = 3267, y = 3227, plane = 0 }
teleport_count = 0
wealth_teleport_count = 0
walks = {}
purchased = false
loadout_prepared = false
modules.shared_travel.has_wealth_ring = function() return false end
complete, failure = preparation.prepare_items(
  "monkey_madness_i",
  "ge",
  loadout,
  true,
  4)
assert(complete, failure and failure.status or "fallback preparation failed")
assert(wealth_teleport_count == 0, "unavailable wealth ring was used")
assert(teleport_count == 1, "dueling-ring fallback was not retained")

print("shared preparation routing tests passed")
