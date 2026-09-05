local banking = gc.require("shared_bank")
local behaviors = gc.require("shared_behaviors")
local config = gc.require("config")
local item_queries = gc.require("shared_items")
local preparation = gc.require("preparation")
local progress = gc.require("progress")
local ui = gc.require("shared_ui")

local method = config.superheat

local function remaining_casts(current_xp, required_xp)
  if current_xp >= required_xp then return 0 end
  return math.ceil((required_xp - current_xp) / method.xp_per_cast)
end

local function supply_plan(casts)
  return {
    {
      id = method.staff_id,
      name = "Staff of fire",
      quantity = 1,
      maximum_unit_price = 2000,
    },
    {
      id = method.nature_rune.id,
      name = method.nature_rune.name,
      quantity = casts,
      maximum_unit_price = method.nature_rune.maximum_unit_price,
    },
    {
      id = method.ore.id,
      name = method.ore.name,
      quantity = casts,
      maximum_unit_price = method.ore.maximum_unit_price,
    },
  }
end

local function load_batch(target, casts)
  return gc.intent("magic.load_superheat_batch", function()
    local bank, bank_error = banking.open()
    if not bank then return nil, bank_error end

    local ore_count = math.min(method.batch_size, casts)
    progress.show(target, "Loading iron ore")
    local loadout = gc.await {
      action = {
        type = "bank.loadout",
        items = {
          { id = method.staff_id, quantity = 1 },
          { id = method.nature_rune.id, quantity = casts },
          { id = method.ore.id, quantity = ore_count },
        },
        minimum_free_slots = 0,
        close = true,
      },
      timeout = { game_ticks = 240 },
    }
    if loadout.status ~= "complete" then
      return nil, { status = "superheat_loadout_failed", receipt = loadout }
    end

    local equipped, equip_error = preparation.equip_staff(
      method.staff_id, target, method.staff_name)
    if not equipped then
      return nil, { status = "superheat_staff_failed", receipt = equip_error }
    end
    return ore_count
  end)
end

local function wait_for_cast(before_xp, before_ore, ticks)
  for _ = 1, ticks do
    gc.await { event = "game.tick" }
    local magic = gc.read("skills").magic
    local ore = item_queries.inventory_quantity(method.ore.id)
    if magic.xp > before_xp and ore < before_ore then
      return magic
    end
  end
  return nil
end

local function stop_result(target, start_xp)
  local magic = gc.read("skills").magic
  progress.show(target, "Stopped")
  ui.park_mouse()
  return {
    status = "stopped",
    method = "superheat_iron",
    level = magic.level,
    xp = magic.xp,
    gained_xp = magic.xp - start_xp,
  }
end

local function run(options)
  local target = options.target
  local required_xp = options.required_xp
  local start_xp = options.start_xp
  local restock = options.restock

  local smithing = gc.read("skills").smithing
  if smithing.level < method.minimum_smithing_level then
    return {
      status = "superheat_smithing_required",
      smithing_level = smithing.level,
      required_smithing_level = method.minimum_smithing_level,
    }
  end

  local configured, behavior_failure = behaviors.configure {
    auto_retaliate = true,
    emergency_consumables = false,
    emergency_escape = false,
    combat_prayer = false,
  }
  if not configured then return behavior_failure end
  gc.await { action = { type = "safety.clear" }, policy = { breaks = false, cursor_release = "none", fidget = "none" } }

  local at_ge, ge_error = preparation.ensure_at_ge(target)
  if not at_ge then return ge_error end
  gc.phase("magic.superheat.bank", { activity = "skilling" })

  local magic = gc.read("skills").magic
  local casts = remaining_casts(magic.xp, required_xp)
  local supplied, supply_error = preparation.ensure_supplies(
    supply_plan(casts), restock, target, "bank")
  if not supplied then
    return supply_error
  end

  local cast_failures = 0
  local completed_casts = 0
  while true do
    magic = gc.read("skills").magic
    if magic.xp >= required_xp or magic.level >= target then break end
    if gc.next_action() == "stop_after_cast" then
      return stop_result(target, start_xp)
    end

    casts = remaining_casts(magic.xp, required_xp)
    local loaded, load_error = load_batch(target, casts)
    if not loaded then return load_error end

    for _ = 1, loaded do
      magic = gc.read("skills").magic
      if magic.xp >= required_xp or magic.level >= target then break end
      if gc.next_action() == "stop_after_cast" then
        return stop_result(target, start_xp)
      end

      local before_xp = magic.xp
      local before_ore = item_queries.inventory_quantity(method.ore.id)
      if before_ore < 1 or item_queries.inventory_quantity(method.nature_rune.id) < 1 then
        return {
          status = "superheat_supplies_exhausted",
          level = magic.level,
          xp = magic.xp,
        }
      end

      progress.show(target, "Superheating iron")
      local cast = gc.await {
        action = {
          type = "spell.cast_on_item",
          spell = method.spell,
          item_id = method.ore.id,
        },
        timeout = { game_ticks = 20 },
      }
      if cast.status ~= "dispatched" then
        cast_failures = cast_failures + 1
        gc.log("warn", "superheat-cast-retry", cast)
      else
        local observed = wait_for_cast(before_xp, before_ore, 8)
        if observed then
          cast_failures = 0
          completed_casts = completed_casts + 1
        else
          cast_failures = cast_failures + 1
          gc.log("warn", "superheat-xp-unchanged", {
            xp = before_xp,
            ore = before_ore,
            receipt = cast,
          })
        end
      end
      if cast_failures >= 3 then
        return {
          status = "superheat_cast_unconfirmed",
          level = magic.level,
          xp = magic.xp,
          failures = cast_failures,
        }
      end
    end
  end

  local final = gc.read("skills").magic
  progress.show(target, "Complete")
  ui.park_mouse()
  gc.phase("magic.target_reached")
  local result = {
    status = "complete",
    target_level = target,
    start_xp = start_xp,
    final_xp = final.xp,
    gained_xp = final.xp - start_xp,
    final_level = final.level,
    method = "superheat_iron",
    completed_casts = completed_casts,
  }
  gc.log("info", "magic-complete", result)
  return result
end

return {
  remaining_casts = remaining_casts,
  supply_plan = supply_plan,
  run = run,
}
