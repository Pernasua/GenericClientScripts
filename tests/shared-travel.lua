local player = { world = { x = 2442, y = 3091, plane = 0 } }
local inventory = { items = { { id = 11984, quantity = 1 } } }
local dialogue = { type = "closed" }
local actions = {}
local requests = {}
local equipped_items = {}
local equipment = { unequip = function() error("unexpected unequip") end }

gc = {
  require = function(name)
    if name == "shared_equipment" then return equipment end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    error("unexpected module " .. name)
  end,
  read = function(subject)
    if subject == "player" then return player end
    if subject == "inventory" then return inventory end
    if subject == "equipment" then return { items = equipped_items } end
    if subject == "dialogue" then return dialogue end
    error("unexpected read " .. subject)
  end,
  await = function(request)
    if request.event == "game.tick" then return { status = "observed" } end
    local action = request.action
    actions[#actions + 1] = action
    requests[#requests + 1] = request
    if action.type == "item.interact" then
      assert(action.id == 11984 and action.action == "Rub",
        "wealth-ring teleport did not resolve the live charge ID")
      dialogue = { type = "choice", options = { { text = "Grand Exchange" } } }
      return { status = "dispatched" }
    end
    if action.type == "dialogue.choose" then
      assert(action.text == "Grand Exchange", "wrong wealth-ring destination")
      player.world = { x = 3163, y = 3478, plane = 0 }
      dialogue = { type = "closed" }
      return { status = "dispatched" }
    end
    error("unexpected action " .. action.type)
  end,
}

local travel = dofile("scripts/shared/travel.lua")
assert(travel.has_wealth_ring(), "charged wealth ring was not detected")
local policy = { breaks = false, cursor_release = "none", fidget = "none" }
local result = travel.teleport_to_grand_exchange({ policy = policy, keyboard = true })
assert(result.status == "complete", result.status)
assert(result.result == "grand_exchange_teleport_verified")
assert(actions[1].type == "item.interact" and actions[2].type == "dialogue.choose")
assert(actions[2].keyboard == true and actions[2].reading == false,
  "urgent teleport changed its keyboard selection")
assert(requests[1].policy == policy and requests[2].policy == policy,
  "urgent teleport allowed discretionary behavior")

actions, requests = {}, {}
assert(travel.teleport_to_grand_exchange().status == "complete")
assert(actions[2].reading == true and actions[2].keyboard == false)
assert(requests[1].policy == nil and requests[2].policy == nil)

inventory.items = {}
equipped_items = { { id = 11982, quantity = 1 } }
local removals = 0
equipment.unequip = function(id, options)
  removals = removals + 1
  assert(id == 11982 and options.policy == policy)
  equipped_items = {}
  inventory.items = { { id = 11984, quantity = 1 } }
  return { status = "complete" }
end
assert(travel.teleport_to_grand_exchange({ policy = policy, keyboard = true }).status == "complete")
assert(removals == 1, "equipped jewelry was removed more than once")

inventory.items = {}
equipped_items = { { id = 11982, quantity = 1 } }
equipment.unequip = function()
  removals = removals + 1
  return { status = "complete" }
end
assert(travel.teleport_to_grand_exchange().status == "ring_of_wealth_not_carried")
assert(removals == 2, "missing inventory jewelry caused an unequip retry loop")

equipped_items = {}
inventory.items = { { id = 2572, quantity = 1 } }
assert(not travel.has_wealth_ring(), "uncharged wealth ring was treated as teleport-ready")

print("shared travel tests passed")
