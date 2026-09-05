local config = gc.require("tree_gnome_config")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local movement = gc.require("shared_movement")
local wait = gc.require("shared_wait")
local interact = gc.require("tree_gnome_interactions")
local travel = gc.require("shared_travel")

local function near_village()
  return geometry.distance(gc.read("player").world, config.points.maze_outside) <= 150
end

local function reach_village_area()
  if near_village() then return { status = "complete", result = "already_near_village" } end
  return travel.teleport_to_castle_wars()
end

local function enter_village_through_maze()
  if geometry.in_zone(gc.read("player").world, config.zones.village) then
    return { status = "complete", result = "already_inside_village" }
  end
  local reached = reach_village_area()
  if reached.status ~= "complete" then return reached end
  local route = movement.walk(config.points.maze_inside, 0, { ticks = 900 })
  if route.status ~= "arrived" then return { status = "maze_entry_failed", receipt = route } end
  if not geometry.in_zone(gc.read("player").world, config.zones.village) then
    return { status = "timed_out", result = "village_entry_unverified", route = route }
  end
  return { status = "complete", result = "village_entered", route = route }
end

local function leave_village_through_maze()
  if not geometry.in_zone(gc.read("player").world, config.zones.village) then
    return { status = "complete", result = "already_outside_village" }
  end
  local route = movement.walk(config.points.maze_outside, 0, { ticks = 900 })
  if route.status ~= "arrived" then return { status = "maze_exit_failed", receipt = route } end
  return { status = "complete", result = "village_left", route = route }
end

local function enter_village_with_elkoy()
  if geometry.in_zone(gc.read("player").world, config.zones.village) then
    return { status = "complete", result = "already_inside_village" }
  end
  local reached = reach_village_area()
  if reached.status ~= "complete" then return reached end
  return interact.talk(
    config.npcs.elkoy_outside,
    config.points.elkoy,
    function() return geometry.in_zone(gc.read("player").world, config.zones.village) end,
    { "Yes please." })
end

local function dynamic_object_action(name, action, predicate)
  local found = gc.read("objects", {
    name = name,
    action = action,
    within = 20,
    limit = 10,
  })
  local target = found[1]
  if not target then
    return {
      status = "rejected",
      result = "named_object_not_observed",
      name = name,
      action = action,
      nearby = gc.read("objects", { within = 20, limit = 30 }),
    }
  end
  local clicked = gc.await {
    action = {
      type = "object.interact",
      id = target.id,
      action = action,
      world = target.world,
      within = 20,
    },
    timeout = { game_ticks = 40 },
  }
  if clicked.status ~= "dispatched" then return clicked end
  if not wait.until_true(predicate, 40) then
    return { status = "timed_out", result = "named_object_result_unverified", receipt = clicked }
  end
  return { status = "complete", result = "named_object_result_verified", receipt = clicked }
end

local function climb_tower_ladder()
  return gc.intent("tree_gnome.climb_tower", function()
    if gc.read("dialogue").type == "continue" then
      local drained, failure = interact.finish_dialogue(
        function() return true end, {}, 30)
      if not drained then return failure end
    end
    local ladder = interact.object(config.objects.tower_ladder, "Climb-up", 16)
    if not ladder then
      return {
        status = "rejected",
        result = "tower_ladder_not_observed",
        nearby = gc.read("objects", { within = 16, limit = 40 }),
      }
    end
    local clicked = gc.await {
      action = {
        type = "object.interact",
        id = config.objects.tower_ladder,
        action = "Climb-up",
        world = ladder.world,
        within = 16,
      },
      timeout = { game_ticks = 40 },
    }
    if clicked.status ~= "dispatched" then return clicked end
    if not wait.until_true(function()
      return gc.read("player").world.plane == 1
    end, 40) then
      return {
        status = "timed_out",
        result = "tower_ladder_result_unverified",
        receipt = clicked,
        messages = gc.read("messages", { limit = 20 }),
      }
    end
    return { status = "complete", result = "tower_ladder_climbed", receipt = clicked }
  end)
end

local function enter_orb_tower()
  local world = gc.read("player").world
  if geometry.in_zone(world, config.zones.tower_upstairs) then
    return { status = "complete", result = "already_upstairs" }
  end
  if geometry.in_zone(world, config.zones.tower_ground) then return climb_tower_ladder() end

  local reached = movement.walk(config.points.crumbled_wall, 2, { ticks = 900 })
  if reached.status ~= "arrived" then return reached end
  local crossed = interact.object_action(
    config.objects.crumbled_wall,
    "Climb-over",
    config.points.crumbled_wall,
    function() return geometry.in_zone(gc.read("player").world, config.zones.tower_ground) end,
    12)
  if crossed.status ~= "complete" then return crossed end
  return climb_tower_ladder()
