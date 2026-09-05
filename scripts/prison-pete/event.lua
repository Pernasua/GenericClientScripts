local failure = gc.require("shared_failure")
local item_queries = gc.require("shared_items")

local INVITATION_NPC_ID = 6754
local PRISON_PETE_NPC_ID = 368
local LEVER_ID = 24296
local KEY_ITEM_ID = 6966
local TARGET_WIDGET_ID = 17891332
local CLOSE_WIDGET_ID = 17891333
local EXIT_APPROACH = { x = 2096, y = 4466, plane = 0 }
local EXIT_TILE = { x = 2101, y = 4466, plane = 0 }

local BALLOON_IDS_BY_MODEL = {
  [10749] = { 369, 5493 },
  [10750] = { 371, 5489 },
  [11028] = { 370, 5488 },
  [11034] = { 5491, 5492 },
}

local function on_prison(world)
  return world and world.plane == 0 and
    world.x >= 2070 and world.x <= 2120 and
    world.y >= 4440 and world.y <= 4490
end

local function wait_for(predicate, ticks)
  for _ = 1, ticks do
    local value = predicate()
    if value then return value end
    gc.await { event = "game.tick" }
  end
  return predicate()
end

local function continue_dialogue()
  local receipt = gc.await {
    action = { type = "dialogue.continue" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  if receipt.status ~= "dispatched" then
    failure.raise("prison-pete-failed", "prison_pete_continue_failed", { receipt = receipt })
  end
  return receipt
end

local function choose(text)
  local receipt = gc.await {
    action = { type = "dialogue.choose", text = text },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  return receipt
end

local function dialogue_has(dialogue, text)
  for _, option in ipairs(dialogue.options or {}) do
    if option.text == text then return true end
  end
  return false
end

local function drain_dialogue(ticks)
  local seen = {}
  local opened = false
  local closed_ticks = 0
  for _ = 1, ticks do
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      opened = true
      closed_ticks = 0
      seen[#seen + 1] = { speaker = dialogue.speaker, text = dialogue.text }
      continue_dialogue()
      gc.await { event = "game.tick" }
    elseif dialogue.type == "choice" and dialogue_has(dialogue, "Okay.") then
      opened = true
      closed_ticks = 0
      local receipt = choose("Okay.")
      if receipt.status ~= "dispatched" and not on_prison(gc.read("player").world) then
        failure.raise("prison-pete-failed", "prison_pete_intro_choice_failed", {
          receipt = receipt,
          dialogue = dialogue,
        })
      end
      gc.await { event = "game.tick" }
    elseif dialogue.type == "choice" then
      return seen, dialogue
    elseif opened then
      closed_ticks = closed_ticks + 1
      if closed_ticks >= 3 then return seen end
      gc.await { event = "game.tick" }
    else
      return seen
    end
  end
  return seen, gc.read("dialogue")
end

local function enter_prison()
  if on_prison(gc.read("player").world) then return end

  local talked = gc.await {
    action = {
      type = "npc.interact",
      id = INVITATION_NPC_ID,
      action = "Talk-to",
      within = 12,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if talked.status ~= "dispatched" then
    failure.raise("prison-pete-failed", "prison_pete_invitation_talk_failed", {
      receipt = talked,
      event = gc.read("random_event"),
    })
  end

  for _ = 1, 100 do
    if on_prison(gc.read("player").world) then return end
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      continue_dialogue()
    elseif dialogue.type == "choice" and
      dialogue_has(dialogue, "Yes, that seems like a good idea.") then
      local receipt = choose("Yes, that seems like a good idea.")
      if receipt.status ~= "dispatched" and not on_prison(gc.read("player").world) then
        failure.raise("prison-pete-failed", "prison_pete_invitation_choice_failed", {
          receipt = receipt,
          dialogue = dialogue,
        })
      end
    end
    gc.await { event = "game.tick" }
  end
  failure.raise("prison-pete-failed", "prison_pete_arrival_not_observed", {
    player = gc.read("player"),
    dialogue = gc.read("dialogue"),
  })
end

local function lever()
  return gc.read("objects", { id = LEVER_ID, action = "Pull", within = 32, limit = 1 })[1]
end

local function target_model()
  local rows = gc.read("widgets", { ids = { TARGET_WIDGET_ID }, limit = 2 })
  return rows[1] and rows[1].model_id or nil
end

local function pull_for_target()
  for _ = 1, 3 do
    local found = lever()
    if not found then
      failure.raise("prison-pete-failed", "prison_pete_lever_not_observed", {
        player = gc.read("player"),
      })
    end
    local pulled = gc.await {
      action = {
        type = "object.interact",
        id = LEVER_ID,
        action = "Pull",
        world = found.world,
        within = 32,
      },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 30 },
    }
    if pulled.status ~= "dispatched" then
      failure.raise("prison-pete-failed", "prison_pete_lever_failed", { receipt = pulled })
    end

    local model = wait_for(function()
      local value = target_model()
      if value then return value end
      if gc.read("dialogue").type ~= "closed" then return "dialogue" end
    end, 20)
    if model ~= "dialogue" and model then return model end
    drain_dialogue(50)
  end
  failure.raise("prison-pete-failed", "prison_pete_target_not_observed", {
    widgets = gc.read("widgets", { ids = { TARGET_WIDGET_ID }, limit = 2 }),
  })
end

local function close_target()
  local receipt = gc.await {
    action = { type = "ui.click", widget_id = CLOSE_WIDGET_ID },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  if receipt.status ~= "dispatched" then
    failure.raise("prison-pete-failed", "prison_pete_target_close_failed", { receipt = receipt })
  end
end

local function balloon_for_model(model)
  local ids = BALLOON_IDS_BY_MODEL[model]
  if not ids then return nil end
  for _, id in ipairs(ids) do
    local candidates = gc.read("npcs", {
      id = id,
      action = "Pop",
      within = 32,
      limit = 20,
    })
    for _, npc in ipairs(candidates) do
      if npc.clickable and npc.in_scene and not npc.dead then return npc end
    end
  end
  return nil
end

local function pop_target(model)
  close_target()
  local balloon = balloon_for_model(model)
  if not balloon then
    failure.raise("prison-pete-failed", "prison_pete_balloon_not_observed", {
      model_id = model,
      expected_ids = BALLOON_IDS_BY_MODEL[model],
    })
  end
  local popped = gc.await {
    action = { type = "npc.interact", id = balloon.id, action = "Pop", within = 32 },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if popped.status ~= "dispatched" then
    failure.raise("prison-pete-failed", "prison_pete_balloon_pop_failed", {
      model_id = model,
      balloon = balloon,
      receipt = popped,
    })
  end
  if not wait_for(function()
    return item_queries.inventory_quantity(KEY_ITEM_ID) > 0
  end, 35) then
    failure.raise("prison-pete-failed", "prison_pete_key_not_obtained", {
      model_id = model,
      receipt = popped,
      inventory = gc.read("inventory"),
    })
  end
  drain_dialogue(40)
end

local function message_contains(fragment, since_tick)
  for _, message in ipairs(gc.read("messages", { since_tick = since_tick, limit = 60 })) do
    if string.find(string.lower(message.text or ""), fragment, 1, true) then
      return message
    end
  end
  return nil
end

local function return_key()
  local returned_tick = gc.read("runtime").game_tick
  local receipt = gc.await {
    action = { type = "item.interact", id = KEY_ITEM_ID, action = "Return" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 30 },
  }
  if receipt.status ~= "dispatched" then
    failure.raise("prison-pete-failed", "prison_pete_key_return_failed", { receipt = receipt })
  end

  local result = wait_for(function()
    local complete = message_contains("got all the keys right", returned_tick)
    if complete then return { status = "complete", message = complete } end
    local right = message_contains("you got the right one", returned_tick)
    if right then return { status = "right", message = right } end
    local wrong = message_contains("that was the wrong key", returned_tick)
    if wrong then return { status = "wrong", message = wrong } end
  end, 60)
  drain_dialogue(60)
  if not result then
    failure.raise("prison-pete-failed", "prison_pete_key_result_not_observed", {
      receipt = receipt,
      messages = gc.read("messages", { since_tick = returned_tick, limit = 60 }),
    })
  end
  return result
end

local function leave_prison(started_tick)
  if not on_prison(gc.read("player").world) then return end
  local approach = gc.await {
    action = { type = "walk.to", destination = EXIT_APPROACH, within = 1 },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 80 },
  }
  if approach.status ~= "arrived" then
    failure.raise("prison-pete-failed", "prison_pete_exit_approach_failed", {
      receipt = approach,
    })
  end
  local exit = gc.await {
    action = { type = "walk.click", destination = EXIT_TILE },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  }
  if exit.status ~= "dispatched" then
    failure.raise("prison-pete-failed", "prison_pete_exit_click_failed", { receipt = exit })
  end
  if not wait_for(function()
    return not on_prison(gc.read("player").world)
  end, 80) then
    failure.raise("prison-pete-failed", "prison_pete_exit_not_observed", {
      receipt = exit,
      player = gc.read("player"),
    })
  end
  drain_dialogue(80)
  local reward = message_contains("your reward is:", started_tick)
  if not reward then
    failure.raise("prison-pete-failed", "prison_pete_reward_not_observed", {
      messages = gc.read("messages", { since_tick = started_tick, limit = 60 }),
    })
  end
  return reward
end

local function solve(started_tick)
  started_tick = started_tick or gc.read("runtime").game_tick
  enter_prison()
  drain_dialogue(160)

  local attempts = {}
  for _ = 1, 8 do
    if message_contains("got all the keys right", started_tick) then break end
    if item_queries.inventory_quantity(KEY_ITEM_ID) == 0 then
      local model = pull_for_target()
      if not BALLOON_IDS_BY_MODEL[model] then
        failure.raise("prison-pete-failed", "prison_pete_unknown_target_model", {
          model_id = model,
        })
      end
      pop_target(model)
      attempts[#attempts + 1] = { model_id = model }
    elseif #attempts == 0 then
      attempts[#attempts + 1] = { model_id = "carried" }
    end
    local result = return_key()
    attempts[#attempts].result = result.status
    if result.status == "complete" then break end
  end

  if not message_contains("got all the keys right", started_tick) then
    failure.raise("prison-pete-failed", "prison_pete_attempt_limit", { attempts = attempts })
  end
  local reward = leave_prison(started_tick)
  return {
    status = "solved",
    attempts = attempts,
    reward = reward,
    player = gc.read("player"),
  }
end

return {
  invitation_npc_id = INVITATION_NPC_ID,
  balloon_ids_for_model = function(model) return BALLOON_IDS_BY_MODEL[model] end,
  on_prison = on_prison,
  solve = solve,
}
