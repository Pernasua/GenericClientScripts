local formatting = gc.require("shared_progress")

local start_xp = 0

local function format_eta(target_xp, current_xp, rate)
  if current_xp >= target_xp then return "Complete" end
  if rate <= 0 then return "--" end
  return formatting.format_duration((target_xp - current_xp) * 3600 / rate)
end

local function begin(xp)
  start_xp = xp
end

local function show(target_level, target_xp, state)
  local prayer = gc.read("skills").prayer
  local runtime_millis = gc.read("runtime").script_runtime_millis
  local gained = math.max(0, prayer.xp - start_xp)
  local rate = runtime_millis <= 0 and 0 or gained * 3600000 / runtime_millis
  gc.overlay {
    {
      label = "Prayer",
      value = tostring(prayer.level) .. " / " .. tostring(target_level) ..
        "  +" .. tostring(gained) .. " XP",
    },
    { label = "XP/hour", value = formatting.compact_rate(rate) },
    { label = "ETA", value = format_eta(target_xp, prayer.xp, rate) },
    { label = "State", value = state },
  }
end

return { begin = begin, show = show }
