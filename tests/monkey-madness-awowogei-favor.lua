local config = dofile("scripts/quest-runner/monkey_madness_i/config.lua")
local geometry = dofile("scripts/shared/geometry.lua")
local player = { world = { x = 2730, y = 2766, plane = 0 } }
local inventory = { [config.items.zoo_monkey] = 1 }
local equipment = {
  [config.items.mspeak_amulet] = 1,
  [config.items.karamjan_greegree] = 1,
}
local checkpoints = {}
local events = {}
local dialogue = { type = "closed" }
local dialogue_lines = 0
local dialogue_finished
local throne_conversations = 0
local guard_conversations = 0
local garkor_attempts = 0
local chapter_open = false
local chapter_closes = 0

local function items(values)
  local result = {}
  for id, quantity in pairs(values) do
    if quantity > 0 then result[#result + 1] = { id = id, quantity = quantity } end
  end
  return { items = result }
end

local function open_dialogue(lines, finished)
  dialogue_lines = lines
  dialogue_finished = finished
  dialogue = { type = "continue", speaker = "test" }
end

local function action_index(kind, id, occurrence)
  local seen = 0
  for index, action in ipairs(events) do
    if action.type == kind and action.id == id then
      seen = seen + 1
      if seen == (occurrence or 1) then return index end
    end
  end
end

local function walked_to(point)
  for _, action in ipairs(events) do
    if action.type == "walk.to" and geometry.distance(action.destination, point) == 0 then
      return true
    end
  end
  return false
end

local areas
gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then
      if not areas then areas = dofile("scripts/quest-runner/monkey_madness_i/areas.lua") end
      return areas
    end
    if name == "shared_behaviors" then
      return { configure = function() return true, { status = "complete" } end }
    end
    if name == "shared_equipment" then
      return {
        equip = function(id)
          assert((equipment[id] or 0) > 0, "favor attempted to replace the equipped disguise")
          return { status = "unchanged" }
        end,
      }
    end
    if name == "shared_geometry" then return geometry end
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    if name == "monkey_madness_preparation" then return {} end
    if name == "monkey_madness_navigation" then return {} end
    if name == "monkey_madness_ape_atoll" then return {} end
    if name == "shared_travel" then return {} end
    if name == "shared_ui" then return dofile("scripts/shared/ui.lua") end
    if name == "shared_wait" then return dofile("scripts/shared/wait.lua") end
    error("unexpected module " .. name)
  end,
  read = function(subject, query)
    if subject == "player" then return player end
    if subject == "inventory" then return items(inventory) end
    if subject == "equipment" then return items(equipment) end
    if subject == "dialogue" then return dialogue end
    if subject == "widgets" then
      if query.group == config.interfaces.chapter_message and chapter_open then
        return { { group_id = config.interfaces.chapter_message } }
      end
      return {}
    end
    if subject == "vars" then
      return {
        varps = { [config.varp] = 4 },
        varbits = { [config.varbits.garkor] = 4 },
      }
    end
    if subject == "npcs" then
      assert(query.id ~= 5277, "favor queried the wrong Elder Guard")
      if query.id == config.npcs.elder_guard then
        return { { id = config.npcs.elder_guard, world = config.points.elder_guard } }
      end
      if query.id == config.npcs.kruk then
        return { { id = config.npcs.kruk, world = config.points.kruk } }
      end
      if query.id == config.npcs.garkor[1] then
        return { { id = config.npcs.garkor[1], world = config.points.garkor } }
      end
      return {}
    end
    if subject == "objects" then
      local points = {
        [config.objects.east_watchtower_ladder] = config.points.east_watchtower_ladder,
        [config.objects.west_bridge_ladder] = config.points.west_bridge_ladder,
        [config.objects.west_watchtower_ladder] = config.points.west_watchtower_ladder,
        [config.objects.east_bridge_ladder] = config.points.east_bridge_ladder,
        [config.objects.awowogei_throne] = config.points.awowogei_throne,
      }
      local world = points[query.id]
      if world then return { { id = query.id, world = world } } end
      return {}
    end
    error("unexpected read " .. subject)
  end,
  await = function(request)
    if request.event == "game.tick" then return { status = "observed" } end
    local action = request.action
    events[#events + 1] = action
    if action.type == "walk.to" then
      assert(action.interrupt_on and action.interrupt_on.dialogue == true, "favor walk did not yield to dialogue")
      player.world = action.destination
      return { status = "arrived" }
    end
    if action.type == "npc.interact" then
      if action.id == config.npcs.elder_guard then
        guard_conversations = guard_conversations + 1
        open_dialogue(2, guard_conversations >= 2 and function()
          player.world = { x = 2802, y = 2758, plane = 0 }
        end or nil)
        return { status = "dispatched" }
      end
      if action.id == config.npcs.kruk then
        open_dialogue(2, function()
          player.world = { x = 2803, y = 2765, plane = 0 }
        end)
        return { status = "dispatched" }
      end
      if action.id == config.npcs.garkor[1] then
        garkor_attempts = garkor_attempts + 1
        if garkor_attempts == 1 then
          open_dialogue(2, function() chapter_open = true end)
          return { status = "dispatched" }
        end
        if garkor_attempts == 2 then
          return { status = "rejected", result = "hover_has_no_matching_action" }
        end
        open_dialogue(2, function() inventory[config.items.squad_sigil] = 1 end)
        return { status = "dispatched" }
      end
    end
    if action.type == "object.interact" then
      if action.id == config.objects.east_watchtower_ladder then
        player.world = config.points.east_bridge_ladder
      elseif action.id == config.objects.west_bridge_ladder then
        player.world = config.points.west_watchtower_ladder
      elseif action.id == config.objects.west_watchtower_ladder then
        player.world = config.points.west_bridge_ladder
      elseif action.id == config.objects.east_bridge_ladder then
        player.world = config.points.east_watchtower_ladder
      elseif action.id == config.objects.awowogei_throne then
        throne_conversations = throne_conversations + 1
        open_dialogue(2, function()
          if throne_conversations >= 2 then inventory[config.items.zoo_monkey] = 0 end
        end)
      else
        error("unexpected object " .. tostring(action.id))
      end
      return { status = "dispatched" }
    end
    if action.type == "ui.close" then
      assert(chapter_open, "closed UI without an open chapter message")
      chapter_open = false
      chapter_closes = chapter_closes + 1
      return { status = "dispatched" }
    end
    if action.type == "dialogue.continue" then
      assert(dialogue.type == "continue", "continued a closed dialogue")
      dialogue_lines = dialogue_lines - 1
      if dialogue_lines > 0 then
        dialogue = { type = "continue", speaker = "test" }
      else
        dialogue = { type = "closed" }
        local finished = dialogue_finished
        dialogue_finished = nil
        if finished then finished() end
      end
      return { status = "dispatched" }
    end
    error("unexpected action " .. tostring(action.type))
  end,
  activity = function() end,
  checkpoint = function(key, value)
    if value ~= nil then
      checkpoints[key] = value
      events[#events + 1] = { type = "checkpoint.set", key = key }
    end
    return checkpoints[key]
  end,
  clear_checkpoint = function(key)
    checkpoints[key] = nil
    events[#events + 1] = { type = "checkpoint.clear", key = key }
  end,
}

local favor = dofile("scripts/quest-runner/monkey_madness_i/favor.lua")
local result = favor.secure_awowogei_favor()
assert(result.status == "complete", result.status)
assert((inventory[config.items.zoo_monkey] or 0) == 0, "Awowogei did not accept the monkey")
assert(throne_conversations == 2, "Awowogei was not spoken to twice")
assert(checkpoints[config.checkpoints.awowogei_guard_authorized] == nil,
  "guard authorization checkpoint survived completed favor")
assert(walked_to(config.points.west_bridge_ladder_approach),
  "reverse bridge traversal did not use the live-proven ladder stance")
assert(walked_to(config.points.east_bridge_ladder_approach),
  "outbound bridge traversal did not use the live-proven ladder stance")

local return_up = action_index("object.interact", config.objects.east_watchtower_ladder)
local return_down = action_index("object.interact", config.objects.west_bridge_ladder)
local guard = action_index("npc.interact", config.npcs.elder_guard)
local outbound_up = action_index("object.interact", config.objects.west_watchtower_ladder)
local outbound_down = action_index("object.interact", config.objects.east_bridge_ladder)
local kruk = action_index("npc.interact", config.npcs.kruk)
local throne_first = action_index("object.interact", config.objects.awowogei_throne, 1)
local throne_second = action_index("object.interact", config.objects.awowogei_throne, 2)
assert(return_up and return_down and guard and outbound_up and outbound_down and kruk and
  throne_first and throne_second, "favor sequence omitted a required interaction")
assert(return_up < return_down and return_down < guard and guard < outbound_up and
  outbound_up < outbound_down and outbound_down < kruk and kruk < throne_first and
  throne_first < throne_second, "favor sequence interactions were out of order")

local sigil = favor.obtain_sigil()
assert(sigil.status == "complete", sigil.status)
assert((inventory[config.items.squad_sigil] or 0) == 1, "Garkor did not provide the squad sigil")
assert(garkor_attempts == 3, "cutscene and transient Garkor interaction were not resumed")
assert(chapter_closes == 1, "post-cutscene chapter message was not closed exactly once")
local release = action_index("npc.interact", config.npcs.elder_guard, 2)
assert(release ~= nil, "sigil sequence did not ask the Elder Guard to leave the throne room")
assert(action_index("npc.interact", config.npcs.garkor[1]) ~= nil,
  "sigil sequence did not talk directly to Garkor")
local garkor = action_index("npc.interact", config.npcs.garkor[1])
assert(release < garkor, "sigil sequence talked to Garkor before leaving the throne room")
for index = release + 1, garkor - 1 do
  assert(events[index].type ~= "walk.to",
    "sigil sequence walked before using an already-interactable Garkor")
end

print("monkey madness Awowogei favor tests passed")
