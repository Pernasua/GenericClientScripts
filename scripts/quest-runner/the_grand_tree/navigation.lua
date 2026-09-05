local config = gc.require("grand_tree_config")
local geometry = gc.require("shared_geometry")
local movement = gc.require("shared_movement")
local interactions = gc.require("grand_tree_interactions")
local travel = gc.require("shared_travel")

local function reach_narnode()
  if gc.read("dialogue").open then return true end
  if interactions.npc(config.npcs.king_narnode, 20, true) then return true end
  gc.activity("travel")
  local moved = movement.walk(config.points.king_narnode, 2, { ticks = 600 })
  if moved.status ~= "arrived" then
    return nil, { status = "grand_tree_travel_failed", receipt = moved }
  end
  if interactions.npc(config.npcs.king_narnode, 20, true) then return true end
  return nil, { status = "king_narnode_not_observed_after_travel", player = gc.read("player") }
end

local function reach_hazelmere()
  if gc.read("dialogue").open or interactions.npc(config.npcs.hazelmere, 16, true) then
    return true
  end
  gc.await { action = { type = "ui.close" }, policy = { breaks = false, cursor_release = "none", fidget = "none" } }
  gc.activity("travel")
  local current = gc.read("player").world
  if geometry.distance(current, config.points.hazelmere_ground) > 120 and
    geometry.distance(current, config.points.hazelmere_upstairs) > 120 then
    if not travel.has_dueling_ring() then
      return nil, { status = "hazelmere_transport_required", player = gc.read("player") }
    end
    local teleported = travel.teleport_to_castle_wars()
    if teleported.status ~= "complete" then
      return nil, { status = "hazelmere_transport_failed", receipt = teleported }
    end
  end
  local moved = movement.walk(config.points.hazelmere_upstairs, 1, { ticks = 600 })
  if moved.status ~= "arrived" then
    return nil, { status = "hazelmere_travel_failed", receipt = moved }
  end
  if interactions.npc(config.npcs.hazelmere, 16, true) then return true end
  return nil, {
    status = "hazelmere_not_observed_after_travel",
    player = gc.read("player"),
    nearby = gc.read("npcs", { within = 20, limit = 30 }),
  }
end

local function return_to_narnode()
  if interactions.npc(config.npcs.king_narnode, 20, true) then return true end
  gc.activity("travel")
  local player = gc.read("player").world
  if geometry.distance(player, config.points.king_narnode) > 120 and
    geometry.distance(player, config.points.castle_wars_exit) > 30 and
    geometry.distance(player, config.points.stronghold_gate_outside) > 80 then
    if not travel.has_dueling_ring() then
      return nil, { status = "narnode_return_transport_required", player = gc.read("player") }
    end
    local teleported = travel.teleport_to_castle_wars()
    if teleported.status ~= "complete" then
      return nil, { status = "narnode_return_transport_failed", receipt = teleported }
    end
  end
  local stage = gc.read("vars", { varps = { config.varp } }).varps[config.varp]
  if gc.read("player").world.y < 3384 and stage == 90 then
    local staged = movement.walk(config.points.stronghold_gate_outside, 1, { ticks = 600 })
    if staged.status ~= "arrived" then return nil, { status = "femi_approach_failed", receipt = staged } end
    local entered = interactions.enter_stronghold_with_femi()
    if entered.status ~= "complete" then return nil, entered end
  end
  return reach_narnode()
end

local function reach_glough_house()
  gc.activity("travel")
  local reached = movement.walk(config.points.glough_room, 2, { ticks = 600 })
  if reached.status ~= "arrived" then
    return nil, { status = "glough_house_travel_failed", receipt = reached }
  end
  return true
end

local function reach_glough()
  if interactions.npc(config.npcs.glough, 16, true) then return true end
  local reached, failure = reach_glough_house()
  if not reached then return nil, failure end
  if interactions.npc(config.npcs.glough, 16, true) then return true end
  return nil, {
    status = "glough_not_observed_after_travel",
    player = gc.read("player"),
    nearby = gc.read("npcs", { within = 20, limit = 30 }),
  }
end

