local function in_zone(world, zone)
  return world and (zone.plane == nil or world.plane == zone.plane) and
    world.x >= zone.x1 and world.x <= zone.x2 and
    world.y >= zone.y1 and world.y <= zone.y2
end

local function distance(left, right)
  if not left or not right or left.plane ~= right.plane then return 99999 end
  return math.max(math.abs(left.x - right.x), math.abs(left.y - right.y))
end

local function copy_point(point)
  if not point then return nil end
  return { x = point.x, y = point.y, plane = point.plane }
end

local function point_key(point)
  if not point then return "-" end
  return point.x .. "," .. point.y .. "," .. (point.plane or 0)
end

return {
  in_zone = in_zone,
  distance = distance,
  copy_point = copy_point,
  point_key = point_key,
}
