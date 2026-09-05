local item_queries = gc.require("shared_items")
local wait = gc.require("shared_wait")
local policy = { breaks = false, cursor_release = "none", fidget = "none" }

local function equipped(id)
  return item_queries.quantity(gc.read("equipment"), id) > 0
end

local function equip(id, action, options)
  options = options or {}
  if equipped(id) then
    return { status = "unchanged", result = "item_already_equipped", item_id = id }
  end
  if item_queries.inventory_quantity(id) == 0 then
    return { status = "rejected", result = "equipment_item_not_carried", item_id = id }
  end
  local receipt = gc.await {
    action = { type = "item.interact", id = id, action = action },
    policy = options.policy or policy,
    timeout = { game_ticks = options.timeout_ticks or 30 },
  }
  if receipt.status ~= "dispatched" then
    return {
      status = "rejected",
      result = "equipment_interaction_failed",
      item_id = id,
      receipt = receipt,
    }
  end
  if not wait.until_true(function()
    return equipped(id)
  end, options.verify_ticks or 20) then
    return {
      status = "timed_out",
      result = "equipment_change_unverified",
      item_id = id,
      receipt = receipt,
    }
  end
  return { status = "complete", result = "item_equipped", item_id = id, receipt = receipt }
end

local function unequip(id, options)
  options = options or {}
  if not equipped(id) then
    return { status = "unchanged", result = "item_already_unequipped", item_id = id }
  end
  local receipt = gc.await {
    action = { type = "equipment.interact", id = id, action = "Remove" },
    policy = options.policy or policy,
    timeout = { game_ticks = options.timeout_ticks or 30 },
  }
  if receipt.status ~= "dispatched" then
    return {
      status = "rejected",
      result = "equipment_interaction_failed",
      item_id = id,
      receipt = receipt,
    }
  end
  if not wait.until_true(function()
    return not equipped(id)
  end, options.verify_ticks or 20) then
    return {
      status = "timed_out",
      result = "equipment_change_unverified",
      item_id = id,
      receipt = receipt,
    }
  end
  return { status = "complete", result = "item_unequipped", item_id = id, receipt = receipt }
end

return {
  equip = equip,
  unequip = unequip,
}
