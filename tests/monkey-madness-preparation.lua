local config = dofile("scripts/quest-runner/monkey_madness_i/config.lua")
local wealth_requirement
for _, requirement in ipairs(config.zoo_loadout) do
  if requirement.id == 11980 then wealth_requirement = requirement break end
end
assert(wealth_requirement and wealth_requirement.quantity == 2,
  "zoo preparation must stock two charged rings of wealth")
assert(wealth_requirement.maximum_unit_price == 20000,
  "charged wealth-ring purchase cap changed unexpectedly")
local demon_wealth_requirement
for _, requirement in ipairs(config.demon_loadout) do
  if requirement.id == 11980 then demon_wealth_requirement = requirement break end
end
assert(demon_wealth_requirement and demon_wealth_requirement.quantity == 1,
  "boss preparation must carry a charged ring of wealth for the direct return")
local demon_prayer_requirement
local demon_staff_requirement
local demon_air_requirement
local demon_chaos_requirement
for _, requirement in ipairs(config.demon_loadout) do
  if requirement.id == 2434 then demon_prayer_requirement = requirement end
  if requirement.id == 1387 then demon_staff_requirement = requirement end
  if requirement.id == 556 then demon_air_requirement = requirement end
  if requirement.id == 562 then demon_chaos_requirement = requirement end
end
assert(demon_prayer_requirement and demon_prayer_requirement.quantity == 4 and
  demon_prayer_requirement.alternative_ids == nil,
  "boss preparation must require four full prayer potions")
assert(demon_staff_requirement and demon_staff_requirement.quantity == 1,
  "boss preparation must carry a staff of fire")
assert(demon_air_requirement and demon_air_requirement.quantity == 900,
  "boss preparation must carry 300 Fire Bolt casts worth of air runes")
assert(demon_chaos_requirement and demon_chaos_requirement.quantity == 300,
  "boss preparation must carry 300 Fire Bolt casts worth of chaos runes")
local castle_wars_teleports = 0
local prepared
local inventory_items = { { id = 2552, quantity = 1 } }
local equipment_items = {}
local bank_items = {}

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then
      return {
        in_south = function() return false end,
        in_north = function() return false end,
      }
    end
    if name == "shared_geometry" then return dofile("scripts/shared/geometry.lua") end
    if name == "shared_preparation" then
      return {
        prepare_items = function(quest, restock, loadout, exact, free_slots)
          prepared = {
            quest = quest,
            restock = restock,
            loadout = loadout,
            exact = exact,
            free_slots = free_slots,
          }
          return true
        end,
      }
    end
    if name == "shared_travel" then
      return {
        has_dueling_ring = function() return true end,
        teleport_to_castle_wars = function()
          castle_wars_teleports = castle_wars_teleports + 1
          return { status = "complete" }
        end,
      }
    end
    error("unexpected module " .. name)
  end,
  read = function(subject)
    if subject == "player" then
      return { world = { x = 3238, y = 3194, plane = 0 } }
    end
    if subject == "inventory" then
      return { items = inventory_items }
    end
    if subject == "equipment" then return { items = equipment_items } end
    if subject == "bank" then return { items = bank_items } end
    error("unexpected read " .. subject)
  end,
  await = function(request)
    assert(request.action.type == "safety.configure")
    return { status = "complete" }
  end,
}

local preparation = dofile("scripts/quest-runner/monkey_madness_i/preparation.lua")
local complete, failure = preparation.prepare_amulet_crafting("ge")
assert(complete, failure and failure.status or "preparation failed")
assert(prepared and prepared.quest == config.id and prepared.restock == "ge")
assert(prepared.exact == true and prepared.free_slots == 4)
assert(castle_wars_teleports == 0, "preparation wasted a ring charge on Castle Wars banking")

prepared = nil
complete, failure = preparation.prepare_demon("ge")
assert(complete, failure and failure.status or "boss preparation failed")
assert(prepared and prepared.free_slots == 2,
  "boss loadout must retain two free inventory slots")

prepared = nil
inventory_items = { { id = 2552, quantity = 1 } }
equipment_items = { { id = config.items.mspeak_amulet, quantity = 1 } }
bank_items = { { id = config.items.amulet_mould, quantity = 1 } }
complete, failure = preparation.prepare("ge")
assert(complete, failure and failure.status or "equipped-item preparation failed")
local food_quantity
local retained_amulet = false
for _, item in ipairs(prepared.loadout) do
  if item.id == 379 then food_quantity = item.quantity end
  if item.id == config.items.mspeak_amulet then retained_amulet = true end
end
assert(food_quantity == 16,
  "equipped retained quest item did not reduce the food loadout")
assert(retained_amulet,
  "equipped retained quest item was omitted from the bank loadout")

print("monkey madness preparation routing tests passed")
