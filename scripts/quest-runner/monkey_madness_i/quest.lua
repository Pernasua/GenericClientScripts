local config = gc.require("monkey_madness_config")
local navigation = gc.require("monkey_madness_navigation")
local interactions = gc.require("monkey_madness_interactions")
local puzzle = gc.require("monkey_madness_puzzle")
local preparation = gc.require("monkey_madness_preparation")
local ape_atoll = gc.require("monkey_madness_ape_atoll")
local areas = gc.require("monkey_madness_areas")
local garkor = gc.require("monkey_madness_garkor")
local infiltration = gc.require("monkey_madness_infiltration")
local amulet = gc.require("monkey_madness_amulet")
local amulet_crafting = gc.require("monkey_madness_amulet_crafting")
local disguise = gc.require("monkey_madness_disguise")
local favor = gc.require("monkey_madness_favor")
local battle = gc.require("monkey_madness_battle")
local completion = gc.require("monkey_madness_completion")
local item_queries = gc.require("shared_items")
local travel = gc.require("shared_travel")

local function carried_quantity(item_id)
  return item_queries.quantity(gc.read("inventory"), item_id) +
    item_queries.quantity(gc.read("equipment"), item_id)
end

local function reach_prison_cell(input)
  local receipts = {}
  local world = gc.read("player").world

  if areas.in_prison(world) and
    carried_quantity(config.items.mspeak_amulet) == 0 and
    item_queries.quantity(gc.read("bank"), config.items.mspeak_amulet) > 0 then
    local escaped = amulet_crafting.escape_prison()
    receipts.bank_trip_escape = escaped
    if escaped.status ~= "complete" then return escaped end

    local teleported = travel.teleport_to_castle_wars({
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      keyboard = true,
    })
    receipts.bank_trip_teleport = teleported
    if teleported.status ~= "complete" then return teleported end

    local prepared, failure = preparation.prepare(input and input.restock or "bank_only")
    if not prepared then return failure end
    receipts.prepared = true
    if carried_quantity(config.items.mspeak_amulet) == 0 then
      return { status = "monkey_madness_mspeak_amulet_not_carried_after_bank" }
    end
    world = gc.read("player").world
  end

  if areas.in_north(world) and not areas.in_prison(world) then
    return { status = "prison_cell_target_not_reachable", player = gc.read("player") }
  end

  if not areas.in_south(world) and not areas.in_prison(world) then
    if not receipts.prepared then
      local prepared, failure = preparation.prepare(input and input.restock or "bank_only")
      if not prepared then return failure end
      receipts.prepared = true
    end

    local landed = ape_atoll.execute()
    receipts.ape_atoll = landed
    if landed.status ~= "complete" then return landed end
  end

  if not areas.in_prison(gc.read("player").world) then
    local captured = amulet_crafting.reach_prison()
    receipts.capture = captured
    if captured.status ~= "complete" then return captured end
  end

  local safe = amulet_crafting.reach_prison_safe_spot()
  receipts.safe_spot = safe
  if safe.status ~= "complete" then return safe end
  return {
    status = "complete",
    result = "ape_atoll_prison_safe_spot_reached",
    receipts = receipts,
    player = gc.read("player"),
  }
end

