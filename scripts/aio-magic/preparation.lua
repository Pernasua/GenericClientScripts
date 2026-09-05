local banking = gc.require("shared_bank")
local equipment_actions = gc.require("shared_equipment")
local exchange = gc.require("shared_exchange")
local geometry = gc.require("shared_geometry")
local loadouts = gc.require("shared_loadouts")
local progress = gc.require("progress")
local travel = gc.require("shared_travel")

local GE_ROUTE = {
  { x = 3024, y = 3205, plane = 0 },
  { x = 3038, y = 3245, plane = 0 },
  { x = 3052, y = 3294, plane = 0 },
  { x = 3070, y = 3359, plane = 0 },
  { x = 3104, y = 3420, plane = 0 },
  { x = 3165, y = 3491, plane = 0 },
}

local function leave_port_sarim_cell(target)
  local player = gc.read("player")
  local door
  for _, candidate in ipairs(gc.read("objects", {
    id = 9563,
    action = "Open",
    within = 2,
    limit = 4,
  })) do
    if candidate.world.x == player.world.x and
      candidate.world.y == player.world.y and
      candidate.world.plane == player.world.plane then
      door = candidate
      break
    end
  end
  if not door then return true end

  progress.show(target, "Leaving jail cell")
  local opened = gc.await {
    action = {
      type = "object.interact",
      id = 9563,
      action = "Open",
      world = door.world,
      within = 2,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  if opened.status ~= "dispatched" then
    return nil, { status = "jail_cell_open_failed", receipt = opened }
  end
  local destination = {
    x = player.world.x - 1,
    y = player.world.y,
    plane = player.world.plane,
  }
  local crossed = gc.await {
    action = { type = "walk.click", destination = destination },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  }
  if crossed.status ~= "dispatched" then
    return nil, { status = "jail_cell_crossing_failed", receipt = crossed }
  end
  for _ = 1, 12 do
    gc.await { event = "game.tick" }
    local world = gc.read("player").world
    if world.x == destination.x and world.y == destination.y then return true end
  end
  return nil, {
    status = "jail_cell_crossing_unverified",
    destination = destination,
    player = gc.read("player"),
  }
end

local function walk_to_ge(target)
  local escaped, escape_error = leave_port_sarim_cell(target)
  if not escaped then return nil, escape_error end
  local player = gc.read("player")
  local closest = 1
  local closest_distance = 99999
  for index, waypoint in ipairs(GE_ROUTE) do
    local distance = geometry.distance(player.world, waypoint)
    if distance < closest_distance then
      closest = index
      closest_distance = distance
    end
  end
  for index = closest, #GE_ROUTE do
    local waypoint = GE_ROUTE[index]
    local within = index == #GE_ROUTE and 8 or 6
    if geometry.distance(gc.read("player").world, waypoint) > within then
      progress.show(target, "Travelling to GE")
      local walk = gc.await {
        action = { type = "walk.to", destination = waypoint, within = within },
        timeout = { game_ticks = 600 },
      }
      if walk.status ~= "arrived" then
        return nil, { status = "ge_travel_failed", waypoint = waypoint, receipt = walk }
      end
    end
  end
  return true
end

local function ensure_at_ge(target)
  local player = gc.read("player")
  local ge = { x = 3165, y = 3491, plane = 0 }
  if geometry.distance(player.world, ge) > 8 then
    progress.show(target, "Travelling to GE")
    if travel.has_wealth_ring() then
      local teleported = travel.teleport_to_grand_exchange()
      if teleported.status ~= "complete" then
        return nil, { status = "ge_teleport_failed", receipt = teleported }
      end
      player = gc.read("player")
    end
    if geometry.distance(player.world, ge) > 8 then
      return walk_to_ge(target)
    end
  end
  return true
end

local function acquire_missing(missing, target, collect_mode)
  progress.show(target, "Withdrawing coins")
  return exchange.buy(missing, {
    minimum_cash_reserve = 5000000,
    bank_timeout_ticks = 200,
    collect_mode = collect_mode,
    before_purchase = function(item)
      progress.show(target, "Buying " .. item.name)
    end,
  })
end

local function ensure_supplies(plan, restock, target, collect_mode)
  local bank, bank_error = banking.open()
  if not bank then
    return nil, bank_error
  end
  local missing = loadouts.missing({
    bank = bank,
    inventory = gc.read("inventory"),
    equipment = gc.read("equipment"),
  }, plan)
  if #missing > 0 then
    if restock ~= "ge" then
      return nil, { status = "supplies_missing", items = missing }
    end
    local acquired, acquire_error = acquire_missing(missing, target, collect_mode)
    if not acquired then
      return nil, acquire_error
    end
    bank, bank_error = banking.open()
    if not bank then
      return nil, bank_error
    end
  end

  return true, bank
end

local function prepare_loadout(plan, restock, target)
  local prepared, bank_or_error = ensure_supplies(plan, restock, target)
  if not prepared then
    return nil, bank_or_error
  end

  local items = {}
  for _, item in ipairs(plan) do
    table.insert(items, { id = item.id, quantity = item.quantity })
  end
  progress.show(target, "Preparing loadout")
  local loadout = gc.await {
    action = {
      type = "bank.loadout",
      items = items,
      minimum_free_slots = 16,
      close = true,
    },
    timeout = { game_ticks = 240 },
  }
  if loadout.status ~= "complete" then
    return nil, { status = "training_loadout_failed", receipt = loadout }
  end
  return true
end

local function equip_staff(id, target, name)
  progress.show(target, "Equipping " .. name)
  local receipt = equipment_actions.equip(
    id,
    "Wield",
    { policy = {}, timeout_ticks = 20, verify_ticks = 2 })
  if receipt.status ~= "complete" and receipt.status ~= "unchanged" then
    return nil, receipt
  end
  return true, receipt
end

return {
  ensure_at_ge = ensure_at_ge,
  ensure_supplies = ensure_supplies,
  prepare_loadout = prepare_loadout,
  equip_staff = equip_staff,
}
