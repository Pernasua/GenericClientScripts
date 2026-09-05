local item_queries = gc.require("shared_items")

local stamina_varbit = 25
local stamina_potion_ids = { 12625, 12627, 12629, 12631 }
local stamina_doses = {
  [12625] = 4,
  [12627] = 3,
  [12629] = 2,
  [12631] = 1,
}
local maximum_attempts = 3
local observation_ticks = 5

local transient_failures = {
  interaction_already_running = true,
  hover_has_no_matching_action = true,
  mouse_missed_target = true,
  context_menu_already_open = true,
  context_menu_has_no_matching_action = true,
  matching_inventory_item_not_clickable = true,
}

local function stamina_active()
  local vars = gc.read("vars", { varbits = { stamina_varbit } })
  return (vars.varbits[stamina_varbit] or 0) > 0
end

local function stamina_potion()
  return item_queries.first(gc.read("inventory"), stamina_potion_ids)
end

local function carried_stamina_doses()
  local total = 0
  local inventory = gc.read("inventory")
  for id, doses in pairs(stamina_doses) do
    total = total + item_queries.quantity(inventory, id) * doses
  end
  return total
end

local function ensure_stamina(options)
  options = options or {}
  if stamina_active() then
    return true, { status = "unchanged", result = "stamina_already_active" }
  end
  if options.minimum_run_energy and
    gc.read("player").run_energy >= options.minimum_run_energy then
    return true, { status = "unchanged", result = "run_energy_sufficient" }
  end

  local attempts = {}
  for _ = 1, maximum_attempts do
    local potion = stamina_potion()
    if not potion then
      return nil, {
        status = "stamina_potion_unavailable",
        attempts = attempts,
      }
    end
    local doses_before = carried_stamina_doses()
    local receipt = gc.await {
      action = { type = "item.interact", id = potion, action = "Drink" },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 20 },
    }
    attempts[#attempts + 1] = receipt

    if receipt.status == "dispatched" then
      for _ = 1, observation_ticks do
        gc.await { event = "game.tick" }
        local effect_observed = stamina_active()
        local dose_consumed = carried_stamina_doses() < doses_before
        if effect_observed or dose_consumed then
          return true, {
            status = "complete",
            result = "stamina_effect_observed",
            effect_observed = effect_observed,
            dose_consumed = dose_consumed,
            attempts = attempts,
          }
        end
      end
    elseif not transient_failures[receipt.result] then
      return nil, {
        status = "stamina_activation_failed",
        attempts = attempts,
      }
    end

    gc.await { event = "game.tick" }
  end
  return nil, {
    status = "stamina_activation_failed",
    attempts = attempts,
  }
end

local function stamina_interrupts(minimum_energy_percent)
  if minimum_energy_percent then
    local vars = gc.read("vars", { varbits = { stamina_varbit } })
    if vars.varbits[stamina_varbit] == 0 then
      return { run_energy_below = minimum_energy_percent }
    end
  end
  -- Unknown effect state also goes through this predicate, so the host returns unavailable.
  return { varbit_equals = { { id = stamina_varbit, value = 0 } } }
end

return {
  ensure_stamina = ensure_stamina,
  stamina_interrupts = stamina_interrupts,
}
