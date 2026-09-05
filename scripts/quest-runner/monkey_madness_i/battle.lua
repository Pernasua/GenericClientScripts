local config = gc.require("monkey_madness_config")
local areas = gc.require("monkey_madness_areas")
local behaviors = gc.require("shared_behaviors")
local equipment_actions = gc.require("shared_equipment")
local item_queries = gc.require("shared_items")
local preparation = gc.require("monkey_madness_preparation")
local protection = gc.require("shared_protection")
local wait = gc.require("shared_wait")

local function configure_survival()
  local configured, behavior_receipt = behaviors.configure {
    auto_retaliate = false,
    emergency_escape = true,
    combat_prayer = false,
  }
  if not configured then return nil, behavior_receipt end
  local armed, safety_failure = preparation.arm_safety(16)
  if not armed then return nil, safety_failure end
  local staff = equipment_actions.equip(config.items.staff_of_fire, "Wield")
  if staff.status ~= "complete" and staff.status ~= "unchanged" then return nil, staff end
  local protected, protection_receipt = protection.enable("magic", 35)
  if not protected then return nil, protection_receipt end
  return true, {
    status = "complete",
    result = "jungle_demon_survival_configured",
    behaviors = behavior_receipt,
    safety = armed,
    protection = protection_receipt,
  }
end

