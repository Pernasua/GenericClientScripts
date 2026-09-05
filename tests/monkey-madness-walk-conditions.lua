local config = dofile("scripts/quest-runner/monkey_madness_i/config.lua")
local geometry = dofile("scripts/shared/geometry.lua")
gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "shared_geometry" then return geometry end
    error("unexpected module " .. name)
  end,
}
local areas = dofile("scripts/quest-runner/monkey_madness_i/areas.lua")
local bounds = areas.prison_bounds()
for plane = 0, 1 do
  for x = 2761, 2778 do
    for y = 2790, 2805 do
      local world = { x = x, y = y, plane = plane }
      local included = false
      for _, rectangle in ipairs(bounds) do
        included = included or geometry.in_zone(world, rectangle)
      end
      assert(included == areas.in_prison(world),
        "prison interrupt changed the safe exclusion at " .. x .. "," .. y .. "," .. plane)
    end
  end
end
assert(not areas.in_prison({ x = 2764, y = 2798, plane = 0 }), "west clearance became a capture zone")
assert(areas.in_prison({ x = 2765, y = 2798, plane = 0 }), "prison interior lost capture coverage")
print("monkey madness walk condition tests passed")