local function execute(phase, input)
  if phase == "start_quest" then
    local target, failure = navigation.reach_narnode()
    if not target then return failure end
    return interactions.start_quest(target)
  end
  if phase == "investigate_shipyard" then
    local target = navigation.npc({ 1460 }, 20)
    if not target then
      local reached = navigation.reach_shipyard_gate()
      if reached.status ~= "complete" then return reached end
      local entered = interactions.enter_shipyard()
      if entered.status ~= "complete" then return entered end
      local failure
      target, failure = navigation.reach_caranock()
      if not target then return failure end
    end
    return interactions.talk_caranock(target)
  end
  if phase == "report_shipyard" then
    local target, failure = navigation.reach_narnode()
    if not target then return failure end
    return interactions.report_to_narnode(target)
  end
  if phase == "meet_daero" then
    local target, failure = navigation.reach_daero()
    if not target then return failure end
    return interactions.talk_daero(target)
  end
  if phase == "enter_hangar" then
    return interactions.enter_hangar()
  end
  if phase == "solve_reinitialization" then
    return puzzle.solve()
  end
  if phase == "confirm_reinitialization" then
    local target, failure = navigation.reach_post_puzzle_daero()
    if not target then return failure end
    return interactions.confirm_reinitialization(target)
  end
  if phase == "ape_atoll_loadout_required" then
    local prepared, failure = preparation.prepare(input and input.restock or "bank_only")
    if not prepared then return failure end
    return { status = "complete", result = "ape_atoll_loadout_prepared" }
  end
  if phase == "reach_ape_atoll" then
    return ape_atoll.execute()
  end
  if phase == "find_garkor" then
    return garkor.execute()
  end
  if phase == "infiltrate_ape_atoll" then
    return infiltration.execute()
  end
  if phase == "amulet_bar_loadout_required" then
    local prepared, failure = preparation.prepare_amulet_bar(
      input and input.restock or "bank_only")
    if not prepared then return failure end
    return { status = "complete", result = "amulet_bar_loadout_prepared" }
  end
  if phase == "reach_ape_atoll_for_amulet_bar" then
    return ape_atoll.execute()
  end
  if phase == "make_enchanted_bar" then
    return amulet.make_enchanted_bar()
  end
  if phase == "amulet_crafting_loadout_required" then
    local prepared, failure = preparation.prepare_amulet_crafting(
      input and input.restock or "bank_only")
    if not prepared then return failure end
    return { status = "complete", result = "amulet_crafting_loadout_prepared" }
  end
  if phase == "reach_ape_atoll_for_amulet" then
    return ape_atoll.execute()
  end
  if phase == "reach_prison_for_amulet" then
    return amulet_crafting.reach_prison()
  end
  if phase == "escape_prison_for_amulet" then
    if input and input.scope == "prison_cell" then
      return amulet_crafting.reach_prison_safe_spot()
    end
    return amulet_crafting.escape_prison()
  end
  if phase == "make_mspeak_amulet" then
    return amulet_crafting.make()
  end
  if phase == "string_mspeak_amulet" then
    return amulet_crafting.finish()
  end
  if phase == "leave_temple_with_amulet" then
    return amulet_crafting.finish()
  end
  if phase == "obtain_monkey_talisman" then
    return disguise.obtain_talisman()
  end
  if phase == "greegree_loadout_required" then
    local prepared, failure = preparation.prepare_greegree(
      input and input.restock or "bank_only")
    if not prepared then return failure end
    return { status = "complete", result = "greegree_loadout_prepared" }
  end
  if phase == "reach_ape_atoll_for_greegree" then
    return ape_atoll.execute()
  end
  if phase == "reach_zooknock_for_greegree" or
    phase == "make_karamjan_greegree" then
    return disguise.make_greegree()
  end
  if phase == "sync_karamjan_greegree" then
    return disguise.sync_greegree()
  end
  if phase == "zoo_loadout_required" then
    local prepared, failure = preparation.prepare_zoo(
      input and input.restock or "bank_only")
    if not prepared then return failure end
    return { status = "complete", result = "zoo_loadout_prepared" }
  end
  if phase == "obtain_zoo_monkey" then
    return favor.obtain_zoo_monkey()
  end
  if phase == "exit_zoo_with_monkey" or phase == "carry_monkey_to_ape_atoll" then
    return favor.carry_monkey_to_ape_atoll()
  end
  if phase == "secure_awowogei_favor" then
    return favor.secure_awowogei_favor()
  end
  if phase == "obtain_squad_sigil" then
    return favor.obtain_sigil()
  end
  if phase == "demon_loadout_required" then
    local prepared, failure = preparation.prepare_demon(
      input and input.restock or "bank_only")
    if not prepared then return failure end
    return { status = "complete", result = "demon_loadout_prepared" }
  end
  if phase == "enter_jungle_demon_battle" then
    return battle.enter()
  end
  if phase == "defeat_jungle_demon" then
    return battle.fight()
  end
  if phase == "return_to_narnode" then
    return completion.finish()
  end
  return { status = "rejected", result = "monkey_madness_phase_not_implemented:" .. tostring(phase) }
end

return {
  execute = execute,
  reach_prison_cell = reach_prison_cell,
}