end

local function search_orb_chest()
  if item_queries.carried_quantity(config.items.first_orb) > 0 then
    return { status = "complete", result = "orb_already_carried" }
  end

  return gc.intent("tree_gnome.search_orb_chest", function()
    local closed = interact.object(config.objects.chest_closed, "Open", 16)
    if closed then
      local opened = gc.await {
        action = {
          type = "object.interact",
          id = config.objects.chest_closed,
          action = "Open",
          world = closed.world,
          within = 16,
        },
        timeout = { game_ticks = 40 },
      }
      if opened.status ~= "dispatched" then return opened end
      if not wait.until_true(function()
        return interact.object(config.objects.chest_open, "Search", 16) ~= nil
      end, 30) then
        return {
          status = "timed_out",
          result = "orb_chest_open_unverified",
          receipt = opened,
        }
      end
    end

    local open = interact.object(config.objects.chest_open, "Search", 16)
    if not open then
      return {
        status = "rejected",
        result = "open_orb_chest_not_observed",
        nearby = gc.read("objects", { within = 20, limit = 30 }),
      }
    end
    local searched = gc.await {
      action = {
        type = "object.interact",
        id = config.objects.chest_open,
        action = "Search",
        world = open.world,
        within = 16,
      },
      timeout = { game_ticks = 40 },
    }
    if searched.status ~= "dispatched" then return searched end
    if not wait.until_true(function()
      return item_queries.carried_quantity(config.items.first_orb) > 0
    end, 40) then
      return {
        status = "timed_out",
        result = "orb_chest_search_unverified",
        receipt = searched,
      }
    end
    return { status = "complete", result = "first_orb_obtained", receipt = searched }
  end)
end

local function leave_orb_tower()
  if gc.read("player").world.plane == 1 then
    local down = dynamic_object_action(
      "Ladder",
      "Climb-down",
      function() return gc.read("player").world.plane == 0 end)
    if down.status ~= "complete" then return down end
  end
  if geometry.in_zone(gc.read("player").world, config.zones.tower_ground) then
    local door = interact.object(config.objects.khazard_door, "Open", 20)
    if door then
      local opened = gc.await {
        action = {
          type = "object.interact",
          id = config.objects.khazard_door,
          action = "Open",
          world = door.world,
          within = 20,
        },
        timeout = { game_ticks = 40 },
      }
      if opened.status ~= "dispatched" then return opened end
    end
    local outside = movement.walk(config.points.tower_exit, 1, { ticks = 120 })
    if outside.status ~= "arrived" then return outside end
  end
  return { status = "complete", result = "orb_tower_left" }
end

local function return_to_village()
  local left = leave_orb_tower()
  if left.status ~= "complete" then return left end
  return enter_village_with_elkoy()
end

local function reach_warlord()
  local left = leave_village_through_maze()
  if left.status ~= "complete" then return left end
  if geometry.distance(gc.read("player").world, config.points.warlord) > 400 and
    travel.has_dueling_ring() then
    local teleported = travel.teleport_to_castle_wars()
    if teleported.status ~= "complete" then
      return { status = "warlord_transport_failed", receipt = teleported }
    end
  end
  local walked = movement.walk(config.points.warlord, 2, { ticks = 900 })
  if walked.status ~= "arrived" then return walked end
  return { status = "complete", result = "warlord_area_reached", receipt = walked }
end

local function escape_hostile_area()
  local teleported = travel.teleport_to_castle_wars({
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    keyboard = true,
  })
  if teleported.status == "complete" then return teleported end
  local necklace = travel.teleport_to_barbarian_outpost({
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    keyboard = true,
  })
  if necklace.status == "complete" then return necklace end
  local walked = movement.walk(config.points.warlord_fallback, 2, {
    ticks = 120,
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  })
  if walked.status == "arrived" then return walked end
  return {
    status = "escape_failed",
    ring = teleported,
    necklace = necklace,
    walk = walked,
  }
end

return {
  enter_village_through_maze = enter_village_through_maze,
  leave_village_through_maze = leave_village_through_maze,
  enter_village_with_elkoy = enter_village_with_elkoy,
  enter_orb_tower = enter_orb_tower,
  search_orb_chest = search_orb_chest,
  leave_orb_tower = leave_orb_tower,
  return_to_village = return_to_village,
  reach_warlord = reach_warlord,
  escape_hostile_area = escape_hostile_area,
}
