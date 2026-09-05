local config = gc.require("waterfall_config")
local equipment_actions = gc.require("shared_equipment")
local geometry = gc.require("shared_geometry")
local item_queries = gc.require("shared_items")
local movement = gc.require("shared_movement")
local travel = gc.require("shared_travel")
local wait = gc.require("shared_wait")
local urgent_policy = { breaks = false, cursor_release = "none", fidget = "none" }

local function varp()
  return gc.read("vars", { varps = { 65 } }).varps[65]
end

local function drain_continue_dialogue(policy)
  for _ = 1, 20 do
    local dialogue = gc.read("dialogue")
    if dialogue.type == "closed" then return true end
    if dialogue.type ~= "continue" then
      return nil, { status = "rejected", result = "unexpected_open_dialogue", dialogue = dialogue }
    end
    local receipt = gc.await {
      action = { type = "dialogue.continue" },
      policy = policy,
      timeout = { game_ticks = 20 },
    }
    if receipt.status ~= "dispatched" then return nil, receipt end
    gc.await { event = "game.tick" }
  end
  return nil, { status = "timed_out", result = "dialogue_close_timeout" }
end

local function interact_object(id, action, world, policy, predicate, result)
  local drained, dialogue_failure = drain_continue_dialogue(policy)
  if not drained then return dialogue_failure end
  gc.await { action = { type = "ui.close" }, policy = policy }
  local near = movement.approach(world, 3, { policy = policy })
  if near.status ~= "arrived" then return near end
  local clicked = gc.await {
    action = {
      type = "object.interact",
      id = id,
      action = action,
      world = world,
      within = 4,
    },
    policy = policy,
    timeout = { game_ticks = 40 },
  }
  if clicked.status ~= "dispatched" then return clicked end
  if not wait.until_true(predicate, 30) then
    return { status = "timed_out", result = result .. "_unverified", receipt = clicked }
  end
  return { status = "complete", result = result, receipt = clicked }
end

local function use_on_object(item_id, object_id, world, predicate, result, within)
  local drained, dialogue_failure = drain_continue_dialogue()
  if not drained then return dialogue_failure end
  local interaction_radius = within or 4
  local near = movement.approach(world, interaction_radius)
  if near.status ~= "arrived" then return near end
  local clicked = gc.await {
    action = {
      type = "item.use_on_object",
      item_id = item_id,
      object_id = object_id,
      world = world,
      within = interaction_radius,
    },
    timeout = { game_ticks = 40 },
  }
  if clicked.status ~= "dispatched" then return clicked end
  if not wait.until_true(predicate, 30) then
    return { status = "timed_out", result = result .. "_unverified", receipt = clicked }
  end
  return { status = "complete", result = result, receipt = clicked }
end

local function open_and_cross(id, world, destination, predicate, result)
  local near = movement.approach(world, 3, { policy = urgent_policy })
  if near.status ~= "arrived" then return near end
  gc.await { event = "game.tick" }
  local matches = gc.read("objects", { id = id, action = "Open", within = 8, limit = 10 })
  local observed = nil
  local observed_distance = nil
  for _, object in ipairs(matches) do
    local candidate = math.max(
      math.abs(object.world.x - world.x),
      math.abs(object.world.y - world.y))
    if object.world.plane == world.plane and
      (observed_distance == nil or candidate < observed_distance) then
      observed = object
      observed_distance = candidate
    end
  end
  if not observed then
    return {
      status = "rejected",
      result = result .. "_object_unresolved",
      same_id = gc.read("objects", { id = id, within = 8, limit = 10 }),
      nearby = gc.read("objects", { within = 4, limit = 30 }),
    }
  end
  local opened = gc.await {
    action = {
      type = "object.interact",
      id = id,
      action = "Open",
      world = observed.world,
      within = 8,
    },
    policy = urgent_policy,
    timeout = { game_ticks = 40 },
  }
  opened.observed = observed
  if opened.status ~= "dispatched" then return opened end
  local crossed = movement.walk(destination, 0, { ticks = 120, policy = urgent_policy })
  if crossed.status ~= "arrived" or not predicate() then
    return { status = "timed_out", result = result .. "_unverified", open = opened, walk = crossed }
  end
  return { status = "complete", result = result, open = opened, walk = crossed }
end

