local config = gc.require("config")
local item_queries = gc.require("shared_items")
local loadouts = gc.require("shared_loadouts")

local function has_equipped(id)
  return item_queries.quantity(gc.read("equipment"), id) > 0
end

local function has_loadout(plan)
  return #loadouts.missing_carried({
    inventory = gc.read("inventory"),
    equipment = gc.read("equipment"),
  }, plan) == 0
end

local function casts_to(cursor_xp, ceiling_xp, required_xp, base_xp)
  local stage_end = math.min(ceiling_xp, required_xp)
  if cursor_xp >= stage_end then
    return 0, cursor_xp
  end
  return math.ceil((stage_end - cursor_xp) / base_xp), stage_end
end

local function spell_for_level(level)
  for index = #config.spells, 1, -1 do
    local spell = config.spells[index]
    if level >= spell.minimum_level then return spell end
  end
  error("No Magic spell configured for level " .. tostring(level))
end

local function add_rune(runes, rune, casts)
  if casts <= 0 then return end
  local planned = runes[rune.id]
  if not planned then
    planned = {
      id = rune.id,
      name = rune.name,
      quantity = 0,
      maximum_unit_price = rune.maximum_unit_price,
    }
    runes[rune.id] = planned
  end
  planned.quantity = planned.quantity + casts * rune.quantity
end

local function plan_for(target_level, current_magic, required_xp_override)
  local plan = {}
  for _, item in ipairs(assert(config.plans[target_level], "Missing supply plan")) do
    table.insert(plan, {
      id = item.id,
      name = item.name,
      quantity = item.quantity,
      maximum_unit_price = item.maximum_unit_price,
    })
  end

  local required_xp = required_xp_override or
    assert(config.target_xp[target_level], "Missing target XP")
  local cursor_xp = current_magic.xp
  local runes = {}
  for index, spell in ipairs(config.spells) do
    local next_spell = config.spells[index + 1]
    local ceiling_xp = next_spell and next_spell.unlock_xp or required_xp
    local casts
    casts, cursor_xp = casts_to(cursor_xp, ceiling_xp, required_xp, spell.base_xp)
    for _, rune in ipairs(spell.runes) do add_rune(runes, rune, casts) end
  end
  for _, spell in ipairs(config.spells) do
    for _, rune in ipairs(spell.runes) do
      if runes[rune.id] then
        table.insert(plan, runes[rune.id])
        runes[rune.id] = nil
      end
    end
  end
  return plan
end

return {
  has_equipped = has_equipped,
  has_loadout = has_loadout,
  plan_for = plan_for,
  spell_for_level = spell_for_level,
}
