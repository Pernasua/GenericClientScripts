local config = gc.require("monkey_madness_config")
local geometry = gc.require("shared_geometry")

local south = {
  config.zones.ape_atoll_south,
  config.zones.ape_atoll_south_corridor_wide,
  config.zones.ape_atoll_south_corridor_narrow,
}
local north = {
  config.zones.ape_atoll_north,
  config.zones.ape_atoll_north_west,
  config.zones.ape_atoll_north_east,
}
local monkey_pen = {
  config.zones.monkey_pen_west,
  config.zones.monkey_pen_east,
  config.zones.monkey_pen_middle,
}
local throne_room = {
  config.zones.throne_room_west,
  config.zones.throne_room_entry,
  config.zones.throne_room,
}

local function in_any(world, zones)
  for _, zone in ipairs(zones) do
    if geometry.in_zone(world, zone) then return true end
  end
  return false
end

local function in_south(world)
  return in_any(world, south)
end

local function in_north(world)
  return in_any(world, north)
end

local function in_prison(world)
  return geometry.in_zone(world, config.zones.ape_atoll_prison) and
    not geometry.in_zone(world, config.zones.prison_west_clear)
end

local function prison_bounds()
  local prison = assert(config.zones.ape_atoll_prison, "prison bounds are required")
  local clear = assert(config.zones.prison_west_clear, "prison west-clear bounds are required")
  local plane = assert(prison.plane, "prison bounds require a plane")
  local x1, x2 = math.max(prison.x1, clear.x1), math.min(prison.x2, clear.x2)
  local y1, y2 = math.max(prison.y1, clear.y1), math.min(prison.y2, clear.y2)
  if x1 > x2 or y1 > y2 or clear.plane and clear.plane ~= plane then
    return { { x1 = prison.x1, y1 = prison.y1, x2 = prison.x2, y2 = prison.y2, plane = plane } }
  end
  local bounds = {}
  local function add(left, bottom, right, top)
    if left <= right and bottom <= top then
      bounds[#bounds + 1] = { x1 = left, y1 = bottom, x2 = right, y2 = top, plane = plane }
    end
  end
  add(prison.x1, prison.y1, x1 - 1, prison.y2)
  add(x2 + 1, prison.y1, prison.x2, prison.y2)
  add(x1, prison.y1, x2, y1 - 1)
  add(x1, y2 + 1, x2, prison.y2)
  return bounds
end

local function at_temple_melee_threshold(world)
  return geometry.in_zone(world, config.zones.temple_melee_threshold)
end

local function in_temple_guard_building(world)
  return geometry.in_zone(world, config.zones.temple_guard_building)
end

local function in_monkey_pen(world)
  return in_any(world, monkey_pen)
end

local function in_throne_room(world)
  return in_any(world, throne_room)
end

local function in_demon_room(world)
  return geometry.in_zone(world, config.zones.jungle_demon_room_ground) or
    geometry.in_zone(world, config.zones.jungle_demon_room_platform)
end

return {
  in_south = in_south,
  in_north = in_north,
  in_prison = in_prison,
  prison_bounds = prison_bounds,
  at_temple_melee_threshold = at_temple_melee_threshold,
  in_temple_guard_building = in_temple_guard_building,
  in_monkey_pen = in_monkey_pen,
  in_throne_room = in_throne_room,
  in_demon_room = in_demon_room,
}
