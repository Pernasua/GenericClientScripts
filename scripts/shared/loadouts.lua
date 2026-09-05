local item_queries = gc.require("shared_items")

local function requirement_quantity(state, item, include_bank)
  local total = item_queries.quantity(state.inventory, item.id) +
    item_queries.quantity(state.equipment, item.id)
  if include_bank then total = total + item_queries.quantity(state.bank, item.id) end
  for _, id in ipairs(item.alternative_ids or {}) do
    total = total + item_queries.quantity(state.inventory, id) +
      item_queries.quantity(state.equipment, id)
    if include_bank then total = total + item_queries.quantity(state.bank, id) end
  end
  return total
end

local function missing(state, loadout)
  local result = {}
  for _, item in ipairs(loadout) do
    local owned = requirement_quantity(state, item, true)
    if owned < item.quantity then
      result[#result + 1] = {
        id = item.id,
        name = item.name,
        quantity = item.quantity - owned,
        maximum_unit_price = item.maximum_unit_price,
        purchase = item.purchase,
      }
    end
  end
  return result
end

local function missing_carried(state, loadout)
  local result = {}
  for _, item in ipairs(loadout) do
    if requirement_quantity(state, item, false) < item.quantity then
      result[#result + 1] = item
    end
  end
  return result
end

local function matches_carried(state, loadout)
  if #state.equipment.items > 0 then return false end
  local allowed = {}
  for _, requirement in ipairs(loadout) do
    allowed[requirement.id] = true
    for _, id in ipairs(requirement.alternative_ids or {}) do allowed[id] = true end
    if requirement_quantity(state, requirement, false) ~= requirement.quantity then return false end
  end
  for _, item in ipairs(state.inventory.items) do
    if not allowed[item.id] then return false end
  end
  return true
end

return {
  missing = missing,
  missing_carried = missing_carried,
  matches_carried = matches_carried,
}
