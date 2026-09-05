local config = dofile("scripts/aio-magic/config.lua")

gc = {
  require = function(name)
    if name == "config" then return config end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    if name == "shared_loadouts" then return dofile("scripts/shared/loadouts.lua") end
    error("unexpected module " .. name)
  end,
}

local supplies = dofile("scripts/aio-magic/supplies.lua")

assert(config.target_xp["50"] == 101333)
assert(config.methods.port_sarim_jail.maximum_level == 50)
assert(config.superheat.minimum_level == 43)
assert(config.superheat.unlock_xp == 50339)
assert(config.superheat.minimum_smithing_level == 15)
assert(config.superheat.batch_size == 26)
assert(config.low_alchemy.minimum_level == 21)
assert(supplies.spell_for_level(34).id == "fire_strike")
assert(supplies.spell_for_level(35).id == "fire_bolt")

local plan = supplies.plan_for("50", { level = 35, xp = 24596 })
local by_id = {}
for _, item in ipairs(plan) do by_id[item.id] = item end

local casts = math.ceil((101333 - 24596) / 22.5)
assert(by_id[562].quantity == casts, "level-50 plan has the wrong Chaos rune count")
assert(by_id[556].quantity == casts * 3, "level-50 plan has the wrong Air rune count")
assert(by_id[558] == nil, "level-35 resume should not buy obsolete Mind runes")
assert(by_id[562].maximum_unit_price == 250)

local auto_plan = supplies.plan_for("50", { level = 35, xp = 24596 }, config.superheat.unlock_xp)
local auto_by_id = {}
for _, item in ipairs(auto_plan) do auto_by_id[item.id] = item end
local auto_casts = math.ceil((config.superheat.unlock_xp - 24596) / 22.5)
assert(auto_by_id[562].quantity == auto_casts,
  "auto plan should buy combat runes only through the Superheat unlock")
assert(auto_by_id[556].quantity == auto_casts * 3)

gc = {
  require = function(name)
    if name == "config" then return config end
    return {}
  end,
}
local superheat = dofile("scripts/aio-magic/superheat.lua")
local superheat_casts = math.ceil((101333 - 50645) / 53)
assert(superheat.remaining_casts(50645, 101333) == superheat_casts)
local superheat_plan = superheat.supply_plan(superheat_casts)
assert(superheat_plan[2].id == 561 and superheat_plan[2].quantity == superheat_casts)
assert(superheat_plan[3].id == 440 and superheat_plan[3].quantity == superheat_casts)
gc.read = function(name)
  assert(name == "skills")
  return { smithing = { level = 1 } }
end
local blocked_superheat = superheat.run {
  target = 50,
  required_xp = 101333,
  start_xp = 50645,
  restock = "ge",
}
assert(blocked_superheat.status == "superheat_smithing_required")
assert(blocked_superheat.required_smithing_level == 15)

gc = {
  require = function(name)
    if name == "config" then return config end
    return {}
  end,
}
local alchemy = dofile("scripts/aio-magic/alchemy.lua")
local alchemy_casts = math.ceil((101333 - 50645) / 31)
assert(alchemy.remaining_casts(50645, 101333) == alchemy_casts)
local alchemy_plan = alchemy.supply_plan(alchemy_casts)
assert(alchemy_plan[2].id == 561 and alchemy_plan[2].quantity == alchemy_casts)
assert(alchemy_plan[3].id == 890 and alchemy_plan[3].quantity == alchemy_casts)

