local config = gc.require("monkey_madness_config")
local geometry = gc.require("shared_geometry")
local movement = gc.require("shared_movement")
local navigation = gc.require("monkey_madness_navigation")
local preparation = gc.require("monkey_madness_preparation")

local function npc(ids, within)
  for _, id in ipairs(ids) do
    local target = gc.read("npcs", { id = id, within = within or 24, limit = 1 })[1]
    if target then return target end
  end
  return nil
end

local function lumdo_stage()
  local vars = gc.read("vars", { varbits = { config.varbits.lumdo } })
  return vars.varbits[config.varbits.lumdo]
end

local function choose(dialogue, wanted)
  for _, option in ipairs(dialogue.options or {}) do
    if option.text == wanted or option.text == wanted .. "." then
      return gc.await {
        action = { type = "dialogue.choose", text = option.text },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 30 },
      }
    end
  end
  return nil
end

local function dialogue_has_option(dialogue, wanted)
  if dialogue.type ~= "choice" then return false end
  for _, option in ipairs(dialogue.options or {}) do
    if option.text == wanted or option.text == wanted .. "." then return true end
  end
  return false
end

local function conversation(target, completed, result, wanted_choice, ticks, policy)
  local initial_dialogue = gc.read("dialogue")
  local talked = { status = "dispatched", result = "existing_dialogue" }
  local target_talk_dispatched = false
  if initial_dialogue.type == "closed" then
    talked = gc.await {
      action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 24 },
      policy = policy,
      timeout = { game_ticks = 40 },
    }
    if talked.status ~= "dispatched" then return nil, talked end
    target_talk_dispatched = true
  end
  local opened = initial_dialogue.type ~= "closed"
  local closed_ticks = 0
  local progressed = false
  for _ = 1, ticks or 160 do
    gc.await { event = "game.tick" }
    progressed = progressed or completed()
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
        continued.result ~= "dialogue_is_choice" and
        continued.result ~= "dialogue_continue_not_visible" then
        return nil, continued
      end
    elseif dialogue.type == "choice" then
      opened = true
      closed_ticks = 0
      local selected = wanted_choice and choose(dialogue, wanted_choice) or nil
      if not selected then
        return nil, {
          status = "monkey_madness_unexpected_dialogue_choice",
          wanted = wanted_choice,
          dialogue = dialogue,
        }
      end
      if selected.status ~= "dispatched" then
        gc.await { event = "game.tick" }
      end
      if selected.status ~= "dispatched" and
        dialogue_has_option(gc.read("dialogue"), wanted_choice) then
        return nil, selected
      end
    elseif opened then
      closed_ticks = closed_ticks + 1
      if progressed and closed_ticks >= 2 then
        return { status = "complete", result = result, receipt = talked }
      end
      if not progressed and closed_ticks >= 20 then
        if not target_talk_dispatched then
          talked = gc.await {
            action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 24 },
            timeout = { game_ticks = 40 },
          }
          if talked.status ~= "dispatched" then return nil, talked end
          target_talk_dispatched = true
          opened = false
          closed_ticks = 0
        else
          return nil, {
            status = "monkey_madness_conversation_closed_without_progress",
            result = result,
            receipt = talked,
          }
        end
      end
    end
  end
  return nil, {
    status = "monkey_madness_conversation_timeout",
    result = result,
    dialogue = gc.read("dialogue"),
  }
end

local function talk_lumdo_initial(policy)
  if lumdo_stage() >= 2 then
    return { status = "complete", result = "lumdo_initial_already_complete" }
  end
  local target = npc(config.npcs.lumdo, 24)
  if not target then
    return { status = "monkey_madness_lumdo_not_observed" }
  end
  local completed, failure = conversation(
    target,
    function() return lumdo_stage() >= 2 end,
    "lumdo_refusal_complete",
    nil,
    240,
    policy)
  return completed or failure
end

local function ask_waydar_to_intervene(policy)
  if lumdo_stage() >= 3 then
    return { status = "complete", result = "waydar_intervention_already_complete" }
  end
  local last_failure
  for _ = 1, 3 do
    local target = npc(config.npcs.waydar, 24)
    if not target then
      return { status = "monkey_madness_crash_waydar_not_observed" }
    end
    local completed, failure = conversation(
      target,
      function() return lumdo_stage() >= 3 end,
      "waydar_intervention_complete",
      "I cannot convince Lumdo to take us to the island...",
      120,
      policy)
    if completed then return completed end
    last_failure = failure
    if failure.status ~= "monkey_madness_conversation_closed_without_progress" then
      return failure
    end
  end
  return last_failure or { status = "monkey_madness_waydar_intervention_unverified" }
end

local function sail_to_ape_atoll(policy)
  local continuation
  while true do
    local cured = gc.await {
      action = { type = "consumable.cure_poison" },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
    }
    if cured.status ~= "complete" and cured.status ~= "unchanged" then return cured end
    local reached = movement.walk(config.points.ape_atoll_landing, 1, {
      ticks = 300,
      policy = policy,
      interrupt_on = { dialogue = true, poisoned = true },
      resume = continuation,
    })
    if reached.status == "arrived" then
      return { status = "complete", result = "ape_atoll_reached", receipt = reached }
    end
    if reached.status ~= "interrupted" or reached.reason ~= "poisoned" or not reached.continuation then
      return reached
    end
    continuation = reached.continuation
  end
end

local function execute(options)
  options = options or {}
  local policy = options.policy
  local armed, safety_error = preparation.arm_safety()
  if not armed then return safety_error end
  if geometry.in_zone(gc.read("player").world, config.zones.ape_atoll_south) then
    return { status = "complete", result = "ape_atoll_already_reached" }
  end
  if not geometry.in_zone(gc.read("player").world, config.zones.crash_island) then
    if not geometry.in_zone(gc.read("player").world, config.zones.post_puzzle_hangar) then
      local stronghold = navigation.travel_to_gnome_stronghold(options)
      if stronghold.status ~= "complete" then return stronghold end
      gc.activity("travel")
      local hangar = movement.walk(config.points.post_puzzle_landing, 1, {
        ticks = 600,
        policy = policy,
        interrupt_on = { dialogue = true },
      })
      if hangar.status ~= "arrived" then return hangar end
    end
    local crash = movement.walk(config.points.crash_island_landing, 1, {
      ticks = 300,
      policy = policy,
      interrupt_on = { dialogue = true },
    })
    if crash.status ~= "arrived" then return crash end
  end
  local initial = talk_lumdo_initial(policy)
  if initial.status ~= "complete" then return initial end
  local intervention = ask_waydar_to_intervene(policy)
  if intervention.status ~= "complete" then return intervention end
  return sail_to_ape_atoll(policy)
end

return {
  execute = execute,
}
