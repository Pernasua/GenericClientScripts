local config = gc.require("witch_config")
local equipment_actions = gc.require("shared_equipment")
local item_queries = gc.require("shared_items")
local experiment = gc.require("witch_experiment")
local garden = gc.require("witch_garden")
local preparation = gc.require("shared_preparation")
local travel = gc.require("shared_travel")

local function in_shed()
  local world = gc.read("player").world
  local zone = config.zones.shed
  return world.plane == zone.plane and world.x >= zone.x1 and world.x <= zone.x2 and
    world.y >= zone.y1 and world.y <= zone.y2
end

local function in_exposed_quest_area()
  local world = gc.read("player").world
  return world.plane == 0 and world.x >= 2900 and world.x <= 2937 and
    world.y >= 3459 and world.y <= 3475
end

local function preflight()
  local player = gc.read("player")
  local skills = gc.read("skills")
  local missing = {}
  if skills.magic.level < 13 then table.insert(missing, "Magic 13") end
  if player.max_hitpoints < 12 then table.insert(missing, "12 Hitpoints") end
  if player.current_hitpoints < player.max_hitpoints then table.insert(missing, "full Hitpoints") end
  if item_queries.carried_quantity(1387) < 1 then table.insert(missing, "staff of fire") end
  if item_queries.carried_quantity(556) < 300 then table.insert(missing, "300 air runes") end
  if item_queries.carried_quantity(558) < 150 then table.insert(missing, "150 mind runes") end
  if item_queries.carried_quantity(2550) < 4 then table.insert(missing, "four rings of recoil") end
  if item_queries.carried_quantity(1993) * 11 < 60 then table.insert(missing, "60 Hitpoints of food") end
  if item_queries.carried_quantity(2409) < 1 then table.insert(missing, "door key") end
  if item_queries.carried_quantity(2411) < 1 then table.insert(missing, "shed key") end
  if not travel.has_necklace() then table.insert(missing, "charged games necklace") end
  if #missing > 0 then
    return nil, { status = "experiment_preflight_failed", missing = missing, player = player }
  end
  return true
end

local function setup()
  local staff = equipment_actions.equip(1387, "Wield", { verify_ticks = 6 })
  if staff.status ~= "complete" and staff.status ~= "unchanged" then return nil, staff end
  local recoil = equipment_actions.equip(2550, "Wear", { verify_ticks = 6 })
  if recoil.status ~= "complete" and recoil.status ~= "unchanged" then return nil, recoil end
  local autocast = gc.await {
    action = { type = "combat.set_autocast", spell = "Fire Strike" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if autocast.status ~= "set" and autocast.status ~= "unchanged" then
    return nil, { status = "experiment_autocast_failed", receipt = autocast }
  end
  local safety = gc.await {
    action = {
      type = "safety.configure",
      minimum_hitpoints = 3,
      consumables = { { id = 1993, action = "Drink", heal_amount = 11 } },
      continue_after_consumable = true,
      escape = {
        x = config.experiment.outside.x,
        y = config.experiment.outside.y,
        plane = config.experiment.outside.plane,
        within = 0,
      },
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  }
  if safety.status ~= "complete" then
    return nil, { status = "experiment_safety_failed", receipt = safety }
  end
  return true
end

local function prepare(restock)
  if in_exposed_quest_area() then
    local teleport = travel.teleport_to_burthorpe()
    if teleport.status ~= "complete" then return nil, teleport end
  end
  local loadout = {}
  for _, item in ipairs(config.combat_loadout) do table.insert(loadout, item) end
  local shed_keys = item_queries.carried_quantity(2411) + item_queries.quantity(gc.read("bank"), 2411)
  if shed_keys > 0 then
    table.insert(loadout, { id = 2411, name = "Key", quantity = 1, purchase = false })
  end
  return preparation.prepare_items("witchs_house", restock, loadout)
end

local function execute()
  local ready, failure = preflight()
  if not ready then return failure end
  local configured
  configured, failure = setup()
  if not configured then return failure end
  if not in_shed() then
    local route = garden.to_shed()
    if route.status == "garden_resume_requires_observed_route" then
      local teleport = travel.teleport_to_burthorpe()
      if teleport.status ~= "complete" then return teleport end
      route = garden.to_shed()
    end
    if route.status ~= "complete" then return route end
  end
  ready, failure = preflight()
  if not ready then return failure end
  return experiment.run_all_forms()
end

return { prepare = prepare, execute = execute }
