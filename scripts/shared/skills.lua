local function xp_for_level(level)
  local points = 0
  for current = 1, level - 1 do
    points = points + math.floor(current + 300 * 2 ^ (current / 7))
  end
  return math.floor(points / 4)
end

return { xp_for_level = xp_for_level }
