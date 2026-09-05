local config = gc.require("monkey_madness_config")
local geometry = gc.require("shared_geometry")
local movement = gc.require("shared_movement")
local travel = gc.require("shared_travel")

local function npc(ids, within)
  for _, id in ipairs(ids) do
    local target = gc.read("npcs", {
      id = id,
      within = within or 24,
      limit = 1,
    })[1]
    if target then return target end
  end
  return nil
end

local function object(id, action, within)
  return gc.read("objects", {
    id = id,
    action = action,
    within = within or 12,
    limit = 1,
  })[1]
end

local function travel_to_gnome_stronghold(options)
  options = options or {}
  local world = gc.read("player").world
  if geometry.in_zone(world, config.zones.grand_tree) or
    geometry.in_zone(world, config.zones.stronghold_transport) then
    return { status = "complete", result = "grand_tree_already_reached" }
  end
  gc.activity("travel")
  if geometry.distance(world, config.points.ge_spirit_tree) > 120 then
    if travel.has_wealth_ring() then
      local teleported = travel.teleport_to_grand_exchange(options)
      if teleported.status ~= "complete" then
        return { status = "monkey_madness_ge_teleport_failed", receipt = teleported }
      end
    elseif travel.has_dueling_ring() then
      local teleported = travel.teleport_to_emirs_arena(options)
      if teleported.status ~= "complete" then
        return { status = "monkey_madness_emirs_teleport_failed", receipt = teleported }
      end
    else
      return { status = "monkey_madness_ge_transport_required", player = gc.read("player") }
    end
  end
  local reached = movement.walk(config.points.stronghold_arrival, 1, {
    ticks = 600,
    policy = options.policy,
    interrupt_on = { dialogue = true },
  })
  if reached.status ~= "arrived" then return reached end
  return { status = "complete", result = "grand_tree_reached", receipt = reached }
end

local function leave_shipyard()
  if not geometry.in_zone(gc.read("player").world, config.zones.shipyard) then
    return { status = "complete", result = "already_outside_shipyard" }
  end
  gc.activity("travel")
  local reached = movement.walk(config.points.shipyard_gate_inside, 1, { ticks = 600 })
  if reached.status ~= "arrived" then return reached end
  local gate = object(config.objects.shipyard_gate, "Open", 10)
  if not gate then
    return {
      status = "monkey_madness_shipyard_exit_gate_not_observed",
      objects = gc.read("objects", { within = 12, limit = 40 }),
    }
  end
  gc.activity("travel")
  local opened = gc.await {
    action = {
      type = "object.interact",
      id = gate.id,
      action = "Open",
      world = gate.world,
      within = 10,
    },
    timeout = { game_ticks = 40 },
  }
  if opened.status ~= "dispatched" then return opened end
  gc.activity("travel")
  local crossed = movement.walk(config.points.shipyard_gate_outside, 0, { ticks = 600 })
  if crossed.status ~= "arrived" then return crossed end
  if geometry.in_zone(gc.read("player").world, config.zones.shipyard) then
    return {
      status = "monkey_madness_shipyard_exit_unverified",
      receipt = opened,
      player = gc.read("player"),
    }
  end
  return { status = "complete", result = "shipyard_exited", receipt = opened }
end

local function reach_shipyard_gate()
  gc.activity("travel")
  local reached = movement.walk(config.points.shipyard_gate, 3, {
    ticks = 600,
    interrupt_on = { dialogue = true },
  })
  if reached.status ~= "arrived" then return reached end
  return { status = "complete", result = "shipyard_gate_reached", receipt = reached }
end

local function reach_caranock()
  gc.activity("travel")
  local reached = movement.walk(config.points.caranock, 4, { ticks = 600 })
  if reached.status ~= "arrived" then return nil, reached end
  local target = npc(config.npcs.caranock, 20)
  if target then return target end
  return nil, {
    status = "monkey_madness_caranock_not_observed",
    player = gc.read("player"),
    nearby = gc.read("npcs", { within = 24, limit = 40 }),
  }
end

local function reach_daero(policy)
  local target = npc(config.npcs.daero, 24)
  if target then return target end
  local world = gc.read("player").world
  if not geometry.in_zone(world, config.zones.grand_tree) and
    not geometry.in_zone(world, config.zones.stronghold_transport) then
    return nil, { status = "monkey_madness_daero_resume_location_unknown", player = world }
  end
  gc.activity("travel")
  local reached = movement.walk(config.points.daero, 5, {
    ticks = 600,
    policy = policy,
    interrupt_on = { dialogue = true },
  })
  if reached.status ~= "arrived" then return nil, reached end
  target = npc(config.npcs.daero, 24)
  if target then return target end
  return nil, {
    status = "monkey_madness_daero_not_observed",
    player = gc.read("player"),
    nearby = gc.read("npcs", { within = 24, limit = 40 }),
  }
end

local function reach_post_puzzle_daero()
  local target = npc(config.npcs.daero, 30)
  if target then return target end
  local world = gc.read("player").world
  if not geometry.in_zone(world, config.zones.post_puzzle_hangar) then
    return nil, { status = "monkey_madness_post_puzzle_resume_location_unknown", player = world }
  end
  gc.activity("travel")
  local reached = movement.walk(config.points.post_puzzle_daero, 6, { ticks = 600 })
  if reached.status ~= "arrived" then return nil, reached end
  target = npc(config.npcs.daero, 30)
  if target then return target end
  return nil, {
    status = "monkey_madness_post_puzzle_daero_not_observed",
    player = gc.read("player"),
    nearby = gc.read("npcs", { within = 30, limit = 50 }),
  }
end

local function reach_narnode()
  local target = npc(config.npcs.king_narnode, 24)
  if target then return target end
  local player = gc.read("player").world
  if geometry.in_zone(player, config.zones.shipyard) then
    local exited = leave_shipyard()
    if exited.status ~= "complete" then return nil, exited end
  end
  if player.plane ~= 0 and not geometry.in_zone(player, config.zones.grand_tree) then
    return nil, { status = "monkey_madness_narnode_resume_location_unknown", player = player }
  end
  gc.activity("travel")
  local reached = movement.walk(config.points.king_narnode, 3, { ticks = 600, interrupt_on = { dialogue = true } })
  if reached.status ~= "arrived" then return nil, reached end
  target = npc(config.npcs.king_narnode, 20)
  if target then return target end
  return nil, {
    status = "monkey_madness_narnode_not_observed",
    player = gc.read("player"),
    nearby = gc.read("npcs", { within = 24, limit = 40 }),
  }
end

return {
  npc = npc,
  reach_narnode = reach_narnode,
  travel_to_gnome_stronghold = travel_to_gnome_stronghold,
  reach_shipyard_gate = reach_shipyard_gate,
  reach_caranock = reach_caranock,
  reach_daero = reach_daero,
  reach_post_puzzle_daero = reach_post_puzzle_daero,
}
