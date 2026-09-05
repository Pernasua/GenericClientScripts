local config = gc.require("config")
local formatting = gc.require("shared_progress")

local start_xp = 0

local function begin(xp)
  start_xp = xp
end

local function show(target, state)
  local thieving = gc.read("skills").thieving
  local runtime_millis = gc.read("runtime").script_runtime_millis
  local gained = math.max(0, thieving.xp - start_xp)
  local rate = runtime_millis <= 0 and 0 or gained * 3600000 / runtime_millis
  local target_xp = config.target_xp[tostring(target)]
  local eta = rate <= 0 and "--" or
    formatting.format_duration(math.max(0, target_xp - thieving.xp) * 3600 / rate)
  gc.overlay {
    {
      label = "Thieving",
      value = tostring(thieving.level) .. " / " .. tostring(target) ..
        "  +" .. tostring(gained) .. " XP",
    },
    { label = "XP/hour", value = formatting.compact_rate(rate) },
    { label = "ETA", value = eta },
    { label = "State", value = state },
  }
end

return { begin = begin, show = show }
