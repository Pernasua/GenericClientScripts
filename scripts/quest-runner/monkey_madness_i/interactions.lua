local config = gc.require("monkey_madness_config")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local ui = gc.require("shared_ui")

local function choose_yes(dialogue)
  for _, option in ipairs(dialogue.options or {}) do
    if option.text == "Yes." or option.text == "Yes" then
      return gc.await {
        action = { type = "dialogue.choose", text = option.text },
        timeout = { game_ticks = 20 },
      }
    end
  end
  return { status = "monkey_madness_start_choice_missing", dialogue = dialogue }
end

local function close_chapter_message()
  return ui.close_group(config.interfaces.chapter_message, 10)
end

local function start_quest(target)
  return gc.intent("monkey_madness.start_quest", function()
    local talked = gc.await {
      action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 20 },
      timeout = { game_ticks = 40 },
    }
    if talked.status ~= "dispatched" then return talked end
    local progressed = false
    local closed_ticks = 0
    for _ = 1, 160 do
      gc.await { event = "game.tick" }
      local vars = gc.read("vars", { varps = { config.varp } })
      progressed = progressed or
        (vars.varps[config.varp] >= 1 and
          item_queries.inventory_quantity(config.items.royal_seal) > 0)
      local dialogue = gc.read("dialogue")
      if dialogue.type == "continue" then
        closed_ticks = 0
        local continued = gc.await {
          action = { type = "dialogue.continue" },
          timeout = { game_ticks = 20 },
        }
        if continued.status ~= "dispatched" then return continued end
      elseif dialogue.type == "choice" then
        closed_ticks = 0
        local chosen = choose_yes(dialogue)
        if chosen.status ~= "dispatched" then return chosen end
      elseif progressed then
        local chapter = close_chapter_message()
        if chapter.status ~= "complete" then return chapter end
        closed_ticks = closed_ticks + 1
        if closed_ticks >= 2 then
          return { status = "complete", result = "monkey_madness_started", receipt = talked }
        end
      end
    end
    return {
      status = "monkey_madness_start_unverified",
      vars = gc.read("vars", { varps = { config.varp } }),
      inventory = gc.read("inventory"),
      dialogue = gc.read("dialogue"),
    }
  end)
end

local function wait_for_dialogue(predicate, started_tick, result)
  local progressed = false
  local closed_ticks = 0
  for _ = 1, 120 do
    gc.await { event = "game.tick" }
    progressed = progressed or predicate()
    for _, message in ipairs(gc.read("messages", { since_tick = started_tick, limit = 12 })) do
      if string.find(string.lower(message.text or ""), "can't reach that", 1, true) then
        return { status = "monkey_madness_target_unreachable", message = message }
      end
    end
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      closed_ticks = 0
      local continued = gc.await {
        action = { type = "dialogue.continue" },
        timeout = { game_ticks = 20 },
      }
      if continued.status ~= "dispatched" then return continued end
    elseif dialogue.type == "choice" then
      return { status = "monkey_madness_unexpected_dialogue_choice", dialogue = dialogue }
    elseif progressed then
      closed_ticks = closed_ticks + 1
      if closed_ticks >= 2 then return { status = "complete", result = result } end
    end
  end
  return { status = result .. "_unverified", dialogue = gc.read("dialogue") }
end

local function enter_shipyard()
  local gate = gc.read("objects", {
    id = config.objects.shipyard_gate,
    action = "Open",
    within = 14,
    limit = 1,
  })[1]
  if not gate then
    return {
      status = "monkey_madness_shipyard_gate_not_observed",
      objects = gc.read("objects", { within = 14, limit = 40 }),
    }
  end
  return gc.intent("monkey_madness.enter_shipyard", function()
    local started_tick = gc.read("runtime").game_tick
    local opened = gc.await {
      action = {
        type = "object.interact",
        id = gate.id,
        action = "Open",
        world = gate.world,
        within = 14,
      },
      timeout = { game_ticks = 40 },
    }
    if opened.status ~= "dispatched" then return opened end
    local settled = wait_for_dialogue(function()
      return gc.read("dialogue").type == "closed"
    end, started_tick, "shipyard_gate_opened")
    settled.receipt = opened
    return settled
  end)
end

local function talk_caranock(target)
  return gc.intent("monkey_madness.talk_caranock", function()
    local started_tick = gc.read("runtime").game_tick
    local talked = gc.await {
      action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 20 },
      timeout = { game_ticks = 40 },
    }
    if talked.status ~= "dispatched" then return talked end
    local finished = wait_for_dialogue(function()
      local vars = gc.read("vars", { varbits = { config.varbits.caranock } })
      return vars.varbits[config.varbits.caranock] >= 3
    end, started_tick, "caranock_investigation_verified")
    finished.receipt = talked
    return finished
  end)
