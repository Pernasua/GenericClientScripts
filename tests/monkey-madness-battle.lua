local player = { name = "genericBoss", world = { x = 3162, y = 3487, plane = 0 } }
local demon_room = { x = 2715, y = 9180, plane = 1 }
local sigil_worn = false
local dialogue_mode = "closed"
local teleport_confirmed = false
local equipped_staff
local quest_stage = 5
local fight_started = false
local entry_dialogue_pending = false
local ticks_until_dialogue = 0
local events = {}

local config = {
  items = { squad_sigil = 4035, staff_of_fire = 1387 },
  npcs = { jungle_demon = 1443 },
  varp = 365,
}

local areas = {
  in_demon_room = function(world)
    return world.x == demon_room.x and world.y == demon_room.y and world.plane == demon_room.plane
  end,
}

local wait = {
  until_true = function(predicate)
    assert(type(predicate) == "function")
    assert(predicate())
    return true
  end,
}

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then return areas end
    if name == "shared_behaviors" then
      return { configure = function(options)
        events[#events + 1] = options.combat_prayer == false and
          "generic_prayer_disabled" or "generic_prayer_enabled"
        return true, { status = "complete" }
      end }
    end
    if name == "shared_equipment" then
      return { equip = function(id)
        equipped_staff = id
        return { status = "complete" }
      end }
    end
    if name == "shared_items" then
      return { inventory_quantity = function(id) return id == config.items.squad_sigil and 1 or 0 end }
    end
    if name == "monkey_madness_preparation" then
      return { arm_safety = function()
        events[#events + 1] = "safety"
        return true, { status = "complete" }
      end }
    end
    if name == "shared_protection" then
      return {
        enable = function()
          events[#events + 1] = "protect"
          return true, { status = "complete" }
        end,
        disable = function() return true, { status = "complete" } end,
      }
    end
    if name == "shared_wait" then return wait end
    error("unexpected module " .. name)
  end,
  read = function(topic)
    if topic == "player" then return player end
    if topic == "dialogue" then
      if dialogue_mode == "choice" then
        return {
          type = "choice",
          options = { { text = "Yes." }, { text = "No." } },
        }
      end
      if dialogue_mode == "continue" then return { type = "continue", options = {} } end
      return { type = "closed", options = {} }
    end
    if topic == "vars" then return { varps = { [config.varp] = quest_stage } } end
    if topic == "npcs" then
      if quest_stage < 6 then
        return { {
          id = config.npcs.jungle_demon,
          distance = 5,
          line_of_sight = true,
          dead = false,
          interacting = fight_started and "genericBoss" or nil,
        } }
      end
      return {}
    end
    if topic == "runtime" then return { game_tick = 10 } end
    error("unexpected read " .. topic)
  end,
  await = function(request)
    if request.event == "game.tick" then
      if entry_dialogue_pending then
        ticks_until_dialogue = ticks_until_dialogue - 1
        if ticks_until_dialogue <= 0 then
          entry_dialogue_pending = false
          dialogue_mode = "continue"
        end
      end
      if fight_started then quest_stage = 6 end
      return { status = "observed" }
    end
    local action = request.action
    if action and action.type == "combat.set_autocast" then
      assert(action.spell == "Fire Bolt")
      events[#events + 1] = "autocast"
      return { status = "set" }
    end
    if action and action.type == "item.interact" then
      sigil_worn = true
      dialogue_mode = "choice"
      return { status = "dispatched" }
    end
    if action and action.type == "dialogue.choose" then
      assert(action.text == "Yes.")
      dialogue_mode = "closed"
      teleport_confirmed = true
      player.world = demon_room
      return { status = "dispatched" }
    end
    if action and action.type == "dialogue.continue" then
      events[#events + 1] = "continue"
      dialogue_mode = "closed"
      return { status = "dispatched" }
    end
    if action and action.type == "npc.interact" then
      events[#events + 1] = "attack"
      fight_started = true
      return { status = "dispatched" }
    end
    error("unexpected await")
  end,
  activity = function() end,
}

local battle = dofile("scripts/quest-runner/monkey_madness_i/battle.lua")
local result = battle.enter()
assert(sigil_worn)
assert(teleport_confirmed)
assert(equipped_staff == config.items.staff_of_fire)
assert(result.status == "complete")
assert(result.result == "jungle_demon_room_entered")

events = {}
dialogue_mode = "closed"
quest_stage = 5
fight_started = false
entry_dialogue_pending = true
ticks_until_dialogue = 2
result = battle.fight()
assert(result.status == "complete")
assert(result.result == "jungle_demon_defeated")

local positions = {}
for index, event in ipairs(events) do positions[event] = positions[event] or index end
assert(positions.protect < positions.continue,
  "entry dialogue was continued before magic protection was active")
assert(positions.generic_prayer_disabled < positions.protect,
  "generic prayer behavior was not disabled before script-owned protection")
assert(positions.continue < positions.autocast,
  "autocast setup ran while the entry dialogue still blocked the combat interface")
assert(positions.autocast < positions.attack,
  "the demon was attacked before autocast was ready")

events = {}
quest_stage = 6
fight_started = false
player.world = { x = 3162, y = 3487, plane = 0 }
result = battle.fight()
assert(result.status == "complete")
assert(result.result == "jungle_demon_already_defeated")
assert(#events == 0,
  "an already-defeated demon should not reconfigure or restart combat")

print("monkey madness battle tests passed")
