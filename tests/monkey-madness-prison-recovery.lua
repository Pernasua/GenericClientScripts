local function point(x, y)
  return { x = x, y = y, plane = 0 }
end

local config = {
  id = "monkey_madness_i",
  label = "Monkey Madness I",
  varbits = { garkor = 126 },
  zones = {
    ape_atoll_prison = { x1 = 2764, x2 = 2776, y1 = 2793, y2 = 2802, plane = 0 },
    prison_west_clear = { x1 = 2762, x2 = 2764, y1 = 2797, y2 = 2799, plane = 0 },
    prison_north_exit = { x1 = 2777, x2 = 2790, y1 = 2798, y2 = 2810, plane = 0 },
    ape_atoll_south = { x1 = 2687, x2 = 2820, y1 = 2687, y2 = 2737, plane = 0 },
    ape_atoll_south_corridor_wide = { x1 = 2713, x2 = 2737, y1 = 2738, y2 = 2743, plane = 0 },
    ape_atoll_south_corridor_narrow = { x1 = 2718, x2 = 2726, y1 = 2744, y2 = 2765, plane = 0 },
    ape_atoll_north = { x1 = 2682, x2 = 2816, y1 = 2766, y2 = 2817, plane = 0 },
    ape_atoll_north_west = { x1 = 2687, x2 = 2716, y1 = 2738, y2 = 2765, plane = 0 },
    ape_atoll_north_east = { x1 = 2735, x2 = 2815, y1 = 2730, y2 = 2765, plane = 0 },
    temple_melee_threshold = { x1 = 2787, x2 = 2787, y1 = 2784, y2 = 2789, plane = 0 },
    temple_guard_building = { x1 = 2787, x2 = 2808, y1 = 2773, y2 = 2793, plane = 0 },
    temple_dungeon = { x1 = 2777, x2 = 2818, y1 = 9185, y2 = 9219, plane = 0 },
  },
  points = {
    garkor = point(2807, 2762),
    prison_start = point(2771, 2794),
    prison_safe_spot = point(2769, 2795),
    prison_guard_prime = point(2772, 2796),
    prison_guard_lock = point(2772, 2798),
    prison_guard_return = point(2772, 2800),
    prison_guard_stage = point(2772, 2801),
    prison_guard_follow = point(2771, 2801),
    prison_clear = point(2762, 2804),
    temple_trapdoor = point(2807, 2785),
  },
  routes = {
    ape_atoll_valley = {},
    prison_to_temple_entry = { point(2787, 2787) },
    temple_trapdoor_approach = { point(2806, 2784) },
    prison_to_garkor = { destination = point(2807, 2762), within = 2,
      via = { point(2784, 2806), point(2784, 2770), point(2807, 2770) } },
  },
  npcs = {
    prison_standby_guard = 5247,
    prison_patrol_guard = 5248,
    crate_spider = 5238,
    temple_guards = { 5275, 5276 },
  },
  objects = { jail_door = 4799 },
  items = { lockpick = 1523 },
}

local player = {
  name = "genericBoss",
  world = point(2769, 2795),
  animation = -1,
  current_hitpoints = 28,
  max_hitpoints = 28,
  run_energy = 10000,
}
local spider_present = true
local spider_attacking = false
local poison = 0
local tick = 1
local actions = {}
local timeline = {}
local one_shot_player_world
local dialogue_type = "closed"
local post_walk_stale_world
local auto_retaliate = false
local valley_protection_actions = {}
local recapture_next_walk = false
local walk_interrupts = {}
local stamina_effect = 100
local occluded_archers = false
local guard_scenario = false
local guard_x = 2772
local guard_y = 2796
local prison_phase
local door_closed = true
local reclose_door = false
local cross_on_lockpick = false

local function copy(value)
  if not value then return nil end
  return { x = value.x, y = value.y, plane = value.plane }
