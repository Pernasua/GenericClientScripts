local config = gc.require("witch_config")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local loadouts = gc.require("shared_loadouts")

local function resolve(state)
  if state.quests.witchs_house.state == "finished" or state.varp == 7 then
    return "complete"
  end
  local hp = state.player and state.player.max_hitpoints or 0
  local current_hp = state.player and state.player.current_hitpoints or 0
  if state.skills.magic.level < 13 or hp < 12 or current_hp < hp then
    return "strict_stats_block"
  end
  if state.varp == 0 and #loadouts.missing_carried(state, config.loadout) > 0 then
    if not state.bank.available then return "bank_unknown" end
    local missing = loadouts.missing(state, config.loadout)
    if #missing > 0 then
      state.missing = missing
      return "loadout_required"
    end
  end

  local world = state.player.world
  if state.varp == 0 then return "accept" end
  if state.varp == 1 or state.varp == 2 then
    local magnet = item_queries.total_owned(state, 2410) > 0
    if not magnet then
      if geometry.in_zone(world, config.zones.basement_east) then
        if item_queries.quantity(state.equipment, 1059) == 0 then return "equip_gloves" end
        return "open_gate"
      end
      if geometry.in_zone(world, config.zones.basement_west) then
        local open = gc.read("objects", { id = 2869, within = 12, limit = 1 })
        return #open > 0 and "obtain_magnet" or "open_cupboard"
      end
      if geometry.in_zone(world, config.zones.witch_house) then return "descend_basement" end
      if item_queries.total_owned(state, 2409) == 0 then return "obtain_house_key" end
      return "enter_house"
    end
    if geometry.in_zone(world, config.zones.basement_east) or geometry.in_zone(world, config.zones.basement_west) then
      return "return_upstairs"
    end
    return "lure_mouse"
  end
  if state.varp == 3 then
    return item_queries.quantity(state.inventory, 2408) == 0 and "take_diary" or "read_diary"
  end
  if state.varp == 5 then
    if item_queries.total_owned(state, 2409) == 0 then return "obtain_house_key" end
    if #loadouts.missing_carried(state, config.combat_loadout) > 0 then
      return "experiment_loadout_required"
    end
    return item_queries.total_owned(state, 2411) > 0 and "shed_ready_checkpoint" or "garden_fountain"
  end
  if state.varp == 6 then return "experiment_complete_checkpoint" end
  return "unknown_stage"
end

return { resolve = resolve }
