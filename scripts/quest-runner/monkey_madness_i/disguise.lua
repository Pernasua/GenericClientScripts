local config = gc.require("monkey_madness_config")
local areas = gc.require("monkey_madness_areas")
local behaviors = gc.require("shared_behaviors")
local equipment_actions = gc.require("shared_equipment")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local movement = gc.require("shared_movement")
local protection = gc.require("shared_protection")
local preparation = gc.require("monkey_madness_preparation")
local amulet = gc.require("monkey_madness_amulet")
local garkor = gc.require("monkey_madness_garkor")
local travel = gc.require("shared_travel")
local wait = gc.require("shared_wait")

local function carried_any(ids)
  for _, id in ipairs(ids) do
    if item_queries.carried_quantity(id) > 0 then return id end
  end
  return nil
end

local function prison_interrupts()
  return { area = { name = "prison", bounds = areas.prison_bounds() } }
end

local function traverse_child_corridor(journey)
  gc.activity("questing")
  if geometry.distance(gc.read("player").world, journey.destination) == 0 then
    return { status = "arrived", result = "already_at_child_staging", reached = gc.read("player").world }
  end
  local continuation
  local receipts = {}
  for _ = 1, 16 do
    local ready, failure = garkor.maintain_stamina()
    if not ready then return nil, failure end
    local moved = movement.walk(journey.destination, journey.within, {
      ticks = 600,
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      via = journey.via, activity = "questing", interrupt_on = garkor.travel_interrupts(), resume = continuation,
    })
    receipts[#receipts + 1] = moved
    local recaptured = areas.in_prison(gc.read("player").world)
    if moved.status == "arrived" and not recaptured then return moved end
    local upkeep = moved.reason == "poisoned" or moved.reason == "varbit_equals" or moved.reason == "run_energy_below"
    if recaptured or moved.status ~= "interrupted" or not upkeep or not moved.continuation then
      return nil, { status = "monkey_madness_disguise_route_failed", destination = journey.destination,
        receipt = moved, receipts = receipts, player = gc.read("player") }
    end
    if moved.reason == "poisoned" then
      local cured, poison_failure = garkor.refresh_antipoison()
      if not cured then return nil, poison_failure end
    end
    continuation = moved.continuation
    gc.await { event = "game.tick" }
  end
  return nil, { status = "monkey_madness_disguise_upkeep_limit", receipts = receipts }
end

local function first_banana_tree()
  for _, id in ipairs(config.objects.banana_trees) do
    local tree = gc.read("objects", {
      id = id,
      action = "Search",
      within = 24,
      limit = 1,
    })[1]
    if tree then return tree end
  end
  return nil
end

local function monkey_aunt()
  return gc.read("npcs", {
    id = config.npcs.monkey_aunt,
    within = 30,
    limit = 1,
  })[1]
end

local function aunt_near_player()
  local aunt = monkey_aunt()
  return aunt and geometry.distance(aunt.world, gc.read("player").world) <= 6
end

local function wait_for_aunt_south_crossing()
  local aunt = monkey_aunt()
  local previous = aunt and geometry.copy_point(aunt.world) or nil
  for _ = 1, 240 do
    gc.await { event = "game.tick" }
    aunt = monkey_aunt()
    if aunt then
      local current = aunt.world
      local crossing = config.points.monkey_aunt_south_crossing
      if previous and current.plane == crossing.plane and
        current.x == crossing.x and current.y == crossing.y and
        previous.plane == current.plane and previous.x == current.x and
        previous.y > current.y then
        return {
          status = "complete",
          result = "monkey_aunt_south_crossing_observed",
          previous = previous,
          current = geometry.copy_point(current),
        }
      end
      previous = geometry.copy_point(current)
    else
      previous = nil
    end
  end
  return nil, {
    status = "monkey_madness_monkey_aunt_south_crossing_not_observed",
  }
end

local function return_to_child_staging()
  if geometry.distance(gc.read("player").world, config.points.monkey_child_staging) == 0 then
    return { status = "arrived", result = "already_at_monkey_child_staging" }
  end
  gc.activity("questing")
  return movement.walk(config.points.monkey_child_staging, 0, {
    ticks = 40,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    interrupt_on = prison_interrupts(),
  })
end

local function retreat_with(failure)
  failure.retreat = return_to_child_staging()
  return nil, failure
end

local transient_banana_search_failure = {
  mouse_missed_target = true,
  hover_has_no_matching_action = true,
  context_menu_already_open = true,
  context_menu_has_no_matching_action = true,
  interaction_already_running = true,
}

local function search_one_banana(receipts)
  local before = item_queries.carried_quantity(config.items.banana)
  local picked
  for attempt = 1, 3 do
    if aunt_near_player() then
      return false, { status = "monkey_aunt_approaching" }
    end
    local tree = first_banana_tree()
    if not tree then
      return nil, {
        status = "monkey_madness_banana_tree_not_observed",
        quantity = before,
        objects = gc.read("objects", { within = 28, limit = 60 }),
      }
    end
    picked = gc.await {
      action = {
        type = "object.interact",
        id = tree.id,
        action = "Search",
        world = tree.world,
        within = 24,
      },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 30 },
    }
    receipts[#receipts + 1] = picked
    if picked.status == "dispatched" then break end
    if not transient_banana_search_failure[picked.result] then return nil, picked end
    if attempt < 3 then gc.await { event = "game.tick" } end
  end
  if picked.status ~= "dispatched" then return nil, picked end
  for _ = 1, 20 do
    if item_queries.carried_quantity(config.items.banana) > before then return true, picked end
    if aunt_near_player() then
      return false, {
        status = "monkey_aunt_approaching",
        receipt = picked,
      }
    end
    gc.await { event = "game.tick" }
  end
  return nil, {
    status = "monkey_madness_banana_pick_unverified",
    receipt = picked,
    quantity = item_queries.carried_quantity(config.items.banana),
  }
end

local function pick_bananas()
  local receipts = {}
  local windows = {}
  for _ = 1, 12 do
    if item_queries.carried_quantity(config.items.banana) >= 5 then break end
    local crossing, crossing_failure = wait_for_aunt_south_crossing()
    if not crossing then return retreat_with(crossing_failure) end
    local window = { crossing = crossing, searches = {} }
    windows[#windows + 1] = window
    while item_queries.carried_quantity(config.items.banana) < 5 and
      not aunt_near_player() do
      local searched, search_result = search_one_banana(receipts)
      window.searches[#window.searches + 1] = search_result
      if searched == nil then return retreat_with(search_result) end
      if searched == false then break end
    end
    local hidden = return_to_child_staging()
    window.retreat = hidden
    if hidden.status ~= "arrived" then return nil, hidden end
  end
  if item_queries.carried_quantity(config.items.banana) < 5 then
    return nil, {
      status = "monkey_madness_banana_windows_exhausted",
      quantity = item_queries.carried_quantity(config.items.banana),
      windows = windows,
    }
  end
  local retreated = return_to_child_staging()
  if retreated.status ~= "arrived" then return nil, retreated end
  return {
    status = "complete",
    result = "five_bananas_obtained",
    receipts = receipts,
    windows = windows,
    retreat = retreated,
  }
end

local child_choices = {
  "Well I'll be a monkey's uncle!",
  "How many bananas did Aunty want?",
  "Ok, I promise!",
  "I've lost that toy you gave me...",
  "Wow - can I borrow it?",
}

local function choose_child_option(dialogue)
  for _, wanted in ipairs(child_choices) do
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

local function child()
  return gc.read("npcs", {
    id = config.npcs.monkey_child,
    within = 16,
    limit = 1,
  })[1]
end

local function talk_to_child_once()
  if aunt_near_player() then
    return {
      status = "interrupted",
      result = "monkey_aunt_approaching",
    }
  end
  gc.activity("questing")
  local approached = movement.walk(config.points.monkey_child, 3, {
    ticks = 40,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    interrupt_on = prison_interrupts(),
  })
  if approached.status ~= "arrived" then return nil, approached end
  if aunt_near_player() then
    return {
      status = "interrupted",
      result = "monkey_aunt_approaching",
    }
  end
  local target = child()
  if not target then
    return nil, {
      status = "monkey_madness_monkey_child_not_observed",
      nearby = gc.read("npcs", { within = 20, limit = 40 }),
    }
  end
  local talked = gc.await {
    action = {
      type = "npc.interact",
      id = target.id,
      action = "Talk-to",
      within = 16,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if talked.status ~= "dispatched" then return nil, talked end
  local opened = false
  local closed = 0
  for _ = 1, 100 do
    if item_queries.carried_quantity(config.items.monkey_talisman) > 0 then
      return { status = "complete", result = "monkey_talisman_obtained", receipt = talked }
    end
    if aunt_near_player() then
      return {
        status = "interrupted",
        result = "monkey_aunt_approaching",
        receipt = talked,
      }
    end
    gc.await { event = "game.tick" }
    if aunt_near_player() then
      return {
        status = "interrupted",
        result = "monkey_aunt_approaching",
        receipt = talked,
      }
    end
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      opened = true
      closed = 0
      local continued = gc.await {
        action = { type = "dialogue.continue", reading = false },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 30 },
      }
      if continued.status ~= "dispatched" and
        continued.result ~= "dialogue_is_choice" and
        continued.result ~= "dialogue_continue_not_visible" then
        return nil, continued
      end
    elseif dialogue.type == "choice" then
      opened = true
      closed = 0
      local selected = choose_child_option(dialogue)
      if not selected then
        return nil, {
          status = "monkey_madness_monkey_child_choice_unhandled",
          dialogue = dialogue,
        }
      end
    elseif opened then
      closed = closed + 1
      if closed >= 3 then
        return { status = "complete", result = "monkey_child_conversation_complete" }
      end
    end
  end
  return nil, { status = "monkey_madness_monkey_child_dialogue_timeout" }
end

local function obtain_talisman()
  if item_queries.carried_quantity(config.items.monkey_talisman) > 0 then
    return { status = "complete", result = "monkey_talisman_already_owned" }
  end
  local armed, safety_failure = preparation.arm_safety(12)
  if not armed then return safety_failure end
  local worn = equipment_actions.equip(config.items.mspeak_amulet, "Wear")
  if worn.status ~= "complete" and worn.status ~= "unchanged" then return worn end

  local world = gc.read("player").world
  local escaped_from_prison = false
  if areas.in_prison(world) then
    local escaped = garkor.escape_prison()
    if escaped.status ~= "complete" then return escaped end
    escaped_from_prison = true
  end
  local configured, behavior_failure = behaviors.configure {
    auto_retaliate = false,
    emergency_escape = true,
    combat_prayer = false,
  }
  if not configured then return behavior_failure end
  local child_route = config.routes.temple_to_monkey_child
  local route
  if escaped_from_prison or
    geometry.distance(gc.read("player").world, config.points.prison_clear) <= 4 then
    gc.activity("questing")
    local direct = movement.walk(config.points.monkey_child_staging, 0, {
      ticks = 120,
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      interrupt_on = prison_interrupts(),
    })
    if direct.status ~= "arrived" then return direct end
    route = direct
  else
    local route_failure
    route, route_failure = traverse_child_corridor(child_route)
    if not route then return route_failure end
  end

  local bananas, banana_failure = pick_bananas()
  if not bananas then return banana_failure end
  local conversations = {}
  local dialogue_windows = {}
  for _ = 1, 12 do
    local crossing, crossing_failure = wait_for_aunt_south_crossing()
    if not crossing then return retreat_with(crossing_failure) end
    local window = { crossing = crossing, conversations = {} }
    dialogue_windows[#dialogue_windows + 1] = window
    for _ = 1, 8 do
      local bananas_before = item_queries.carried_quantity(config.items.banana)
      local result, failure = talk_to_child_once()
      conversations[#conversations + 1] = result or failure
      window.conversations[#window.conversations + 1] = result or failure
      if not result then
        local hidden = return_to_child_staging()
        failure.retreat = hidden
        return failure
      end
      if item_queries.carried_quantity(config.items.monkey_talisman) > 0 then break end
      if bananas_before >= 5 and
        item_queries.carried_quantity(config.items.banana) < bananas_before then
        result.bananas_given = true
        break
      end
      if result.result == "monkey_aunt_approaching" or aunt_near_player() then break end
    end
    local hidden = return_to_child_staging()
    window.retreat = hidden
    if hidden.status ~= "arrived" then return hidden end
    if item_queries.carried_quantity(config.items.monkey_talisman) > 0 then
      return {
        status = "complete",
        result = "monkey_talisman_obtained",
        route = route,
        bananas = bananas,
        conversations = conversations,
        dialogue_windows = dialogue_windows,
      }
    end
  end
  return {
    status = "monkey_madness_monkey_talisman_not_received",
    conversations = conversations,
    dialogue_windows = dialogue_windows,
    inventory = gc.read("inventory"),
  }
end

local function zooknock_stage()
  local vars = gc.read("vars", {
    varps = { config.varp },
    varbits = { config.varbits.zooknock },
  })
  return vars.varps[config.varp], vars.varbits[config.varbits.zooknock]
end

local function use_item_on_zooknock(target, item_id, label)
  if item_queries.carried_quantity(item_id) == 0 then return { status = "monkey_madness_" .. label .. "_missing" } end
  local before = item_queries.carried_quantity(item_id)
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
  if not wait.until_true(function()
    local varp, stage = zooknock_stage()
    return item_queries.carried_quantity(item_id) < before or varp >= 4 or stage >= 6
  end, 40) then
    return { status = "monkey_madness_" .. label .. "_delivery_unverified", receipt = used }
  end
  return { status = "complete", result = label .. "_delivered", receipt = used }
end

local function collect_greegree(target)
  if item_queries.carried_quantity(config.items.karamjan_greegree) > 0 then
    return { status = "complete", result = "karamjan_greegree_already_owned" }
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
  for _ = 1, 100 do
    gc.await { event = "game.tick" }
    if item_queries.carried_quantity(config.items.karamjan_greegree) > 0 then
      return { status = "complete", result = "karamjan_greegree_obtained", receipt = talked }
    end
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
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
      local selected
      for _, option in ipairs(dialogue.options or {}) do
        if option.text == "What do we need for the monkey talisman?" then
          selected = gc.await {
            action = { type = "dialogue.choose", text = option.text },
            policy = { breaks = false, cursor_release = "none", fidget = "none" },
            timeout = { game_ticks = 30 },
          }
          break
        end
      end
      if not selected then
        return {
          status = "monkey_madness_zooknock_greegree_choice_unhandled",
          dialogue = dialogue,
        }
      end
    end
  end
  return { status = "monkey_madness_karamjan_greegree_not_received" }
end

local function make_greegree()
  if item_queries.carried_quantity(config.items.karamjan_greegree) > 0 then
    return { status = "complete", result = "karamjan_greegree_already_owned" }
  end
  local armed, safety_failure = preparation.arm_safety(12)
  if not armed then return safety_failure end
  local reached = amulet.reach_zooknock()
  if reached.status ~= "complete" then return reached end
  local target = reached.target
  local talisman = use_item_on_zooknock(
    target,
    config.items.monkey_talisman,
    "monkey_talisman")
  if talisman.status ~= "complete" then return talisman end
  local remains_id = carried_any({
    config.items.karamjan_monkey_bones,
    config.items.karamjan_monkey_corpse,
  })
  if not remains_id then return { status = "monkey_madness_monkey_remains_missing" } end
  local remains = use_item_on_zooknock(target, remains_id, "monkey_remains")
  if remains.status ~= "complete" then return remains end
  local collected = collect_greegree(target)
  if collected.status ~= "complete" then return collected end
  local exited = travel.teleport_to_castle_wars({
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    keyboard = true,
  })
  if exited.status ~= "complete" then
    return { status = "monkey_madness_dungeon_exit_failed", receipt = exited }
  end
  local disabled, protection_receipt = protection.disable("melee")
  if not disabled then return protection_receipt end
  return {
    status = "complete",
    result = "karamjan_greegree_obtained",
    reached = reached,
    protection = protection_receipt,
    talisman = talisman,
    remains = remains,
    collected = collected,
    exited = exited,
  }
end

local function sync_greegree()
  if item_queries.carried_quantity(config.items.karamjan_greegree) == 0 then
    return { status = "monkey_madness_karamjan_greegree_missing" }
  end
  if geometry.in_zone(gc.read("player").world, config.zones.zooknock_dungeon) then
    local exited = travel.teleport_to_castle_wars({
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      keyboard = true,
    })
    if exited.status ~= "complete" then
      return { status = "monkey_madness_dungeon_exit_failed", receipt = exited }
    end
    local disabled, protection_receipt = protection.disable("melee")
    if not disabled then return protection_receipt end
    return {
      status = "complete",
      result = "greegree_progress_synced",
      exited = exited,
      protection = protection_receipt,
    }
  end
  local varp = zooknock_stage()
  if varp >= 4 then return { status = "complete", result = "greegree_progress_synced" } end
  return make_greegree()
end

return {
  obtain_talisman = obtain_talisman,
  make_greegree = make_greegree,
  sync_greegree = sync_greegree,
}
