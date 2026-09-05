local formatting = gc.require("shared_progress")
local skills = gc.require("shared_skills")

local start_xp = 0

local function format_eta(magic, rate)
  if magic.level >= 99 then
    return "Maxed"
  end
  if rate <= 0 then
    return "--"
  end
  local remaining = math.max(0, skills.xp_for_level(magic.level + 1) - magic.xp)
  return formatting.format_duration(remaining * 3600 / rate)
end

local function begin(xp)
  start_xp = xp
end

local function show(target, state)
  local magic = gc.read("skills").magic
  local runtime_millis = gc.read("runtime").script_runtime_millis
  local gained = math.max(0, magic.xp - start_xp)
  local rate = runtime_millis <= 0 and 0 or gained * 3600000 / runtime_millis
  gc.overlay {
    {
      label = "Magic",
      value = tostring(magic.level) .. " / " .. tostring(target) .. "  +" .. tostring(gained) .. " XP",
    },
    { label = "XP/hour", value = formatting.compact_rate(rate) },
    { label = "Next level", value = format_eta(magic, rate) },
    { label = "State", value = state },
  }
end

return {
  begin = begin,
  show = show,
}
