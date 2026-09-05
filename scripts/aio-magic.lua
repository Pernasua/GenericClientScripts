-- genericclient-interface: 2

local config = gc.require("config")
local behaviors = gc.require("shared_behaviors")
local item_queries = gc.require("shared_items")
local ui = gc.require("shared_ui")
local progress = gc.require("progress")
local supplies = gc.require("supplies")
local preparation = gc.require("preparation")
local training = gc.require("training")
local superheat_training = gc.require("superheat")
local alchemy_training = gc.require("alchemy")

local target_xp = config.target_xp
local methods = config.methods
local has_equipped = supplies.has_equipped
local has_loadout = supplies.has_loadout
local plan_for = supplies.plan_for
local spell_for_level = supplies.spell_for_level
local overlay = progress.show
local ensure_at_ge = preparation.ensure_at_ge
local prepare_loadout = preparation.prepare_loadout
local equip_staff = preparation.equip_staff
local recover_hitpoints = training.recover_hitpoints
local disengage = training.disengage
local available_target = training.available_target
local wait_for_target = training.wait_for_target
local travel_to_method = training.travel_to_method

local function run_post_43(options)
  local smithing = gc.read("skills").smithing
  if smithing.level >= config.superheat.minimum_smithing_level then
    return superheat_training.run(options)
  end
  return alchemy_training.run(options)
end

