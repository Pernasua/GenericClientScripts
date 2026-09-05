local config = gc.require("monkey_madness_config")
local areas = gc.require("monkey_madness_areas")
local behaviors = gc.require("shared_behaviors")
local equipment_actions = gc.require("shared_equipment")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local movement = gc.require("shared_movement")
local preparation = gc.require("monkey_madness_preparation")
local garkor = gc.require("monkey_madness_garkor")
local protection = gc.require("shared_protection")

local function without_local_retreat(failure)
  failure.recovery_attempted = false
  failure.recovery_completed = false
  failure.recovery_reason = "framework_safety_owns_emergency_recovery"
  return failure
end

local function enable_melee_protection(minimum_points)
  return protection.enable("melee", minimum_points or 1)
end

local function traverse_corridor(journey, avoid_tiles)
  gc.activity("hazardous_travel")
  local continuation
  local receipts = {}
  for _ = 1, 16 do
    local ready, failure = garkor.maintain_stamina()
    if not ready then return nil, failure end
    local moved = movement.walk(journey.destination, journey.within, {
      ticks = journey.ticks or 600,
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      activity = "hazardous_travel", via = journey.via, arrival_tiles = journey.arrival_tiles,
      avoid_tiles = avoid_tiles and avoid_tiles() or nil,
      interrupt_on = garkor.travel_interrupts(), resume = continuation,
    })
    receipts[#receipts + 1] = moved
    local recaptured = areas.in_prison(gc.read("player").world)
    if moved.status == "arrived" and not recaptured then return moved end
    local upkeep = moved.reason == "poisoned" or moved.reason == "varbit_equals" or moved.reason == "run_energy_below"
    if recaptured or moved.status ~= "interrupted" or not upkeep or not moved.continuation then
      return nil, { status = "monkey_madness_temple_route_failed", destination = journey.destination,
        receipt = moved, receipts = receipts, player = gc.read("player") }
    end
    if moved.reason == "poisoned" then
      local cured, poison_failure = garkor.refresh_antipoison()
      if not cured then return nil, poison_failure end
    end
    continuation = moved.continuation
    gc.await { event = "game.tick" }
  end
  return nil, { status = "monkey_madness_temple_upkeep_limit", receipts = receipts }
end

local function first_object(ids, action, within)
  for _, id in ipairs(ids) do
    local object = gc.read("objects", {
      id = id,
      action = action,
      within = within,
      limit = 1,
    })[1]
    if object then return object end
  end
  return nil
end

local function object_at(id, world, within)
  for _, object in ipairs(gc.read("objects", {
    id = id,
    within = within,
    limit = 40,
  })) do
    if geometry.distance(object.world, world) == 0 then return object end
  end
  return nil
end

local function temple_guard_tiles()
  local tiles = {}
  local seen = {}
  for _, id in ipairs(config.npcs.temple_guards) do
    for _, guard in ipairs(gc.read("npcs", { id = id, within = 30, limit = 20 })) do
      local size = math.max(1, guard.size or 1)
      for x = guard.world.x, guard.world.x + size - 1 do
        for y = guard.world.y, guard.world.y + size - 1 do
          local tile = { x = x, y = y, plane = guard.world.plane }
          local key = geometry.point_key(tile)
          if not seen[key] then
            seen[key] = true
            tiles[#tiles + 1] = tile
          end
        end
      end
    end
  end
  return tiles
end

local function approach_trapdoor()
  if geometry.distance(gc.read("player").world, config.points.temple_trapdoor) <= 2 then
    return { status = "arrived", result = "already_near_trapdoor", reached = gc.read("player").world }
  end
  local moved, failure = traverse_corridor(config.routes.temple_trapdoor_approach, temple_guard_tiles)
  if moved then return moved end
  return nil, {
    status = "monkey_madness_temple_gorilla_body_blocked",
    receipt = failure,
    guards = gc.read("npcs", { within = 30, limit = 60 }),
    player = gc.read("player"),
  }
end

local function reach_north_side()
  local world = gc.read("player").world
  if areas.in_north(world) then return { status = "complete", result = "north_side_reached" } end
  if areas.in_south(world) then
    local captured = garkor.reach_prison()
    if captured.status ~= "complete" then return captured end
  end
  world = gc.read("player").world
  if areas.in_prison(world) then
    local escaped = garkor.escape_prison()
    if escaped.status ~= "complete" then return escaped end
  end
  local antipoison, poison_failure = garkor.refresh_antipoison()
  if not antipoison then return poison_failure end
  if not areas.in_north(gc.read("player").world) then
    return { status = "monkey_madness_temple_route_start_unknown", player = gc.read("player") }
  end
  return { status = "complete", result = "north_side_reached" }
end

local function enter_temple()
  if geometry.in_zone(gc.read("player").world, config.zones.temple_dungeon) then
    return { status = "complete", result = "temple_already_entered" }
  end
  gc.activity("hazardous_travel")
  local configured, behavior_failure = behaviors.configure {
    auto_retaliate = false,
    emergency_escape = true,
  }
  if not configured then return behavior_failure end
  local north = reach_north_side()
  if north.status ~= "complete" then return north end

  local route = {}
  local missiles_receipt
  if not areas.in_temple_guard_building(gc.read("player").world) then
    local protected, protection_receipt = protection.enable("missiles", 24)
    if not protected then return protection_receipt end
    missiles_receipt = protection_receipt
    local route_failure
    route, route_failure = traverse_corridor(config.routes.prison_to_temple_entry)
    if not route then return route_failure end
    if not areas.at_temple_melee_threshold(gc.read("player").world) then
      return {
        status = "monkey_madness_temple_melee_threshold_not_reached",
        route = route,
        player = gc.read("player"),
      }
    end
  end

  local melee_enabled, melee_receipt = enable_melee_protection(24)
  if not melee_enabled then return melee_receipt end

  local approach, approach_failure = approach_trapdoor()
  if not approach then return approach_failure end

  local trapdoor = first_object({
    config.objects.temple_trapdoor_open,
    config.objects.temple_trapdoor,
  }, "Climb-down", 4)
  local opened
  if not trapdoor then
    local closed = first_object({ config.objects.temple_trapdoor }, "Open", 4)
    if closed then
      opened = gc.await {
        action = {
          type = "object.interact",
          id = closed.id,
          action = "Open",
          world = closed.world,
          within = 2,
        },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 12 },
      }
      if opened.status ~= "dispatched" then return opened end
      for _ = 1, 8 do
        gc.await { event = "game.tick" }
        trapdoor = first_object({
          config.objects.temple_trapdoor_open,
          config.objects.temple_trapdoor,
        }, "Climb-down", 4)
        if trapdoor then break end
      end
    end
  end
  if not trapdoor then
    return {
      status = "monkey_madness_temple_trapdoor_not_observed",
      objects = gc.read("objects", { within = 12, limit = 60 }),
    }
  end
  local entered = gc.await {
    action = {
      type = "object.interact",
      id = trapdoor.id,
      action = "Climb-down",
      world = trapdoor.world,
      within = 2,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 12 },
  }
  if entered.status ~= "dispatched" then return entered end
  for _ = 1, 40 do
    gc.await { event = "game.tick" }
    if geometry.in_zone(gc.read("player").world, config.zones.temple_dungeon) then
      return {
        status = "complete",
        result = "temple_entered",
        route = route,
        approach = approach,
        receipt = entered,
        missiles = missiles_receipt,
        melee = melee_receipt,
      }
    end
  end
  return { status = "monkey_madness_temple_entry_unverified", opened = opened, receipt = entered }
end

local function use_bar_on_flame()
  if item_queries.inventory_quantity(config.items.unstrung_amulet) > 0 or item_queries.inventory_quantity(config.items.mspeak_amulet) > 0 then
    return { status = "complete", result = "unstrung_amulet_already_obtained" }
  end
  local protected, protection_receipt = enable_melee_protection()
  if not protected then return protection_receipt end
  gc.activity("hazardous_travel")
  local approach = movement.walk(config.points.temple_flame_staging, 0, {
    ticks = 120,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  })
  if approach.status ~= "arrived" then return approach end
  if geometry.distance(gc.read("player").world, config.points.temple_flame_staging) ~= 0 then
    return {
      status = "monkey_madness_temple_flame_staging_not_reached",
      receipt = approach,
      player = gc.read("player"),
    }
  end
  local flame = object_at(
    config.objects.temple_flame,
    config.points.temple_flame_edge,
    4)
  if not flame then
    return {
      status = "monkey_madness_temple_flame_edge_not_observed",
      objects = gc.read("objects", { id = config.objects.temple_flame, within = 8, limit = 40 }),
    }
  end
  local used = gc.await {
    action = {
      type = "item.use_on_object",
      item_id = config.items.enchanted_bar,
      object_id = flame.id,
      world = flame.world,
      within = 2,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if used.status ~= "dispatched" then return used end
  for _ = 1, 40 do
    gc.await { event = "game.tick" }
    if item_queries.inventory_quantity(config.items.unstrung_amulet) > 0 then
      return { status = "complete", result = "unstrung_amulet_obtained", receipt = used }
    end
    if gc.read("dialogue").type == "continue" then
      gc.await {
        action = { type = "dialogue.continue", reading = false },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 10 },
      }
    end
  end
  return { status = "monkey_madness_unstrung_amulet_not_received", receipt = used }
end

local function string_amulet()
  if item_queries.inventory_quantity(config.items.mspeak_amulet) > 0 or
    item_queries.quantity(gc.read("equipment"), config.items.mspeak_amulet) > 0 then
    return { status = "complete", result = "mspeak_amulet_already_owned" }
  end
  if item_queries.inventory_quantity(config.items.unstrung_amulet) == 0 then
    return { status = "monkey_madness_unstrung_amulet_missing" }
  end
  if item_queries.inventory_quantity(config.items.ball_of_wool) == 0 then
    return { status = "monkey_madness_ball_of_wool_missing" }
  end
  local used = gc.await {
    action = {
      type = "item.use_on_item",
      item_id = config.items.ball_of_wool,
      target_item_id = config.items.unstrung_amulet,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if used.status ~= "dispatched" then return used end
  for _ = 1, 30 do
    gc.await { event = "game.tick" }
    if item_queries.inventory_quantity(config.items.mspeak_amulet) > 0 then
      return { status = "complete", result = "mspeak_amulet_obtained", receipt = used }
    end
  end
  return { status = "monkey_madness_mspeak_amulet_not_observed", receipt = used }
end

local function equip_mspeak_amulet()
  local equipped = equipment_actions.equip(
    config.items.mspeak_amulet,
    "Wear",
    { verify_ticks = 20 })
  if equipped.status ~= "complete" and equipped.status ~= "unchanged" then
    return equipped
  end
  return {
    status = "complete",
    result = "mspeak_amulet_equipped",
    receipt = equipped,
  }
end

local function leave_temple()
  if not geometry.in_zone(gc.read("player").world, config.zones.temple_dungeon) then
    return { status = "complete", result = "temple_already_exited" }
  end
  local protected, protection_receipt = enable_melee_protection()
  if not protected then return protection_receipt end
  local rope = first_object({ config.objects.temple_rope }, "Climb", 16)
  if not rope then
    return {
      status = "monkey_madness_temple_rope_not_observed",
      objects = gc.read("objects", { within = 20, limit = 60 }),
    }
  end
  gc.activity("hazardous_travel")
  local approach = movement.walk(rope.world, 2, {
    ticks = 120,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  })
  if approach.status ~= "arrived" then return approach end
  rope = first_object({ config.objects.temple_rope }, "Climb", 4)
  if not rope then
    return {
      status = "monkey_madness_temple_rope_not_observed",
      objects = gc.read("objects", { within = 8, limit = 40 }),
    }
  end
  local climbed = gc.await {
    action = {
      type = "object.interact",
      id = rope.id,
      action = "Climb",
      world = rope.world,
      within = 3,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if climbed.status ~= "dispatched" then return climbed end
  for _ = 1, 40 do
    gc.await { event = "game.tick" }
    if not geometry.in_zone(gc.read("player").world, config.zones.temple_dungeon) then
      return {
        status = "complete",
        result = "temple_exited",
        approach = approach,
        receipt = climbed,
        protection = protection_receipt,
      }
    end
  end
  return { status = "monkey_madness_temple_exit_unverified", receipt = climbed }
end

local function reach_monkey_child_staging()
  if geometry.in_zone(gc.read("player").world, config.zones.temple_dungeon) then
    return { status = "monkey_madness_child_route_started_inside_temple" }
  end
  local protected, protection_receipt = enable_melee_protection()
  if not protected then return protection_receipt end
  if geometry.distance(gc.read("player").world, config.points.monkey_child_staging) == 0 then
    return { status = "complete", result = "monkey_child_staging_reached", protection = protection_receipt,
      player = gc.read("player") }
  end
  local route, route_failure = traverse_corridor(config.routes.temple_to_monkey_child)
  if not route then return route_failure end
  if geometry.distance(gc.read("player").world, config.points.monkey_child_staging) ~= 0 then
    return {
      status = "monkey_madness_child_staging_not_reached",
      route = route,
      player = gc.read("player"),
    }
  end
  return {
    status = "complete",
    result = "monkey_child_staging_reached",
    route = route,
    protection = protection_receipt,
    player = gc.read("player"),
  }
end

local function reach_prison_checkpoint()
  local armed, safety_failure = preparation.arm_safety()
  if not armed then return safety_failure end
  local captured = garkor.reach_prison()
  if captured.status ~= "complete" then return without_local_retreat(captured) end
  return {
    status = "complete",
    result = "amulet_prison_reached",
    captured = captured,
    player = gc.read("player"),
  }
end

local function escape_prison_checkpoint()
  local armed, safety_failure = preparation.arm_safety()
  if not armed then return safety_failure end
  local escaped = garkor.escape_prison()
  if escaped.status ~= "complete" then return without_local_retreat(escaped) end
  return {
    status = "complete",
    result = "amulet_prison_escaped",
    escaped = escaped,
    player = gc.read("player"),
  }
end

local function reach_prison_safe_spot()
  local armed, safety_failure = preparation.arm_safety()
  if not armed then return safety_failure end
  return garkor.reach_prison_safe_spot()
end

local function prepare_amulet_checkpoint()
  local configured, behavior_receipt = behaviors.configure {
    auto_retaliate = false,
    emergency_escape = true,
  }
  if not configured then return nil, behavior_receipt end
  local armed, safety_failure = preparation.arm_safety()
  if not armed then return nil, safety_failure end
  return {
    behaviors = behavior_receipt,
    safety = safety_failure,
  }
end

local function complete_amulet_checkpoint()
  local strung = string_amulet()
  if strung.status ~= "complete" then return without_local_retreat(strung) end
  local worn = equip_mspeak_amulet()
  if worn.status ~= "complete" then return without_local_retreat(worn) end
  local exited = leave_temple()
  if exited.status ~= "complete" then return without_local_retreat(exited) end
  local staged = reach_monkey_child_staging()
  if staged.status ~= "complete" then return without_local_retreat(staged) end
  return {
    status = "complete",
    result = "mspeak_amulet_checkpoint_reached",
    strung = strung,
    worn = worn,
    exited = exited,
    staged = staged,
  }
end

local function finish_mspeak_amulet()
  local prepared, preparation_failure = prepare_amulet_checkpoint()
  if not prepared then return preparation_failure end
  local completed = complete_amulet_checkpoint()
  completed.prepared = prepared
  return completed
end

local function make_mspeak_amulet()
  local prepared, preparation_failure = prepare_amulet_checkpoint()
  if not prepared then return preparation_failure end

  local entered = enter_temple()
  if entered.status ~= "complete" then return without_local_retreat(entered) end
  local forged = use_bar_on_flame()
  if forged.status ~= "complete" then return without_local_retreat(forged) end
  local completed = complete_amulet_checkpoint()
  completed.prepared = prepared
  completed.entered = entered
  completed.forged = forged
  return completed
end

return {
  reach_prison = reach_prison_checkpoint,
  reach_prison_safe_spot = reach_prison_safe_spot,
  escape_prison = escape_prison_checkpoint,
  make = make_mspeak_amulet,
  finish = finish_mspeak_amulet,
  string = string_amulet,
  equip = equip_mspeak_amulet,
  leave_temple = leave_temple,
  reach_monkey_child_staging = reach_monkey_child_staging,
  enter_temple = enter_temple,
}
