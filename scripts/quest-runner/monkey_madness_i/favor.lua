local config = gc.require("monkey_madness_config")
local areas = gc.require("monkey_madness_areas")
local behaviors = gc.require("shared_behaviors")
local equipment_actions = gc.require("shared_equipment")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local movement = gc.require("shared_movement")
local preparation = gc.require("monkey_madness_preparation")
local navigation = gc.require("monkey_madness_navigation")
local ape_atoll = gc.require("monkey_madness_ape_atoll")
local travel = gc.require("shared_travel")
local ui = gc.require("shared_ui")
local wait = gc.require("shared_wait")

local function clear_monkey_chatter(observed)
  local owned = false
  for _ = 1, 8 do
    local dialogue = observed or gc.read("dialogue")
    observed = nil
    if not owned then
      if dialogue.type ~= "continue" or dialogue.speaker ~= "The monkey in your backpack..." then
        return { status = "complete", result = "monkey_chatter_clear" }
      end
      owned = true
    elseif dialogue.type == "closed" then
      return { status = "complete", result = "monkey_chatter_clear" }
    elseif dialogue.type ~= "continue" or
      (dialogue.speaker ~= "The monkey in your backpack..." and dialogue.speaker ~= gc.read("player").name) then
      return {
        status = "monkey_madness_monkey_chatter_changed",
        dialogue = dialogue,
      }
    end
    local continued = gc.await {
      action = { type = "dialogue.continue", reading = false },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 20 },
    }
    if continued.status ~= "dispatched" then return continued end
    gc.await { event = "game.tick" }
  end
  return { status = "monkey_madness_monkey_chatter_timeout" }
end

local function reach_with_monkey(destination, within, ticks, activity)
  local continuation
  for _ = 1, 8 do
    local cleared = clear_monkey_chatter()
    if cleared.status ~= "complete" then return cleared end
    gc.activity(activity or "questing")
    local moved = movement.walk(destination, within or 2, {
      ticks = ticks or 300,
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      interrupt_on = { dialogue = true },
      resume = continuation,
    })
    if moved.status ~= "interrupted" or moved.reason ~= "dialogue" or not moved.continuation then
      return moved
    end
    local dialogue = moved.dialogue or gc.read("dialogue")
    if dialogue.type ~= "continue" or dialogue.speaker ~= "The monkey in your backpack..." then
      return moved
    end
    local cleared_after_interrupt = clear_monkey_chatter(dialogue)
    if cleared_after_interrupt.status ~= "complete" then return cleared_after_interrupt end
    continuation = moved.continuation
  end
  return { status = "monkey_madness_monkey_chatter_walk_retry_limit" }
end

local function npc(id, within)
  if type(id) == "table" then
    for _, candidate in ipairs(id) do
      local target = npc(candidate, within)
      if target then return target end
    end
    return nil
  end
  return gc.read("npcs", { id = id, within = within or 24, limit = 1 })[1]
end

local function wait_for_npc(id, within, ticks)
  for _ = 1, ticks or 30 do
    local target = npc(id, within)
    if target then return target end
    gc.await { event = "game.tick" }
  end
  return npc(id, within)
end

local function wait_for_clickable_npc(id, within, ticks)
  for _ = 1, ticks or 30 do
    local target = npc(id, within)
    if target and target.clickable ~= false then return target end
    gc.await { event = "game.tick" }
  end
  local target = npc(id, within)
  if target and target.clickable ~= false then return target end
end

local function object(id, action, within)
  if type(id) == "table" then
    for _, candidate in ipairs(id) do
      local target = object(candidate, action, within)
      if target then return target end
    end
    return nil
  end
  return gc.read("objects", {
    id = id,
    action = action,
    within = within or 16,
    limit = 1,
  })[1]
end

local function equip_disguise()
  local amulet = equipment_actions.equip(config.items.mspeak_amulet, "Wear")
  if amulet.status ~= "complete" and amulet.status ~= "unchanged" then return amulet end
  local greegree = equipment_actions.equip(config.items.karamjan_greegree, "Hold")
  if greegree.status ~= "complete" and greegree.status ~= "unchanged" then return greegree end
  return { status = "complete", result = "monkey_disguise_equipped", amulet = amulet, greegree = greegree }