local function talk(id, world, predicate, choice, policy)
  local near = movement.approach(world, 3, { policy = policy })
  if near.status ~= "arrived" then return near end
  local clicked = gc.await {
    action = { type = "npc.interact", id = id, action = "Talk-to", within = 10 },
    policy = policy,
    timeout = { game_ticks = 40 },
  }
  if clicked.status ~= "dispatched" then return clicked end
  local dialogue_receipts = {}
  local progressed = false
  local closed_ticks = 0
  for _ = 1, 80 do
    gc.await { event = "game.tick" }
    progressed = progressed or predicate()
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      closed_ticks = 0
      local receipt = gc.await {
        action = { type = "dialogue.continue" },
        policy = policy,
      }
      table.insert(dialogue_receipts, receipt)
      if receipt.status ~= "dispatched" then return receipt end
    elseif dialogue.type == "choice" then
      closed_ticks = 0
      local selected = nil
      for _, option in ipairs(dialogue.options) do
        if option.text == choice then selected = option.text break end
      end
      if not selected then
        return { status = "rejected", result = "unexpected_dialogue_choice", dialogue = dialogue }
      end
      local receipt = gc.await {
        action = { type = "dialogue.choose", text = selected },
        policy = policy,
      }
      table.insert(dialogue_receipts, receipt)
      if receipt.status ~= "dispatched" then return receipt end
    elseif progressed then
      closed_ticks = closed_ticks + 1
      if closed_ticks >= 2 then
        return {
          status = "complete",
          result = "dialogue_progress_verified",
          receipt = clicked,
          dialogue = dialogue_receipts,
        }
      end
    end
  end
  return { status = "timed_out", result = "dialogue_progress_timeout", varp = varp() }
end

local function reach_waterfall_area()
  local world = gc.read("player").world
  if math.max(math.abs(world.x - config.points.almera.x),
    math.abs(world.y - config.points.almera.y)) <= 150 then
    return { status = "complete", result = "already_near_waterfall" }
  end
  return travel.teleport_to_barbarian_outpost()
end

local function reach_gnome_area()
  local world = gc.read("player").world
  if math.max(math.abs(world.x - config.points.gnome_surface.x),
    math.abs(world.y - config.points.gnome_surface.y)) <= 150 then
    return { status = "complete", result = "already_near_gnome_village" }
  end
  return travel.teleport_to_castle_wars()
end

local function leave_gnome_dungeon()
  local teleported = travel.teleport_to_castle_wars({ policy = urgent_policy, keyboard = true })
  if teleported.status == "complete" then return teleported end
  return movement.walk(config.points.gnome_surface, 1, { ticks = 900, policy = urgent_policy })
end

local function escape_hostile_area()
  local world = gc.read("player").world
  if geometry.in_zone(world, config.zones.gnome_basement) then
    return leave_gnome_dungeon()
  end
  if geometry.in_zone(world, config.zones.hudon_island) or
    geometry.in_zone(world, config.zones.dead_tree_island) or
    geometry.in_zone(world, config.zones.ledge) or
    geometry.in_zone(world, config.zones.falls) or
    geometry.in_zone(world, config.zones.pillar_room) or
    geometry.in_zone(world, config.zones.chalice_room) then
    local teleported = travel.teleport_to_burthorpe({ policy = urgent_policy, keyboard = true })
    if teleported.status == "complete" then return teleported end
    return {
      status = "escape_failed",
      result = "waterfall_final_area_escape_failed",
      world = world,
      teleport = teleported,
    }
  end
  return { status = "complete", result = "not_in_gnome_dungeon" }
end

local function read_book()
  return gc.intent("waterfall.read_book", function()
    local opened = gc.await {
      action = { type = "item.interact", id = config.items.book, action = "Read" },
    }
    if opened.status ~= "dispatched" then return opened end
    local closed = nil
    for tick = 1, 30 do
      gc.await { event = "game.tick" }
      if varp() >= 3 then
        if not closed then
          closed = gc.await { action = { type = "ui.close" } }
        end
        return { status = "complete", result = "book_read", receipt = opened, close = closed }
      end
      local dialogue = gc.read("dialogue")
      if dialogue.type == "continue" then
        gc.await { action = { type = "dialogue.continue" } }
      elseif tick == 2 then
        closed = gc.await { action = { type = "ui.close" } }
      end
    end
    return { status = "timed_out", result = "book_read_unverified", receipt = opened, varp = varp() }
  end)
