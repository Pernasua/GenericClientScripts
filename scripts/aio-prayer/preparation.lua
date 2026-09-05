local banking = gc.require("shared_bank")
local config = gc.require("config")
local exchange = gc.require("shared_exchange")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local progress = gc.require("progress")
local travel = gc.require("shared_travel")

local function ensure_at_ge(target_level, target_xp)
  if geometry.distance(gc.read("player").world, config.ge) <= 8 then return true end
  if travel.has_dueling_ring() then
    progress.show(target_level, target_xp, "Teleporting")
    local teleported = travel.teleport_to_emirs_arena()
    if teleported.status ~= "complete" then
      return nil, { status = "prayer_ge_teleport_failed", receipt = teleported }
    end
  end
  progress.show(target_level, target_xp, "Travelling to GE")
  gc.activity("travel")
  local walked = gc.await {
    action = { type = "walk.to", destination = config.ge, within = 8, run = true },
    timeout = { game_ticks = 1200 },
  }
  if walked.status ~= "arrived" then
    return nil, { status = "prayer_ge_walk_failed", receipt = walked }
  end
  return true
end

local function buy_bones(quantity_needed, target_level, target_xp)
  progress.show(target_level, target_xp, "Withdrawing coins")
  return exchange.buy({
    {
      id = config.bone.id,
      name = config.bone.name,
      quantity = quantity_needed,
      maximum_unit_price = config.bone.maximum_unit_price,
    },
  }, {
    minimum_cash_reserve = config.minimum_cash_reserve,
    collect_mode = "bank",
    purchase_timeout_ticks = 400,
    before_purchase = function()
      progress.show(target_level, target_xp, "Buying dragon bones")
    end,
  })
end

local function prepare(required_bones, restock, target_level, target_xp)
  local reached, reach_error = ensure_at_ge(target_level, target_xp)
  if not reached then return nil, reach_error end
  local bank, bank_error = banking.open()
  if not bank then return nil, bank_error end
  local owned = item_queries.quantity(bank, config.bone.id) +
    item_queries.inventory_quantity(config.bone.id)
  local missing = math.max(0, required_bones - owned)
  if missing > 0 then
    if restock ~= "ge" then
      return nil, { status = "prayer_bones_missing", quantity = missing }
    end
    local purchased, purchase_error = buy_bones(missing, target_level, target_xp)
    if not purchased then return nil, purchase_error end
    bank, bank_error = banking.open()
    if not bank then return nil, bank_error end
    owned = item_queries.quantity(bank, config.bone.id) +
      item_queries.inventory_quantity(config.bone.id)
  end
  if owned < required_bones then
    return nil, { status = "prayer_bones_unverified", required = required_bones, owned = owned }
  end
  return true
end

return { prepare = prepare }
