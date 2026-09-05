local config = gc.require("monkey_madness_config")
local behaviors = gc.require("shared_behaviors")
local consumables = gc.require("shared_consumables")
local geometry = gc.require("shared_geometry")
local movement = gc.require("shared_movement")
local item_queries = gc.require("shared_items")
local preparation = gc.require("monkey_madness_preparation")
local protection = gc.require("shared_protection")
local travel = gc.require("shared_travel")

local minimum_food_reserve = 3

local function retreat_for_supplies(reason)
  gc.activity("travel")
  local teleported = travel.teleport_to_castle_wars({
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    keyboard = true,
  })
  return {
    status = teleported.status == "complete" and
      "monkey_madness_dungeon_restock_required" or
      "monkey_madness_dungeon_retreat_failed",
    reason = reason,
    teleport = teleported,
    player = gc.read("player"),
    inventory = gc.read("inventory"),
    prayer = gc.read("skills").prayer,
  }
end

local function maintain_stamina()
  return consumables.ensure_stamina()
end

local function cure_poison()
  local receipt = gc.await {
    action = { type = "consumable.cure_poison" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if receipt.status == "complete" or receipt.status == "unchanged" then
    return true, receipt
  end
  return nil, {
    status = "monkey_madness_poison_cure_failed",
    emergency = true,
    receipt = receipt,
  }
end

local function check_dungeon_supplies()
  if item_queries.inventory_quantity(config.items.lobster) <= minimum_food_reserve then
    return nil, {
      status = "monkey_madness_food_reserve_reached",
      emergency = true,
    }
  end
  local cured, poison_failure = cure_poison()
  if not cured then return nil, poison_failure end
  local protected, prayer_failure = protection.enable("melee", 12)
  if not protected then
    return nil, {
      status = "monkey_madness_melee_protection_unavailable",
      emergency = true,
      receipt = prayer_failure,
    }
  end
  local stamina, stamina_failure = maintain_stamina()
  if not stamina then
    return nil, {
      status = "monkey_madness_stamina_unavailable",
      emergency = false,
      receipt = stamina_failure,
    }
  end
  return true
end

local function zooknock_stage()
  local vars = gc.read("vars", { varbits = { config.varbits.zooknock } })
  return vars.varbits[config.varbits.zooknock]
end

local function traverse_dungeon()
  gc.activity("hazardous_travel")
  local journey = config.routes.zooknock_dungeon
  local continuation
  local receipts = {}
  for _ = 1, 24 do
    local supplied, supply_failure = check_dungeon_supplies()
    if not supplied then
      if supply_failure.emergency then return nil, retreat_for_supplies(supply_failure) end
      return nil, {
        status = "monkey_madness_dungeon_supply_failed",
        reason = supply_failure,
        receipts = receipts,
        player = gc.read("player"),
      }
    end
    local moved = movement.walk(journey.destination, journey.within, {
      ticks = 900,
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      activity = "hazardous_travel",
      resume = continuation,
      interrupt_on = {
        poisoned = true,
        inventory_below = { { id = config.items.lobster, quantity = minimum_food_reserve + 1 } },
        skill_below = { prayer = 12 },
        varbit_equals = {
          { id = config.varbits.stamina_active, value = 0 },
          { id = config.varbits.protect_from_melee, value = 0 },
        },
      },
    })
    receipts[#receipts + 1] = moved
    if moved.status == "arrived" then return moved end
    local upkeep = moved.reason == "poisoned" or moved.reason == "inventory_below" or
      moved.reason == "skill_below" or moved.reason == "varbit_equals"
    if moved.status ~= "interrupted" or not upkeep or not moved.continuation then
      return nil, {
        status = "monkey_madness_zooknock_route_failed",
        destination = journey.destination,
        receipt = moved,
        receipts = receipts,
        player = gc.read("player"),
      }
    end
    continuation = moved.continuation
    gc.await { event = "game.tick" }
  end
  return nil, { status = "monkey_madness_dungeon_upkeep_limit", receipts = receipts }
end

local function dungeon_entrance()
  return gc.read("objects", {
    id = config.objects.zooknock_dungeon_entrance,
    action = "Climb-down",
    within = 12,
    limit = 1,
  })[1]
end

local function enter_zooknock_dungeon()
  gc.activity("hazardous_travel")
  if geometry.in_zone(gc.read("player").world, config.zones.zooknock_dungeon) then
    return { status = "complete", result = "zooknock_dungeon_already_entered" }
  end
  local approach = movement.walk(config.points.zooknock_dungeon_entrance, 1, {
    ticks = 400,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    activity = "hazardous_travel",
  })
  if approach.status ~= "arrived" then return approach end
  local descended
  for _ = 1, 8 do
    local entrance = dungeon_entrance()
    if not entrance then
      return {
        status = "monkey_madness_zooknock_entrance_not_observed",
        objects = gc.read("objects", { within = 12, limit = 60 }),
      }
    end
    descended = gc.await {
      action = {
        type = "object.interact",
        id = entrance.id,
        action = "Climb-down",
        world = entrance.world,
        within = 12,
      },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 30 },
    }
    if descended.status == "dispatched" then break end
    if descended.result ~= "interaction_already_running" and
      descended.result ~= "cancelled: combat_guard" and
      descended.result ~= "cancelled: emergency_consumable" and
      descended.result ~= "hover_has_no_matching_action" then
      return descended
    end
    gc.await { event = "game.tick" }
  end
  if not descended or descended.status ~= "dispatched" then return descended end
  for _ = 1, 40 do
    gc.await { event = "game.tick" }
    if geometry.in_zone(gc.read("player").world, config.zones.zooknock_dungeon) then
      return {
        status = "complete",
        result = "zooknock_dungeon_entered",
        receipt = descended,
      }
    end
  end
  return {
    status = "monkey_madness_zooknock_dungeon_entry_unverified",
    receipt = descended,
    player = gc.read("player"),
  }
end

local function zooknock()
  return gc.read("npcs", {
    id = config.npcs.zooknock,
    within = 24,
    limit = 1,
  })[1]
end

local function clear_active_attacker()
  local player = gc.read("player")
  local target
  for _, npc in ipairs(gc.read("npcs", { within = 8, limit = 20 })) do
    if npc.interacting == player.name then
      for _, action in ipairs(npc.actions or {}) do
        if action == "Attack" then target = npc break end
      end
    end
    if target then break end
  end
  if not target then return { status = "complete", result = "no_active_attacker" } end

  gc.activity("combat")
  local attacked = gc.await {
    action = { type = "npc.interact", id = target.id, action = "Attack", within = 8 },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  if attacked.status ~= "dispatched" then
    return { status = "monkey_madness_attacker_clear_failed", receipt = attacked }
  end
  for _ = 1, 60 do
    gc.await { event = "game.tick" }
    local alive = false
    for _, current in ipairs(gc.read("npcs", { id = target.id, within = 12, limit = 10 })) do
      if current.index == target.index and not current.dead then alive = true end
    end
    if not alive then
      gc.activity("questing")
      return { status = "complete", result = "active_attacker_cleared", receipt = attacked }
    end
  end
  return {
    status = "monkey_madness_attacker_clear_timeout",
    target = target,
    receipt = attacked,
    player = gc.read("player"),
  }
end

local function continue_dialogue()
  return gc.await {
    action = { type = "dialogue.continue", reading = false },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
end

local function choose(text)
  return gc.await {
    action = { type = "dialogue.choose", text = text, reading = false },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 12 },
  }
end

local function introduce_zooknock()
  if zooknock_stage() >= 5 then
    return { status = "complete", result = "zooknock_already_briefed" }
  end
  local cleared = clear_active_attacker()
  if cleared.status ~= "complete" then return cleared end
  local target = zooknock()
  if not target then
    return { status = "monkey_madness_zooknock_not_observed" }
  end
  local talked = gc.await {
    action = {
      type = "npc.interact",
      id = target.id,
      action = "Talk-to",
      within = 24,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if talked.status ~= "dispatched" then return talked end

  local choices = {}
  for _ = 1, 100 do
    if zooknock_stage() >= 5 then
      return {
        status = "complete",
        result = "zooknock_briefed",
        talked = talked,
        attacker = cleared,
        choices = choices,
      }
    end
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      local continued = continue_dialogue()
      if continued.status ~= "dispatched" then return continued end
    elseif dialogue.type == "choice" then
      local selected = choose("What do we need for the monkey amulet?")
      if selected.status ~= "dispatched" then selected = choose("I'll be back later.") end
      choices[#choices + 1] = selected
      if selected.status ~= "dispatched" then
        return {
          status = "monkey_madness_zooknock_choice_failed",
          receipt = selected,
          dialogue = dialogue,
        }
      end
    end
    gc.await { event = "game.tick" }
  end
  return {
    status = "monkey_madness_zooknock_briefing_timeout",
    talked = talked,
    choices = choices,
    dialogue = gc.read("dialogue"),
  }
end

local function use_item_on_zooknock(item_id, label)
  if item_queries.inventory_quantity(item_id) == 0 then
    return { status = "complete", result = label .. "_already_delivered" }
  end
  local cleared = clear_active_attacker()
  if cleared.status ~= "complete" then return cleared end
  local target = zooknock()
  if not target then return { status = "monkey_madness_zooknock_not_observed" } end
  local used = gc.await {
    action = {
      type = "item.use_on_npc",
      item_id = item_id,
      npc_id = target.id,
      within = 24,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if used.status ~= "dispatched" then return used end
  for _ = 1, 40 do
    gc.await { event = "game.tick" }
    if item_queries.inventory_quantity(item_id) == 0 then
      return { status = "complete", result = label .. "_delivered", receipt = used }
    end
    if gc.read("dialogue").type == "continue" then
      local continued = continue_dialogue()
      if continued.status ~= "dispatched" then return continued end
    end
  end
  return {
    status = "monkey_madness_" .. label .. "_delivery_unverified",
    receipt = used,
    inventory = gc.read("inventory"),
  }
end

local function collect_enchanted_bar()
  if item_queries.inventory_quantity(config.items.enchanted_bar) > 0 then
    return { status = "complete", result = "enchanted_bar_already_owned" }
  end
  local cleared = clear_active_attacker()
  if cleared.status ~= "complete" then return cleared end
  local target = zooknock()
  if not target then return { status = "monkey_madness_zooknock_not_observed" } end
  local talked = gc.await {
    action = {
      type = "npc.interact",
      id = target.id,
      action = "Talk-to",
      within = 24,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if talked.status ~= "dispatched" then return talked end
  for _ = 1, 80 do
    gc.await { event = "game.tick" }
    if item_queries.inventory_quantity(config.items.enchanted_bar) > 0 then
      return { status = "complete", result = "enchanted_bar_obtained", receipt = talked }
    end
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      local continued = continue_dialogue()
      if continued.status ~= "dispatched" then return continued end
    elseif dialogue.type == "choice" then
      local selected = choose("What do we need for the monkey amulet?")
      if selected.status ~= "dispatched" then
        return {
          status = "monkey_madness_enchanted_bar_choice_failed",
          receipt = selected,
          dialogue = dialogue,
        }
      end
    end
  end
  return {
    status = "monkey_madness_enchanted_bar_not_received",
    receipt = talked,
    dialogue = gc.read("dialogue"),
    inventory = gc.read("inventory"),
  }
end

local function make_enchanted_bar()
  local configured, behavior_failure = behaviors.configure { auto_retaliate = false, emergency_escape = true }
  if not configured then return behavior_failure end
  local armed, safety_failure = preparation.arm_safety()
  if not armed then return safety_failure end
  gc.activity("questing")
  local entered = enter_zooknock_dungeon()
  if entered.status ~= "complete" then return entered end
  local route, route_failure = traverse_dungeon()
  if not route then return route_failure end
  local briefing = introduce_zooknock()
  if briefing.status ~= "complete" then return briefing end

  local dentures = use_item_on_zooknock(config.items.monkey_dentures, "dentures")
  if dentures.status ~= "complete" then return dentures end
  local mould = use_item_on_zooknock(config.items.amulet_mould, "amulet_mould")
  if mould.status ~= "complete" then return mould end
  local gold = use_item_on_zooknock(config.items.gold_bar, "gold_bar")
  if gold.status ~= "complete" then return gold end
  local enchanted = collect_enchanted_bar()
  if enchanted.status ~= "complete" then return enchanted end
  local exited = travel.teleport_to_castle_wars({
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    keyboard = true,
  })
  if exited.status ~= "complete" then
    return { status = "monkey_madness_dungeon_exit_failed", receipt = exited }
  end
  local disabled, protection_receipt = protection.disable("melee")
  if not disabled then return protection_receipt end
  local ordinary, behavior_receipt = behaviors.configure { auto_retaliate = true, emergency_escape = true }
  if not ordinary then return behavior_receipt end
  return {
    status = "complete",
    result = "enchanted_bar_obtained",
    entered = entered,
    route = route,
    briefing = briefing,
    deliveries = { dentures = dentures, mould = mould, gold = gold },
    enchanted = enchanted,
    exited = exited,
    protection = protection_receipt,
  }
end

local function reach_zooknock()
  local configured, behavior_failure = behaviors.configure { auto_retaliate = false, emergency_escape = true }
  if not configured then return behavior_failure end
  local cured, poison_failure = cure_poison()
  if not cured then return poison_failure end
  local protected, protection_receipt = protection.enable("melee", 12)
  if not protected then
    return {
      status = "monkey_madness_melee_protection_unavailable",
      receipt = protection_receipt,
    }
  end
  local entered = enter_zooknock_dungeon()
  if entered.status ~= "complete" then return entered end
  local route, route_failure = traverse_dungeon()
  if not route then return route_failure end
  local target = zooknock()
  if not target then
    return {
      status = "monkey_madness_zooknock_not_observed",
      player = gc.read("player"),
      nearby = gc.read("npcs", { within = 30, limit = 50 }),
    }
  end
  return {
    status = "complete",
    result = "zooknock_reached",
    protection = protection_receipt,
    entered = entered,
    route = route,
    target = target,
  }
end

return {
  make_enchanted_bar = make_enchanted_bar,
  reach_zooknock = reach_zooknock,
}
