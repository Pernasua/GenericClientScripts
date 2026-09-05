local movement = gc.require("shared_movement")
local banking = gc.require("shared_bank")
local config = gc.require("config")
local geometry = gc.require("shared_geometry")

local bakery = config.bakery

local function closest_to(objects, point)
  local closest = nil
  local distance = math.huge
  for _, object in ipairs(objects) do
    local candidate = geometry.distance(object.world, point)
    if candidate < distance then
      closest = object
      distance = candidate
    end
  end
  return closest
end

local function resolve_stall(within)
  return closest_to(gc.read("objects", {
    id = bakery.stall_id,
    action = bakery.action,
    within = within or 15,
    limit = 4,
  }), bakery.arrival)
end

local function resolve_baker(stall)
  local bakers = gc.read("npcs", {
    where = { name = bakery.baker_name },
    within = 15,
    limit = 10,
  })
  return closest_to(bakers, stall.world)
end

local function ensure_market()
  local player = gc.read("player")
  if not geometry.in_zone(player.world, bakery.zone) then
    gc.activity("travel")
    local receipt = movement.walk(bakery.arrival, 5, { ticks = 2400 })
    if receipt.status ~= "arrived" then
      return nil, { status = "bakery_travel_failed", receipt = receipt }
    end
  end
  local stall = resolve_stall(15)
  if not stall then
    return nil, {
      status = "bakery_stall_not_observed",
      player = gc.read("player"),
      stall_id = bakery.stall_id,
    }
  end
  return stall
end

local function position_safely()
  local stall, failure = ensure_market()
  if not stall then return nil, failure end
  local baker = resolve_baker(stall)
  if not baker then
    return nil, {
      status = "bakery_baker_not_observed",
      player = gc.read("player"),
      stall = stall,
    }
  end
  if geometry.distance(gc.read("player").world, baker.world) > 0 then
    local receipt = movement.walk(baker.world, 0, { ticks = 180 })
    if receipt.status ~= "arrived" then
      return nil, { status = "bakery_safe_tile_failed", baker = baker, receipt = receipt }
    end
  end
  stall = resolve_stall(4)
  if not stall then
    return nil, {
      status = "bakery_safe_stall_not_observed",
      player = gc.read("player"),
      baker = baker,
    }
  end
  return stall
end

local function bank_all()
  gc.activity("travel")
  if geometry.distance(gc.read("player").world, bakery.bank) > bakery.bank_within then
    local receipt = movement.walk(bakery.bank, bakery.bank_within, { ticks = 300 })
    if receipt.status ~= "arrived" then
      return nil, { status = "bakery_bank_travel_failed", receipt = receipt }
    end
  end
  local bank, bank_error = banking.open()
  if not bank then return nil, bank_error end
  local receipt = gc.await {
    action = {
      type = "bank.loadout",
      items = {},
      minimum_free_slots = 28,
      close = true,
    },
    activity = "banking",
    timeout = { game_ticks = 240 },
  }
  if receipt.status ~= "complete" then
    return nil, { status = "bakery_bank_deposit_failed", receipt = receipt }
  end
  return receipt
end

return {
  bank_all = bank_all,
  ensure_market = ensure_market,
  position_safely = position_safely,
  resolve_stall = resolve_stall,
}
