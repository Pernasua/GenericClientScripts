local NPC_ID = 326
local LAMP_ID = 2528

local function inventory_quantity(id)
  local total = 0
  for _, item in ipairs(gc.read("inventory").items or {}) do
    if item.id == id then total = total + item.quantity end
  end
  return total
end

local function reward_message(since_tick)
  for _, message in ipairs(gc.read("messages", { since_tick = since_tick, limit = 20 })) do
    local text = string.lower(message.text or "")
    if string.find(text, "your reward is:", 1, true) and
      string.find(text, "lamp", 1, true) then
      return message
    end
  end
  return nil
end

return {
  run = function()
    local event = gc.read("random_event")
    if not event.active or event.npc_id ~= NPC_ID then
      error("Genie solver started without its owned event")
    end

    return gc.intent("genie.reward", function()
      local started_tick = event.detected_tick
      local starting_lamps = inventory_quantity(LAMP_ID)
      local talked = false
      for _ = 1, 80 do
        local dialogue = gc.read("dialogue")
        if dialogue.type == "continue" then
          local continued = gc.await {
            action = { type = "dialogue.continue" },
            timeout = { game_ticks = 20 },
          }
          if continued.status ~= "dispatched" then
            error("Genie dialogue failed: " .. tostring(continued.result), 0)
          end
        elseif dialogue.type == "choice" then
          error("Genie presented an unexpected dialogue choice", 0)
        else
          event = gc.read("random_event")
          local reward = reward_message(started_tick)
          local lamps = inventory_quantity(LAMP_ID)
          if reward and lamps > starting_lamps and not event.present then
            return {
              status = "solved",
              reward = reward,
              lamp_id = LAMP_ID,
              lamp_quantity = lamps,
            }
          end
          if event.present and not talked then
            local receipt = gc.await {
              action = {
                type = "npc.interact",
                id = NPC_ID,
                action = "Talk-to",
                within = 12,
              },
              timeout = { game_ticks = 30 },
            }
            if receipt.status ~= "dispatched" then
              error("Genie talk failed: " .. tostring(receipt.result), 0)
            end
            talked = true
          else
            gc.await { event = "game.tick" }
          end
        end
      end

      error("Genie reward was not observed", 0)
    end)
  end,
}
