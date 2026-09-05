local stop = {}
local actions = {}
local overlay
local activity
local activity_history = {}
local player = { name = "genericBoss", current_hitpoints = 28, max_hitpoints = 28 }
local attackers = {}
local inventory = { items = {} }

gc = {
  activity = function(value)
    activity = value
    activity_history[#activity_history + 1] = value
  end,
  state = function() end,
  read = function(kind)
    if kind == "player" then return player end
    if kind == "npcs" then return attackers end
    if kind == "inventory" then return inventory end
    error("unexpected read " .. kind)
  end,
  overlay = function(rows) overlay = rows end,
  await = function(request)
    if request.action then actions[#actions + 1] = request.action end
    if request.event == "game.tick" then error(stop, 0) end
    return { status = "rejected" }
  end,
}

local safety_net = dofile("scripts/safety-net.lua")
local ok, failure = pcall(safety_net.run)

assert(not ok and failure == stop, "safety net did not enter its passive wait")
assert(#actions == 0, "safety net issued eager recovery input")
assert(overlay[1].value == "Awaiting manual control after script failure")
assert(#overlay[1].value > 24, "overlay regression no longer exercises long text")

actions = {}
attackers = { { id = 5242, name = "Scorpion", interacting = "genericBoss" } }
gc.await = function(request)
  if request.action then
    actions[#actions + 1] = request.action
  end
  if request.event == "game.tick" then error(stop, 0) end
  return { status = "observed" }
end

ok, failure = pcall(safety_net.run)
assert(not ok and failure == stop,
  "non-emergency combat did not return to passive waiting")
assert(#actions == 0, "healthy combat issued emergency input")
assert(activity == "manual", "safety net did not retain manual activity")
for _, declared in ipairs(activity_history) do
  assert(declared ~= "combat", "safety net delegated prayer control to combat guard")
end

actions = {}
player = { name = "genericBoss", current_hitpoints = 7, max_hitpoints = 28 }
inventory = {
  items = {
    { id = 379, name = "Lobster", actions = { "Eat", "Drop" } },
  },
}
gc.await = function(request)
  if request.action then
    actions[#actions + 1] = request.action
    if request.action.type == "safety.recover" then
      return { status = "rejected", result = "safety_net_not_configured" }
    end
    player = { name = "genericBoss", current_hitpoints = 19, max_hitpoints = 28 }
    return { status = "dispatched", result = "direct_widget_click" }
  end
  if request.event == "game.tick" then error(stop, 0) end
  return { status = "rejected" }
end

ok, failure = pcall(safety_net.run)
assert(not ok and failure == stop, "emergency food fallback did not remain active")
assert(#actions == 2 and actions[1].type == "safety.recover" and
  actions[2].type == "item.interact" and actions[2].id == 379,
  "unconfigured emergency recovery did not eat available food")
for _, declared in ipairs(activity_history) do
  assert(declared ~= "combat", "emergency recovery delegated prayer control to combat guard")
end

actions = {}
player = { name = "genericBoss", current_hitpoints = 7, max_hitpoints = 28 }
gc.await = function(request)
  if request.action then
    actions[#actions + 1] = request.action
    return { status = "dispatched", result = "emergency_escape_complete" }
  end
  return { status = "observed" }
end

local escaped = safety_net.run()
assert(escaped.recovery_completed == true)
assert(#actions == 1 and actions[1].type == "safety.recover",
  "configured emergency escape bypassed the safety controller")

print("passive safety net tests passed")
