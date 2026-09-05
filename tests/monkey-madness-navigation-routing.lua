local config = dofile("scripts/quest-runner/monkey_madness_i/config.lua")
local player
local wealth_ring
local dueling_ring
local wealth_teleports
local duel_teleports
local journeys
local journey_failure
local geometry

local function point(x, y, plane) return { x = x, y = y, plane = plane or 0 } end
local targets = {
  [config.npcs.daero[1]] = config.points.daero,
  [config.npcs.king_narnode[1]] = config.points.king_narnode,
}

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "shared_geometry" then return geometry end
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    if name == "shared_wait" then return dofile("scripts/shared/wait.lua") end
    if name == "shared_travel" then
      return {
        has_wealth_ring = function() return wealth_ring end,
        has_dueling_ring = function() return dueling_ring end,
        teleport_to_grand_exchange = function()
          wealth_teleports = wealth_teleports + 1
          player = point(3162, 3487)
          return { status = "complete" }
        end,
        teleport_to_emirs_arena = function()
          duel_teleports = duel_teleports + 1
          player = point(3315, 3235)
          return { status = "complete" }
        end,
      }
    end
    error("unexpected module " .. name)
  end,
  read = function(kind, query)
    if kind == "player" then return { world = player } end
    if kind == "npcs" then
      local target = targets[query.id]
      if target and geometry.distance(player, target) == 0 then
        return { { id = query.id, world = target } }
      end
      return {}
    end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    assert(request.action.type == "walk.to", "transport still uses " .. request.action.type .. " in Lua")
    journeys[#journeys + 1] = request
    if journey_failure then return journey_failure end
    player = request.action.destination
    return { status = "arrived", reached = player }
  end,
  activity = function() end,
}
geometry = dofile("scripts/shared/geometry.lua")
local navigation = dofile("scripts/quest-runner/monkey_madness_i/navigation.lua")

local function reset(world)
  player = world
  wealth_ring, dueling_ring = true, true
  wealth_teleports, duel_teleports = 0, 0
  journeys = {}
  journey_failure = nil
end

reset(point(3000, 3000))
local result = navigation.travel_to_gnome_stronghold()
assert(result.status == "complete", result.status)
assert(wealth_teleports == 1 and duel_teleports == 0, "wasted a dueling-ring charge despite carrying a wealth ring")
assert(#journeys == 1 and geometry.distance(journeys[1].action.destination, point(2461, 3444)) == 0,
  "Stronghold journey stopped before its spirit-tree crossing")
assert(journeys[1].action.interrupt_on.dialogue, "foreign dialogue cannot interrupt unowned travel")
reset(point(3000, 3000))
wealth_ring = false
assert(navigation.travel_to_gnome_stronghold().status == "complete")
assert(wealth_teleports == 0 and duel_teleports == 1 and #journeys == 1)
reset(point(3000, 3000))
wealth_ring, dueling_ring = false, false
assert(navigation.travel_to_gnome_stronghold().status == "monkey_madness_ge_transport_required")
assert(#journeys == 0)
reset(point(3184, 3508))
assert(navigation.travel_to_gnome_stronghold({ policy = { breaks = false, cursor_release = "none", fidget = "none" }, keyboard = true }).status == "complete")
assert(wealth_teleports == 0 and duel_teleports == 0 and journeys[1].policy.breaks == false)
reset(point(2461, 3444))
assert(navigation.travel_to_gnome_stronghold().status == "complete" and #journeys == 0)

reset(config.points.king_narnode)
assert(navigation.reach_shipyard_gate().status == "complete")
assert(#journeys == 1 and geometry.distance(journeys[1].action.destination, config.points.shipyard_gate) == 0,
  "glider travel retained per-floor climbs or a separate menu selection")
reset(point(2970, 2972))
assert(navigation.reach_narnode().id == config.npcs.king_narnode[1])
assert(#journeys == 1 and geometry.distance(journeys[1].action.destination, config.points.king_narnode) == 0,
  "return journey stopped before the flight and descent")

reset(point(2465, 3501, 3))
assert(navigation.reach_daero().id == config.npcs.daero[1])
assert(#journeys == 1 and journeys[1].action.destination == config.points.daero,
  "Daero travel descended to the ground before climbing again")
reset(point(2465, 3501, 3))
assert(navigation.reach_narnode().id == config.npcs.king_narnode[1])
assert(#journeys == 1 and journeys[1].action.destination == config.points.king_narnode)
reset(point(2970, 2972))
journey_failure = { status = "interrupted", reason = "dialogue", continuation = "glider" }
local target, failure = navigation.reach_narnode()
assert(not target and failure == journey_failure and #journeys == 1,
  "foreign dialogue was consumed or travel continued after interruption")

print("monkey madness navigation routing tests passed")