end

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then
      return dofile("scripts/quest-runner/monkey_madness_i/areas.lua")
    end
    if name == "monkey_madness_preparation" then
      return { arm_safety = function() return true end }
    end
    if name == "shared_behaviors" then
      return dofile("scripts/shared/behaviors.lua")
    end
    if name == "shared_consumables" then
      return {
        stamina_interrupts = function(energy)
          return dofile("scripts/shared/consumables.lua").stamina_interrupts(energy)
        end,
        ensure_stamina = function()
          return true, { status = "unchanged", result = "stamina_already_active" }
        end,
      }
    end
    if name == "shared_geometry" then
      return dofile("scripts/shared/geometry.lua")
    end
    if name == "shared_items" then
      return dofile("scripts/shared/items.lua")
    end
    if name == "shared_movement" then
      return dofile("scripts/shared/movement.lua")
    end
    if name == "shared_equipment" then return {} end
    if name == "shared_protection" then
      return {
        enable = function(style)
          valley_protection_actions[#valley_protection_actions + 1] = "enable:" .. style
          return true, { status = "complete" }
        end,
        disable = function(style)
          valley_protection_actions[#valley_protection_actions + 1] = "disable:" .. style
          return true, { status = "complete" }
        end,
      }
    end
    error("unexpected module " .. name)
  end,
  read = function(kind, query)
    if kind == "player" then
      if one_shot_player_world then
        local world = one_shot_player_world
        one_shot_player_world = nil
        return {
          world = world,
          animation = player.animation,
          current_hitpoints = player.current_hitpoints,
          max_hitpoints = player.max_hitpoints,
        }
      end
      return player
    end
    if kind == "runtime" then return { game_tick = tick } end
    if kind == "dialogue" then return { type = dialogue_type } end
    if kind == "messages" then return {} end
    if kind == "inventory" then
      return { items = {
        { id = config.items.lockpick, quantity = 1 },
        { id = 2448, quantity = 1 },
      } }
    end
    if kind == "vars" then return { varps = { [102] = poison }, varbits = { [25] = stamina_effect, [126] = 0 } } end
    if kind == "objects" then
      if query and query.id == config.objects.jail_door and door_closed then
        return { { id = config.objects.jail_door, world = point(2770, 2796), actions = { "Pick-lock" } } }
      end
      return {}
    end
    if kind == "npcs" then
      if guard_scenario and query and query.id == config.npcs.prison_standby_guard then
        return { {
          id = config.npcs.prison_standby_guard,
          world = point(guard_x, guard_y),
          dead = false,
        } }
      end
      if occluded_archers and (not query or not query.id) then
        return { {
          id = 5274,
          world = point(2777, 2790),
          interacting = player.name,
          in_scene = true,
          clickable = false,
          line_of_sight = false,
          dead = false,
        } }
      end
      if spider_present and (not query or not query.id or
        query.id == config.npcs.crate_spider) then
        return { {
          id = config.npcs.crate_spider,
          index = 19009,
          world = point(2766, 2797),
          interacting = spider_attacking and player.name or nil,
          in_scene = true,
          clickable = true,
          line_of_sight = true,
          dead = false,
        } }
      end
      return {}
    end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event == "game.tick" then
      timeline[#timeline + 1] = "tick"
      tick = tick + 1
      if guard_scenario and prison_phase == "prison_lockpick_primed" then
        guard_x = 2772
        guard_y = 2798
      elseif guard_scenario and prison_phase == "prison_exit_primed" then
        guard_x = 2771
        guard_y = 2801
      end
      if reclose_door then
        door_closed = true
        reclose_door = false
      end
      if auto_retaliate and spider_present and spider_attacking then
        spider_present = false
        spider_attacking = false
        player.world = point(2767, 2795)
      end
      return { status = "observed" }
    end
    local action = request.action
    actions[#actions + 1] = action
    local destination = action.destination
    timeline[#timeline + 1] = action.type ..
      (action.action and ":" .. action.action or "") ..
      (destination and ":" .. destination.x .. "," .. destination.y or "")
    if action.type == "npc.interact" then
      spider_present = false
      player.world = point(2767, 2795)
      return { status = "dispatched", result = "npc_interaction_dispatched" }
    end
    if action.type == "dialogue.continue" then
      dialogue_type = "closed"
      return { status = "dispatched", result = "dialogue_continued" }
    end
    if action.type == "consumable.cure_poison" then
      if poison > 0 then
        local before = poison
        poison = -20
        return {
          status = "complete",
          result = "poison_cured",
          poison_before = before,
          poison_after = poison,
        }
      end
      return {
        status = "unchanged",
        result = poison < 0 and "antipoison_active" or "poison_not_active",
      }
    end
    if action.type == "client.behaviors.configure" then
      auto_retaliate = action.auto_retaliate
      return { status = "complete", result = "behaviors_configured" }
    end
    if action.type == "walk.to" then
      if #walk_interrupts > 0 then
        local result = table.remove(walk_interrupts, 1)
        if result.reason == "varbit_equals" then stamina_effect = 0 end
        if result.reason == "poisoned" then poison = 30 end
        return result
      end
      if recapture_next_walk then
        recapture_next_walk = false
        player.world = point(2771, 2794)
        return { status = "interrupted", reason = "area", detail = "prison", continuation = "captured" }
      end
      player.world = copy(action.destination)
      if post_walk_stale_world then
        one_shot_player_world = post_walk_stale_world
        post_walk_stale_world = nil
      end
      return { status = "arrived", reached = copy(action.destination) }
    end
    if action.type == "walk.click" then
      player.world = copy(action.destination)
      return { status = "dispatched", result = "one_shot_tile_click" }
    end
    if action.type == "object.interact" then
      if cross_on_lockpick and action.action == "Pick-lock" then
        player.world = point(2771, 2796)
        door_closed = false
        reclose_door = true
      end
      return { status = "dispatched" }
    end
    return { status = "unchanged" }
  end,
  activity = function() end,
  state = function(value)
    prison_phase = value
    if guard_scenario and value == "prison_wait_lockpick_prime" then
      guard_x = 2772
      guard_y = 2796
    elseif guard_scenario and value == "prison_wait_exit_prime" then
      guard_x = 2772
      guard_y = 2801
    end
  end,
  overlay = function() end,
  log = function() end,
}

local garkor = dofile("scripts/quest-runner/monkey_madness_i/garkor.lua")

player.world = copy(config.points.prison_clear)
recapture_next_walk = true
actions = {}
local recaptured = garkor.execute()
assert(recaptured.status == "monkey_madness_recaptured_on_garkor_route", recaptured.status)
local recapture_walks = {}
for _, action in ipairs(actions) do
  if action.type == "walk.to" then recapture_walks[#recapture_walks + 1] = action end
end
assert(#recapture_walks == 1 and #recapture_walks[1].via == 3,
  "recapture handling lost the northern corridor or started another walk")
assert(recapture_walks[1].interrupt_on.area.name == "prison", "capture was not declared to the walker")

config.routes.ape_atoll_valley = { destination = point(2771, 2794), within = 2 }
player.world = point(2746, 2720)
spider_present = false
poison = 0
actions = {}
valley_protection_actions = {}
walk_interrupts = {
  { status = "interrupted", reason = "varbit_equals", continuation = "stamina-path" },
  { status = "interrupted", reason = "poisoned", continuation = "poison-path" },
}
local valley = garkor.reach_prison()
assert(valley.status == "complete", valley.status)
assert(valley_protection_actions[1] == "enable:missiles",
  "valley rush did not enable missile protection")
assert(valley_protection_actions[2] == "disable:missiles",
  "prison arrival did not release missile protection")
local valley_walks = {}
for _, action in ipairs(actions) do
  if action.type == "walk.to" then valley_walks[#valley_walks + 1] = action end
end
assert(#valley_walks == 3 and valley_walks[2].resume == "stamina-path" and valley_walks[3].resume == "poison-path",
  "valley upkeep restarted the journey instead of preserving its continuation")
assert(valley_walks[1].interrupt_on.varbit_equals and valley_walks[2].interrupt_on.run_energy_below == 60,
  "valley upkeep did not change its wait condition after stamina expired at high energy")
assert(poison < 0, "poison interruption did not run the existing cure handler")
stamina_effect = 100
poison = 0
config.routes.ape_atoll_valley = {}

player.world = point(2771, 2794)
spider_present = true
spider_attacking = false
actions = {}
local passive_defence = garkor.settle_combat(point(2771, 2794))
assert(passive_defence.status == "complete", passive_defence.status)
for _, action in ipairs(actions) do
  assert(action.type ~= "npc.interact", "self-defence issued a bespoke NPC attack")
  assert(action.type ~= "prayer.set", "self-defence activated a protection prayer")
end
assert(auto_retaliate == true, "ordinary questing did not enable auto-retaliate")

player.world = point(2771, 2794)
player.interacting = nil
spider_present = false
occluded_archers = true
actions = {}
local occluded_defence = garkor.settle_combat(point(2771, 2794), 6)
assert(occluded_defence.status == "complete",
  "unreachable archers blocked the prison timing loop")
occluded_archers = false

player.world = point(2771, 2794)
player.interacting = nil
spider_present = false
guard_scenario = true
guard_x = 2772
guard_y = 2796
door_closed = true
reclose_door = false
cross_on_lockpick = true
prison_phase = nil
actions = {}
timeline = {}
local threshold_escape = garkor.escape_prison({ stop_at_safe_spot = true })
assert(threshold_escape.status == "complete",
  "crossing the jail threshold was not accepted as a successful pick")
assert(player.world.x == config.points.prison_safe_spot.x and
  player.world.y == config.points.prison_safe_spot.y,
  "threshold recovery did not continue forward to the safe spot")
local lockpick_index
for index, event in ipairs(timeline) do
  if event == "object.interact:Pick-lock" then lockpick_index = index end
end
assert(lockpick_index and timeline[lockpick_index + 1] == "walk.to:2769,2795",
  "threshold crossing did not immediately continue to the prison safe spot")
guard_scenario = false
cross_on_lockpick = false
door_closed = true

player.world = point(2771, 2794)
player.interacting = nil
spider_present = false
spider_attacking = false
guard_scenario = true
guard_x = 2772
guard_y = 2796
door_closed = true
reclose_door = false
cross_on_lockpick = true
prison_phase = nil
actions = {}
valley_protection_actions = {}
local full_escape = garkor.escape_prison()
assert(full_escape.status == "complete", full_escape.status)
assert(full_escape.result == "ape_atoll_prison_exited", full_escape.result)
assert(player.world.x == config.points.prison_clear.x and
  player.world.y == config.points.prison_clear.y,
  "full prison escape did not finish outside the prison")
local timed_retaliation_disabled = false
for _, action in ipairs(actions) do
  if action.type == "client.behaviors.configure" then
    assert(action.combat_prayer == false,
      "prison escape delegated prayer control to the combat guard")
    if action.auto_retaliate == false then timed_retaliation_disabled = true end
  end
end
assert(timed_retaliation_disabled,
  "prison escape did not disable auto-retaliate for the exit dash")
assert(valley_protection_actions[#valley_protection_actions] == "enable:missiles",
  "prison escape did not explicitly enable missile protection before leaving")
local prison_exit_journeys = 0
for _, action in ipairs(actions) do
  if action.type == "walk.to" and
    action.destination.x == config.points.prison_clear.x and
    action.destination.y == config.points.prison_clear.y then
    prison_exit_journeys = prison_exit_journeys + 1
    assert(action.within == 0, "prison egress did not require the observed safe tile")
  end
  assert(action.type ~= "walk.click", "prison egress bypassed the journey owner")
end
assert(prison_exit_journeys == 1, "prison egress was split into independent walks")
guard_scenario = false
cross_on_lockpick = false
door_closed = true

player.world = point(2771, 2794)
spider_present = true
spider_attacking = true
actions = {}
local hostile_defence = garkor.settle_combat(point(2771, 2794))
assert(hostile_defence.status == "complete", hostile_defence.status)
assert(player.world.x == 2771 and player.world.y == 2794,
  "self-defence did not restore its caller anchor")
for _, action in ipairs(actions) do
  assert(action.type ~= "npc.interact", "self-defence issued a bespoke NPC attack")
  assert(action.type ~= "prayer.set", "self-defence activated a protection prayer")
end

spider_attacking = false

local healthy = garkor.refresh_antipoison()
assert(healthy.status == "unchanged", "healthy player consumed antipoison")
assert(poison == 0, "healthy poison state changed")

poison = 6
local cured = garkor.refresh_antipoison()
assert(cured.status == "complete", "active poison was not cured")
assert(poison < 0, "antipoison protection was not observed")

poison = 6
player.world = point(2771, 2794)
dialogue_type = "continue"
actions = {}
local captured = garkor.reach_prison()
assert(captured.status == "complete", captured.status)
assert(poison < 0, "prison arrival did not cure forced poison")
local used_generic_poison_cure = false
local capture_dialogue_index
local poison_index
for index, action in ipairs(actions) do
  if not capture_dialogue_index and action.type == "dialogue.continue" then
    capture_dialogue_index = index
  end
  if not poison_index and action.type == "consumable.cure_poison" then poison_index = index end
  if action.type == "consumable.cure_poison" then used_generic_poison_cure = true end
end
assert(used_generic_poison_cure, "prison arrival did not use the generic poison cure")
assert(capture_dialogue_index and poison_index and capture_dialogue_index < poison_index,
  "prison arrival tried to cure poison before draining capture dialogue")
local ordinary_retaliation_enabled = false
for _, action in ipairs(actions) do
  assert(action.type ~= "prayer.set", "prison arrival activated a protection prayer")
  if action.type == "client.behaviors.configure" and action.auto_retaliate == true then
    ordinary_retaliation_enabled = true
  end
end
assert(ordinary_retaliation_enabled,
  "prison arrival did not restore ordinary auto-retaliation")

player.world = point(2771, 2794)
spider_present = false
spider_attacking = false
poison = -20
actions = {}
one_shot_player_world = point(2771, 2796)
local transient = garkor.escape_prison()
assert(transient.status == "monkey_madness_guard_lock_window_not_observed",
  transient.status)
local first_walk
for _, action in ipairs(actions) do
  if action.type == "walk.to" then
    first_walk = action
    break
  end
end
assert(first_walk and
  first_walk.destination.x == config.points.prison_start.x and
  first_walk.destination.y == config.points.prison_start.y,
  "transient topology tried to cross the closed door toward the safe spot")

player.world = point(2769, 2796)
spider_present = false
spider_attacking = false
poison = -20
actions = {}
post_walk_stale_world = point(2769, 2796)
local stale_safe_spot = garkor.escape_prison()
assert(stale_safe_spot.status == "monkey_madness_prison_exit_prime_not_observed",
  stale_safe_spot.status)

player.world = point(2771, 2794)
spider_present = true
spider_attacking = true
poison = -20
actions = {}
dialogue_type = "continue"
local dialogue_first = garkor.escape_prison()
assert(dialogue_first.status == "monkey_madness_prison_exit_prime_not_observed",
  dialogue_first.status)
local dialogue_index
for index, action in ipairs(actions) do
  if not dialogue_index and action.type == "dialogue.continue" then dialogue_index = index end
  assert(action.type ~= "npc.interact", "prison recovery issued a bespoke spider attack")
end
assert(dialogue_index, "capture dialogue was not drained before prison recovery")

player.world = point(2769, 2795)
spider_present = true
spider_attacking = false
dialogue_type = "closed"
actions = {}
local safe = garkor.reach_prison_safe_spot()
assert(safe.status == "complete", safe.status)
assert(safe.result == "ape_atoll_prison_safe_spot_reached", safe.result)
assert(player.world.x == 2769 and player.world.y == 2795, "safe scope moved off anchor")

actions = {}
local escaped = garkor.escape_prison()
assert(escaped.status == "monkey_madness_prison_exit_prime_not_observed", escaped.status)
assert(player.world.x == 2769 and player.world.y == 2795, "safe anchor not restored")
for _, action in ipairs(actions) do
  assert(not (action.type == "walk.to" and
    action.destination.x == config.points.prison_start.x and
    action.destination.y == config.points.prison_start.y), "requested prison_start")
  assert(not (action.type == "object.interact" and action.action == "Pick-lock"), "requested Pick-lock")
end

local teleports = 0
local post_escape_walks = 0
local protection_actions = {}
local mock_player = { world = point(2771, 2794) }
gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then
      return dofile("scripts/quest-runner/monkey_madness_i/areas.lua")
    end
    if name == "monkey_madness_preparation" then
      return { arm_safety = function() return true end }
    end
    if name == "monkey_madness_garkor" then
      return { reach_prison = function()
        return { status = "monkey_madness_valley_walk_failed" }
      end, escape_prison = function()
        mock_player.world = copy(config.points.prison_clear)
        return { status = "complete", result = "ape_atoll_prison_exited" }
      end, travel_interrupts = function() return {} end,
        maintain_stamina = function() return true end }
    end
    if name == "shared_behaviors" then
      return dofile("scripts/shared/behaviors.lua")
    end
    if name == "shared_geometry" then
      return dofile("scripts/shared/geometry.lua")
    end
    if name == "shared_items" then
      return dofile("scripts/shared/items.lua")
    end
    if name == "shared_movement" then
      return dofile("scripts/shared/movement.lua")
    end
    if name == "shared_equipment" then return {} end
    if name == "shared_travel" then
      return { teleport_to_castle_wars = function()
        teleports = teleports + 1
        return { status = "complete" }
      end }
    end
    if name == "shared_protection" then
      return {
        enable = function(style)
          protection_actions[#protection_actions + 1] = "enable:" .. style
          return true, { status = "complete" }
        end,
        disable = function(style)
          protection_actions[#protection_actions + 1] = "disable:" .. style
          return true, { status = "complete" }
        end,
      }
    end
    error("unexpected module " .. name)
  end,
  read = function(kind)
    if kind == "player" then return mock_player end
    if kind == "npcs" then return {} end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.action and request.action.type == "walk.to" then
      post_escape_walks = post_escape_walks + 1
      mock_player.world = request.action.destination
      return { status = "arrived", reached = request.action.destination }
    end
    return { status = "complete" }
  end,
  activity = function() end,
}

local amulet_crafting = dofile(
  "scripts/quest-runner/monkey_madness_i/amulet_crafting.lua")
local local_failure = amulet_crafting.reach_prison()
assert(local_failure.status == "monkey_madness_valley_walk_failed")
assert(local_failure.recovery_attempted == false)
assert(teleports == 0, "local prison failure rubbed a ring")

local safe_escape = amulet_crafting.escape_prison()
assert(safe_escape.status == "complete", safe_escape.status)
assert(post_escape_walks == 0, "escape phase duplicated the next objective's route")
assert(#protection_actions == 0,
  "amulet wrapper duplicated garkor-owned exit protection")
assert(safe_escape.player.world.x == config.points.prison_clear.x and
  safe_escape.player.world.y == config.points.prison_clear.y)

local phases = { "obtain_monkey_talisman" }
local phase_index = 1
local executions = {}
gc = {
  require = function(name)
    if name == "monkey_madness_config" then
      return { id = "monkey_madness_i", label = "Monkey Madness I" }
    end
    if name == "shared_behaviors" then
      return dofile("scripts/shared/behaviors.lua")
    end
    if name == "shared_state" then
      return { read = function()
        return {
          phase = phases[phase_index],
          varp = 3,
          varbits = {},
          player = { world = point(2775, 2793) },
        }
      end }
    end
    if name == "monkey_madness_state" then
      return { resolve = function(state) return state.phase end }
    end
    if name == "monkey_madness_quest" then
      return {
        execute = function(phase)
          executions[#executions + 1] = phase
          phase_index = phase_index + 1
          return { status = "complete", result = phase .. "_complete" }
        end,
        reach_prison_cell = function(input)
          executions[#executions + 1] = "reach_prison_cell:" .. input.restock
          return { status = "complete", result = "ape_atoll_prison_safe_spot_reached" }
        end,
      }
    end
    error("unexpected module " .. name)
  end,
  await = function() return { status = "complete" } end,
  state = function() end,
  overlay = function() end,
}

local runner = dofile("scripts/quest-runner/monkey_madness_i/runner.lua")
local bounded = runner.run({ scope = "prison_cell", restock = "ge" })
assert(bounded.status == "escape_prison_for_amulet", bounded.status)
assert(#executions == 1, "prison scope should use one staging operation")
assert(executions[1] == "reach_prison_cell:ge")

phases = {
  "escape_prison_for_amulet",
  "make_mspeak_amulet",
  "obtain_monkey_talisman",
  "complete",
}
phase_index = 1
executions = {}
runner = dofile("scripts/quest-runner/monkey_madness_i/runner.lua")
local completed = runner.run({ scope = "complete" })
assert(completed.status == "complete", completed.status)
assert(#executions == 3, "complete scope stopped at an intermediate phase")
assert(executions[1] == "escape_prison_for_amulet")
assert(executions[2] == "make_mspeak_amulet")
assert(executions[3] == "obtain_monkey_talisman")

print("monkey madness prison recovery tests passed")
