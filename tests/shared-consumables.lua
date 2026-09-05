local stamina_varbit = 0
local stamina_id = 12625
local run_energy = 5000
local drink_attempts = 0
local consume_on_attempt = 2
local hard_failure

local function inventory()
  return {
    items = stamina_id and {
      { id = stamina_id, quantity = 1, name = "Stamina potion" },
    } or {},
  }
end

gc = {
  require = function(name)
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    error("unexpected module " .. name)
  end,
  read = function(kind)
    if kind == "inventory" then return inventory() end
    if kind == "player" then return { run_energy = run_energy } end
    if kind == "vars" then return { varbits = { [25] = stamina_varbit } } end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event == "game.tick" then return { status = "observed" } end
    local action = request.action
    assert(action.type == "item.interact" and action.action == "Drink")
    drink_attempts = drink_attempts + 1
    if hard_failure then
      return { status = "rejected", result = hard_failure }
    end
    if drink_attempts == consume_on_attempt then
      stamina_id = 12627
      stamina_varbit = 100
    end
    return { status = "dispatched", result = "menu_action_executed" }
  end,
}

local consumables = dofile("scripts/shared/consumables.lua")

local ready, receipt = consumables.ensure_stamina()
assert(ready and receipt.status == "complete")
assert(receipt.result == "stamina_effect_observed")
assert(drink_attempts == 2,
  "a dispatched stamina click without an effect was not retried")
assert(#receipt.attempts == 2, "stamina receipt omitted bounded attempts")

stamina_varbit = 50
stamina_id = 12625
drink_attempts = 0
ready, receipt = consumables.ensure_stamina()
assert(ready and receipt.result == "stamina_already_active")
assert(drink_attempts == 0, "active stamina consumed another dose")

stamina_varbit = 0
run_energy = 7000
drink_attempts = 0
ready, receipt = consumables.ensure_stamina { minimum_run_energy = 6000 }
assert(ready and receipt.result == "run_energy_sufficient")
assert(drink_attempts == 0, "sufficient run energy consumed a stamina dose")

run_energy = 5000
hard_failure = "item_not_found"
ready, receipt = consumables.ensure_stamina()
assert(ready == nil and receipt.status == "stamina_activation_failed")
assert(#receipt.attempts == 1, "hard item failure was retried")


-- The effect/energy pair alternates predicates, so a successful no-op handler can continue.
stamina_varbit = 50
run_energy = 5000
local active_interrupt = consumables.stamina_interrupts(60)
assert(active_interrupt.run_energy_below == nil and active_interrupt.varbit_equals[1].value == 0,
  "active stamina kept interrupting on energy that the potion handler intentionally ignores")
stamina_varbit = 0
run_energy = 7000
local expired_interrupt = consumables.stamina_interrupts(60)
assert(expired_interrupt.run_energy_below == 60 and expired_interrupt.varbit_equals == nil,
  "expired stamina at high energy would interrupt continuously")
stamina_varbit = nil
local unknown_interrupt = consumables.stamina_interrupts(60)
assert(unknown_interrupt.varbit_equals[1].id == 25,
  "missing effect data was treated as a known inactive effect")

print("shared consumable tests passed")