end

local function choose(dialogue, choices)
  if choices == true and dialogue.options and dialogue.options[1] then
    return gc.await {
      action = { type = "dialogue.choose", text = dialogue.options[1].text },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 30 },
    }
  end
  for _, wanted in ipairs(choices or {}) do
    for _, option in ipairs(dialogue.options or {}) do
      if option.text == wanted or option.text == wanted .. "." then
        return gc.await {
          action = { type = "dialogue.choose", text = option.text },
          policy = { breaks = false, cursor_release = "none", fidget = "none" },
          timeout = { game_ticks = 30 },
        }
      end
    end
  end
  return nil
end

local function drain_dialogue(completed, label, choices, ticks)
  local opened = false
  local closed_ticks = 0
  local unopened_ticks = 0
  for _ = 1, ticks or 180 do
    if completed and completed() and gc.read("dialogue").type == "closed" then
      return { status = "complete", result = label }
    end
    gc.await { event = "game.tick" }
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      opened = true
      closed_ticks = 0
      local continued = gc.await {
        action = { type = "dialogue.continue", reading = false },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 30 },
      }
      if continued.status ~= "dispatched" and
        continued.result ~= "dialogue_is_choice" and
        continued.result ~= "dialogue_continue_not_visible" then
        return continued
      end
    elseif dialogue.type == "choice" then
      opened = true
      closed_ticks = 0
      local selected = choose(dialogue, choices)
      if not selected then
        return {
          status = "monkey_madness_" .. label .. "_choice_unhandled",
          dialogue = dialogue,
        }
      end
      if selected.status ~= "dispatched" then
        gc.await { event = "game.tick" }
        local current = gc.read("dialogue")
        if current.type == "choice" then return selected end
      end
    elseif opened then
      if completed and completed() then
        return { status = "complete", result = label }
      end
      closed_ticks = closed_ticks + 1
      if closed_ticks >= 8 then
        if not completed or completed() then
          return { status = "complete", result = label }
        end
        return { status = "monkey_madness_" .. label .. "_closed_without_progress" }
      end
    else
      if completed and completed() then
        return { status = "complete", result = label }
      end
      unopened_ticks = unopened_ticks + 1
      if unopened_ticks >= 8 then
        return { status = "monkey_madness_" .. label .. "_dialogue_not_opened" }
      end
    end
  end
  return {
    status = "monkey_madness_" .. label .. "_dialogue_timeout",
    dialogue = gc.read("dialogue"),
  }
end

