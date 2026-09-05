local failure = gc.require("shared_failure")

local NPC_ID = 375

local function reward_message(since_tick)
  for _, message in ipairs(gc.read("messages", { since_tick = since_tick, limit = 20 })) do
    if string.find(string.lower(message.text or ""), "your reward is:", 1, true) then
      return message
    end
  end
  return nil
end

return {
  run = function()
    local event = gc.read("random_event")
    if not event.active or event.npc_id ~= NPC_ID then
      error("Rick Turpentine solver started without its owned event")
    end

    return gc.intent("rick_turpentine.reward", function()
      local started_tick = event.detected_tick
      local talked = false
      for _ = 1, 80 do
        local dialogue = gc.read("dialogue")
        if dialogue.type == "continue" then
          local continued = gc.await {
            action = { type = "dialogue.continue" },
            timeout = { game_ticks = 20 },
          }
          if continued.status ~= "dispatched" then
            failure.raise("rick-turpentine-failed", "dialogue_failed", { receipt = continued, dialogue = dialogue })
          end
        elseif dialogue.type == "choice" then
          failure.raise("rick-turpentine-failed", "unexpected_dialogue_choice", { dialogue = dialogue })
        else
          event = gc.read("random_event")
          local reward = reward_message(started_tick)
          if reward and not event.present then
            return { status = "solved", reward = reward, inventory = gc.read("inventory") }
          end
          if event.present and not talked then
            local receipt = gc.await {
              action = { type = "npc.interact", id = NPC_ID, action = "Talk-to", within = 12 },
              timeout = { game_ticks = 30 },
            }
            if receipt.status ~= "dispatched" then
              failure.raise("rick-turpentine-failed", "talk_failed", { receipt = receipt, event = event })
            end
            talked = true
          else
            gc.await { event = "game.tick" }
          end
        end
      end

      failure.raise("rick-turpentine-failed", "reward_not_observed", {
        event = gc.read("random_event"),
        messages = gc.read("messages", { since_tick = started_tick, limit = 20 }),
      })
    end)
  end,
}
