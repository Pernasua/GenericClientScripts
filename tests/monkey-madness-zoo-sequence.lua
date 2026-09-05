local config = dofile("scripts/quest-runner/monkey_madness_i/config.lua")
assert(config.npcs.elder_guard == 5278,
  "Awowogei access must use Quest Helper's MM_ELDER_GUARD_2")
local geometry = dofile("scripts/shared/geometry.lua")
local player = { name = "genericBoss", world = { x = 2608, y = 3278, plane = 0 } }
local inventory = { [config.items.mspeak_amulet] = 1, [config.items.karamjan_greegree] = 1 }
local equipment = {}
local checkpoints = {}
local events = {}
local monkey_talk_attempts = 0
local dialogue = { type = "closed" }
local exit_ticks
local gate_open = false
local gate_dialogue = false
local monkey_chatter_continues = 0
local interrupt_next_walk = false
local stale_dialogue_reads = 0
local monkey_chatter_in_progress = false
local zoo_monkey_dialogue_lines = 0
local zoo_monkey_dialogue_continues = 0
local pending_continuation
local chatter_response = "genericBoss"
local interrupt_speaker = "The monkey in your backpack..."
local omit_continuation = false

local function items(values)
  local result = {}
  for id, quantity in pairs(values) do
    if quantity > 0 then result[#result + 1] = { id = id, quantity = quantity } end
  end
  return { items = result }
end

local function equipped(id)
  return (equipment[id] or 0) > 0
end

local equipment_actions = {
  equip = function(id, action)
    events[#events + 1] = { type = "equip", id = id }
    if id == config.items.mspeak_amulet then
      assert(action == "Wear", "wrong M'speak amulet equip action")
    elseif id == config.items.karamjan_greegree then
      assert(action == "Hold", "wrong live greegree equip action")
    end
    if equipped(id) then return { status = "unchanged" } end
    assert((inventory[id] or 0) > 0, "equipped item was not carried")
    inventory[id] = inventory[id] - 1
    equipment[id] = 1
    return { status = "complete" }
  end,
  unequip = function(id)
    events[#events + 1] = { type = "unequip", id = id }
    if not equipped(id) then return { status = "unchanged" } end
    equipment[id] = 0
    inventory[id] = (inventory[id] or 0) + 1
    return { status = "complete" }
  end,
}

local areas
gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then
      if not areas then areas = dofile("scripts/quest-runner/monkey_madness_i/areas.lua") end
      return areas
    end
    if name == "shared_behaviors" then
      return {
        configure = function(options)
          events[#events + 1] = {
            type = "behaviors.configure",
            emergency_escape = options.emergency_escape,
          }
          return true, { status = "complete" }
        end,
      }
    end
    if name == "shared_equipment" then return equipment_actions end
    if name == "shared_geometry" then return geometry end
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    if name == "monkey_madness_preparation" then
      return { arm_safety = function() return true, { status = "complete" } end }
    end
    if name == "monkey_madness_navigation" then return {} end
    if name == "monkey_madness_ape_atoll" then
      return {
        execute = function(options)
          events[#events + 1] = { type = "ape_atoll.execute" }
          assert(options and options.policy.breaks == false and options.keyboard == true,
            "monkey-carry transit allowed behavior-profile breaks")
          assert((inventory[config.items.zoo_monkey] or 0) == 1,
            "zoo monkey disappeared before Ape Atoll travel")
          player.world = { x = 2770, y = 2707, plane = 0 }
          return { status = "complete" }
        end,
      }
    end
    if name == "shared_travel" then
      return {
        has_dueling_ring = function() return false end,
        teleport_to_castle_wars = function() error("zoo sequence attempted a teleport") end,
      }
    end
    if name == "shared_ui" then return dofile("scripts/shared/ui.lua") end
    if name == "shared_wait" then return dofile("scripts/shared/wait.lua") end
    error("unexpected module " .. name)
  end,
  read = function(subject, query)
    if subject == "player" then return player end
    if subject == "inventory" then return items(inventory) end
    if subject == "equipment" then return items(equipment) end
    if subject == "dialogue" then
      if stale_dialogue_reads > 0 then
        stale_dialogue_reads = stale_dialogue_reads - 1
        return { type = "closed" }
      end
      return dialogue
    end
    if subject == "npcs" then
      local id = query.id
      if id == config.npcs.monkey_minder then
        return { { id = id, world = config.points.ardougne_zoo_minder } }
      end
      if id == config.npcs.zoo_monkey[1] then
        return { { id = id, world = config.points.ardougne_zoo_monkey } }
      end
      return {}
    end
    if subject == "objects" then
      if query.id == config.objects.marim_gate and query.action == "Open" and not gate_open then
        return { { id = query.id, world = config.points.marim_gate_south } }
      end
      if query.id == config.objects.marim_gate_open[2] and gate_open then
        return { { id = query.id, world = config.points.marim_gate_south } }
      end
      return {}
    end
    error("unexpected read " .. subject)
  end,
  await = function(request)
    if request.event == "game.tick" then
      stale_dialogue_reads = 0
      if exit_ticks then
        exit_ticks = exit_ticks - 1
        if exit_ticks == 0 then
          player.world = { x = 2608, y = 3278, plane = 0 }
          exit_ticks = nil
        end
      end
      return { status = "observed" }
    end
    local action = request.action
    events[#events + 1] = action
    if action.type == "npc.interact" then
      if action.id == config.npcs.monkey_minder then
        if areas.in_monkey_pen(player.world) then
          assert(not equipped(config.items.karamjan_greegree),
            "greegree remained equipped while leaving the monkey pen")
          dialogue = { type = "continue" }
        else
          assert(equipped(config.items.mspeak_amulet) and
            equipped(config.items.karamjan_greegree),
            "monkey disguise was not equipped before entering the pen")
          player.world = { x = 2602, y = 3278, plane = 0 }
        end
        return { status = "dispatched" }
      end
      if action.id == config.npcs.zoo_monkey[1] then
        assert(areas.in_monkey_pen(player.world), "zoo monkey was approached outside the pen")
        monkey_talk_attempts = monkey_talk_attempts + 1
        if monkey_talk_attempts > 1 then
          inventory[config.items.zoo_monkey] = 1
          zoo_monkey_dialogue_lines = 2
          dialogue = { type = "continue", speaker = "Monkey" }
        end
        return { status = "dispatched" }
      end
    end
    if action.type == "walk.to" then
      assert(action.interrupt_on and action.interrupt_on.dialogue == true,
        "favor walk did not allow blocking dialogue to yield back to Lua")
      if interrupt_next_walk then
        interrupt_next_walk = false
        dialogue = { type = "continue", speaker = interrupt_speaker }
        stale_dialogue_reads = 1
        pending_continuation = not omit_continuation and "monkey-chatter-1" or nil
        return {
          status = "interrupted",
          reason = "dialogue",
          dialogue = dialogue,
          continuation = pending_continuation,
        }
      end
      assert(action.resume == pending_continuation,
        "monkey chatter restarted its journey instead of resuming the interrupted walk")
      pending_continuation = nil
      player.world = action.destination
      return { status = "arrived" }
    end
    if action.type == "object.interact" and action.id == config.objects.marim_gate then
      dialogue = { type = "continue", speaker = "Kruk" }
      gate_dialogue = true
      return { status = "dispatched" }
    end
    if action.type == "dialogue.continue" then
      local speaker = dialogue.speaker
      dialogue = { type = "closed" }
      if speaker == "The monkey in your backpack..." then
        monkey_chatter_continues = monkey_chatter_continues + 1
        monkey_chatter_in_progress = true
        dialogue = { type = "continue", speaker = chatter_response }
      elseif monkey_chatter_in_progress then
        monkey_chatter_continues = monkey_chatter_continues + 1
        monkey_chatter_in_progress = false
      elseif zoo_monkey_dialogue_lines > 0 then
        zoo_monkey_dialogue_continues = zoo_monkey_dialogue_continues + 1
        zoo_monkey_dialogue_lines = zoo_monkey_dialogue_lines - 1
        if zoo_monkey_dialogue_lines > 0 then
          dialogue = { type = "continue", speaker = "genericBoss" }
        end
      elseif gate_dialogue then
        gate_open = true
        gate_dialogue = false
        player.world = config.points.marim_gate_north
      else
        exit_ticks = 5
      end
      return { status = "dispatched" }
    end
    error("unexpected action " .. action.type)
  end,
  activity = function() end,
  checkpoint = function(key, value)
    if value ~= nil then checkpoints[key] = value end
    return checkpoints[key]
  end,
  clear_checkpoint = function(key)
    checkpoints[key] = nil
    events[#events + 1] = { type = "checkpoint.clear", key = key }
  end,
}

local favor = dofile("scripts/quest-runner/monkey_madness_i/favor.lua")
local obtained = favor.obtain_zoo_monkey()
assert(obtained.status == "complete", obtained.status)
assert(monkey_talk_attempts == 2,
  "a dispatched zoo-monkey click with no dialogue or item change was not retried")
assert(zoo_monkey_dialogue_continues == 2,
  "dialogue stopped before closing after its completion predicate became true")
assert((inventory[config.items.zoo_monkey] or 0) == 1, "zoo monkey was not received")
assert(equipped(config.items.mspeak_amulet), "M'speak amulet was removed")
assert(not equipped(config.items.karamjan_greegree),
  "greegree was not removed before speaking to the minder again")
assert(not areas.in_monkey_pen(player.world), "player did not leave the monkey pen")

player.world = { x = 2530, y = 3360, plane = 0 }
dialogue = { type = "continue", speaker = "The monkey in your backpack..." }
interrupt_next_walk = true
events = {}
local carried = favor.carry_monkey_to_ape_atoll()
assert(carried.status == "complete", carried.status)
assert(monkey_chatter_continues == 4,
  "backpack-monkey dialogue sequences were not cleared before and during critical movement")
local first_walk
local walks = 0
for _, event in ipairs(events) do
  if event.type == "walk.to" then
    first_walk = first_walk or event.destination
    walks = walks + 1
  end
end
assert(geometry.distance(first_walk, { x = 2466, y = 3482, plane = 0 }) == 0,
  "monkey carry must request its destination directly from the observed position")
assert(walks == 3, "monkey carry added route legs beyond its interrupted journey and Marim approach")
assert(areas.in_north(player.world), "player did not enter Marim with the monkey")
assert((inventory[config.items.zoo_monkey] or 0) == 1,
  "zoo monkey disappeared during the no-teleport route")
assert(equipped(config.items.mspeak_amulet) and equipped(config.items.karamjan_greegree),
  "monkey disguise was not restored before entering Marim")

player.world = { x = 2530, y = 3360, plane = 0 }
dialogue = { type = "continue", speaker = "The monkey in your backpack..." }
chatter_response = "Kruk"
events = {}
local changed = favor.carry_monkey_to_ape_atoll()
assert(changed.status == "monkey_madness_monkey_chatter_changed", changed.status)
assert(dialogue.speaker == "Kruk", "monkey chatter consumed a different NPC's dialogue")
assert(#events == 2 and events[2].type == "dialogue.continue",
  "foreign dialogue must stop monkey travel immediately after the owned line")

dialogue = { type = "closed" }
monkey_chatter_in_progress = false
interrupt_speaker = "Kruk"
interrupt_next_walk = true
events = {}
local foreign = favor.carry_monkey_to_ape_atoll()
assert(foreign.status == "interrupted" and foreign.dialogue.speaker == "Kruk", foreign.status)
assert(#events == 2 and events[2].type == "walk.to",
  "foreign dialogue must return the interruption without continuing or moving again")

dialogue = { type = "closed" }
stale_dialogue_reads = 0
interrupt_speaker = "The monkey in your backpack..."
interrupt_next_walk = true
omit_continuation = true
events = {}
local unresumable = favor.carry_monkey_to_ape_atoll()
assert(unresumable.status == "interrupted" and not unresumable.continuation, unresumable.status)
assert(#events == 2 and events[2].type == "walk.to",
  "an interruption without a continuation must not silently start a fresh journey")

print("monkey madness zoo sequence tests passed")