return {
  inputs = {
    {
      id = "target_level",
      label = "Target level",
      type = "choice",
      default = "20",
      choices = {
        { value = "13", label = "13" },
        { value = "20", label = "20" },
        { value = "30", label = "30" },
        { value = "50", label = "50" },
      },
    },
    {
      id = "method",
      label = "Method",
      type = "choice",
      default = "auto",
      choices = {
        { value = "auto", label = "Auto" },
        { value = "port_sarim_jail", label = "Port Sarim jail corridor" },
      },
    },
    {
      id = "restock",
      label = "Restock",
      type = "choice",
      default = "ge",
      choices = {
        { value = "ge", label = "Grand Exchange" },
        { value = "bank_only", label = "Bank only" },
      },
    },
  },

  actions = {
    { id = "stop_after_cast", label = "Stop after cast" },
  },

  run = function(input)
    local target = assert(tonumber(input.target_level), "Invalid target level")
    local required_xp = assert(target_xp[input.target_level], "Unsupported target level")
    local automatic = input.method == "auto"
    local method_id = automatic and "port_sarim_jail" or input.method
    local method = assert(methods[method_id], "Unknown Magic method")
    assert(target <= method.maximum_level,
      method.label .. " is not implemented above level " .. tostring(method.maximum_level))

    gc.await { event = "game.tick" }
    local start = gc.read("skills").magic
    progress.begin(start.xp)
    if start.xp >= required_xp or start.level >= target then
      overlay(target, "Target already met")
      ui.park_mouse()
      return { status = "already_complete", level = start.level, xp = start.xp }
    end

    if automatic and start.level >= config.superheat.minimum_level then
      return run_post_43 {
        target = target,
        required_xp = required_xp,
        start_xp = start.xp,
        restock = input.restock,
      }
    end

    local combat_required_xp = automatic and
      math.min(required_xp, config.superheat.unlock_xp) or required_xp
    local plan = plan_for(input.target_level, start, combat_required_xp)
    overlay(target, "Securing combat")
    local configured, behavior_failure = behaviors.configure {
      auto_retaliate = false,
      emergency_escape = true,
      combat_prayer = false,
    }
    if not configured then return behavior_failure end

    local safety = gc.await {
      action = {
        type = "safety.configure",
        minimum_hitpoints = 1,
        consumables = {
          { id = 1993, action = "Drink", heal_amount = 11 },
        },
        continue_after_consumable = true,
        escape = method.escape,
      },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
    }
    if safety.status ~= "complete" then
      return { status = "safety_guard_failed", receipt = safety }
    end

    if not has_loadout(plan) then
      local at_ge, ge_error = ensure_at_ge(target)
      if not at_ge then
        return ge_error
      end
      local prepared, prepare_error = prepare_loadout(plan, input.restock, target)
      if not prepared then
        gc.log("error", "magic-preparation-failed", prepare_error)
        return prepare_error
      end
    end
    local initial_spell = spell_for_level(start.level)
    local equipped, equip_error = equip_staff(
      initial_spell.staff_id, target, initial_spell.staff_name)
    if not equipped then
      return equip_error
    end

    local arrived, travel_error = travel_to_method(method, target)
    if not arrived then
      return { status = "training_travel_failed", receipt = travel_error }
    end
    gc.phase("magic." .. method_id .. ".arrived", { activity = "skilling" })

    local stop_requested = false
    local configured_spell = nil
    local autocast_enabled = false
    local consecutive_attack_failures = 0
    while true do
      local dialogue = gc.read("dialogue")
      if dialogue.type == "continue" then
        local continued = gc.await {
          action = { type = "dialogue.continue" },
          policy = { breaks = false, cursor_release = "none", fidget = "none" },
          timeout = { game_ticks = 20 },
        }
        if continued.status ~= "dispatched" then
          return { status = "combat_dialogue_failed", receipt = continued }
        end
        gc.await { event = "game.tick" }
      end
      local magic = gc.read("skills").magic
      if magic.xp >= combat_required_xp or magic.level >= target then
        break
      end
      if gc.next_action() == "stop_after_cast" then
        stop_requested = true
      end
      if stop_requested then
        overlay(target, "Stopped")
        disengage(method)
        ui.park_mouse()
        return { status = "stopped", level = magic.level, xp = magic.xp }
      end

      local recovered, recovery_error = recover_hitpoints(target)
      if not recovered then
        disengage(method)
        ui.park_mouse()
        return recovery_error
      end

      local spell = spell_for_level(magic.level)
      if not has_equipped(spell.staff_id) then
        equipped, equip_error = equip_staff(spell.staff_id, target, spell.staff_name)
        if not equipped then
          return equip_error
        end
      end
      if configured_spell ~= spell.id then
        overlay(target, "Setting autocast")
        local autocast = gc.await {
          action = { type = "combat.set_autocast", spell = spell.id },
          policy = { breaks = false, cursor_release = "none", fidget = "none" },
          timeout = { game_ticks = 30 },
        }
        if autocast.status == "set" or autocast.status == "unchanged" then
          autocast_enabled = true
        elseif autocast.status == "unsupported" then
          autocast_enabled = false
        else
          disengage(method)
          ui.park_mouse()
          return {
            status = "autocast_setup_failed",
            spell = spell.id,
            level = magic.level,
            xp = magic.xp,
            receipt = autocast,
          }
        end
        configured_spell = spell.id
      end
      local inventory = gc.read("inventory")
      local missing_runes = false
      for _, rune in ipairs(spell.runes) do
        if item_queries.quantity(inventory, rune.id) < rune.quantity then
          missing_runes = true
          break
        end
      end
      if missing_runes then
        overlay(target, "Supplies exhausted")
        disengage(method)
        ui.park_mouse()
        return { status = "supplies_exhausted", level = magic.level, xp = magic.xp, spell = spell.id }
      end

      local target_npc = available_target(method)
      if not target_npc then
        overlay(target, "Waiting for target")
        target_npc = wait_for_target(method, 100)
        if not target_npc then
          disengage(method)
          ui.park_mouse()
          return { status = "target_unavailable", level = magic.level, xp = magic.xp }
        end
      end

      overlay(target, spell.label .. (autocast_enabled and " · Auto" or ""))
      local before_xp = magic.xp
      local before_tick = gc.read("runtime").game_tick
      local attack
      if autocast_enabled then
        attack = gc.await {
          action = {
            type = "npc.interact",
            id = target_npc.id,
            action = "Attack",
            within = method.npc_radius,
          },
          timeout = { game_ticks = 30 },
        }
      else
        attack = gc.await {
          action = {
            type = "combat.cast",
            spell = spell.id,
            npc_id = target_npc.id,
            within = method.npc_radius,
          },
          timeout = { game_ticks = 30 },
        }
      end
      if attack.status ~= "dispatched" then
        consecutive_attack_failures = consecutive_attack_failures + 1
        gc.log("warn", "magic-attack-retry", attack)
        if consecutive_attack_failures >= 5 then
          disengage(method)
          ui.park_mouse()
          return {
            status = "attack_unavailable",
            spell = spell.id,
            level = magic.level,
            xp = magic.xp,
            receipt = attack,
          }
        end
        gc.await { ticks = 2 }
      else
        local changed = false
        local idle_ticks = 0
        local quiet_ticks = 0
        local observed_xp = before_xp
        local observation_ticks = autocast_enabled and 80 or 8
        for _ = 1, observation_ticks do
          gc.await { event = "game.tick" }
          magic = gc.read("skills").magic
          if magic.xp > observed_xp then
            changed = true
            observed_xp = magic.xp
            quiet_ticks = 0
          else
            quiet_ticks = quiet_ticks + 1
          end
          if autocast_enabled then
            overlay(target, spell.label .. " · Auto")
            if gc.read("player").interacting then
              idle_ticks = 0
            else
              idle_ticks = idle_ticks + 1
            end
            if changed and idle_ticks >= 2 then
              break
            end
            if quiet_ticks >= 12 or (not changed and idle_ticks >= 5) then
              break
            end
          elseif changed then
            break
          end
        end
        if changed then
          consecutive_attack_failures = 0
        else
          consecutive_attack_failures = consecutive_attack_failures + 1
          gc.log("warn", "magic-xp-unchanged", {
            spell = spell.id,
            target = target_npc.name,
            target_id = target_npc.id,
            xp = before_xp,
            messages = gc.read("messages", { since_tick = before_tick, limit = 5 }),
          })
          if consecutive_attack_failures >= 5 then
            disengage(method)
            ui.park_mouse()
            return {
              status = "attack_unconfirmed",
              spell = spell.id,
              target = target_npc.name,
              target_id = target_npc.id,
              level = magic.level,
              xp = magic.xp,
            }
          end
        end
      end
    end

    if automatic and combat_required_xp < required_xp then
      disengage(method)
      return run_post_43 {
        target = target,
        required_xp = required_xp,
        start_xp = start.xp,
        restock = input.restock,
      }
    end

    local final = gc.read("skills").magic
    overlay(target, "Complete")
    local disengaged = disengage(method)
    ui.park_mouse()
    gc.phase("magic.target_reached")
    local result = {
      status = "complete",
      target_level = target,
      start_xp = start.xp,
      final_xp = final.xp,
      gained_xp = final.xp - start.xp,
      final_level = final.level,
      method = method_id,
      disengage = disengaged,
    }
    gc.log("info", "magic-complete", result)
    return result
  end,
}