local wealth_teleports = 0
local walks = 0
local has_ring = true
local player_world = { x = 2467, y = 3494, plane = 0 }
gc = {
  require = function(name)
    if name == "shared_geometry" then
      return {
        distance = function(a, b)
          if a.plane ~= b.plane then return 99999 end
          return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
        end,
      }
    end
    if name == "shared_travel" then
      return {
        has_wealth_ring = function() return has_ring end,
        teleport_to_grand_exchange = function()
          wealth_teleports = wealth_teleports + 1
          player_world = { x = 3162, y = 3477, plane = 0 }
          return { status = "complete" }
        end,
      }
    end
    if name == "progress" then return { show = function() end } end
    if name == "shared_bank" or name == "shared_equipment" or
      name == "shared_exchange" or name == "shared_loadouts" then return {} end
    error("unexpected module " .. name)
  end,
  read = function(name)
    if name == "objects" then return {} end
    assert(name == "player")
    return { world = player_world }
  end,
  await = function(request)
    assert(request.action.type == "walk.to")
    walks = walks + 1
    player_world = request.action.destination
    return { status = "arrived" }
  end,
}

local preparation = dofile("scripts/aio-magic/preparation.lua")
assert(preparation.ensure_at_ge(50))
assert(wealth_teleports == 1)
assert(walks == 1, "GE teleport landing should be followed by the final bank approach")

has_ring = false
player_world = { x = 3012, y = 3189, plane = 0 }
walks = 0
assert(preparation.ensure_at_ge(50))
assert(walks == 6, "Port Sarim should use staged projectable GE waypoints")

local observed_collect_mode
gc = {
  require = function(name)
    if name == "shared_bank" then
      return { open = function() return { items = {} } end }
    end
    if name == "shared_exchange" then
      return {
        buy = function(_, options)
          observed_collect_mode = options.collect_mode
          return true
        end,
      }
    end
    if name == "shared_loadouts" then
      return {
        missing = function()
          return { { id = 440, name = "Iron ore", quantity = 957, maximum_unit_price = 150 } }
        end,
      }
    end
    if name == "progress" then return { show = function() end } end
    return {}
  end,
  read = function(name)
    assert(name == "inventory" or name == "equipment")
    return { items = {} }
  end,
}
local collection_preparation = dofile("scripts/aio-magic/preparation.lua")
assert(collection_preparation.ensure_supplies(
  { { id = 440, name = "Iron ore", quantity = 957, maximum_unit_price = 150 } },
  "ge",
  50,
  "bank"))
assert(observed_collect_mode == "bank",
  "bulk Superheat supplies must collect directly to the bank")

local superheat_options
local alchemy_options
local smithing_level = 1
gc = {
  require = function(name)
    if name == "config" then return config end
    if name == "superheat" then
      return {
        run = function(options)
          superheat_options = options
          return { status = "routed_to_superheat" }
        end,
      }
    end
    if name == "alchemy" then
      return {
        run = function(options)
          alchemy_options = options
          return { status = "routed_to_alchemy" }
        end,
      }
    end
    if name == "progress" then return { begin = function() end, show = function() end } end
    if name == "shared_ui" then return { park_mouse = function() end } end
    if name == "supplies" then
      return {
        has_equipped = function() error("combat path should not run") end,
        has_loadout = function() error("combat path should not run") end,
        plan_for = function() error("combat path should not run") end,
        spell_for_level = function() error("combat path should not run") end,
      }
    end
    return {}
  end,
  await = function(request)
    assert(request.event == "game.tick")
    return {}
  end,
  read = function(name)
    assert(name == "skills")
    return {
      magic = { level = 43, xp = 50645 },
      smithing = { level = smithing_level, xp = 18 },
    }
  end,
}
local descriptor = dofile("scripts/aio-magic.lua")
local routed = descriptor.run { target_level = "50", method = "auto", restock = "ge" }
assert(routed.status == "routed_to_alchemy")
assert(alchemy_options.target == 50)
assert(alchemy_options.required_xp == 101333)
assert(alchemy_options.start_xp == 50645)
assert(alchemy_options.restock == "ge")

smithing_level = 15
routed = descriptor.run { target_level = "50", method = "auto", restock = "ge" }
assert(routed.status == "routed_to_superheat")
assert(superheat_options.target == 50)
assert(superheat_options.required_xp == 101333)
assert(superheat_options.start_xp == 50645)
assert(superheat_options.restock == "ge")

print("AIO Magic level-50 tests passed")
