local movement = gc.require("shared_movement")
local banking = gc.require("shared_bank")
local exchange = gc.require("shared_exchange")
local state_api = gc.require("shared_state")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local loadouts = gc.require("shared_loadouts")
local travel = gc.require("shared_travel")
local witch_config = gc.require("witch_config")
local waterfall_config = gc.require("waterfall_config")
local tree_gnome_config = gc.require("tree_gnome_config")
local fight_arena_config = gc.require("fight_arena_config")
local grand_tree_config = gc.require("grand_tree_config")
local monkey_madness_config = gc.require("monkey_madness_config")

local configs = {
  witchs_house = witch_config,
  waterfall = waterfall_config,
  tree_gnome_village = tree_gnome_config,
  fight_arena = fight_arena_config,
  the_grand_tree = grand_tree_config,
  monkey_madness_i = monkey_madness_config,
}

local ge = { x = 3165, y = 3491, plane = 0 }
local maximum_local_walk_distance = 120
local al_kharid_bank = { x = 3269, y = 3167, plane = 0 }
local walking_banks = {
  { x = 2443, y = 3083, plane = 0 },
  { x = 2946, y = 3368, plane = 0 },
  { x = 3094, y = 3492, plane = 0 },
  { x = 3092, y = 3245, plane = 0 },
  ge,
}

local function overlay(quest, phase)
  gc.overlay {
    { label = "Quest", value = configs[quest].label },
    { label = "Phase", value = phase:gsub("_", " ") },
    { label = "State", value = "Observed" },
  }
end

local function in_lumbridge_staging(world)
  return world and world.plane == 0 and
    world.x >= 3080 and world.x <= 3260 and
    world.y >= 3180 and world.y <= 3280
end

local function home_to_lumbridge(quest)
  if in_lumbridge_staging(gc.read("player").world) then
    return true, { status = "complete", result = "already_in_lumbridge_staging" }
  end
  overlay(quest, "home_teleport")
  local receipt = gc.await {
    action = { type = "travel.home_teleport" },
    timeout = { game_ticks = 80 },
  }
  if receipt.status ~= "complete" then
    return nil, { status = "safe_transport_required", receipt = receipt }
  end
  return true, receipt
end

local function in_al_kharid(world)
  return world and world.plane == 0 and
    world.x >= 3268 and world.x <= 3400 and
    world.y >= 3100 and world.y <= 3375
end

local function nearest_walking_bank(player)
  if in_al_kharid(player) then
    return al_kharid_bank, geometry.distance(player, al_kharid_bank)
  end
  local nearest = walking_banks[1]
  local nearest_distance = geometry.distance(player, nearest)
  for index = 2, #walking_banks do
    local candidate_distance = geometry.distance(player, walking_banks[index])
    if candidate_distance < nearest_distance then
      nearest = walking_banks[index]
      nearest_distance = candidate_distance
    end
  end
  return nearest, nearest_distance
end

local function ensure_at_ge(quest)
  local player = gc.read("player").world
  if geometry.distance(player, ge) <= 8 then
    return true
  end
  if not in_al_kharid(player) then
    if travel.has_wealth_ring() then
      overlay(quest, "teleport_to_ge")
      local teleported = travel.teleport_to_grand_exchange()
      if teleported.status ~= "complete" then
        return nil, { status = "ge_transport_failed", receipt = teleported }
      end
    elseif travel.has_necklace() then
      overlay(quest, "teleport_to_burthorpe")
      local teleported = travel.teleport_to_burthorpe()
      if teleported.status ~= "complete" then
        return nil, { status = "ge_transport_failed", receipt = teleported }
      end
    elseif travel.has_dueling_ring() then
      overlay(quest, "teleport_emirs_arena")
      local teleported = travel.teleport_to_emirs_arena()
      if teleported.status ~= "complete" then
        return nil, { status = "ge_transport_failed", receipt = teleported }
      end
    elseif geometry.distance(gc.read("player").world, ge) > maximum_local_walk_distance then
      local teleported, teleport_error = home_to_lumbridge(quest)
      if not teleported then return nil, teleport_error end
    end
  end
  overlay(quest, "travel_to_ge")
  local receipt = movement.walk(ge, 8, { ticks = 900 })
  if receipt.status ~= "arrived" then
    return nil, { status = "ge_travel_failed", receipt = receipt }
  end
  return true
end