end

local function report_to_narnode(target)
  return gc.intent("monkey_madness.report_to_narnode", function()
    local started_tick = gc.read("runtime").game_tick
    local talked = gc.await {
      action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 20 },
      timeout = { game_ticks = 40 },
    }
    if talked.status ~= "dispatched" then return talked end
    local finished = wait_for_dialogue(function()
      local vars = gc.read("vars", { varbits = { config.varbits.narnode } })
      return vars.varbits[config.varbits.narnode] >= 7 and
        item_queries.inventory_quantity(config.items.narnodes_orders) > 0
    end, started_tick, "narnode_shipyard_report_verified")
    finished.receipt = talked
    return finished
  end)
end

local DAERO_CHOICES = {
  "Talk about the 10th squad...",
  "Who is it?",
  "Yes",
  "Leave...",
}

local function choose_daero(dialogue)
  for _, wanted in ipairs(DAERO_CHOICES) do
    for _, option in ipairs(dialogue.options or {}) do
      if option.text == wanted then
        return gc.await {
          action = { type = "dialogue.choose", text = wanted },
          timeout = { game_ticks = 20 },
        }
      end
    end
  end
  return { status = "monkey_madness_daero_choice_unexpected", dialogue = dialogue }
end

local function choose_daero_travel(dialogue, chosen)
  local vars = gc.read("vars", { varbits = { config.varbits.daero } })
  local stage = vars.varbits[config.varbits.daero]
  local choices
  if stage <= 2 then
    choices = { "Talk about the 10th squad...", "Who is it?", "Yes", "Leave..." }
  elseif stage == 3 then
    choices = {
      "How will I travel?",
      "Are you coming with me?",
      "Who is Garkor?",
      "Who is it?",
      "Talk about the 10th squad...",
      "Talk about Caranock...",
      "Talk about the journey...",
      "Yes",
      "Leave...",
    }
  else
    choices = { "Yes", "Who is it?", "Leave..." }
  end
  for _, wanted in ipairs(choices) do
    if not chosen[wanted] then
      for _, option in ipairs(dialogue.options or {}) do
        if option.text == wanted then
          chosen[wanted] = true
          return gc.await {
            action = { type = "dialogue.choose", text = wanted },
            timeout = { game_ticks = 20 },
          }
        end
      end
    end
  end
  for _, option in ipairs(dialogue.options or {}) do
    if option.text == "Return to previous menu" then
      return gc.await {
        action = { type = "dialogue.choose", text = option.text },
        timeout = { game_ticks = 20 },
      }
    end
  end
  for _, option in ipairs(dialogue.options or {}) do
    if option.text == "Leave..." then
      if not chosen[option.text] then chosen[option.text] = true end
        return gc.await {
          action = { type = "dialogue.choose", text = option.text },
          timeout = { game_ticks = 20 },
        }
    end
  end
  return {
    status = "monkey_madness_daero_travel_choice_unexpected",
    dialogue = dialogue,
    chosen = chosen,
  }
end

local function nearby_daero()
  for _, id in ipairs(config.npcs.daero) do
    local target = gc.read("npcs", { id = id, within = 30, limit = 1 })[1]
    if target then return target end
  end
  return nil
end

local function talk_daero(target)
  if item_queries.inventory_quantity(config.items.narnodes_orders) == 0 then
    return { status = "monkey_madness_narnodes_orders_missing" }
  end
  return gc.intent("monkey_madness.talk_daero", function()
    local started_tick = gc.read("runtime").game_tick
    local talked = gc.await {
      action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 24 },
      timeout = { game_ticks = 40 },
    }
    if talked.status ~= "dispatched" then return talked end
    local progressed = false
    local closed_ticks = 0
    for _ = 1, 160 do
      gc.await { event = "game.tick" }
      local vars = gc.read("vars", { varbits = { config.varbits.daero } })
      progressed = progressed or vars.varbits[config.varbits.daero] >= 1
      for _, message in ipairs(gc.read("messages", { since_tick = started_tick, limit = 12 })) do
        if string.find(string.lower(message.text or ""), "can't reach that", 1, true) then
          return { status = "monkey_madness_daero_unreachable", message = message }
        end
      end
      local dialogue = gc.read("dialogue")
      if dialogue.type == "continue" then
        closed_ticks = 0
        local continued = gc.await {
          action = { type = "dialogue.continue" },
          timeout = { game_ticks = 20 },
        }
        if continued.status ~= "dispatched" then return continued end
      elseif dialogue.type == "choice" then
        closed_ticks = 0
        local chosen = choose_daero(dialogue)
        if chosen.status ~= "dispatched" then return chosen end
      elseif progressed then
        closed_ticks = closed_ticks + 1
        if closed_ticks >= 5 then
          return { status = "complete", result = "daero_orders_delivered", receipt = talked }
        end
      end
    end
    return {
      status = "monkey_madness_daero_handoff_unverified",
      dialogue = gc.read("dialogue"),
      vars = gc.read("vars", { varbits = { config.varbits.daero } }),
    }
  end)
