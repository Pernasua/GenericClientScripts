local config = gc.require("monkey_madness_config")
local areas = gc.require("monkey_madness_areas")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local loadouts = gc.require("shared_loadouts")

local function on_ape_atoll(world)
  return areas.in_south(world) or
    geometry.in_zone(world, config.zones.ape_atoll_prison) or
    areas.in_north(world) or
    geometry.in_zone(world, config.zones.temple_dungeon)
end

local function infiltration_loadout(dentures, mould)
  local retained = dentures + mould
  local loadout = {}
  for _, item in ipairs(config.ape_atoll_loadout) do
    local copy = {}
    for key, value in pairs(item) do copy[key] = value end
    if copy.id == 379 then copy.quantity = math.max(1, copy.quantity - retained) end
    loadout[#loadout + 1] = copy
  end
  return loadout
end

local function loadout_item(loadout, id)
  for _, item in ipairs(loadout) do
    if item.id == id then return item end
  end
end

local function carried_quantity(state, item)
  local total = item_queries.quantity(state.inventory, item.id) +
    item_queries.quantity(state.equipment, item.id)
  for _, id in ipairs(item.alternative_ids or {}) do
    total = total + item_queries.quantity(state.inventory, id) +
      item_queries.quantity(state.equipment, id)
  end
  return total
end

local function infiltration_ready(state)
  return carried_quantity(state, loadout_item(config.ape_atoll_loadout, 379)) >= 5 and
    carried_quantity(state, loadout_item(config.ape_atoll_loadout, 2448)) > 0 and
    carried_quantity(state, loadout_item(config.ape_atoll_loadout, 2552)) > 0 and
    carried_quantity(state, loadout_item(config.ape_atoll_loadout, 1523)) > 0 and
    carried_quantity(state, loadout_item(config.ape_atoll_loadout, 2434)) > 0
end

local function amulet_bar_ready(state)
  return carried_quantity(state, loadout_item(config.amulet_bar_loadout, 379)) >= 5 and
    carried_quantity(state, loadout_item(config.amulet_bar_loadout, 2448)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_bar_loadout, 2552)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_bar_loadout, 1523)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_bar_loadout, 2434)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_bar_loadout, 2357)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_bar_loadout, 4006)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_bar_loadout, 4020)) > 0
end

local function amulet_crafting_ready(state)
  return carried_quantity(state, loadout_item(config.amulet_crafting_loadout, 379)) >= 5 and
    carried_quantity(state, loadout_item(config.amulet_crafting_loadout, 2448)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_crafting_loadout, 12625)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_crafting_loadout, 2552)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_crafting_loadout, 1523)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_crafting_loadout, 2434)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_crafting_loadout, 4007)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_crafting_loadout, 4020)) > 0 and
    carried_quantity(state, loadout_item(config.amulet_crafting_loadout, 1759)) > 0
end

local function owns_any(state, ids)
  for _, id in ipairs(ids) do
    if item_queries.total_owned(state, id) > 0 then return true end
  end
  return false
end