local function ensure_at_bank(quest)
  local player = gc.read("player").world
  local nearest, nearest_distance = nearest_walking_bank(player)
  if nearest_distance <= 1 then return true end
  if nearest_distance > maximum_local_walk_distance and travel.has_wealth_ring() then
    overlay(quest, "teleport_to_ge")
    local teleported = travel.teleport_to_grand_exchange()
    if teleported.status ~= "complete" then
      return nil, { status = "bank_transport_failed", receipt = teleported }
    end
    player = gc.read("player").world
    nearest, nearest_distance = nearest_walking_bank(player)
  elseif nearest_distance > maximum_local_walk_distance and travel.has_dueling_ring() then
    overlay(quest, "teleport_emirs_arena")
    local teleported = travel.teleport_to_emirs_arena()
    if teleported.status ~= "complete" then
      return nil, { status = "bank_transport_failed", receipt = teleported }
    end
    player = gc.read("player").world
    nearest, nearest_distance = nearest_walking_bank(player)
  elseif nearest_distance > maximum_local_walk_distance and not travel.has_necklace() then
    local teleported, teleport_error = home_to_lumbridge(quest)
    if not teleported then return nil, teleport_error end
    player = gc.read("player").world
    nearest, nearest_distance = nearest_walking_bank(player)
  end
  overlay(quest, "travel_to_bank")
  local receipt = movement.walk(nearest, 1, { ticks = 900 })
  if receipt.status ~= "arrived" then
    return nil, { status = "bank_travel_failed", receipt = receipt }
  end
  return true
end

local function acquire_missing(missing, quest)
  overlay(quest, "withdraw_coins")
  return exchange.buy(missing, {
    minimum_cash_reserve = 5000000,
    bank_timeout_ticks = 200,
    before_purchase = function(item)
      overlay(quest, "buy_" .. item.name:lower():gsub("[^a-z0-9]+", "_"))
    end,
  })
end

local function prepare_items(quest, restock, loadout, exact, minimum_free_slots)
  minimum_free_slots = minimum_free_slots or 4
  local state = state_api.read(quest)
  if #loadouts.missing_carried(state, loadout) == 0 and
    (not exact or loadouts.matches_carried(state, loadout)) then
    return true
  end
  local missing = loadouts.missing(state, loadout)
  local ge_required = restock == "ge" and
    (not state.bank.available or #missing > 0)
  local at_destination, travel_error
  if ge_required then
    at_destination, travel_error = ensure_at_ge(quest)
  else
    at_destination, travel_error = ensure_at_bank(quest)
  end
  if not at_destination then
    return nil, travel_error
  end
  local bank, bank_error = banking.open()
  if not bank then
    return nil, bank_error
  end
  state = state_api.read(quest)
  missing = loadouts.missing(state, loadout)
  if #missing > 0 then
    if restock ~= "ge" then
      return nil, { status = "supplies_missing", items = missing }
    end
    if geometry.distance(gc.read("player").world, ge) > 8 then
      local closed = gc.await {
        action = { type = "ui.close" },
        activity = "banking",
      }
      if closed.status ~= "dispatched" and closed.status ~= "complete" then
        return nil, { status = "bank_close_failed", receipt = closed }
      end
      local at_ge, ge_error = ensure_at_ge(quest)
      if not at_ge then return nil, ge_error end
      bank, bank_error = banking.open()
      if not bank then return nil, bank_error end
      state = state_api.read(quest)
      missing = loadouts.missing(state, loadout)
    end
    if #missing > 0 then
      local acquired, acquire_error = acquire_missing(missing, quest)
      if not acquired then
        return nil, acquire_error
      end
      bank, bank_error = banking.open()
      if not bank then
        return nil, bank_error
      end
      state = state_api.read(quest)
    end
  end

  local items = {}
  for _, item in ipairs(loadout) do
    local remaining = item.quantity
    local candidate_ids = { item.id }
    for _, alternative_id in ipairs(item.alternative_ids or {}) do
      candidate_ids[#candidate_ids + 1] = alternative_id
    end
    for _, candidate_id in ipairs(candidate_ids) do
      local quantity = math.min(remaining, item_queries.total_owned(state, candidate_id))
      if quantity > 0 then
        items[#items + 1] = { id = candidate_id, quantity = quantity }
        remaining = remaining - quantity
      end
      if remaining == 0 then break end
    end
    if remaining > 0 then
      return nil, {
        status = "quest_loadout_inventory_changed",
        item = item,
        missing_quantity = remaining,
      }
    end
  end
  overlay(quest, "prepare_loadout")
  local receipt = gc.await {
    action = {
      type = "bank.loadout",
      items = items,
      minimum_free_slots = minimum_free_slots,
      close = true,
    },
    timeout = { game_ticks = 240 },
  }
  if receipt.status ~= "complete" then
    return nil, { status = "quest_loadout_failed", receipt = receipt }
  end
  state = state_api.read(quest)
  if #loadouts.missing_carried(state, loadout) > 0 or
    (exact and not loadouts.matches_carried(state, loadout)) then
    return nil, { status = "quest_loadout_unverified" }
  end
  return true
end

local function refresh_bank(quest)
  local at_bank, travel_error = ensure_at_bank(quest)
  if not at_bank then return nil, travel_error end
  local bank, bank_error = banking.open()
  if not bank then return nil, bank_error end
  local closed = gc.await {
    action = { type = "ui.close" },
    activity = "banking",
  }
  if closed.status ~= "dispatched" and closed.status ~= "complete" then
    return nil, { status = "bank_close_failed", receipt = closed }
  end
  gc.await { ticks = 2 }
  return true
end

local function prepare(quest, restock)
  return prepare_items(quest, restock, configs[quest].loadout)
end

return { prepare = prepare, prepare_items = prepare_items, refresh_bank = refresh_bank }
