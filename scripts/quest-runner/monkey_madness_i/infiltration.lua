local config = gc.require("monkey_madness_config")
local areas = gc.require("monkey_madness_areas")
local behaviors = gc.require("shared_behaviors")
local geometry = gc.require("shared_geometry")
local movement = gc.require("shared_movement")
local item_queries = gc.require("shared_items")
local garkor = gc.require("monkey_madness_garkor")
local preparation = gc.require("monkey_madness_preparation")

local function traverse_infiltration(journey)
  gc.activity("hazardous_travel")
  local moved = movement.walk(journey.destination, journey.within, {
    ticks = 600,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    activity = "hazardous_travel", via = journey.via, avoid_tiles = journey.avoid_tiles,
    interrupt_on = { area = { name = "prison", bounds = areas.prison_bounds() } },
  })
  if areas.in_prison(gc.read("player").world) then
    return nil, { status = "monkey_madness_infiltration_recaptured",
      destination = journey.destination, receipt = moved }
  end
  if moved.status ~= "arrived" then
    return nil, { status = "monkey_madness_infiltration_walk_failed", destination = journey.destination,
      receipt = moved, player = gc.read("player") }
  end
  return moved
end

local function object(id, action, within)
  return gc.read("objects", {
    id = id,
    action = action,
    within = within or 10,
    limit = 1,
  })[1]
end

local function interact(target, action, within)
  local receipt
  for _ = 1, 8 do
    receipt = gc.await {
      action = {
        type = "object.interact",
        id = target.id,
        action = action,
        world = target.world,
        within = within or 8,
      },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 30 },
    }
    if receipt.status == "dispatched" then return receipt end
    if receipt.result ~= "interaction_already_running" and
      receipt.result ~= "cancelled: emergency_consumable" and
      receipt.result ~= "cancelled: combat_guard" and
      receipt.result ~= "hover_has_no_matching_action" then
      return receipt
    end
    gc.await { event = "game.tick" }
  end
  return receipt
end

