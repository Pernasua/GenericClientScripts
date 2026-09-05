local config = gc.require("config")
local formatting = gc.require("shared_progress")

local start_xp = 0

local function begin(xp)
  start_xp = xp
end

local function show(target, state)
  local agility = gc.read("skills").agility
  local runtime_millis = gc.read("runtime").script_runtime_millis
  local gained = math.max(0, agility.xp - start_xp)
  local rate = runtime_millis <= 0 and 0 or gained * 3600000 / runtime_millis
  local next_xp = agility.level >= 99 and agility.xp or config.xp_for_level(agility.level + 1)
  local next_eta = rate <= 0 and "--" or
    formatting.format_duration(math.max(0, next_xp - agility.xp) * 3600 / rate)
  gc.overlay {
    {
      label = "Agility",
      value = tostring(agility.level) .. " / " .. tostring(target) .. "  +" .. tostring(gained) .. " XP",
    },
    { label = "XP/hour", value = formatting.compact_rate(rate) },
    { label = "Next level", value = next_eta },
    { label = "State", value = state },
  }
end

return { begin = begin, show = show }