local function interact_with_dialogue(action, completed, label, choices)
  if completed and completed() then return { status = "complete", result = label } end
  local cleared = clear_monkey_chatter()
  if cleared.status ~= "complete" then return cleared end
  local attempts = {}
  for _ = 1, 3 do
    local receipt = gc.await {
      action = action,
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 40 },
    }
    attempts[#attempts + 1] = receipt
    if receipt.status == "dispatched" then
      local result = drain_dialogue(completed, label, choices, 220)
      result.receipt = receipt
      result.attempts = attempts
      if result.status ~= "monkey_madness_" .. label .. "_dialogue_not_opened" then
        return result
      end
    elseif receipt.result ~= "hover_has_no_matching_action" then
      return receipt
    end
    gc.await { event = "game.tick" }
  end
  return {
    status = "monkey_madness_" .. label .. "_dialogue_not_opened",
    attempts = attempts,
  }
end

local function talk_to(target, completed, label, choices)
  if not target then return { status = "monkey_madness_" .. label .. "_target_missing" } end
  return interact_with_dialogue(
    { type = "npc.interact", id = target.id, action = "Talk-to", within = 24 },
    completed,
    label,
    choices)
end

local function interact_and_talk(target, completed, label)
  if not target then return { status = "monkey_madness_" .. label .. "_object_missing" } end
  return interact_with_dialogue(
    {
      type = "object.interact",
      id = target.id,
      action = "Talk-to",
      world = target.world,
      within = 16,
    },
    completed,
    label)
end

local function on_ape_atoll()
  local world = gc.read("player").world
  return areas.in_south(world) or areas.in_north(world) or
    geometry.in_zone(world, config.zones.ape_atoll_bridge) or
    geometry.in_zone(world, config.zones.ape_atoll_over_bridge) or
    areas.in_throne_room(world)
end

local function reach_zoo()
  local world = gc.read("player").world
  if geometry.distance(world, config.points.ardougne_zoo_minder) <= 24 then
    return { status = "complete", result = "ardougne_zoo_already_reached" }
  end
  if geometry.distance(world, config.points.ardougne_zoo_minder) > 350 and travel.has_dueling_ring() then
    local teleported = travel.teleport_to_castle_wars({
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      keyboard = true,
    })
    if teleported.status ~= "complete" then return teleported end
  end
  local reached = reach_with_monkey(config.points.ardougne_zoo_minder, 6, 600, "travel")
  if reached.status ~= "arrived" then return reached end
  return { status = "complete", result = "ardougne_zoo_reached", receipt = reached }
end

local function leave_monkey_pen()
  if not areas.in_monkey_pen(gc.read("player").world) then return { status = "complete", result = "outside_monkey_pen" } end
  local removed = equipment_actions.unequip(config.items.karamjan_greegree)
  if removed.status ~= "complete" and removed.status ~= "unchanged" then return removed end
  local target = wait_for_npc(config.npcs.monkey_minder, 20, 30)
  return talk_to(target, function() return not areas.in_monkey_pen(gc.read("player").world) end, "monkey_pen_exited")
end

local function obtain_zoo_monkey()
  local armed, safety_failure = preparation.arm_safety(12)
  if not armed then return safety_failure end
  local reached = reach_zoo()
  if reached.status ~= "complete" then return reached end
  local disguise = equip_disguise()
  if disguise.status ~= "complete" then return disguise end

  if not areas.in_monkey_pen(gc.read("player").world) then
    local entered
    for _ = 1, 3 do
      local minder = wait_for_npc(config.npcs.monkey_minder, 20, 30)
      entered = talk_to(minder, function()
        return areas.in_monkey_pen(gc.read("player").world)
      end, "monkey_pen_entered", true)
      if entered.status == "complete" then break end
      if entered.status ~= "monkey_madness_monkey_pen_entered_closed_without_progress" then
        return entered
      end
    end
    if not areas.in_monkey_pen(gc.read("player").world) then return entered end
  end
  if item_queries.carried_quantity(config.items.zoo_monkey) == 0 then
    local target = wait_for_npc(config.npcs.zoo_monkey, 18, 30)
    local received = talk_to(target, function()
      return item_queries.carried_quantity(config.items.zoo_monkey) > 0
    end, "zoo_monkey_received")
    if received.status ~= "complete" then return received end
  end

  local disabled, behavior_failure = behaviors.configure { auto_retaliate = true, emergency_escape = false }
  if not disabled then return behavior_failure end
  local exited = leave_monkey_pen()
  if exited.status ~= "complete" then return exited end
  return {
    status = "complete",
    result = "zoo_monkey_obtained",
    reached = reached,
    disguise = disguise,
    exit = exited,
  }
end

local function enter_marim()
  local function inside()
    local world = gc.read("player").world
    return geometry.in_zone(world, config.zones.ape_atoll_north) or
      geometry.in_zone(world, config.zones.ape_atoll_north_west) or
      geometry.in_zone(world, config.zones.ape_atoll_north_east) or
      geometry.in_zone(world, config.zones.ape_atoll_bridge) or
      geometry.in_zone(world, config.zones.ape_atoll_over_bridge) or
      areas.in_throne_room(world)
  end
  if inside() then
    return { status = "complete", result = "marim_already_entered" }
  end
  local function gate_is_open()
    return object(config.objects.marim_gate_open, nil, 12) ~= nil
  end
  local dialogue = gc.read("dialogue")
  if dialogue.type == "continue" and dialogue.speaker == "Kruk" then
    local continued = drain_dialogue(gate_is_open, "marim_gate_opened", nil, 60)
    if continued.status ~= "complete" and
      continued.status ~= "monkey_madness_marim_gate_opened_closed_without_progress" then
      return continued
    end
    if inside() then
      return { status = "complete", result = "marim_entered", gate = continued }
    end
  end
  local approached = reach_with_monkey(config.points.marim_gate_south, 1, 300)
  if approached.status ~= "arrived" then return approached end
  local gate = object(config.objects.marim_gate, "Open", 12)
  local opened
  if gate then
    opened = interact_with_dialogue(
      {
        type = "object.interact",
        id = gate.id,
        action = "Open",
        world = gate.world,
        within = 12,
      },
      gate_is_open,
      "marim_gate_opened")
    if opened.status ~= "complete" then return opened end
    if inside() then
      return { status = "complete", result = "marim_entered", gate = opened }
    end
  end
  local crossed = reach_with_monkey(config.points.marim_gate_north, 0, 80)
  if crossed.status ~= "arrived" then return crossed end
  if gc.read("player").world.y < config.points.marim_gate_north.y then
    return {
      status = "monkey_madness_marim_gate_cross_unverified",
      gate = gate,
      receipt = opened,
      player = gc.read("player"),
    }
  end
  return { status = "complete", result = "marim_entered", receipt = opened }
end

local function carry_monkey_to_ape_atoll()
  if item_queries.carried_quantity(config.items.zoo_monkey) == 0 then
    return { status = "monkey_madness_zoo_monkey_not_carried" }
  end
  local disabled, behavior_failure = behaviors.configure { auto_retaliate = true, emergency_escape = false }
  if not disabled then return behavior_failure end
  local exited = leave_monkey_pen()
  if exited.status ~= "complete" then return exited end

  if not on_ape_atoll() then
    local world = gc.read("player").world
    if not geometry.in_zone(world, config.zones.grand_tree) and
      not geometry.in_zone(world, config.zones.stronghold_transport) and
      not geometry.in_zone(world, config.zones.post_puzzle_hangar) and
      not geometry.in_zone(world, config.zones.crash_island) then
      local journey = config.routes.zoo_to_grand_tree
      local reached = reach_with_monkey(journey.destination, journey.within, 900, "travel")
      if reached.status ~= "arrived" then return reached end
    end
    local traveled = ape_atoll.execute { policy = { breaks = false, cursor_release = "none", fidget = "none" }, keyboard = true }
    if traveled.status ~= "complete" then return traveled end
  end

  local disguise = equip_disguise()
  if disguise.status ~= "complete" then return disguise end
  local entered = enter_marim()
  if entered.status ~= "complete" then return entered end
  return { status = "complete", result = "zoo_monkey_brought_to_marim", disguise = disguise, gate = entered }
end

local function garkor_stage()
  local vars = gc.read("vars", { varps = { config.varp }, varbits = { config.varbits.garkor } })
  return vars.varps[config.varp], vars.varbits[config.varbits.garkor]
end

local function use_ladder(id, action, arrived, label)
  local cleared = clear_monkey_chatter()
  if cleared.status ~= "complete" then return cleared end
  local ladder = object(id, action, 12)
  if not ladder then
    return {
      status = "monkey_madness_" .. label .. "_ladder_not_observed",
      objects = gc.read("objects", { within = 16, limit = 40 }),
    }
  end
  local receipt = gc.await {
    action = {
      type = "object.interact",
      id = ladder.id,
      action = action,
      world = ladder.world,
      within = 12,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if receipt.status ~= "dispatched" then return receipt end
  if not wait.until_true(arrived, 30) then
    return { status = "monkey_madness_" .. label .. "_unverified", receipt = receipt }
  end
  return { status = "complete", result = label, receipt = receipt }
end

local function climb_bridge()
  if geometry.in_zone(gc.read("player").world, config.zones.ape_atoll_over_bridge) then
    return { status = "complete", result = "bridge_crossed" }
  end
  if not geometry.in_zone(gc.read("player").world, config.zones.ape_atoll_bridge) then
    local reached = reach_with_monkey(config.points.west_watchtower_ladder, 1, 300)
    if reached.status ~= "arrived" then return reached end
    local climbed = use_ladder(
      config.objects.west_watchtower_ladder,
      "Climb-up",
      function()
        return geometry.in_zone(gc.read("player").world, config.zones.ape_atoll_bridge)
      end,
      "bridge_ascent")
    if climbed.status ~= "complete" then return climbed end
  end
  local crossed = reach_with_monkey(config.points.east_bridge_ladder_approach, 0, 120)
  if crossed.status ~= "arrived" then return crossed end
  local descended = use_ladder(
    config.objects.east_bridge_ladder,
    "Climb-down",
    function()
      return geometry.in_zone(gc.read("player").world, config.zones.ape_atoll_over_bridge)
    end,
    "bridge_descent")
  if descended.status ~= "complete" then return descended end
  return { status = "complete", result = "bridge_crossed", receipt = descended.receipt }
end

local function return_from_kruk_side()
  local world = gc.read("player").world
  local crossed_bridge = geometry.in_zone(world, config.zones.ape_atoll_over_bridge) or
    geometry.in_zone(world, config.zones.ape_atoll_bridge)
  if geometry.in_zone(world, config.zones.ape_atoll_over_bridge) then
    local reached = reach_with_monkey(config.points.east_watchtower_ladder, 1, 120)
    if reached.status ~= "arrived" then return reached end
    local climbed = use_ladder(
      config.objects.east_watchtower_ladder,
      "Climb-up",
      function()
        return geometry.in_zone(gc.read("player").world, config.zones.ape_atoll_bridge)
      end,
      "bridge_return_ascent")
    if climbed.status ~= "complete" then return climbed end
  end
  if geometry.in_zone(gc.read("player").world, config.zones.ape_atoll_bridge) then
    local crossed = reach_with_monkey(config.points.west_bridge_ladder_approach, 0, 120)
    if crossed.status ~= "arrived" then return crossed end
    local descended = use_ladder(
      config.objects.west_bridge_ladder,
      "Climb-down",
      function() return areas.in_north(gc.read("player").world) end,
      "bridge_return_descent")
    if descended.status ~= "complete" then return descended end
  end
  if areas.in_north(gc.read("player").world) then
    return {
      status = "complete",
      result = crossed_bridge and "returned_to_marim_side" or "already_on_marim_side",
    }
  end
  if not areas.in_north(gc.read("player").world) then
    return {
      status = "monkey_madness_guard_resume_location_unknown",
      player = gc.read("player"),
    }
  end
end

local function secure_awowogei_favor()
  if item_queries.carried_quantity(config.items.zoo_monkey) == 0 then
    return { status = "monkey_madness_zoo_monkey_not_carried" }
  end
  local disabled, behavior_failure = behaviors.configure { auto_retaliate = true, emergency_escape = false }
  if not disabled then return behavior_failure end
  local disguise = equip_disguise()
  if disguise.status ~= "complete" then return disguise end
  local entered = enter_marim()
  if entered.status ~= "complete" then return entered end

  if not areas.in_throne_room(gc.read("player").world) then
    local _, stage = garkor_stage()
    if stage < 3 then
      local journey = config.routes.marim_gate_to_garkor
      local reached = reach_with_monkey(journey.destination, journey.within)
      if reached.status ~= "arrived" then return reached end
      local garkor = wait_for_npc(config.npcs.garkor[1], 20, 30)
      local briefed = talk_to(garkor, function()
        local _, current = garkor_stage()
        return current >= 3
      end, "garkor_monkey_briefing_complete")
      if briefed.status ~= "complete" then return briefed end
    end

    if gc.checkpoint(config.checkpoints.awowogei_guard_authorized) ~= 1 then
      local returned = return_from_kruk_side()
      if returned.status ~= "complete" then return returned end
      local guard_reached = reach_with_monkey(config.points.elder_guard, 3, 180)
      if guard_reached.status ~= "arrived" then return guard_reached end
      local guard = wait_for_npc(config.npcs.elder_guard, 18, 30)
      local guard_talk = talk_to(guard, nil, "elder_guard_conversation_complete")
      if guard_talk.status ~= "complete" then return guard_talk end
      gc.checkpoint(config.checkpoints.awowogei_guard_authorized, 1)
    end

    if not geometry.in_zone(gc.read("player").world, config.zones.ape_atoll_bridge) and
      not geometry.in_zone(gc.read("player").world, config.zones.ape_atoll_over_bridge) then
      local journey = config.routes.garkor_to_west_ladder
      local reached = reach_with_monkey(journey.destination, journey.within)
      if reached.status ~= "arrived" then return reached end
    end
    local bridge = climb_bridge()
    if bridge.status ~= "complete" then return bridge end

    local kruk_reached = reach_with_monkey(config.points.kruk, 3, 100)
    if kruk_reached.status ~= "arrived" then return kruk_reached end
    local kruk = wait_for_npc(config.npcs.kruk, 18, 30)
    local kruk_talk = talk_to(kruk, function()
      return areas.in_throne_room(gc.read("player").world)
    end, "kruk_conversation_complete")
    if kruk_talk.status ~= "complete" then return kruk_talk end
  end

  local conversations = {}
  for _ = 1, 3 do
    if item_queries.carried_quantity(config.items.zoo_monkey) == 0 then break end
    local throne = object(config.objects.awowogei_throne, "Talk-to", 16)
    local talked = interact_and_talk(throne, function()
      return item_queries.carried_quantity(config.items.zoo_monkey) == 0
    end, "awowogei_favor_earned")
    conversations[#conversations + 1] = talked
    if talked.status ~= "complete" and
      talked.status ~= "monkey_madness_awowogei_favor_earned_closed_without_progress" then
      return talked
    end
  end
  if item_queries.carried_quantity(config.items.zoo_monkey) > 0 then
    return {
      status = "monkey_madness_awowogei_favor_unverified",
      conversations = conversations,
      dialogue = gc.read("dialogue"),
    }
  end
  gc.clear_checkpoint(config.checkpoints.awowogei_guard_authorized)
  local enabled, enable_failure = behaviors.configure { auto_retaliate = true, emergency_escape = true }
  if not enabled then return enable_failure end
  return { status = "complete", result = "awowogei_favor_earned", conversations = conversations }
end

local function obtain_sigil()
  if item_queries.carried_quantity(config.items.squad_sigil) > 0 then
    return { status = "complete", result = "squad_sigil_already_owned" }
  end
  local enabled, behavior_failure = behaviors.configure { auto_retaliate = true, emergency_escape = true }
  if not enabled then return behavior_failure end
  if not on_ape_atoll() then
    return {
      status = "monkey_madness_sigil_resume_location_unknown",
      player = gc.read("player"),
    }
  end
  local disguise = equip_disguise()
  if disguise.status ~= "complete" then return disguise end
  local entered = enter_marim()
  if entered.status ~= "complete" then return entered end
  if areas.in_throne_room(gc.read("player").world) then
    local guard = wait_for_npc(config.npcs.elder_guard, 20, 30)
    local released = talk_to(guard, function()
      return not areas.in_throne_room(gc.read("player").world)
    end, "elder_guard_release_complete")
    if released.status ~= "complete" then return released end
  end
  local conversations = {}
  for _ = 1, 3 do
    local chapter = ui.close_group(config.interfaces.chapter_message, 10)
    if chapter.status ~= "complete" then return chapter end
    local target = wait_for_clickable_npc(config.npcs.garkor[1], 20, 60)
    if not target then
      local reached = reach_with_monkey(config.points.garkor, 2, 240)
      if reached.status ~= "arrived" then return reached end
      target = wait_for_clickable_npc(config.npcs.garkor[1], 20, 30)
    end
    local received = talk_to(target, function()
      return item_queries.carried_quantity(config.items.squad_sigil) > 0
    end, "squad_sigil_received")
    conversations[#conversations + 1] = received
    if received.status == "complete" then
      return {
        status = "complete",
        result = "squad_sigil_obtained",
        conversations = conversations,
      }
    end
    if received.status ~= "monkey_madness_squad_sigil_received_closed_without_progress" then
      return received
    end
  end
  return {
    status = "monkey_madness_squad_sigil_not_received",
    conversations = conversations,
  }
end

return {
  obtain_zoo_monkey = obtain_zoo_monkey,
  carry_monkey_to_ape_atoll = carry_monkey_to_ape_atoll,
  secure_awowogei_favor = secure_awowogei_favor,
  obtain_sigil = obtain_sigil,
}