local function choose_and_verify(choice, item_id, expected_zone, ticks, since_tick)
  local function choose_now()
    return gc.await {
      action = { type = "dialogue.choose", text = choice, reading = false },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 10 },
    }
  end
  since_tick = since_tick or gc.read("runtime").game_tick
  local last_mesbox_tick = -1
  local choice_pending = false
  local receipts = {}
  for _ = 1, ticks or 60 do
    if item_id and item_queries.inventory_quantity(item_id) > 0 then return true end
    if expected_zone and geometry.in_zone(gc.read("player").world, expected_zone) then return true end

    local newest_mesbox
    for _, message in ipairs(gc.read("messages", { since_tick = since_tick, limit = 20 })) do
      if message.type == "mesbox" and message.game_tick > last_mesbox_tick and
        (not newest_mesbox or message.game_tick > newest_mesbox.game_tick) then
        newest_mesbox = message
      end
    end
    local advanced_this_tick = false
    if newest_mesbox then
      last_mesbox_tick = newest_mesbox.game_tick
      local advanced = gc.await {
        action = { type = "ui.key", key = "SPACE" },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 20 },
      }
      receipts[#receipts + 1] = { message = newest_mesbox, advanced = advanced }
      if advanced.status ~= "dispatched" then
        return nil, {
          status = "monkey_madness_infiltration_mesbox_failed",
          receipt = advanced,
          receipts = receipts,
        }
      end
      choice_pending = true
      advanced_this_tick = true
    end

    local dialogue = gc.read("dialogue")
    if not advanced_this_tick and (dialogue.type == "choice" or choice_pending) then
      local chosen = choose_now()
      receipts[#receipts + 1] = { chosen = chosen }
      if chosen.status == "dispatched" then
        choice_pending = false
      elseif chosen.result ~= "exact_dialogue_choice_not_visible" then
        return nil, {
          status = "monkey_madness_infiltration_choice_failed",
          option = choice,
          receipt = chosen,
          receipts = receipts,
        }
      end
    elseif dialogue.type == "continue" then
      local continued = gc.await {
        action = { type = "dialogue.continue", reading = false },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 30 },
      }
      if continued.status ~= "dispatched" and
        continued.result ~= "dialogue_continue_not_visible" and
        continued.result ~= "dialogue_is_choice" then
        return nil, {
          status = "monkey_madness_infiltration_dialogue_failed",
          receipt = continued,
          receipts = receipts,
        }
      end
      receipts[#receipts + 1] = { continued = continued }
    elseif dialogue.type ~= "closed" and dialogue.type ~= "choice" then
      return nil, {
        status = "monkey_madness_infiltration_dialogue_unexpected",
        dialogue = dialogue,
        receipts = receipts,
      }
    end
    gc.await { event = "game.tick" }
  end
  return nil, {
    status = "monkey_madness_infiltration_postcondition_timeout",
    option = choice,
    item_id = item_id,
    player = gc.read("player"),
    dialogue = gc.read("dialogue"),
    messages = gc.read("messages", { limit = 20 }),
    receipts = receipts,
  }
end

local function reach_denture_building()
  local world = gc.read("player").world
  if geometry.in_zone(world, config.zones.denture_building) then
    return true, {}
  end

  local escaped_from_prison = geometry.in_zone(world, config.zones.prison_north_exit) or
    geometry.in_zone(world, config.zones.prison_west_clear) or
    geometry.distance(world, config.points.prison_clear) <= 4
  if areas.in_south(world) then
    local captured = garkor.reach_prison()
    if captured.status ~= "complete" then return nil, captured end
    escaped_from_prison = true
    world = gc.read("player").world
  end

  if areas.in_prison(world) then
    local escaped = garkor.escape_prison()
    if escaped.status ~= "complete" then return nil, escaped end
    escaped_from_prison = true
  end

  if escaped_from_prison then
    local refreshed, poison_failure = garkor.refresh_antipoison()
    if not refreshed then return nil, poison_failure end
  end

  local configured, behavior_failure = behaviors.configure {
    auto_retaliate = false,
    emergency_escape = true,
  }
  if not configured then return nil, behavior_failure end
  if escaped_from_prison then
    local route, failure = traverse_infiltration(config.routes.prison_to_dentures)
    if not route then return nil, failure end
  else
    local route, failure = traverse_infiltration(config.routes.garkor_to_dentures)
    if not route then return nil, failure end
  end

  local door = object(config.objects.denture_building_door, "Open", 10)
  if not door then
    return nil, {
      status = "monkey_madness_denture_door_not_observed",
      player = gc.read("player"),
      objects = gc.read("objects", { within = 12, limit = 60 }),
    }
  end
  local opened = interact(door, "Open", 8)
  if opened.status ~= "dispatched" then return nil, opened end
  for _ = 1, 30 do
    gc.await { event = "game.tick" }
    if geometry.in_zone(gc.read("player").world, config.zones.denture_building) then
      return true, { behaviors = behaviors, door = opened }
    end
  end
  return nil, {
    status = "monkey_madness_denture_building_entry_unverified",
    receipt = opened,
    player = gc.read("player"),
  }
end

local function obtain_dentures()
  if item_queries.inventory_quantity(config.items.monkey_dentures) > 0 then return { status = "complete" } end
  local settled = garkor.settle_combat()
  if settled.status ~= "complete" then return settled end
  gc.activity("questing")
  local approach, approach_failure = traverse_infiltration(config.routes.denture_safe_approach)
  if not approach then return approach_failure end
  local crate = object(config.objects.denture_crate, "Search", 4)
  if not crate then
    return {
      status = "monkey_madness_denture_crate_not_observed",
      objects = gc.read("objects", { within = 8, limit = 60 }),
    }
  end
  local since_tick = gc.read("runtime").game_tick
  local searched = interact(crate, "Search", 2)
  if searched.status ~= "dispatched" then return searched end
  local obtained, failure = choose_and_verify(
    "Yes", config.items.monkey_dentures, nil, 60, since_tick)
  if not obtained then return failure end
  return {
    status = "complete",
    result = "monkey_dentures_obtained",
    combat = settled,
    approach = approach,
    receipt = searched,
  }
end

local function wait_for_message(since_tick, text, ticks)
  for _ = 1, ticks do
    for _, message in ipairs(gc.read("messages", { since_tick = since_tick, limit = 20 })) do
      if string.find(string.lower(message.text or ""), text, 1, true) then
        return message
      end
    end
    gc.await { event = "game.tick" }
  end
end

local function descend_to_mould_room()
  if geometry.in_zone(gc.read("player").world, config.zones.amulet_mould_room) then
    return { status = "complete" }
  end

  local settled = garkor.settle_combat()
  if settled.status ~= "complete" then return settled end
  gc.activity("questing")

  gc.activity("hazardous_travel")
  local approach = movement.walk(config.points.denture_hole, 0, {
    ticks = 40,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    avoid_tiles = config.danger_tiles.denture_light_floor,
  })
  if approach.status ~= "arrived" then return approach end

  local crate = object(config.objects.denture_hole_crate, "Search", 4)
  if not crate then
    return {
      status = "monkey_madness_denture_hole_not_observed",
      objects = gc.read("objects", { within = 8, limit = 60 }),
    }
  end
  local since_tick = gc.read("runtime").game_tick
  local searched = interact(crate, "Search", 2)
  if searched.status ~= "dispatched" then return searched end
  local discovered = wait_for_message(since_tick, "find a hole in the floor", 12)
  if not discovered then
    return {
      status = "monkey_madness_denture_hole_message_missing",
      receipt = searched,
      messages = gc.read("messages", { since_tick = since_tick, limit = 20 }),
    }
  end

  local advanced = gc.await {
    action = { type = "ui.key", key = "SPACE" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  if advanced.status ~= "dispatched" then return advanced end

  local selected
  for _ = 1, 12 do
    gc.await { event = "game.tick" }
    selected = gc.await {
      action = { type = "dialogue.choose", text = "Yes, I'm sure.", reading = false },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 8 },
    }
    if selected.status == "dispatched" then break end
  end
  if not selected or selected.status ~= "dispatched" then
    return {
      status = "monkey_madness_denture_hole_choice_missing",
      searched = searched,
      advanced = advanced,
      dialogue = gc.read("dialogue"),
    }
  end

  local descent_tick = gc.read("runtime").game_tick
  local lowering = wait_for_message(descent_tick, "begin to lower yourself", 20)
  if lowering then
    local continued = gc.await {
      action = { type = "ui.key", key = "SPACE" },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 20 },
    }
    if continued.status ~= "dispatched" then return continued end
  end
  for _ = 1, 80 do
    gc.await { event = "game.tick" }
    if geometry.in_zone(gc.read("player").world, config.zones.amulet_mould_room) then
      return {
        status = "complete",
        result = "amulet_mould_room_entered",
        combat = settled,
        approach = approach,
        searched = searched,
        advanced = advanced,
        selected = selected,
        lowering = lowering,
      }
    end
  end
  return {
    status = "monkey_madness_denture_hole_descent_unverified",
    combat = settled,
    approach = approach,
    searched = searched,
    selected = selected,
    player = gc.read("player"),
  }
end

local function obtain_mould()
  if item_queries.inventory_quantity(config.items.amulet_mould) > 0 then return { status = "complete" } end
  local settled = garkor.settle_combat()
  if settled.status ~= "complete" then return settled end
  gc.activity("hazardous_travel")
  local approach = movement.walk(config.points.amulet_mould_crate, 1, { ticks = 300 })
  if approach.status ~= "arrived" then return approach end
  local crate = object(config.objects.amulet_mould_crate, "Search", 8)
  if not crate then
    return {
      status = "monkey_madness_amulet_mould_crate_not_observed",
      objects = gc.read("objects", { within = 10, limit = 80 }),
    }
  end
  local since_tick = gc.read("runtime").game_tick
  local searched = interact(crate, "Search", 8)
  if searched.status ~= "dispatched" then return searched end
  local obtained, failure = choose_and_verify(
    "Yes", config.items.amulet_mould, nil, 60, since_tick)
  if not obtained then return failure end
  return {
    status = "complete",
    result = "amulet_mould_obtained",
    combat = settled,
    receipt = searched,
  }
end

local function execute()
  local armed, safety_failure = preparation.arm_safety()
  if not armed then return safety_failure end
  gc.activity("questing")
  local receipts = {}

  if item_queries.inventory_quantity(config.items.monkey_dentures) == 0 then
    local reached, reach_receipt = reach_denture_building()
    if not reached then return reach_receipt end
    receipts.reach = reach_receipt
    local dentures = obtain_dentures()
    if dentures.status ~= "complete" then return dentures end
    receipts.dentures = dentures
  end

  if not geometry.in_zone(gc.read("player").world, config.zones.denture_building) and
    not geometry.in_zone(gc.read("player").world, config.zones.amulet_mould_room) then
    local reached, reach_receipt = reach_denture_building()
    if not reached then return reach_receipt end
    receipts.recovery = reach_receipt
  end

  if not geometry.in_zone(gc.read("player").world, config.zones.amulet_mould_room) then
    local descended = descend_to_mould_room()
    if descended.status ~= "complete" then return descended end
    receipts.descent = descended
  end

  local mould = obtain_mould()
  if mould.status ~= "complete" then return mould end
  receipts.mould = mould
  return {
    status = "complete",
    result = "amulet_parts_obtained",
    dentures = item_queries.inventory_quantity(config.items.monkey_dentures),
    moulds = item_queries.inventory_quantity(config.items.amulet_mould),
    receipts = receipts,
  }
end

return { execute = execute }
