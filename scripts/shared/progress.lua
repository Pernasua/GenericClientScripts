local function compact_rate(rate)
  if rate >= 1000 then return string.format("%.1fk", rate / 1000) end
  return tostring(math.floor(rate + 0.5))
end

local function format_duration(seconds)
  seconds = math.floor(seconds + 0.5)
  if seconds < 60 then return tostring(seconds) .. "s" end
  if seconds < 3600 then
    return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
  end
  return string.format(
    "%dh %02dm",
    math.floor(seconds / 3600),
    math.floor(seconds / 60) % 60)
end

return {
  compact_rate = compact_rate,
  format_duration = format_duration,
}
