local forced_heal_percent = 30

local function active_attackers(player)
  local attackers = {}
  for _, npc in ipairs(gc.read("npcs", { within = 16, limit = 40 })) do
    if npc.interacting == player.name then attackers[#attackers + 1] = npc end
  end
  return attackers
end

local function emergency_hitpoints(player)
  return player.current_hitpoints > 0 and player.max_hitpoints > 0 and
    player.current_hitpoints * 100 < player.max_hitpoints * forced_heal_percent
end

local function has_action(item, expected)
  for _, action in ipairs(item.actions or {}) do
    if action == expected then return true end
  end
  return false
end

local function eat_available_food()
  for _, item in ipairs((gc.read("inventory") or {}).items or {}) do
    if has_action(item, "Eat") then
      local receipt = gc.await {
        action = { type = "item.interact", id = item.id, action = "Eat" },
        timeout = { game_ticks = 6 },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
      }
      if receipt.status == "dispatched" or receipt.status == "complete" then
        return receipt
      end
    end
  end
  return { status = "rejected", result = "no_edible_inventory_item" }
end

local function completed_escape(receipt)
  return receipt.result == "emergency_escape_complete" or
    receipt.result == "emergency_food_and_escape_complete"
end

return {
  run = function()
    gc.activity("manual")
    gc.state("attention_required")
    while true do
      local player = gc.read("player")
      local attackers = active_attackers(player)

      if #attackers > 0 and emergency_hitpoints(player) then
        gc.state("recovering_active_combat")
        gc.overlay {
          { label = "Safety Net", value = "Recovering from active combat" },
          { label = "Attacker", value = attackers[1].name or tostring(attackers[1].id) },
          { label = "HP", value = player.current_hitpoints .. "/" .. player.max_hitpoints },
        }

        local recovered = gc.await {
          action = { type = "safety.recover" },
          timeout = { game_ticks = 6 },
          policy = { breaks = false, cursor_release = "none", fidget = "none" },
        }
        if completed_escape(recovered) then
          return {
            status = "complete",
            result = "safety_net_active_combat_escape",
            recovery_attempted = true,
            recovery_completed = true,
            receipt = recovered,
          }
        end

        local controller_handled_food = recovered.result == "emergency_consumable_dispatched" or
          recovered.result == "safety_recovery_already_running"
        if not controller_handled_food then eat_available_food() end
      end

      gc.state("attention_required")
      gc.overlay {
        {
          label = "Safety Net",
          value = "Awaiting manual control after script failure",
        },
        {
          label = "HP",
          value = player.current_hitpoints .. "/" .. player.max_hitpoints,
        },
      }
      gc.await { event = "game.tick" }
    end
  end,
}
