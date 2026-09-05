local geometry = gc.require("shared_geometry")

local function walk(destination, within, options)
  options = options or {}
  return gc.await {
    action = {
      type = "walk.to",
      destination = destination,
      within = within or 3,
      run = options.run ~= false,
      via = options.via,
      avoid_tiles = options.avoid_tiles,
      interrupt_on = options.interrupt_on,
      resume = options.resume,
      arrival_tiles = options.arrival_tiles,
    },
    activity = options.activity,
    humanize = options.humanize,
    policy = options.policy,
    timeout = { game_ticks = options.ticks or 900 },
  }
end

local function approach(destination, within, options)
  if geometry.distance(gc.read("player").world, destination) <= (within or 3) then
    return { status = "arrived", result = "already_near_target" }
  end
  return walk(destination, within, options)
end

return {
  walk = walk,
  approach = approach,
}
