local movement = gc.require("shared_movement")
local config = gc.require("waterfall_config")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local travel = gc.require("shared_travel")
local wait = gc.require("shared_wait")

local function use_pebble()
  local current = gc.read("player").world
  if math.max(
    math.abs(current.x - config.points.tombstone.x),
    math.abs(current.y - config.points.tombstone.y)) > 200 then
    local teleported = travel.teleport_to_barbarian_outpost()
    if teleported.status ~= "complete" then return teleported end
  end
  local approach = movement.walk(config.points.tombstone, 3, { ticks = 900 })
  if approach.status ~= "arrived" then return approach end
  gc.await { event = "game.tick" }
  local tombstones = gc.read("objects", {
    id = config.objects.tombstone,
    within = 8,
    limit = 4,
  })
  if #tombstones == 0 then
    return {
      status = "rejected",
      result = "glarial_tombstone_unresolved",
      nearby = gc.read("objects", { within = 8, limit = 30 }),
    }
  end
  local entered = gc.await {
    action = {
      type = "item.use_on_object",
      item_id = config.items.pebble,
      object_id = config.objects.tombstone,
      world = tombstones[1].world,
      within = 8,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if entered.status ~= "dispatched" then return entered end
  if not wait.until_true(function()
    return geometry.in_zone(gc.read("player").world, config.zones.glarial_tomb)
  end, 30) then
    return { status = "timed_out", result = "glarial_tomb_entry_unverified", receipt = entered }
  end
  return { status = "complete", result = "glarial_tomb_entered", receipt = entered }
end

local function search(object_id, action, world, item_id, result)
  local approach = movement.walk(world, 3, {
    ticks = 300,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  })
  if approach.status ~= "arrived" then return approach end
  gc.await { event = "game.tick" }
  local objects = gc.read("objects", {
    id = object_id,
    action = action,
    within = 8,
    limit = 4,
  })
  if #objects == 0 then
    return {
      status = "rejected",
      result = result .. "_object_unresolved",
      nearby = gc.read("objects", { within = 8, limit = 30 }),
    }
  end
  local clicked = gc.await {
    action = {
      type = "object.interact",
      id = object_id,
      action = action,
      world = objects[1].world,
      within = 8,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if clicked.status ~= "dispatched" then return clicked end
  if not wait.until_true(function() return item_queries.inventory_quantity(item_id) > 0 end, 20) then
    return { status = "timed_out", result = result .. "_unverified", receipt = clicked }
  end
  return { status = "complete", result = result, receipt = clicked }
end

local function obtain_amulet()
  local nearby = gc.read("objects", {
    id = config.objects.amulet_chest_open,
    within = 12,
    limit = 1,
  })
  local id = #nearby > 0 and config.objects.amulet_chest_open or
    config.objects.amulet_chest_closed
  return search(
    id,
    "Open",
    config.points.amulet_chest,
    config.items.amulet,
    "glarial_amulet_obtained")
end

local function leave()
  local teleported = travel.teleport_to_barbarian_outpost({
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    keyboard = true,
  })
  if teleported.status == "complete" then
    return { status = "complete", result = "glarial_tomb_left", teleport = teleported }
  end
  local journey = movement.walk(config.points.tomb_surface, 1, {
    ticks = 300,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  })
  journey.teleport = teleported
  return journey
end

local function escape()
  if not geometry.in_zone(gc.read("player").world, config.zones.glarial_tomb) then
    return { status = "complete", result = "not_in_glarial_tomb" }
  end
  return leave()
end

local function execute(phase)
  if phase == "enter_glarial_tomb" then return use_pebble() end
  if phase == "obtain_amulet" then return obtain_amulet() end
  if phase == "obtain_urn" then
    return search(
      config.objects.urn_tomb,
      "Search",
      config.points.urn_tomb,
      config.items.urn,
      "glarial_urn_obtained")
  end
  if phase == "leave_glarial_tomb" then return leave() end
  return { status = "rejected", result = "tomb_phase_unknown:" .. tostring(phase) }
end

return { execute = execute, escape = escape }
