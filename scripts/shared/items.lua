local function quantity(container, id)
  local total = 0
  for _, item in ipairs((container and container.items) or {}) do
    if item.id == id then total = total + item.quantity end
  end
  return total
end

local function inventory_quantity(id)
  return quantity(gc.read("inventory"), id)
end

local function carried_quantity(id)
  return inventory_quantity(id) + quantity(gc.read("equipment"), id)
end

local function carried_in(state, id)
  return quantity(state.inventory, id) + quantity(state.equipment, id)
end

local function total_owned(state, id)
  return carried_in(state, id) + quantity(state.bank, id)
end

local function first(container, ids)
  for _, id in ipairs(ids) do
    if quantity(container, id) > 0 then return id end
  end
end

return {
  quantity = quantity,
  inventory_quantity = inventory_quantity,
  carried_quantity = carried_quantity,
  carried_in = carried_in,
  total_owned = total_owned,
  first = first,
}