local function return_after_glough()
  if interactions.npc(config.npcs.king_narnode, 20, true) then return true end
  local drained = interactions.drain_continue_dialogue()
  if drained.status ~= "complete" then return nil, drained end
  return reach_narnode()
end

local function reach_watchtower()
  local player = gc.read("player").world
  if player.y >= 9800 or player.x >= 10000 then return true end
  if player.plane == 2 and geometry.distance(player, config.points.glough_watchtower) <= 16 then
    return true
  end
  if player.plane == 0 and geometry.distance(player, config.points.glough_room) > 120 then
    local returned, failure = return_to_narnode()
    if not returned then return nil, failure end
    player = gc.read("player").world
  end
  if player.plane ~= 1 or geometry.distance(player, config.points.glough_room) > 20 then
    local reached, failure = reach_glough_house()
    if not reached then return nil, failure end
  end
  if geometry.distance(gc.read("player").world, config.points.watchtower_tree_approach) > 0 then
    local approached = movement.walk(config.points.watchtower_tree_approach, 0, { ticks = 600 })
    if approached.status ~= "arrived" then
      return nil, { status = "watchtower_tree_approach_failed", receipt = approached }
    end
  end
  local climbed = interactions.climb_glough_watchtower()
  if climbed.status ~= "complete" then return nil, climbed end
  return true
end

local function reach_charlie()
  if interactions.npc(config.npcs.charlie, 20, true) then return true end
  gc.activity("travel")
  local reached = movement.walk(config.points.grand_tree_top, 1, { ticks = 600 })
  if reached.status ~= "arrived" then
    return nil, { status = "charlie_approach_failed", receipt = reached }
  end
  if interactions.npc(config.npcs.charlie, 20, true) then return true end
  return nil, {
    status = "charlie_not_observed_after_climb",
    player = gc.read("player"),
    nearby = gc.read("npcs", { within = 20, limit = 30 }),
  }
end

local function reach_shipyard_foreman()
  if interactions.npc(config.npcs.shipyard_foreman, 20, true) then return true end
  local player = gc.read("player").world
  if player.plane ~= 0 or player.x < 2945 or player.x > 3007 or
    player.y < 3015 or player.y > 3070 then
    return nil, { status = "shipyard_not_entered", player = player }
  end
  gc.activity("travel")
  local reached = movement.walk(config.points.shipyard_foreman, 3, { ticks = 600 })
  if reached.status ~= "arrived" then
    return nil, { status = "shipyard_foreman_travel_failed", receipt = reached }
  end
  if interactions.npc(config.npcs.shipyard_foreman, 20, true) then return true end
  return nil, {
    status = "shipyard_foreman_not_observed_after_travel",
    player = gc.read("player"),
    nearby = gc.read("npcs", { within = 20, limit = 30 }),
  }
end

local function return_lumber_order_to_charlie()
  if interactions.npc(config.npcs.charlie, 20, true) then return true end
  local player = gc.read("player").world
  if player.plane ~= 3 or geometry.distance(player, config.points.grand_tree_top) > 20 then
    local returned, failure = return_to_narnode()
    if not returned then return nil, failure end
  end
  return reach_charlie()
end

local function reach_anita()
  if interactions.npc(config.npcs.anita, 20, true) then return true end
  gc.activity("travel")
  local reached = movement.walk(config.points.anita_upstairs, 1, { ticks = 600 })
  if reached.status ~= "arrived" then
    return nil, { status = "anita_house_travel_failed", receipt = reached }
  end
  if interactions.npc(config.npcs.anita, 20, true) then return true end
  return nil, {
    status = "anita_not_observed_after_travel",
    player = gc.read("player"),
    nearby = gc.read("npcs", { within = 20, limit = 30 }),
  }
end

return {
  reach_narnode = reach_narnode,
  reach_hazelmere = reach_hazelmere,
  return_to_narnode = return_to_narnode,
  reach_glough = reach_glough,
  return_after_glough = return_after_glough,
  reach_charlie = reach_charlie,
  reach_shipyard_foreman = reach_shipyard_foreman,
  return_lumber_order_to_charlie = return_lumber_order_to_charlie,
  reach_anita = reach_anita,
  reach_watchtower = reach_watchtower,
}
