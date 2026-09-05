local config = gc.require("monkey_madness_config")
local areas = gc.require("monkey_madness_areas")
local behaviors = gc.require("shared_behaviors")
local consumables = gc.require("shared_consumables")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local movement = gc.require("shared_movement")
local preparation = gc.require("monkey_madness_preparation")
local protection = gc.require("shared_protection")

local stamina_drink_energy = 6000

local function at_point(world, point)
  return world and point and world.plane == point.plane and
    world.x == point.x and world.y == point.y
end

local function wait_at_point(point, ticks)
  for _ = 1, ticks do
    if at_point(gc.read("player").world, point) then return true end
    gc.await { event = "game.tick" }
  end
  return at_point(gc.read("player").world, point)
end

local function maintain_stamina()
  return consumables.ensure_stamina { minimum_run_energy = stamina_drink_energy }
end

local function travel_interrupts()
  local conditions = consumables.stamina_interrupts(stamina_drink_energy / 100)
  conditions.poisoned = true
  conditions.area = { name = "prison", bounds = areas.prison_bounds() }
  return conditions
end

local function garkor_stage()
  local vars = gc.read("vars", { varbits = { config.varbits.garkor } })
  return vars.varbits[config.varbits.garkor]
end

local function cure_poison()
  local receipt = gc.await {
    action = { type = "consumable.cure_poison" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if receipt.status == "complete" or receipt.status == "unchanged" then
    return receipt
  end
  return nil, {
    status = "monkey_madness_antipoison_failed",
    receipt = receipt,
  }
end

local function active_attackers(player)
  local attackers = {}
  if not player.name then return attackers end
  for _, npc in ipairs(gc.read("npcs", { within = 12, limit = 40 })) do
    local can_reach_player = npc.line_of_sight ~= false or npc.clickable ~= false
    if not npc.dead and npc.interacting == player.name and can_reach_player then
      attackers[#attackers + 1] = npc
    end
  end
  return attackers
end

local function anchored_and_idle(anchor)
  local player = gc.read("player")
  return at_point(player.world, anchor) and
    not player.interacting and
    #active_attackers(player) == 0
end

local function settle_combat(anchor, ticks, combat_prayer)
  local configured, behavior_failure = behaviors.configure {
    auto_retaliate = true,
    emergency_escape = true,
    combat_prayer = combat_prayer ~= false,
  }
  if not configured then return behavior_failure end
  anchor = geometry.copy_point(anchor or gc.read("player").world)

  local remaining_ticks = ticks or 60
  local attackers = {}
  local restored = { status = "unchanged", result = "anchor_preserved" }
  for _ = 1, 3 do
    local quiet_ticks = 0
    while remaining_ticks > 0 and quiet_ticks < 3 do
      local player = gc.read("player")
      attackers = active_attackers(player)
      if #attackers == 0 and not player.interacting then
        quiet_ticks = quiet_ticks + 1
      else
        quiet_ticks = 0
        gc.activity("combat")
      end
      remaining_ticks = remaining_ticks - 1
      gc.await { event = "game.tick" }
    end
    if quiet_ticks < 3 then
      return {
        status = "monkey_madness_combat_did_not_settle",
        attackers = attackers,
        player = gc.read("player"),
      }
    end
    local player = gc.read("player")
    attackers = active_attackers(player)
    if #attackers > 0 or player.interacting then
      gc.activity("combat")
    else
      if at_point(player.world, anchor) then
        gc.activity("questing")
        return {
          status = "complete",
          result = "combat_settled",
          anchor = restored,
        }
      end
      gc.activity("questing")
      restored = movement.walk(anchor, 0, {
        ticks = 40,
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
      })
      if restored.status ~= "arrived" or not wait_at_point(anchor, 3) then
        return {
          status = "monkey_madness_combat_anchor_failed",
          anchor = anchor,
          receipt = restored,
          player = gc.read("player"),
        }
      end
    end
  end
  return {
    status = "monkey_madness_combat_anchor_unstable",
    anchor = restored,
    player = gc.read("player"),
  }
end

local drain_capture_dialogue

local function complete_capture(receipts)
  if gc.read("dialogue").type ~= "closed" then
    local dialogue_closed, dialogue_failure = drain_capture_dialogue()
    if not dialogue_closed then return dialogue_failure end
  end
  local configured, behavior_receipt = behaviors.configure { auto_retaliate = true, emergency_escape = true }
  if not configured then return behavior_receipt end
  local unprotected, protection_receipt = protection.disable("missiles")
  if not unprotected then return protection_receipt end
  local cured, poison_failure = cure_poison()
  if not cured then return poison_failure end
  if receipts then
    receipts.capture_antipoison = cured
    receipts.capture_behaviors = behavior_receipt
    receipts.capture_protection = protection_receipt
  end
  return {
    status = "complete",
    result = "ape_atoll_prison_reached",
    antipoison = cured,
    receipts = receipts,
  }
end

local function reach_prison()
  if areas.in_prison(gc.read("player").world) then
    return complete_capture()
  end
  if not areas.in_south(gc.read("player").world) then
    return { status = "monkey_madness_valley_start_unknown", player = gc.read("player") }
  end

  gc.activity("hazardous_travel")
  local configured, behavior_receipt = behaviors.configure { auto_retaliate = false, emergency_escape = true }
  if not configured then return behavior_receipt end
  local protected, protection_receipt = protection.enable("missiles", 12)
  if not protected then return protection_receipt end
  local stamina, stamina_receipt = maintain_stamina()
  if not stamina then return stamina_receipt end
  local antipoison, poison_failure = cure_poison()
  if not antipoison then return poison_failure end
  local receipts = {
    behaviors = behavior_receipt,
    protection = protection_receipt,
    stamina = stamina_receipt,
    antipoison = antipoison,
    walks = {},
  }
  local journey = config.routes.ape_atoll_valley
  local continuation
  local arrived = false
  for _ = 1, 16 do
    local walked = movement.walk(journey.destination, journey.within, {
      ticks = 500,
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      activity = "hazardous_travel", via = journey.via,
      interrupt_on = travel_interrupts(), resume = continuation,
    })
    receipts.walks[#receipts.walks + 1] = walked
    if areas.in_prison(gc.read("player").world) then return complete_capture(receipts) end
    if walked.status == "arrived" then arrived = true break end
    local upkeep = walked.reason == "poisoned" or walked.reason == "varbit_equals" or walked.reason == "run_energy_below"
    if walked.status ~= "interrupted" or not upkeep or not walked.continuation then
      return { status = "monkey_madness_valley_walk_failed", destination = journey.destination,
        receipt = walked, player = gc.read("player") }
    end
    if walked.reason == "poisoned" then
      local cured, failure = cure_poison()
      if not cured then return failure end
      receipts.antipoison = cured
    else
      local ready, failure = maintain_stamina()
      if not ready then return failure end
    end
    continuation = walked.continuation
    gc.await { event = "game.tick" }
  end
  if not arrived then return { status = "monkey_madness_valley_upkeep_limit", receipts = receipts } end
  local cured, failure = cure_poison()
  if not cured then return failure end
  receipts.antipoison = cured

  for _ = 1, 50 do
    if areas.in_prison(gc.read("player").world) then
      return complete_capture(receipts)
    end
    gc.await { event = "game.tick" }
  end
  return {
    status = "monkey_madness_capture_not_observed",
    receipts = receipts,
    player = gc.read("player"),
    messages = gc.read("messages", { limit = 30 }),
  }
end

local function jail_door()
  return gc.read("objects", {
    id = config.objects.jail_door,
    action = "Pick-lock",
    within = 12,
    limit = 1,
  })[1]
end

local function prison_guard(id)
  return gc.read("npcs", {
    id = id,
    within = 24,
    limit = 1,
  })[1]
end

local guard_ids = {
  config.npcs.prison_standby_guard,
  config.npcs.prison_patrol_guard,
}
local prison_markers = {
  { npc_id = config.npcs.prison_standby_guard, label = "Trefaji", color = "#ffb347" },
  { npc_id = config.npcs.prison_patrol_guard, label = "Aberab", color = "#57d7ff" },
}
local previous_prison_snapshot

local function record_prison_snapshot()
  local player = gc.read("player")
  local observed = {}
  local signature = { geometry.point_key(player.world), tostring(player.animation) }
  for _, id in ipairs(guard_ids) do
    local guard = prison_guard(id)
    observed[#observed + 1] = {
      id = id,
      world = guard and geometry.copy_point(guard.world) or nil,
    }
    signature[#signature + 1] = geometry.point_key(guard and guard.world or nil)
  end
  signature = table.concat(signature, "|")
  if signature == previous_prison_snapshot then return end
  gc.log("info", "prison-guard-snapshot", {
    tick = gc.read("runtime").game_tick,
    player = {
      world = geometry.copy_point(player.world),
      destination = geometry.copy_point(player.destination),
      animation = player.animation,
      current_hitpoints = player.current_hitpoints,
      max_hitpoints = player.max_hitpoints,
    },
    guards = observed,
  })
  previous_prison_snapshot = signature
end

local function prison_state(state)
  gc.state(state)
  gc.overlay({ { label = "Quest", value = config.label } }, prison_markers)
  record_prison_snapshot()
end

local function crossed_jail_door(world)
  return world and world.plane == 0 and
    world.x >= 2769 and world.x <= 2772 and
    world.y >= 2796 and world.y <= 2797
end

local function prison_topology(world)
  world = world or gc.read("player").world
  local door = jail_door()
  local topology = {
    world = geometry.copy_point(world),
    door_state = door and "closed_pickable" or "open_or_absent",
    door = door and {
      id = door.id,
      world = geometry.copy_point(door.world),
      actions = door.actions,
    } or nil,
  }
  if not geometry.in_zone(world, config.zones.ape_atoll_prison) or
    geometry.in_zone(world, config.zones.prison_west_clear) then
    topology.state = "fully_clear"
  elseif world.x >= 2770 and world.y <= 2795 then
    topology.state = "cell_interior"
  elseif world.x <= 2769 and world.y <= 2796 then
    topology.state = "west_safe_side"
  else
    topology.state = "door_threshold"
  end
  return topology
end

local function wait_for_jail_door_cross(ticks)
  for _ = 1, ticks do
    record_prison_snapshot()
    if crossed_jail_door(gc.read("player").world) then return true end
    gc.await { event = "game.tick" }
  end
  return false
end

local function wait_for_lock_window(ticks)
  local primed = {}
  for _ = 1, ticks do
    record_prison_snapshot()
    for _, id in ipairs(guard_ids) do
      local guard = prison_guard(id)
      if guard then
        if primed[id] then
          if at_point(guard.world, config.points.prison_guard_lock) then
            return guard, primed[id]
          end
          local still_northbound = guard.world.x == config.points.prison_guard_prime.x and
            guard.world.y >= config.points.prison_guard_prime.y and
            guard.world.y <= config.points.prison_guard_lock.y
          if not still_northbound then primed[id] = nil end
        elseif at_point(guard.world, config.points.prison_guard_prime) then
          primed[id] = {
            guard_id = id,
            tick = gc.read("runtime").game_tick,
            world = geometry.copy_point(guard.world),
          }
          prison_state("prison_lockpick_primed")
        end
      elseif primed[id] then
        primed[id] = nil
      end
    end
    if next(primed) == nil then prison_state("prison_wait_lockpick_prime") end
    gc.await { event = "game.tick" }
  end
  return nil
end

local function wait_for_guard_at(point, ticks)
  for _ = 1, ticks do
    record_prison_snapshot()
    for _, id in ipairs(guard_ids) do
      local guard = prison_guard(id)
      if guard and at_point(guard.world, point) then return guard end
    end
    gc.await { event = "game.tick" }
  end
  return nil
end

local function wait_for_exit_decision(guard_id, ticks)
  for _ = 1, ticks do
    record_prison_snapshot()
    local guard = prison_guard(guard_id)
    if not guard then return nil, "guard_missing" end
    if at_point(guard.world, config.points.prison_guard_follow) then
      return guard, "exit"
    end
    if at_point(guard.world, config.points.prison_guard_return) then
      return guard, "retreat"
    end
    gc.await { event = "game.tick" }
  end
  return nil, "timeout"
end

local function lock_result(since_tick)
  for _, message in ipairs(gc.read("messages", { since_tick = since_tick, limit = 12 })) do
    local text = string.lower(message.text or "")
    if string.find(text, "manage to pick the lock", 1, true) then return "success", message end
    if string.find(text, "fail to pick the lock", 1, true) then return "failed", message end
  end
  return nil
end

local function lockpick_while_guard_is_away(guard_id, attempts)
  local reached_north = false
  for _ = 1, 12 do
    record_prison_snapshot()
    local guard = prison_guard(guard_id)
    if not guard then return nil, "guard_missing" end
    if guard.world.y > config.points.prison_guard_return.y then reached_north = true end
    if reached_north and at_point(guard.world, config.points.prison_guard_return) then
      return nil, "guard_returning"
    end

    local door = jail_door()
    if not door then return true, "door_open" end
    local since_tick = gc.read("runtime").game_tick
    local picked = gc.await {
      action = {
        type = "object.interact",
        id = door.id,
        action = "Pick-lock",
        world = door.world,
        within = 12,
      },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 20 },
    }
    local attempt = { picked = picked }
    attempts[#attempts + 1] = attempt
    if picked.status ~= "dispatched" then
      if picked.result ~= "interaction_already_running" and
        picked.result ~= "cancelled: emergency_consumable" then
        return nil, "lockpick_rejected"
      end
      gc.await { event = "game.tick" }
    else
      for _ = 1, 12 do
        record_prison_snapshot()
        if crossed_jail_door(gc.read("player").world) then
          attempt.result = "threshold_crossed"
          return true, "door_crossed"
        end
        local result, message = lock_result(since_tick)
        if result then
          attempt.result = result
          attempt.message = message
          if result == "success" then return true, "lock_opened" end
          break
        end

        guard = prison_guard(guard_id)
        if not guard then return nil, "guard_missing" end
        if guard.world.y > config.points.prison_guard_return.y then reached_north = true end
        if reached_north and at_point(guard.world, config.points.prison_guard_return) then
          attempt.result = "guard_returning"
          return nil, "guard_returning"
        end
        gc.await { event = "game.tick" }
      end
    end
  end
  return nil, "lock_window_exhausted"
end

drain_capture_dialogue = function()
  local start_tick = gc.read("runtime").game_tick
  local earliest_return = start_tick < 100 and 100 or start_tick + 12
  local quiet_ticks = 0
  for _ = 1, 240 do
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      quiet_ticks = 0
      local continued = gc.await {
        action = { type = "dialogue.continue", reading = false },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 30 },
      }
      if continued.status ~= "dispatched" and
        continued.result ~= "dialogue_continue_not_visible" then
        return nil, {
          status = "monkey_madness_capture_dialogue_failed",
          receipt = continued,
        }
      end
    elseif dialogue.type == "closed" then
      quiet_ticks = quiet_ticks + 1
      if quiet_ticks >= 12 and gc.read("runtime").game_tick >= earliest_return then
        return true
      end
    else
      return nil, {
        status = "monkey_madness_capture_dialogue_unexpected",
        dialogue = dialogue,
      }
    end
    gc.await { event = "game.tick" }
  end
  return nil, {
    status = "monkey_madness_capture_dialogue_timeout",
    dialogue = gc.read("dialogue"),
  }
end

local function escape_prison(options)
  options = options or {}
  local initial_topology = prison_topology()
  if initial_topology.state == "fully_clear" then
    local configured, behavior_failure = behaviors.configure {
      auto_retaliate = false,
      emergency_escape = true,
      combat_prayer = false,
    }
    if not configured then return behavior_failure end
    return { status = "complete", result = "ape_atoll_prison_already_exited" }
  end
  local configured, behavior_failure = behaviors.configure {
    auto_retaliate = true,
    emergency_escape = true,
    combat_prayer = false,
  }
  if not configured then return behavior_failure end
  gc.activity("questing")
  if gc.read("dialogue").type ~= "closed" then
    local dialogue_closed, dialogue_failure = drain_capture_dialogue()
    if not dialogue_closed then return dialogue_failure end
  end
  local combat = settle_combat(nil, nil, false)
  if combat.status ~= "complete" then return combat end
  local antipoison, poison_failure = cure_poison()
  if not antipoison then return poison_failure end
  local topology = prison_topology()
  if topology.state == "fully_clear" then
    return { status = "complete", result = "ape_atoll_prison_already_exited" }
  end
  local attempts = {
    initial_topology = initial_topology,
    topology = topology,
    initial_combat = combat,
  }
  local tracked_guard
  if topology.state == "cell_interior" then
    prison_state("prison_prepare")
    if gc.read("dialogue").type ~= "closed" then
      local dialogue_closed, dialogue_failure = drain_capture_dialogue()
      if not dialogue_closed then return dialogue_failure end
    end

    if topology.door_state == "closed_pickable" then
      if item_queries.inventory_quantity(config.items.lockpick) == 0 then
        return { status = "monkey_madness_lockpick_missing", topology = topology }
      end
      prison_state("prison_move_to_start")
      gc.activity("questing")
      local positioned = movement.walk(config.points.prison_start, 0, {
        ticks = 30,
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
      })
      attempts.start = positioned
      local live_world = gc.read("player").world
      if positioned.status ~= "arrived" or
        not (at_point(positioned.reached, config.points.prison_start) or
          at_point(live_world, config.points.prison_start)) then
        return {
          status = "monkey_madness_prison_start_failed",
          receipt = positioned,
          attempts = attempts,
          player = gc.read("player"),
        }
      end

      for cycle = 1, 10 do
        local settled = settle_combat(config.points.prison_start, nil, false)
        if settled.status ~= "complete" then return settled end
        local refreshed, refresh_failure = cure_poison()
        if not refreshed then return refresh_failure end
        prison_state("prison_wait_lockpick_prime")
        local lock_guard, primed = wait_for_lock_window(320)
        if not lock_guard then
          return {
            status = "monkey_madness_guard_lock_window_not_observed",
            player = gc.read("player"),
            nearby = gc.read("npcs", { within = 24, limit = 30 }),
          }
        end
        tracked_guard = lock_guard.id
        local cycle_receipt = {
          cycle = cycle,
          guard_id = tracked_guard,
          primed = primed,
          lock_window = geometry.copy_point(lock_guard.world),
        }
        attempts[#attempts + 1] = cycle_receipt

        if not anchored_and_idle(config.points.prison_start) then
          local interrupted = settle_combat(config.points.prison_start, nil, false)
          cycle_receipt.interrupted = interrupted
          if interrupted.status ~= "complete" then return interrupted end
          tracked_guard = nil
        else
          prison_state("prison_lockpicking")
          local opened, reason = lockpick_while_guard_is_away(tracked_guard, attempts)
          cycle_receipt.lock_result = reason
          if opened then break end
          tracked_guard = nil
        end
      end

      if not tracked_guard then
        return {
          status = "monkey_madness_prison_lock_window_exhausted",
          attempts = attempts,
          player = gc.read("player"),
        }
      end

      prison_state("prison_cross_door")
      if not wait_for_jail_door_cross(12) then
        return {
          status = "monkey_madness_prison_door_cross_failed",
          attempts = attempts,
          player = gc.read("player"),
        }
      end
    end
  end

  prison_state("prison_reach_safe_spot")
  gc.activity("questing")
  local safe_walk = movement.walk(config.points.prison_safe_spot, 0, {
    ticks = 30,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  })
  attempts.safe_spot_walk = safe_walk
  local safe_world = gc.read("player").world
  if safe_walk.status ~= "arrived" or
    not (at_point(safe_walk.reached, config.points.prison_safe_spot) or
      at_point(safe_world, config.points.prison_safe_spot)) then
    return {
      status = "monkey_madness_prison_safe_spot_failed",
      receipt = safe_walk,
      attempts = attempts,
      player = gc.read("player"),
    }
  end
  local safe = settle_combat(config.points.prison_safe_spot, nil, false)
  attempts.safe_spot = safe
  if safe.status ~= "complete" then return safe end
  if not wait_at_point(config.points.prison_safe_spot, 3) then
    return {
      status = "monkey_madness_prison_safe_spot_failed",
      receipt = safe,
      attempts = attempts,
      player = gc.read("player"),
    }
  end
  gc.activity("questing")
  if options.stop_at_safe_spot then
    return {
      status = "complete",
      result = "ape_atoll_prison_safe_spot_reached",
      attempts = attempts,
      player = gc.read("player"),
    }
  end
  local exit_cycles = {}
  attempts.exit_cycles = exit_cycles
  for cycle = 1, 6 do
    local settled = settle_combat(config.points.prison_safe_spot, nil, false)
    if settled.status ~= "complete" then return settled end
    local refreshed, refresh_failure = cure_poison()
    if not refreshed then return refresh_failure end
    prison_state("prison_wait_exit_prime")
    local exit_guard = wait_for_guard_at(config.points.prison_guard_stage, 320)
    if not exit_guard then
      return {
        status = "monkey_madness_prison_exit_prime_not_observed",
        attempts = attempts,
        player = gc.read("player"),
      }
    end
    tracked_guard = exit_guard.id
    local exit_cycle = {
      cycle = cycle,
      guard_id = tracked_guard,
      primed = {
        tick = gc.read("runtime").game_tick,
        world = geometry.copy_point(exit_guard.world),
      },
    }
    exit_cycles[#exit_cycles + 1] = exit_cycle
    prison_state("prison_exit_primed")

    if not anchored_and_idle(config.points.prison_safe_spot) then
      local interrupted = settle_combat(config.points.prison_safe_spot, nil, false)
      exit_cycle.interrupted = interrupted
      if interrupted.status ~= "complete" then return interrupted end
      tracked_guard = nil
    else
      local timed, timed_receipt = behaviors.configure {
        auto_retaliate = false,
        emergency_escape = true,
        combat_prayer = false,
      }
      if not timed then return timed_receipt end
      exit_cycle.behaviors = timed_receipt
      local _, decision = wait_for_exit_decision(tracked_guard, 20)
      exit_cycle.decision = decision
      if decision == "exit" then
        local protected, protection_receipt = protection.enable("missiles", 12)
        exit_cycle.protection = protection_receipt
        if not protected then return protection_receipt end
        prison_state("prison_click_outside")
        gc.activity("questing")
        local exited = movement.walk(config.points.prison_clear, 0, {
          ticks = 60,
          policy = { breaks = false, cursor_release = "none", fidget = "none" },
        })
        exit_cycle.exit = exited
        local live_world = gc.read("player").world
        if exited.status == "arrived" and
          (at_point(exited.reached, config.points.prison_clear) or
            at_point(live_world, config.points.prison_clear)) then
          gc.activity("questing")
          return { status = "complete", result = "ape_atoll_prison_exited", attempts = attempts }
        end
        return {
          status = "monkey_madness_prison_exit_click_failed",
          receipt = exited,
          attempts = attempts,
          player = gc.read("player"),
        }
      end
      if decision ~= "retreat" then
        local ordinary, ordinary_receipt = behaviors.configure {
          auto_retaliate = true,
          emergency_escape = true,
          combat_prayer = false,
        }
        if not ordinary then return ordinary_receipt end
        return {
          status = "monkey_madness_prison_exit_wait_failed",
          reason = decision,
          guard_id = tracked_guard,
          attempts = attempts,
          player = gc.read("player"),
        }
      end

      prison_state("prison_retreat_to_safe_spot")
      local retreated = settle_combat(config.points.prison_safe_spot, 60, false)
      exit_cycle.retreat = retreated
      if retreated.status ~= "complete" or
        not wait_at_point(config.points.prison_safe_spot, 3) then
        return {
          status = "monkey_madness_prison_retreat_failed",
          guard_id = tracked_guard,
          attempts = attempts,
          player = gc.read("player"),
        }
      end
      tracked_guard = nil
    end
  end
  return {
    status = "monkey_madness_prison_exit_opportunities_exhausted",
    attempts = attempts,
    player = gc.read("player"),
  }
end

local function reach_prison_safe_spot()
  return escape_prison({ stop_at_safe_spot = true })
end

local function reach_garkor_from_prison()
  gc.activity("hazardous_travel")
  local configured, behavior_failure = behaviors.configure { auto_retaliate = false, emergency_escape = true }
  if not configured then return nil, behavior_failure end
  local ready, stamina_failure = maintain_stamina()
  if not ready then return nil, stamina_failure end
  local journey = config.routes.prison_to_garkor
  local receipts = {}
  local continuation
  for _ = 1, 16 do
    local moved = movement.walk(journey.destination, journey.within, {
      ticks = 600,
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      activity = "hazardous_travel", via = journey.via,
      interrupt_on = travel_interrupts(), resume = continuation,
    })
    receipts[#receipts + 1] = moved
    if areas.in_prison(gc.read("player").world) then
      return nil, { status = "monkey_madness_recaptured_on_garkor_route",
        destination = journey.destination, receipt = moved, receipts = receipts }
    end
    if moved.status == "arrived" then return moved end
    local upkeep = moved.reason == "poisoned" or moved.reason == "varbit_equals" or moved.reason == "run_energy_below"
    if moved.status ~= "interrupted" or not upkeep or not moved.continuation then
      return nil, { status = "monkey_madness_garkor_route_failed", destination = journey.destination,
        receipt = moved, player = gc.read("player") }
    end
    if moved.reason == "poisoned" then
      local cured, failure = cure_poison()
      if not cured then return nil, failure end
    else
      local restored, failure = maintain_stamina()
      if not restored then return nil, failure end
    end
    continuation = moved.continuation
    gc.await { event = "game.tick" }
  end
  return nil, { status = "monkey_madness_garkor_upkeep_limit", receipts = receipts }
end

local function talk_to_garkor()
  if garkor_stage() >= 2 then
    return { status = "complete", result = "garkor_already_briefed" }
  end
  local target = gc.read("npcs", {
    where = { name = "Garkor" },
    action = "Talk-to",
    within = 24,
    limit = 1,
  })[1]
  if not target then
    return {
      status = "monkey_madness_garkor_not_observed",
      player = gc.read("player"),
      nearby = gc.read("npcs", { within = 24, limit = 50 }),
    }
  end

  local talked = gc.await {
    action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 24 },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if talked.status ~= "dispatched" then return talked end

  local opened = false
  local closed_ticks = 0
  for _ = 1, 180 do
    local progressed = garkor_stage() >= 2
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      opened = true
      closed_ticks = 0
      local continued = gc.await {
        action = { type = "dialogue.continue" },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 30 },
      }
      if continued.status ~= "dispatched" and
        continued.result ~= "dialogue_continue_not_visible" and
        continued.result ~= "dialogue_is_choice" then
        return continued
      end
    elseif dialogue.type == "choice" then
      return {
        status = "monkey_madness_unexpected_garkor_choice",
        dialogue = dialogue,
      }
    elseif opened then
      closed_ticks = closed_ticks + 1
      if progressed and closed_ticks >= 2 then
        return { status = "complete", result = "garkor_briefing_complete", receipt = talked }
      end
      gc.await { event = "game.tick" }
    else
      gc.await { event = "game.tick" }
    end
  end
  return {
    status = "monkey_madness_garkor_dialogue_timeout",
    stage = garkor_stage(),
    dialogue = gc.read("dialogue"),
  }
end

local function execute()
  local armed, safety_failure = preparation.arm_safety()
  if not armed then return safety_failure end
  if garkor_stage() >= 2 then return { status = "complete", result = "garkor_already_briefed" } end

  local world = gc.read("player").world
  if areas.in_south(world) then
    local captured = reach_prison()
    if captured.status ~= "complete" then return captured end
  end
  if areas.in_prison(gc.read("player").world) then
    local escaped = escape_prison()
    if escaped.status ~= "complete" then return escaped end
  end
  if not areas.in_north(gc.read("player").world) then
    return { status = "monkey_madness_garkor_route_start_unknown", player = gc.read("player") }
  end
  local current = gc.read("player").world
  local distance_to_garkor = math.max(
    math.abs(current.x - config.points.garkor.x),
    math.abs(current.y - config.points.garkor.y))
  local route = {}
  if distance_to_garkor > 8 then
    local route_failure
    route, route_failure = reach_garkor_from_prison()
    if not route then return route_failure end
  else
    local configured, behavior_failure = behaviors.configure { auto_retaliate = false, emergency_escape = true }
    if not configured then return behavior_failure end
  end
  local briefing = talk_to_garkor()
  briefing.route = route
  return briefing
end

return {
  execute = execute,
  reach_prison = reach_prison,
  reach_prison_safe_spot = reach_prison_safe_spot,
  escape_prison = escape_prison,
  settle_combat = settle_combat,
  refresh_antipoison = cure_poison,
  maintain_stamina = maintain_stamina,
  travel_interrupts = travel_interrupts,
}
