local skills = dofile("scripts/shared/skills.lua")
local progress = dofile("scripts/shared/progress.lua")

assert(skills.xp_for_level(2) == 83)
assert(progress.compact_rate(1530) == "1.5k")
assert(progress.format_duration(65) == "1m 05s")

local parked
gc = {
  await = function(request)
    parked = request.action
    return { status = "dispatched" }
  end,
}
local ui = dofile("scripts/shared/ui.lua")
ui.park_mouse()
assert(parked.type == "mouse.offscreen")

local logged
gc.log = function(level, event, fields)
  logged = { level = level, event = event, fields = fields }
end
local failure = dofile("scripts/shared/failure.lua")
local succeeded, raised = pcall(failure.raise, "test-failed", "expected_failure", { id = 42 })
assert(not succeeded and raised == "expected_failure")
assert(logged.event == "test-failed" and logged.fields.id == 42)

local bank_open = false
gc = {
  read = function(subject)
    if subject == "bank" then
      return { open = bank_open, available = bank_open, items = {} }
    end
    if subject == "objects" then return {} end
    error("unexpected read " .. subject)
  end,
  await = function(request)
    if request.event == "game.tick" then return { status = "observed" } end
    local action = request.action
    if action.type == "npc.interact" then
      bank_open = true
      return { status = "dispatched" }
    end
    error("unexpected bank action " .. action.type)
  end,
}

dofile("tests/support/intent.lua")(gc)
local bank = dofile("scripts/shared/bank.lua")
assert(bank.open().available == true)

local actions = {}
gc = {
  await = function(request)
    if request.ticks then return { status = "observed" } end
    actions[#actions + 1] = request.action
    if request.action.type == "npc.interact" then return { status = "dispatched" } end
    if request.action.type == "ui.close" then return { status = "dispatched" } end
    return { status = "complete" }
  end,
}

local exchange = dofile("scripts/shared/exchange.lua")
local purchased, receipt = exchange.buy({
  { id = 556, name = "Air rune", quantity = 10, maximum_unit_price = 50 },
}, {
  minimum_cash_reserve = 5000000,
  collect_mode = "bank",
})
assert(purchased == true)
assert(receipt.status == "complete")
assert(actions[1].type == "bank.loadout")
assert(actions[3].type == "ge.buy")
assert(actions[3].minimum_cash_reserve == 5000000)
assert(actions[3].collect_mode == "bank")

gc.require = function(name)
  if name == "shared_items" then return dofile("scripts/shared/items.lua") end
  error("unexpected module " .. name)
end
local loadouts = dofile("scripts/shared/loadouts.lua")
local state = {
  inventory = { items = { { id = 100, quantity = 1 } } },
  equipment = { items = {} },
  bank = { items = { { id = 100, quantity = 2 } } },
}
local missing = loadouts.missing(state, {
  { id = 100, name = "Test item", quantity = 4, maximum_unit_price = 10 },
})
assert(#missing == 1 and missing[1].quantity == 1)

print("shared catalog mechanics tests passed")