local function resolve(state)
  if state.quests.monkey_madness_i and state.quests.monkey_madness_i.state == "finished" then
    return "complete"
  end
  if state.varp == 0 then return "start_quest" end
  if state.varp <= 2 then
    if state.varbits[config.varbits.caranock] < 3 then return "investigate_shipyard" end
    if state.varbits[config.varbits.narnode] < 7 then return "report_shipyard" end
    if state.varbits[config.varbits.daero] < 1 then return "meet_daero" end
    if state.varbits[config.varbits.daero] < 5 then return "enter_hangar" end
    if state.varbits[config.varbits.daero] < 6 then return "solve_reinitialization" end
    if state.varbits[config.varbits.daero] < 7 then return "confirm_reinitialization" end
  end
  local past_garkor = owns_any(state, {
    config.items.monkey_dentures,
    config.items.amulet_mould,
    config.items.enchanted_bar,
    config.items.unstrung_amulet,
    config.items.mspeak_amulet,
    config.items.monkey_talisman,
    config.items.karamjan_greegree,
  })
  local world = state.player and state.player.world
  if item_queries.total_owned(state, config.items.karamjan_greegree) > 0 and
    geometry.in_zone(world, config.zones.zooknock_dungeon) then
    return "sync_karamjan_greegree"
  end
  if state.varp <= 3 and state.varbits[config.varbits.garkor] < 2 and not past_garkor then
    if on_ape_atoll(state.player and state.player.world) then return "find_garkor" end
    if not loadouts.matches_carried(state, config.ape_atoll_loadout) then
      return "ape_atoll_loadout_required"
    end
    return "reach_ape_atoll"
  end
  if state.varp == 3 then
    local has_amulet = item_queries.total_owned(state, config.items.mspeak_amulet) > 0
    local has_talisman = item_queries.total_owned(state, config.items.monkey_talisman) > 0
    if item_queries.total_owned(state, config.items.karamjan_greegree) > 0 then
      return "sync_karamjan_greegree"
    end
    if has_amulet and has_talisman then
      if geometry.in_zone(world, config.zones.zooknock_dungeon) then
        return "make_karamjan_greegree"
      end
      if areas.in_south(world) then return "reach_zooknock_for_greegree" end
      return loadouts.matches_carried(state, config.greegree_loadout) and
        "reach_ape_atoll_for_greegree" or "greegree_loadout_required"
    end
    if has_amulet then
      if geometry.in_zone(world, config.zones.temple_dungeon) or
        (areas.in_north(world) and not areas.in_prison(world) and
          geometry.distance(world, config.points.monkey_child_staging) ~= 0) then
        return "leave_temple_with_amulet"
      end
      return "obtain_monkey_talisman"
    end
    if item_queries.total_owned(state, config.items.unstrung_amulet) > 0 then
      local carried_unstrung = item_queries.quantity(state.inventory, config.items.unstrung_amulet) +
        item_queries.quantity(state.equipment, config.items.unstrung_amulet)
      local carried_wool = item_queries.quantity(state.inventory, config.items.ball_of_wool) +
        item_queries.quantity(state.equipment, config.items.ball_of_wool)
      return carried_unstrung > 0 and carried_wool > 0 and
        "string_mspeak_amulet" or "amulet_crafting_loadout_required"
    end
    if item_queries.total_owned(state, config.items.enchanted_bar) > 0 then
      if geometry.in_zone(world, config.zones.zooknock_dungeon) then
        return "enchanted_bar_obtained"
      end
      if areas.in_prison(world) then return "escape_prison_for_amulet" end
      if areas.in_south(world) then return "reach_prison_for_amulet" end
      if on_ape_atoll(world) then return "make_mspeak_amulet" end
      return amulet_crafting_ready(state) and
        "reach_ape_atoll_for_amulet" or "amulet_crafting_loadout_required"
    end
    if geometry.in_zone(world, config.zones.zooknock_dungeon) then
      return "make_enchanted_bar"
    end
    local dentures = item_queries.quantity(state.inventory, config.items.monkey_dentures) +
      item_queries.quantity(state.equipment, config.items.monkey_dentures)
    local mould = item_queries.quantity(state.inventory, config.items.amulet_mould) +
      item_queries.quantity(state.equipment, config.items.amulet_mould)
    if item_queries.total_owned(state, config.items.monkey_dentures) > 0 and
      item_queries.total_owned(state, config.items.amulet_mould) > 0 then
      if on_ape_atoll(world) then
        return amulet_bar_ready(state) and
          "make_enchanted_bar" or "amulet_bar_loadout_required"
      end
      return loadouts.matches_carried(state, config.amulet_bar_loadout) and
        "reach_ape_atoll_for_amulet_bar" or "amulet_bar_loadout_required"
    end
    local inside_infiltration = geometry.in_zone(world, config.zones.denture_building) or
      geometry.in_zone(world, config.zones.amulet_mould_room)
    if not inside_infiltration then
      if on_ape_atoll(world) then
        if not infiltration_ready(state) then return "ape_atoll_loadout_required" end
      elseif #loadouts.missing_carried(state, infiltration_loadout(dentures, mould)) > 0 then
        return "ape_atoll_loadout_required"
      end
    end
    if not on_ape_atoll(world) and not geometry.in_zone(world, config.zones.amulet_mould_room) then
      return "reach_ape_atoll"
    end
    return "infiltrate_ape_atoll"
  end
  if state.varp == 4 then
    local has_monkey = item_queries.total_owned(state, config.items.zoo_monkey) > 0
    if has_monkey then
      if areas.in_monkey_pen(world) then return "exit_zoo_with_monkey" end
      if on_ape_atoll(world) or areas.in_throne_room(world) or
        geometry.in_zone(world, config.zones.ape_atoll_bridge) or
        geometry.in_zone(world, config.zones.ape_atoll_over_bridge) then
        return "secure_awowogei_favor"
      end
      return "carry_monkey_to_ape_atoll"
    end
    if areas.in_throne_room(world) or geometry.in_zone(world, config.zones.ape_atoll_north) or
      geometry.in_zone(world, config.zones.ape_atoll_north_west) or
      geometry.in_zone(world, config.zones.ape_atoll_north_east) or
      geometry.in_zone(world, config.zones.ape_atoll_bridge) or
      geometry.in_zone(world, config.zones.ape_atoll_over_bridge) then
      return "obtain_squad_sigil"
    end
    if areas.in_monkey_pen(world) or
      (world and world.plane == 0 and
        math.max(math.abs(world.x - config.points.ardougne_zoo_minder.x),
          math.abs(world.y - config.points.ardougne_zoo_minder.y)) <= 30) then
      return "obtain_zoo_monkey"
    end
    return loadouts.matches_carried(state, config.zoo_loadout) and
      "obtain_zoo_monkey" or "zoo_loadout_required"
  end
  if state.varp == 5 then
    local world = state.player and state.player.world
    if areas.in_demon_room(world) then return "defeat_jungle_demon" end
    if loadouts.matches_carried(state, config.demon_loadout) then
      return "enter_jungle_demon_battle"
    end
    if state.varbits[config.varbits.garkor] >= 6 or
      item_queries.total_owned(state, config.items.squad_sigil) > 0 then
      return "demon_loadout_required"
    end
    return "obtain_squad_sigil"
  end
  if state.varp >= 6 then return "return_to_narnode" end
  return "unknown_stage"
end

return { resolve = resolve }
