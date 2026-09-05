local config = gc.require("fight_arena_config")
local equipment_actions = gc.require("shared_equipment")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local movement = gc.require("shared_movement")
local wait = gc.require("shared_wait")
local interact = gc.require("fight_arena_interactions")
local travel = gc.require("shared_travel")

local function reach_lady()
  local reached = movement.approach(config.points.lady_servil, 3)
  if reached.status ~= "arrived" then return reached end
  return { status = "complete", result = "lady_servil_area_reached", receipt = reached }
end

local function obtain_armour()
  local stage = interact.varp()
  if stage ~= 1 and item_queries.carried_quantity(config.items.khazard_helmet) > 0 and
    item_queries.carried_quantity(config.items.khazard_armour) > 0 then
    return { status = "complete", result = "khazard_armour_already_owned" }
  end

  -- Stand inside the armoury; targeting the chest tile itself can stop outside
  -- its south wall even though the object is geometrically adjacent.
  local reached = movement.approach(config.points.armoury, 0)
  if reached.status ~= "arrived" then return reached end
  gc.await { event = "game.tick" }

  return gc.intent("fight_arena.obtain_armour", function()
    local searchable = interact.object(config.objects.armour_chest_closed, "Search", 20) or
      interact.object(config.objects.armour_chest_open, "Search", 20)
    local closed = interact.object(config.objects.armour_chest_closed, "Open", 20)
    if not searchable and closed then
      local opened = gc.await {
        action = {
          type = "object.interact",
          id = closed.id,
          action = "Open",
          world = closed.world,
          within = 20,
        },
        timeout = { game_ticks = 40 },
      }
      if opened.status ~= "dispatched" then return opened end
      if not wait.until_true(function()
        return interact.object(config.objects.armour_chest_closed, "Search", 20) ~= nil or
          interact.object(config.objects.armour_chest_open, "Search", 20) ~= nil
      end, 30) then
        return { status = "timed_out", result = "armour_chest_open_unverified", receipt = opened }
      end
    end

    searchable = interact.object(config.objects.armour_chest_closed, "Search", 20) or
      interact.object(config.objects.armour_chest_open, "Search", 20)
    if not searchable then
      return {
        status = "rejected",
        result = "armour_chest_not_observed",
        nearby = gc.read("objects", { within = 20, limit = 50 }),
      }
    end
    local searched = gc.await {
      action = {
        type = "object.interact",
        id = searchable.id,
        action = "Search",
        world = searchable.world,
        within = 20,
      },
      timeout = { game_ticks = 40 },
    }
    if searched.status ~= "dispatched" then return searched end
    if not wait.until_true(function()
      if stage == 1 then return interact.varp() ~= stage end
      return item_queries.carried_quantity(config.items.khazard_helmet) > 0 and
        item_queries.carried_quantity(config.items.khazard_armour) > 0
    end, 40) then
      return { status = "timed_out", result = "khazard_armour_unverified", receipt = searched }
    end
    return { status = "complete", result = "khazard_armour_obtained", receipt = searched }
  end)
end

local function equip_armour()
  return gc.intent("fight_arena.equip_armour", function()
    local helmet = equipment_actions.equip(
      config.items.khazard_helmet,
      "Wear",
      { timeout_ticks = 20, verify_ticks = 12 })
    if helmet.status ~= "complete" and helmet.status ~= "unchanged" then return helmet end
    local armour = equipment_actions.equip(
      config.items.khazard_armour,
      "Wear",
      { timeout_ticks = 20, verify_ticks = 12 })
    if armour.status ~= "complete" and armour.status ~= "unchanged" then return armour end
    return { status = "complete", result = "khazard_armour_equipped" }
  end)
end

local function reach_bar()
  if geometry.distance(gc.read("player").world, config.points.bar) == 0 then
    return { status = "complete", result = "bar_customer_tile_reached" }
  end

  local near = movement.approach(config.points.bar_door, 1)
  if near.status ~= "arrived" then return near end
  gc.await { event = "game.tick" }
  local door = interact.object(config.objects.bar_door, "Open", 8)
  if door then
    local opened = gc.await {
      action = {
        type = "object.interact",
        id = door.id,
        action = "Open",
        world = door.world,
        within = 8,
      },
      timeout = { game_ticks = 40 },
    }
    if opened.status ~= "dispatched" then return opened end
    gc.await { ticks = 2 }
  end

  local reached = movement.walk(config.points.bar, 0, { ticks = 120 })
  if reached.status ~= "arrived" then return reached end
  return { status = "complete", result = "bar_customer_tile_reached", receipt = reached }
end

local function reach_arena_area()
  local player = gc.read("player").world
  if player.x >= 10000 or geometry.distance(player, config.points.sammy) <= 32 then
    return { status = "complete", result = "arena_area_already_reached" }
  end
  if travel.has_dueling_ring() then
    local teleported = travel.teleport_to_castle_wars()
    if teleported.status ~= "complete" then return teleported end
  end
  local reached = movement.walk(config.points.sammy, 5, { ticks = 600 })
  if reached.status ~= "arrived" then return reached end
  return { status = "complete", result = "arena_area_reached", receipt = reached }
end

return {
  reach_lady = reach_lady,
  obtain_armour = obtain_armour,
  equip_armour = equip_armour,
  reach_bar = reach_bar,
  reach_arena_area = reach_arena_area,
}