local function configure_autocast()
  local autocast = gc.await {
    action = { type = "combat.set_autocast", spell = "Fire Bolt" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if autocast.status ~= "set" and autocast.status ~= "unchanged" then
    return nil, { status = "monkey_madness_fire_bolt_autocast_failed", receipt = autocast }
  end
  return true, autocast
end

local function configure_combat()
  local survived, survival_receipt = configure_survival()
  if not survived then return nil, survival_receipt end
  local autocast, autocast_receipt = configure_autocast()
  if not autocast then return nil, autocast_receipt end
  return true, {
    status = "complete",
    result = "jungle_demon_combat_configured",
    survival = survival_receipt,
    autocast = autocast_receipt,
  }
end

local function enter_battle()
  if areas.in_demon_room(gc.read("player").world) then return { status = "complete", result = "demon_room_already_entered" } end
  if item_queries.inventory_quantity(config.items.squad_sigil) == 0 then
    return { status = "monkey_madness_squad_sigil_not_carried" }
  end
  local configured, failure = configure_combat()
  if not configured then return failure end
  local worn = gc.await {
    action = { type = "item.interact", id = config.items.squad_sigil, action = "Wear" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if worn.status ~= "dispatched" then return worn end
  local confirmation
  for _ = 1, 20 do
    if areas.in_demon_room(gc.read("player").world) then break end
    local dialogue = gc.read("dialogue")
    if dialogue.type == "choice" then
      local yes
      for _, option in ipairs(dialogue.options or {}) do
        if option.text == "Yes" or option.text == "Yes." then
          yes = option.text
          break
        end
      end
      if not yes then
        return {
          status = "monkey_madness_sigil_confirmation_unexpected",
          dialogue = dialogue,
        }
      end
      confirmation = gc.await {
        action = { type = "dialogue.choose", text = yes, reading = false, keyboard = true },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 20 },
      }
      if confirmation.status ~= "dispatched" then return confirmation end
      break
    end
    gc.await { event = "game.tick" }
  end
  if not wait.until_true(function()
    return areas.in_demon_room(gc.read("player").world)
  end, 60) then
    return {
      status = "monkey_madness_demon_room_entry_unverified",
      receipt = worn,
      player = gc.read("player"),
    }
  end
  return {
    status = "complete",
    result = "jungle_demon_room_entered",
    receipt = worn,
    confirmation = confirmation,
  }
end

local function demon()
  return gc.read("npcs", {
    id = config.npcs.jungle_demon,
    action = "Attack",
    within = 24,
    limit = 1,
  })[1]
end

local function quest_stage()
  local vars = gc.read("vars", { varps = { config.varp } })
  return vars.varps[config.varp]
end

local function drain_continue()
  for _ = 1, 20 do
    local dialogue = gc.read("dialogue")
    if dialogue.type == "closed" then return true end
    if dialogue.type ~= "continue" then
      return nil, { status = "monkey_madness_demon_dialogue_unexpected", dialogue = dialogue }
    end
    local continued = gc.await {
      action = { type = "dialogue.continue", reading = false },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 20 },
    }
    if continued.status ~= "dispatched" and
      continued.result ~= "dialogue_continue_not_visible" then return nil, continued end
    gc.await { event = "game.tick" }
  end
  return nil, {
    status = "monkey_madness_demon_dialogue_timeout",
    dialogue = gc.read("dialogue"),
  }
end

local function await_entry_transition()
  for _ = 1, 40 do
    local dialogue = gc.read("dialogue")
    if dialogue.type ~= "closed" then return drain_continue() end
    local player = gc.read("player")
    local target = demon()
    if target and target.interacting == player.name then return true end
    gc.await { event = "game.tick" }
  end
  return nil, {
    status = "monkey_madness_battle_transition_unobserved",
    dialogue = gc.read("dialogue"),
    target = demon(),
    player = gc.read("player"),
  }
end

local function attack(target)
  local attacked = gc.await {
    action = {
      type = "npc.interact",
      id = target.id,
      action = "Attack",
      within = 24,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if attacked.status ~= "dispatched" then
    return nil, { status = "monkey_madness_jungle_demon_attack_failed", receipt = attacked }
  end
  return true, attacked
end

local function fight()
  if quest_stage() >= 6 then return { status = "complete", result = "jungle_demon_already_defeated" } end
  if not areas.in_demon_room(gc.read("player").world) then
    return { status = "monkey_madness_demon_room_not_reached", player = gc.read("player") }
  end
  gc.activity("combat")
  local survived, survival_failure = configure_survival()
  if not survived then return survival_failure end
  local drained, dialogue_failure = await_entry_transition()
  if not drained then
    return { status = "monkey_madness_demon_dialogue_failed", receipt = dialogue_failure }
  end
  local autocast, autocast_failure = configure_autocast()
  if not autocast then return autocast_failure end

  local target
  for _ = 1, 80 do
    target = demon()
    if target then break end
    gc.await { event = "game.tick" }
  end
  if not target then
    return {
      status = "monkey_madness_jungle_demon_not_observed",
      nearby = gc.read("npcs", { within = 30, limit = 60 }),
    }
  end
  if not target.line_of_sight or target.distance < 3 or target.distance > 10 then
    return {
      status = "monkey_madness_jungle_demon_spawn_position_unsafe",
      target = target,
      player = gc.read("player"),
    }
  end

  local started, attack_receipt = attack(target)
  if not started then return attack_receipt end
  local missing_ticks = 0
  for _ = 1, 1400 do
    gc.await { event = "game.tick" }
    if quest_stage() >= 6 then
      local disabled, protection_receipt = protection.disable("magic")
      if not disabled then return protection_receipt end
      local configured, behavior_receipt = behaviors.configure {
        auto_retaliate = true,
        emergency_escape = true,
      }
      if not configured then return behavior_receipt end
      return {
        status = "complete",
        result = "jungle_demon_defeated",
        receipt = attack_receipt,
        protection = protection_receipt,
        behaviors = behavior_receipt,
      }
    end
    local drained, dialogue_failure = drain_continue()
    if not drained then return { status = "monkey_madness_demon_dialogue_failed", receipt = dialogue_failure } end
    if gc.read("runtime").game_tick % 10 == 0 then
      local protected, protection_failure = protection.enable("magic", 12)
      if not protected then return protection_failure end
    end

    target = demon()
    if not target or target.dead then
      missing_ticks = missing_ticks + 1
      if missing_ticks >= 50 then
        return {
          status = "monkey_madness_demon_stage_unverified",
          varp = quest_stage(),
          messages = gc.read("messages", { limit = 30 }),
        }
      end
    else
      missing_ticks = 0
      if target.distance < 3 then
        return {
          status = "monkey_madness_jungle_demon_entered_melee_range",
          target = target,
          player = gc.read("player"),
        }
      end
      if not gc.read("player").interacting and target.line_of_sight and target.distance <= 10 then
        local resumed, resume_failure = attack(target)
        if not resumed then return resume_failure end
      end
    end
  end
  return {
    status = "monkey_madness_jungle_demon_combat_timeout",
    varp = quest_stage(),
    messages = gc.read("messages", { limit = 30 }),
  }
end

return {
  enter = enter_battle,
  fight = fight,
}