end

local function enter_hangar()
  return gc.intent("monkey_madness.enter_hangar", function()
    local started_tick = gc.read("runtime").game_tick
    local conversations = {}
    local chosen = {}
    local closed_ticks = 0
    local progressed = false
    local function begin_conversation()
      local target = nearby_daero()
      if not target then
        return {
          status = "monkey_madness_daero_resume_target_not_observed",
          player = gc.read("player"),
          nearby = gc.read("npcs", { within = 30, limit = 50 }),
        }
      end
      local talked = gc.await {
        action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 30 },
        timeout = { game_ticks = 40 },
      }
      conversations[#conversations + 1] = talked
      return talked
    end
    if gc.read("dialogue").type == "closed" then
      local talked = begin_conversation()
      if talked.status ~= "dispatched" then return talked end
    end
    for _ = 1, 240 do
      gc.await { event = "game.tick" }
      local vars = gc.read("vars", { varbits = { config.varbits.daero } })
      progressed = progressed or vars.varbits[config.varbits.daero] >= 5
      for _, message in ipairs(gc.read("messages", { since_tick = started_tick, limit = 12 })) do
        if string.find(string.lower(message.text or ""), "can't reach that", 1, true) then
          return { status = "monkey_madness_daero_travel_unreachable", message = message }
        end
      end
      local dialogue = gc.read("dialogue")
      if dialogue.type == "continue" then
        closed_ticks = 0
        local continued = gc.await {
          action = { type = "dialogue.continue" },
          timeout = { game_ticks = 20 },
        }
        if continued.status ~= "dispatched" then return continued end
      elseif dialogue.type == "choice" then
        closed_ticks = 0
        local selected = choose_daero_travel(dialogue, chosen)
        if selected.status ~= "dispatched" then return selected end
      else
        closed_ticks = closed_ticks + 1
        if progressed and closed_ticks >= 5 then
          return {
            status = "complete",
            result = "daero_reinitialization_started",
            conversations = conversations,
          }
        end
        if not progressed and closed_ticks >= 3 then
          local player = gc.read("player")
          local world = player and player.world
          local on_first_floor = world and world.plane == 1 and
            world.x >= config.zones.grand_tree.x1 and world.x <= config.zones.grand_tree.x2 and
            world.y >= config.zones.grand_tree.y1 and world.y <= config.zones.grand_tree.y2
          if not on_first_floor and not geometry.in_zone(world, config.zones.hangar) then
            return {
              status = "monkey_madness_daero_transition_location_unknown",
              player = player,
              conversations = conversations,
            }
          end
          if #conversations >= 4 then
            return {
              status = "monkey_madness_daero_conversation_limit",
              player = player,
              conversations = conversations,
            }
          end
          local talked = begin_conversation()
          if talked.status ~= "dispatched" then return talked end
          closed_ticks = 0
        end
      end
    end
    return {
      status = "monkey_madness_hangar_entry_unverified",
      player = gc.read("player"),
      dialogue = gc.read("dialogue"),
      vars = gc.read("vars", { varbits = { config.varbits.daero } }),
      conversations = conversations,
    }
  end)
end

local function confirm_reinitialization(target)
  return gc.intent("monkey_madness.confirm_reinitialization", function()
    local started_tick = gc.read("runtime").game_tick
    local talked = gc.await {
      action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 30 },
      timeout = { game_ticks = 40 },
    }
    if talked.status ~= "dispatched" then return talked end
    local finished = wait_for_dialogue(function()
      local vars = gc.read("vars", { varbits = { config.varbits.daero } })
      return vars.varbits[config.varbits.daero] >= 7
    end, started_tick, "daero_reinitialization_confirmed")
    finished.receipt = talked
    return finished
  end)
end

return {
  start_quest = start_quest,
  enter_shipyard = enter_shipyard,
  talk_caranock = talk_caranock,
  report_to_narnode = report_to_narnode,
  talk_daero = talk_daero,
  enter_hangar = enter_hangar,
  confirm_reinitialization = confirm_reinitialization,
}
