local bank_objects = {
  { id = 4483, action = "Use" },
}

local function interact_with_object(object, action)
  return gc.await {
    action = {
      type = "object.interact",
      id = object.id,
      action = action,
      world = object.world,
      within = 12,
    },
    activity = "banking",
    timeout = { game_ticks = 30 },
  }
end

local function click_bank()
  for _, target in ipairs(bank_objects) do
    local object = gc.read("objects", {
      id = target.id,
      action = target.action,
      within = 12,
      limit = 1,
    })[1]
    if object then
      return interact_with_object(object, target.action)
    end
  end

  local object = gc.read("objects", {
    action = "Bank",
    within = 12,
    limit = 1,
  })[1]
  if object then
    return interact_with_object(object, "Bank")
  end

  return gc.await {
    action = { type = "npc.interact", name = "Banker", action = "Bank", within = 10 },
    activity = "banking",
    timeout = { game_ticks = 30 },
  }
end

local function open()
  local bank = gc.read("bank")
  if bank and bank.open then return bank end

  return gc.intent("bank.open", function()
    local receipt = click_bank()
    if receipt.status ~= "dispatched" then
      gc.await {
        action = { type = "ui.close" },
        activity = "banking",
      }
      gc.await { ticks = 2 }
      receipt = click_bank()
    end
    if receipt.status ~= "dispatched" then
      return nil, { status = "bank_open_failed", receipt = receipt }
    end
    for _ = 1, 20 do
      gc.await { event = "game.tick" }
      bank = gc.read("bank")
      if bank and bank.open and bank.available then return bank end
    end
    return nil, { status = "bank_snapshot_unavailable", bank = bank }
  end)
end

return { open = open }
