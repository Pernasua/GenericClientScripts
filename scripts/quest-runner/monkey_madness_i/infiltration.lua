local config = gc.require("monkey_madness_config")
local garkor = gc.require("monkey_madness_garkor")
local preparation = gc.require("monkey_madness_preparation")

local function in_zone(world, zone)
  return world and world.plane == zone.plane and
    world.x >= zone.x1 and world.x <= zone.x2 and
    world.y >= zone.y1 and world.y <= zone.y2
end

local function in_south(world)
  return in_zone(world, config.zones.ape_atoll_south) or
    in_zone(world, config.zones.ape_atoll_south_corridor_wide) or
    in_zone(world, config.zones.ape_atoll_south_corridor_narrow)
end

local function quantity(id)
  local total = 0
  for _, item in ipairs(gc.read("inventory").items or {}) do
    if item.id == id then total = total + item.quantity end
  end
  return total
end

local function walk(destination, within, ticks, breaks)
  gc.activity("travel")
  return gc.await {
    action = {
      type = "walk.to",
      destination = destination,
      within = within or 1,
      run = true,
    },
    breaks = breaks == true,
    timeout = { game_ticks = ticks or 300 },
  }
end

local function walk_route(route, breaks)
  local receipts = {}
  for _, point in ipairs(route) do
    local receipt = walk(point, 1, 300, breaks)
    receipts[#receipts + 1] = receipt
    if receipt.status ~= "arrived" then
      return nil, {
        status = "monkey_madness_infiltration_walk_failed",
        destination = point,
        receipt = receipt,
        receipts = receipts,
        player = gc.read("player"),
      }
    end
    if in_zone(gc.read("player").world, config.zones.ape_atoll_prison) then
      return nil, {
        status = "monkey_madness_infiltration_recaptured",
        destination = point,
        receipts = receipts,
      }
    end
  end
  return receipts
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
  return gc.await {
    action = {
      type = "object.interact",
      id = target.id,
      action = action,
      world = target.world,
      within = within or 8,
    },
    breaks = false,
    timeout = { game_ticks = 30 },
  }
end

local function choose_and_verify(choice, item_id, expected_zone, ticks)
  local function choose_now()
    return gc.await {
      action = { type = "dialogue.choose", text = choice, reading = false },
      breaks = false,
      timeout = { game_ticks = 10 },
    }
  end
  for _ = 1, ticks or 60 do
    if item_id and quantity(item_id) > 0 then return true end
    if expected_zone and in_zone(gc.read("player").world, expected_zone) then return true end
    local dialogue = gc.read("dialogue")
    if dialogue.type == "choice" then
      local chosen = choose_now()
      if chosen.status ~= "dispatched" then
        return nil, {
          status = "monkey_madness_infiltration_choice_failed",
          option = choice,
          receipt = chosen,
        }
      end
    elseif dialogue.type == "continue" then
      local continued = gc.await {
        action = { type = "dialogue.continue", reading = false },
        breaks = false,
        timeout = { game_ticks = 30 },
      }
      if continued.status ~= "dispatched" and
        continued.result ~= "dialogue_continue_not_visible" and
        continued.result ~= "dialogue_is_choice" then
        return nil, {
          status = "monkey_madness_infiltration_dialogue_failed",
          receipt = continued,
        }
      end
      if continued.status == "dispatched" then
        local chosen = choose_now()
        if chosen.status == "dispatched" then gc.await { event = "game.tick" } end
      end
    elseif dialogue.type == "closed" then
      local continued = gc.await {
        action = { type = "dialogue.continue", reading = false },
        breaks = false,
        timeout = { game_ticks = 10 },
      }
      if continued.status ~= "dispatched" and
        continued.result ~= "dialogue_continue_not_visible" and
        continued.result ~= "dialogue_is_choice" then
        return nil, {
          status = "monkey_madness_infiltration_dialogue_failed",
          receipt = continued,
        }
      end
      if continued.status == "dispatched" then
        local chosen = choose_now()
        if chosen.status == "dispatched" then gc.await { event = "game.tick" } end
      end
      gc.await { event = "game.tick" }
    else
      return nil, {
        status = "monkey_madness_infiltration_dialogue_unexpected",
        dialogue = dialogue,
      }
    end
  end
  return nil, {
    status = "monkey_madness_infiltration_postcondition_timeout",
    option = choice,
    item_id = item_id,
    player = gc.read("player"),
    dialogue = gc.read("dialogue"),
    messages = gc.read("messages", { limit = 20 }),
  }
end

local function reach_denture_building()
  local world = gc.read("player").world
  if in_zone(world, config.zones.denture_building) then
    local disabled, prayer_failure = garkor.disable_protection()
    if not disabled then return nil, prayer_failure end
    return true, {}
  end

  local escaped_from_prison = false
  if in_south(world) then
    local captured = garkor.reach_prison()
    if captured.status ~= "complete" then return nil, captured end
    escaped_from_prison = true
    world = gc.read("player").world
  end

  if in_zone(world, config.zones.ape_atoll_prison) then
    local escaped = garkor.escape_prison()
    if escaped.status ~= "complete" then return nil, escaped end
    escaped_from_prison = true
  end

  local protected, prayer_failure = garkor.maintain_prayer()
  if not protected then return nil, prayer_failure end
  if escaped_from_prison then
    local route, failure = walk_route(config.routes.prison_to_dentures, false)
    if not route then return nil, failure end
  else
    local route, failure = walk_route(config.routes.garkor_to_dentures, false)
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
    if in_zone(gc.read("player").world, config.zones.denture_building) then
      local disabled, prayer_failure = garkor.disable_protection()
      if not disabled then return nil, prayer_failure end
      return true, { door = opened }
    end
  end
  return nil, {
    status = "monkey_madness_denture_building_entry_unverified",
    receipt = opened,
    player = gc.read("player"),
  }
end

local function obtain_dentures()
  if quantity(config.items.monkey_dentures) > 0 then return { status = "complete" } end
  local crate = object(config.objects.denture_crate, "Search", 8)
  if not crate then
    return {
      status = "monkey_madness_denture_crate_not_observed",
      objects = gc.read("objects", { within = 8, limit = 60 }),
    }
  end
  local searched = interact(crate, "Search", 8)
  if searched.status ~= "dispatched" then return searched end
  local obtained, failure = choose_and_verify("Yes", config.items.monkey_dentures, nil, 60)
  if not obtained then return failure end
  local safe = walk(config.points.denture_crate, 0, 40, false)
  if safe.status ~= "arrived" then return safe end
  return {
    status = "complete",
    result = "monkey_dentures_obtained",
    receipt = searched,
    safe = safe,
  }
end

local function descend_to_mould_room()
  if in_zone(gc.read("player").world, config.zones.amulet_mould_room) then
    return { status = "complete" }
  end
  local crate = object(config.objects.denture_hole_crate, "Search", 8)
  if not crate then
    return {
      status = "monkey_madness_denture_hole_not_observed",
      objects = gc.read("objects", { within = 8, limit = 60 }),
    }
  end
  local searched = interact(crate, "Search", 8)
  if searched.status ~= "dispatched" then return searched end
  local descended, failure = choose_and_verify(
    "Yes, I'm sure.", nil, config.zones.amulet_mould_room, 80)
  if not descended then return failure end
  return { status = "complete", result = "amulet_mould_room_entered", receipt = searched }
end

local function obtain_mould()
  if quantity(config.items.amulet_mould) > 0 then return { status = "complete" } end
  local approach = walk(config.points.amulet_mould_crate, 2, 300, true)
  if approach.status ~= "arrived" then return approach end
  local crate = object(config.objects.amulet_mould_crate, "Search", 8)
  if not crate then
    return {
      status = "monkey_madness_amulet_mould_crate_not_observed",
      objects = gc.read("objects", { within = 10, limit = 80 }),
    }
  end
  local searched = interact(crate, "Search", 8)
  if searched.status ~= "dispatched" then return searched end
  local obtained, failure = choose_and_verify("Yes", config.items.amulet_mould, nil, 60)
  if not obtained then return failure end
  return { status = "complete", result = "amulet_mould_obtained", receipt = searched }
end

local function execute()
  local armed, safety_failure = preparation.arm_safety()
  if not armed then return safety_failure end
  gc.activity("questing")
  local receipts = {}

  if quantity(config.items.monkey_dentures) == 0 then
    local reached, reach_receipt = reach_denture_building()
    if not reached then return reach_receipt end
    receipts.reach = reach_receipt
    local dentures = obtain_dentures()
    if dentures.status ~= "complete" then return dentures end
    receipts.dentures = dentures
  end

  if not in_zone(gc.read("player").world, config.zones.denture_building) and
    not in_zone(gc.read("player").world, config.zones.amulet_mould_room) then
    local reached, reach_receipt = reach_denture_building()
    if not reached then return reach_receipt end
    receipts.recovery = reach_receipt
  end

  if not in_zone(gc.read("player").world, config.zones.amulet_mould_room) then
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
    dentures = quantity(config.items.monkey_dentures),
    moulds = quantity(config.items.amulet_mould),
    receipts = receipts,
  }
end

return { execute = execute }