end

local function execute(phase)
  if phase == "accept" then
    local arrived = reach_waterfall_area()
    if arrived.status ~= "complete" then return arrived end
    return talk(config.npcs.almera, config.points.almera, function() return varp() >= 1 end, "Yes.")
  elseif phase == "reach_hudon" or phase == "reach_falls" then
    local arrived = reach_waterfall_area()
    if arrived.status ~= "complete" then return arrived end
    return movement.walk(config.points.hudon_landing, 1, { ticks = 900 })
  elseif phase == "talk_hudon" then
    return talk(config.npcs.hudon, config.points.hudon, function() return varp() >= 2 end, nil)
  elseif phase == "cross_to_tree" or phase == "cross_to_tree_final" then
    local edge = movement.walk(config.points.crossing_rock_stand, 0, { ticks = 120 })
    if edge.status ~= "arrived" then return edge end
    return use_on_object(
      config.items.rope, config.objects.crossing_rock, config.points.crossing_rock,
      function() return geometry.in_zone(gc.read("player").world, config.zones.dead_tree_island) end,
      "dead_tree_island_reached",
      10)
  elseif phase == "descend_tree" or phase == "descend_tree_final" then
    return use_on_object(
      config.items.rope, config.objects.overhanging_tree, config.points.overhanging_tree,
      function() return geometry.in_zone(gc.read("player").world, config.zones.ledge) end,
      "waterfall_ledge_reached")
  elseif phase == "leave_ledge" then
    return interact_object(
      config.objects.barrel, "Get in", config.points.barrel, urgent_policy,
      function()
        local world = gc.read("player").world
        return not geometry.in_zone(world, config.zones.ledge) and not geometry.in_zone(world, config.zones.dead_tree_island)
      end,
      "tourist_centre_reached")
  elseif phase == "reach_tourist_stairs" then
    return movement.walk(config.points.tourist_upstairs, 0, { ticks = 900 })
  elseif phase == "obtain_book" then
    return interact_object(
      config.objects.bookcase, "Search", config.points.bookcase, nil,
      function() return item_queries.inventory_quantity(config.items.book) > 0 end,
      "book_obtained")
  elseif phase == "read_book" then
    return read_book()
  elseif phase == "leave_tourist_house" then
    return movement.walk(config.points.tourist_ground, 0, { ticks = 900 })
  elseif phase == "reach_gnome_dungeon" then
    local arrived = reach_gnome_area()
    if arrived.status ~= "complete" then return arrived end
    return movement.walk(config.points.gnome_basement_entrance, 1, { ticks = 900, policy = urgent_policy })
  elseif phase == "obtain_golrie_key" then
    return interact_object(
      config.objects.golrie_crate, "Search", config.points.golrie_crate, urgent_policy,
      function() return item_queries.inventory_quantity(config.items.golrie_key) > 0 end,
      "golrie_key_obtained")
  elseif phase == "open_golrie_gate" then
    return open_and_cross(
      config.objects.golrie_gate,
      config.points.golrie_gate,
      config.points.golrie,
      function() return geometry.in_zone(gc.read("player").world, config.zones.golrie_room) end,
      "golrie_room_entered")
  elseif phase == "obtain_pebble" then
    return talk(
      config.npcs.golrie,
      config.points.golrie,
      function() return item_queries.inventory_quantity(config.items.pebble) > 0 end,
      nil,
      urgent_policy)
  elseif phase == "leave_gnome_dungeon" then
    return leave_gnome_dungeon()
  elseif phase == "equip_amulet" then
    return equipment_actions.equip(
      config.items.amulet,
      "Wear",
      { timeout_ticks = 40, verify_ticks = 12 })
  elseif phase == "enter_falls" then
    return interact_object(
      config.objects.falls_entrance, "Open", config.points.falls_entrance, urgent_policy,
      function() return geometry.in_zone(gc.read("player").world, config.zones.falls) end,
      "waterfall_dungeon_entered")
  end
  return { status = "rejected", result = "navigation_phase_unknown:" .. tostring(phase) }
end

return { execute = execute, escape_hostile_area = escape_hostile_area }
