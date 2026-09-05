local geometry = dofile("scripts/shared/geometry.lua")

local ground_zone = { x1 = 10, x2 = 20, y1 = 30, y2 = 40, plane = 0 }
assert(geometry.in_zone({ x = 10, y = 40, plane = 0 }, ground_zone))
assert(not geometry.in_zone({ x = 10, y = 40, plane = 1 }, ground_zone))
assert(geometry.in_zone(
  { x = 15, y = 35, plane = 2 },
  { x1 = 10, x2 = 20, y1 = 30, y2 = 40 }))
assert(geometry.distance(
  { x = 10, y = 30, plane = 0 },
  { x = 14, y = 32, plane = 0 }) == 4)
assert(geometry.distance(nil, ground_zone) == 99999)
local copied = geometry.copy_point({ x = 14, y = 32, plane = 1, ignored = true })
assert(copied.x == 14 and copied.y == 32 and copied.plane == 1 and copied.ignored == nil)
assert(geometry.copy_point(nil) == nil)
assert(geometry.point_key(copied) == "14,32,1")
assert(geometry.point_key(nil) == "-")

local movement_request
gc = {
  require = function(name)
    if name == "shared_geometry" then return geometry end
    error("unexpected module " .. name)
  end,
  read = function(subject)
    assert(subject == "player")
    return { world = { x = 12, y = 34, plane = 0 } }
  end,
  await = function(request)
    movement_request = request
    return { status = "arrived", reached = request.action.destination }
  end,
}
local movement = dofile("scripts/shared/movement.lua")
assert(movement.approach({ x = 12, y = 34, plane = 0 }, 0).status == "arrived")
assert(movement_request == nil, "an already reached approach dispatched movement")
local policy = { breaks = false, cursor_release = "none", fidget = "none" }
local via = { { x = 14, y = 36, plane = 0 } }
movement.walk({ x = 20, y = 40, plane = 0 }, 2, {
  policy = policy,
  ticks = 80,
  via = via,
  activity = "hazardous_travel",
  run = false,
  interrupt_on = { dialogue = true },
  resume = "continuation",
})
assert(movement_request.action.type == "walk.to" and movement_request.action.within == 2)
assert(movement_request.policy == policy and movement_request.breaks == nil)
assert(movement_request.timeout.game_ticks == 80 and movement_request.activity == "hazardous_travel")
assert(movement_request.action.via == via and movement_request.action.run == false)
assert(movement_request.action.interrupt_on.dialogue and movement_request.action.resume == "continuation")
movement.approach({ x = 20, y = 40, plane = 0 })
assert(movement_request.policy == nil and movement_request.action.within == 3)
assert(movement_request.timeout.game_ticks == 900 and movement_request.action.run)
local waited_ticks = 0
gc = {
  await = function(request)
    assert(request.event == "game.tick")
    waited_ticks = waited_ticks + 1
    return { status = "observed" }
  end,
}
local wait = dofile("scripts/shared/wait.lua")
assert(wait.until_true(function() return waited_ticks >= 2 end, 3))
assert(waited_ticks == 2)

local inventory = {
  items = {
    { id = 100, quantity = 2 },
    { id = 100, quantity = 3 },
    { id = 200, quantity = 1 },
  },
}
local equipment = { items = { { id = 100, quantity = 1 } } }
local bank = { items = { { id = 100, quantity = 7 } } }

gc = {
  read = function(subject)
    if subject == "inventory" then return inventory end
    if subject == "equipment" then return equipment end
    error("unexpected read " .. subject)
  end,
}

local items = dofile("scripts/shared/items.lua")
assert(items.quantity(inventory, 100) == 5)
assert(items.quantity(nil, 100) == 0)
assert(items.inventory_quantity(100) == 5)
assert(items.carried_quantity(100) == 6)
assert(items.carried_in({ inventory = inventory, equipment = equipment }, 100) == 6)
assert(items.total_owned({ inventory = inventory, equipment = equipment, bank = bank }, 100) == 13)
assert(items.first(inventory, { 300, 200, 100 }) == 200)

gc.require = function(name)
  if name == "shared_items" then return items end
  if name == "shared_wait" then return wait end
  error("unexpected module " .. name)
end
gc.await = function(request)
  if request.event == "game.tick" then return { status = "observed" } end
  local action = request.action
  if action.type == "item.interact" then
    inventory.items = {}
    equipment.items = { { id = action.id, quantity = 1 } }
    return { status = "dispatched" }
  end
  if action.type == "equipment.interact" then
    equipment.items = {}
    inventory.items = { { id = action.id, quantity = 1 } }
    return { status = "dispatched" }
  end
  error("unexpected action " .. action.type)
end

local equipment_api = dofile("scripts/shared/equipment.lua")
local equipped = equipment_api.equip(200, "Wear", { verify_ticks = 2 })
assert(equipped.status == "complete")
assert(equipment_api.equip(200, "Wear").status == "unchanged")
local removed = equipment_api.unequip(200, { verify_ticks = 2 })
assert(removed.status == "complete")

local requested
gc.await = function(request)
  requested = request.action
  return { status = "complete", result = "client_behaviors_configured" }
end

local behaviors = dofile("scripts/shared/behaviors.lua")
local configured = behaviors.configure {
  emergency_consumables = false,
  auto_retaliate = false,
  emergency_escape = false,
  combat_prayer = true,
}
assert(configured == true)
assert(requested.type == "client.behaviors.configure")
assert(requested.emergency_consumables == false)
assert(requested.combat_prayer == true)
assert(requested.auto_retaliate == false)
assert(requested.emergency_escape == false)

configured = behaviors.configure {}
assert(configured == true)
assert(requested.emergency_consumables == true)
assert(requested.emergency_escape == true)
assert(requested.combat_prayer == true)
assert(requested.auto_retaliate == true)

configured = behaviors.configure { combat_prayer = false }
assert(configured == true)
assert(requested.combat_prayer == false)

gc.await = function()
  return { status = "rejected", result = "auto_retaliate_not_visible" }
end
local accepted, failure = behaviors.configure {
  auto_retaliate = true,
  emergency_escape = true,
}
assert(accepted == nil)
assert(failure.status == "client_behavior_configuration_failed")

print("shared quest mechanics tests passed")
