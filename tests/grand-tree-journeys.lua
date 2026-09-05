local config = dofile("scripts/quest-runner/the_grand_tree/config.lua")
local player
local journeys
local journey_failure
local geometry
local targets = {
  [config.npcs.king_narnode[1]] = config.points.king_narnode,
  [config.npcs.hazelmere[1]] = config.points.hazelmere_upstairs,
  [config.npcs.glough[1]] = config.points.glough_room,
  [config.npcs.charlie[1]] = config.points.grand_tree_top,
  [config.npcs.anita[1]] = config.points.anita_upstairs,
}

gc = {
  require = function(name)
    if name == "grand_tree_config" then return config end
    if name == "grand_tree_interactions" then
      return dofile("scripts/quest-runner/the_grand_tree/interactions.lua")
    end
    if name == "shared_geometry" then return geometry end
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    if name == "shared_travel" then
      return { has_dueling_ring = function() error("unexpected resource teleport") end }
    end
    error("unexpected module " .. name)
  end,
  activity = function() end,
  read = function(kind, query)
    if kind == "player" then return { world = player } end
    if kind == "dialogue" then return { type = "closed", open = false } end
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
    local action = request.action
    if action.type == "ui.close" then return { status = "dispatched" } end
    assert(action.type == "walk.to", "ordinary climb remained in quest Lua")
    journeys[#journeys + 1] = request
    if journey_failure then return journey_failure end
    player = action.destination
    return { status = "arrived", reached = player }
  end,
}
geometry = dofile("scripts/shared/geometry.lua")
dofile("tests/support/intent.lua")(gc)
local navigation = dofile("scripts/quest-runner/the_grand_tree/navigation.lua")

local function journey(method, origin, destination)
  player = origin
  journeys = {}
  journey_failure = nil
  local arrived, failure = navigation[method]()
  assert(arrived, failure and failure.status)
  assert(#journeys == 1, method .. " retained an intermediate climb or walk")
  assert(journeys[1].action.destination == destination, method .. " stops before its destination")
end

journey("reach_hazelmere", config.points.hazelmere_ground, config.points.hazelmere_upstairs)
journey("reach_glough", config.points.king_narnode, config.points.glough_room)
journey("return_after_glough", config.points.glough_room, config.points.king_narnode)
journey("reach_charlie", config.points.king_narnode, config.points.grand_tree_top)
journey("reach_glough", config.points.grand_tree_top, config.points.glough_room)
journey("reach_anita", config.points.grand_tree_top, config.points.anita_upstairs)
journey("reach_glough", config.points.anita_upstairs, config.points.glough_room)

player = config.points.king_narnode
journeys = {}
journey_failure = { status = "interrupted", reason = "dialogue", continuation = "charlie" }
local arrived, failure = navigation.reach_charlie()
assert(not arrived and failure.receipt == journey_failure and #journeys == 1,
  "interrupted transport was accepted or retried as a new journey")

print("Grand Tree journey tests passed")
