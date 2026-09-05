local config = dofile("scripts/quest-runner/monkey_madness_i/config.lua")
local player
local stage
local dialogue
local actions
local journeys
local armed
local cure_failure
local walk_failure
local poison_interrupt
local choice_changes
local talking_to
local geometry

local function point(x, y, plane) return { x = x, y = y, plane = plane or 0 } end
local function same(first, second) return geometry.distance(first, second) == 0 end
local hangar = point(2649, 4516)
local crash = point(2894, 2726)
local south = point(2803, 2706)
local intervention = "I cannot convince Lumdo to take us to the island..."

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_navigation" then
      return dofile("scripts/quest-runner/monkey_madness_i/navigation.lua")
    end
    if name == "monkey_madness_preparation" then
      return { arm_safety = function() armed = true; return true end }
    end
    if name == "shared_geometry" then return geometry end
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    if name == "shared_travel" then return {} end
    error("unexpected module " .. name)
  end,
  activity = function() end,
  read = function(kind, query)
    if kind == "player" then return { world = player } end
    if kind == "dialogue" then return dialogue end
    if kind == "vars" then return { varbits = { [125] = stage } } end
    if kind == "npcs" then return { { id = query.id, world = player, actions = { "Talk-to" } } } end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event then return { status = "observed" } end
    assert(armed, "travel began before emergency safety was armed")
    local action = request.action
    actions[#actions + 1] = action
    if action.type == "consumable.cure_poison" then
      return cure_failure or { status = "unchanged" }
    end
    if action.type == "walk.to" then
      journeys[#journeys + 1] = request
      assert(action.interrupt_on.dialogue, "service travel does not preserve foreign dialogue")
      if same(action.destination, south) then
        assert(actions[#actions - 1].type == "consumable.cure_poison", "sailing skipped its poison check")
        assert(stage >= 3, "sailing bypassed Waydar's intervention")
        if poison_interrupt then
          poison_interrupt = false
          return { status = "interrupted", reason = "poisoned", continuation = "lumdo-crossing" }
        end
      end
      if walk_failure then return walk_failure end
      player = action.destination
      return { status = "arrived", reached = player }
    end
    if action.type == "npc.interact" then
      assert(action.action == "Talk-to", "repeat transport still dispatches NPC input from Lua")
      talking_to = action.id
      if stage < 2 then
        assert(talking_to == config.npcs.lumdo[1], "initial refusal did not involve Lumdo")
        dialogue = { type = "continue" }
      else
        assert(stage == 2 and talking_to == config.npcs.waydar[1], "repeat service conversation remained in Lua")
        dialogue = { type = "choice", options = { { text = intervention } } }
      end
      return { status = "dispatched" }
    end
    if action.type == "dialogue.choose" then
      assert(action.text == intervention, "quest intervention choice changed")
      if choice_changes then
        dialogue = { type = "continue" }
        return { status = "rejected", result = "exact_dialogue_choice_not_visible" }
      end
      stage = 3
      dialogue = { type = "closed" }
      return { status = "dispatched" }
    end
    if action.type == "dialogue.continue" then
      stage = talking_to == config.npcs.lumdo[1] and 2 or 3
      dialogue = { type = "closed" }
      return { status = "dispatched" }
    end
    error("unexpected action " .. action.type)
  end,
}
geometry = dofile("scripts/shared/geometry.lua")
local ape_atoll = dofile("scripts/quest-runner/monkey_madness_i/ape_atoll.lua")

local function reset(world, lumdo_stage)
  player = world
  stage = lumdo_stage or 3
  dialogue = { type = "closed" }
  actions, journeys = {}, {}
  armed = false
  cure_failure, walk_failure, talking_to = nil, nil, nil
  poison_interrupt, choice_changes = false, false
end

reset(config.points.daero)
local result = ape_atoll.execute()
assert(result.status == "complete" and result.result == "ape_atoll_reached")
assert(#journeys == 3 and same(journeys[1].action.destination, hangar) and
  same(journeys[2].action.destination, crash) and same(journeys[3].action.destination, south),
  "repeat services did not preserve hangar, Crash Island and poison-check boundaries")

reset(hangar)
assert(ape_atoll.execute().status == "complete" and #journeys == 2)
reset(crash)
assert(ape_atoll.execute({ policy = { breaks = false, cursor_release = "none", fidget = "none" } }).status == "complete" and #journeys == 1)
assert(journeys[1].policy.breaks == false)
reset(crash, 1)
assert(ape_atoll.execute().status == "complete" and stage == 3 and #journeys == 1,
  "native boat travel bypassed the initial quest conversations")
reset(crash, 2)
choice_changes = true
assert(ape_atoll.execute().status == "complete" and stage == 3,
  "the intervention failed when its selected choice became a continue page")

reset(crash)
poison_interrupt = true
assert(ape_atoll.execute().status == "complete" and #journeys == 2)
assert(journeys[2].action.resume == "lumdo-crossing", "poison upkeep restarted the boat instead of resuming it")
reset(crash)
cure_failure = { status = "rejected", result = "no_poison_cure" }
assert(ape_atoll.execute() == cure_failure and #journeys == 0)
reset(hangar)
walk_failure = { status = "interrupted", reason = "dialogue", continuation = "waydar" }
assert(ape_atoll.execute() == walk_failure and #actions == 1,
  "foreign service dialogue was consumed or followed by another action")
reset(south)
assert(ape_atoll.execute().status == "complete" and armed and #actions == 0)

print("monkey madness Ape Atoll service and quest conversation tests passed")
