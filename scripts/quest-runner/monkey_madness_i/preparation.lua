local config = gc.require("monkey_madness_config")
local areas = gc.require("monkey_madness_areas")
local geometry = gc.require("shared_geometry")
local preparation = gc.require("shared_preparation")

local dueling_ring_ids = { 2552, 2554, 2556, 2558, 2560, 2562, 2564, 2566 }
local retained_quest_items = {
  [config.items.monkey_dentures] = "Monkey dentures",
  [config.items.amulet_mould] = "M'amulet mould",
  [config.items.enchanted_bar] = "Enchanted bar",
  [config.items.unstrung_amulet] = "Unstrung M'speak amulet",
  [config.items.mspeak_amulet] = "M'speak amulet",
  [config.items.monkey_talisman] = "Monkey talisman",
  [config.items.karamjan_monkey_bones] = "Monkey bones",
  [config.items.karamjan_monkey_corpse] = "Monkey corpse",
  [config.items.karamjan_greegree] = "Karamjan monkey greegree",
  [config.items.zoo_monkey] = "Monkey",
  [config.items.squad_sigil] = "10th squad sigil",
}

local function on_ape_atoll(world)
  return areas.in_south(world) or
    geometry.in_zone(world, config.zones.ape_atoll_prison) or
    areas.in_north(world) or
    geometry.in_zone(world, config.zones.amulet_mould_room) or
    geometry.in_zone(world, config.zones.zooknock_dungeon) or
    geometry.in_zone(world, config.zones.temple_dungeon)
end

local function active_loadout()
  local owned = {}
  for _, container in ipairs({
    gc.read("inventory"),
    gc.read("equipment"),
    gc.read("bank"),
  }) do
    for _, item in ipairs(container.items or {}) do
      if retained_quest_items[item.id] then
        owned[item.id] = (owned[item.id] or 0) + item.quantity
      end
    end
  end
  local retained = 0
  for id in pairs(retained_quest_items) do
    if (owned[id] or 0) > 0 then retained = retained + 1 end
  end
  local loadout = {}
  for _, item in ipairs(config.ape_atoll_loadout) do
    local copy = {}
    for key, value in pairs(item) do copy[key] = value end
    if copy.id == 379 then copy.quantity = math.max(1, copy.quantity - retained) end
    loadout[#loadout + 1] = copy
  end
  for id, name in pairs(retained_quest_items) do
    if (owned[id] or 0) > 0 then
      loadout[#loadout + 1] = {
        id = id,
        name = name,
        quantity = 1,
        purchase = false,
      }
    end
  end
  return loadout
end

local function current_ring_id()
  local inventory = gc.read("inventory")
  for _, id in ipairs(dueling_ring_ids) do
    for _, item in ipairs(inventory.items or {}) do
      if item.id == id and item.quantity > 0 then return id end
    end
  end
  return nil
end

local function arm_safety(minimum_hitpoints)
  local ring = current_ring_id()
  if not ring then
    return nil, { status = "monkey_madness_escape_ring_not_carried" }
  end
  local receipt = gc.await {
    action = {
      type = "safety.configure",
      minimum_hitpoints = minimum_hitpoints or 4,
      consumables = { { id = 379, action = "Eat", heal_amount = 12 } },
      continue_after_consumable = true,
      allow_overheal = true,
      escape = {
        type = "inventory_dialogue",
        item_id = ring,
        alternative_item_ids = dueling_ring_ids,
        action = "Rub",
        choice = "Castle Wars Arena",
        x = 2440,
        y = 3089,
        plane = 0,
        within = 10,
      },
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  }
  if receipt.status ~= "complete" then
    return nil, { status = "monkey_madness_safety_failed", receipt = receipt }
  end
  return true, receipt
end

local function prepare_loadout(restock, loadout, minimum_free_slots)
  local world = gc.read("player").world
  if current_ring_id() then
    local armed, safety_error = arm_safety()
    if not armed then return nil, safety_error end
  elseif on_ape_atoll(world) then
    return nil, { status = "monkey_madness_escape_ring_not_carried" }
  end
  local prepared, failure = preparation.prepare_items(
    config.id,
    restock,
    loadout,
    true,
    minimum_free_slots)
  if not prepared then return nil, failure end
  local rearmed, rearm_error = arm_safety()
  if not rearmed then return nil, rearm_error end
  return true
end

local function prepare(restock)
  return prepare_loadout(
    restock,
    active_loadout(),
    config.ape_atoll_minimum_free_slots)
end

local function prepare_amulet_bar(restock)
  return prepare_loadout(restock, config.amulet_bar_loadout, 4)
end

local function prepare_amulet_crafting(restock)
  return prepare_loadout(restock, config.amulet_crafting_loadout, 4)
end

local function prepare_greegree(restock)
  return prepare_loadout(restock, config.greegree_loadout, 4)
end

local function prepare_zoo(restock)
  return prepare_loadout(restock, config.zoo_loadout, 5)
end

local function prepare_demon(restock)
  return prepare_loadout(restock, config.demon_loadout, 2)
end

return {
  prepare = prepare,
  prepare_amulet_bar = prepare_amulet_bar,
  prepare_amulet_crafting = prepare_amulet_crafting,
  prepare_greegree = prepare_greegree,
  prepare_zoo = prepare_zoo,
  prepare_demon = prepare_demon,
  arm_safety = arm_safety,
}
