local function point(x, y)
  return { x = x, y = y, plane = 0 }
end

local config = {
  zones = {
    ape_atoll_prison = { x1 = 2764, x2 = 2776, y1 = 2793, y2 = 2802, plane = 0 },
    prison_west_clear = { x1 = 2762, x2 = 2764, y1 = 2797, y2 = 2799, plane = 0 },
  },
  routes = {
    temple_to_monkey_child = { destination = point(2746, 2799), within = 0, via = {} },
  },
  points = {
    monkey_child_staging = point(2746, 2799),
    monkey_child = point(2743, 2794),
    monkey_aunt_south_crossing = point(2743, 2791),
  },
  npcs = {
    monkey_aunt = 5270,
    monkey_child = 5268,
  },
  objects = {
    banana_trees = { 4749 },
  },
  items = {
    mspeak_amulet = 4021,
    monkey_talisman = 4023,
    banana = 1963,
  },
}

local aunt_path = {
  point(2733, 2792),
  point(2743, 2793),
  point(2743, 2792),
  point(2743, 2791),
  point(2733, 2788),
  point(2732, 2788),
  point(2732, 2790),
  point(2733, 2793),
  point(2738, 2796),
  point(2743, 2792),
}
local aunt_index = 1
local aunt_world = aunt_path[aunt_index]
local previous_aunt_world
local patrol_window = 0
local ticks_since_crossing
local player = { world = point(2746, 2799), run_energy = 10000 }
local bananas = 0
local talisman = 0
local dialogue = "closed"
local dialogue_progress = 0
local searches = {}
local talks = {}
local actions = {}
local bananas_given_window

local function same_point(left, right)
  return left.x == right.x and left.y == right.y and left.plane == right.plane
end

local function advance_patrol()
  previous_aunt_world = aunt_world
  aunt_index = aunt_index % #aunt_path + 1
  aunt_world = aunt_path[aunt_index]
  if same_point(aunt_world, config.points.monkey_aunt_south_crossing) and
    previous_aunt_world.y > aunt_world.y then
    patrol_window = patrol_window + 1
    ticks_since_crossing = 0
  elseif ticks_since_crossing then
    ticks_since_crossing = ticks_since_crossing + 1
  end
end

local function inventory()
  local items = {}
  if bananas > 0 then items[#items + 1] = { id = 1963, quantity = bananas } end
  if talisman > 0 then items[#items + 1] = { id = 4023, quantity = talisman } end
  return { items = items }
end

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then return dofile("scripts/quest-runner/monkey_madness_i/areas.lua") end
    if name == "shared_behaviors" then
      return { configure = function() return true, { status = "complete" } end }
    end
    if name == "shared_equipment" then
      return { equip = function() return { status = "unchanged" } end }
    end
    if name == "shared_geometry" then return dofile("scripts/shared/geometry.lua") end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    if name == "shared_movement" then return dofile("scripts/shared/movement.lua") end
    if name == "shared_protection" then return {} end
    if name == "shared_wait" then return dofile("scripts/shared/wait.lua") end
    if name == "monkey_madness_preparation" then
      return { arm_safety = function() return true end }
    end
    if name == "monkey_madness_garkor" then
      return { travel_interrupts = function() return {} end,
        maintain_stamina = function() return true end }
    end
    if name == "monkey_madness_navigation" or
      name == "monkey_madness_amulet" or name == "shared_travel" then
      return {}
    end
    error("unexpected module " .. name)
  end,
  read = function(kind, query)
    if kind == "player" then return player end
    if kind == "inventory" then return inventory() end
    if kind == "equipment" then
      return { items = { { id = 4021, quantity = 1 } } }
    end
    if kind == "dialogue" then return { type = dialogue } end
    if kind == "objects" then
      if query and query.id == 4749 and query.action == "Search" then
        return { { id = 4749, world = point(2744, 2796) } }
      end
      return {}
    end
    if kind == "npcs" then
      if query and query.id == 5270 then
        return { { id = 5270, world = aunt_world } }
      end
      if query and query.id == 5268 then
        return { { id = 5268, world = point(2743, 2796) } }
      end
      return {}
    end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event == "game.tick" then
      advance_patrol()
      return { status = "observed" }
    end
    local action = request.action
    actions[#actions + 1] = action
    if action.type == "walk.to" then
      player.world = action.destination
      dialogue = "closed"
      -- A completed native journey includes the tick that verified arrival.
      advance_patrol()
      return { status = "arrived", reached = action.destination }
    end
    if action.type == "object.interact" and action.id == 4749 then
      searches[#searches + 1] = {
        window = patrol_window,
        ticks_since_crossing = ticks_since_crossing,
      }
      player.world = point(2744, 2796)
      bananas = bananas + 1
      advance_patrol()
      return { status = "dispatched" }
    end
    if action.type == "npc.interact" and action.id == 5268 then
      talks[#talks + 1] = {
        window = patrol_window,
        ticks_since_crossing = ticks_since_crossing,
      }
      player.world = point(2743, 2794)
      dialogue = "continue"
      advance_patrol()
      return { status = "dispatched" }
    end
    if action.type == "dialogue.continue" then
      dialogue_progress = dialogue_progress + 1
      if dialogue_progress == 4 then
        bananas = 0
        bananas_given_window = patrol_window
        dialogue = "closed"
      elseif dialogue_progress >= 5 then
        talisman = 1
        dialogue = "closed"
      else
        dialogue = "continue"
      end
      advance_patrol()
      return { status = "dispatched" }
    end
    if action.type == "client.behaviors.configure" then
      return { status = "complete" }
    end
    error("unexpected action " .. action.type)
  end,
  activity = function() end,
  state = function() end,
  overlay = function() end,
}

local disguise = dofile("scripts/quest-runner/monkey_madness_i/disguise.lua")
local result = disguise.obtain_talisman()

assert(result.status == "complete", table.concat({
  result.status,
  "talisman=" .. talisman,
  "bananas=" .. bananas,
  "dialogue_progress=" .. dialogue_progress,
  "searches=" .. #searches,
  "talks=" .. #talks,
  "windows=" .. patrol_window,
}, " "))
for _, action in ipairs(actions) do
  assert(action.type ~= "walk.click", "timed child movement bypassed the journey owner")
  if action.type == "walk.to" then
    assert(action.interrupt_on and action.interrupt_on.area.name == "prison",
      "timed child travel omitted capture interruption")
  end
end
assert(talisman == 1, "child timing sequence did not obtain the talisman")
assert(player.world.x == 2746 and player.world.y == 2799,
  "child timing sequence did not finish at the hiding spot")
assert(#searches == 5, "banana collection did not stop at five")
for _, search in ipairs(searches) do
  assert(search.window > 0,
    "banana search started outside the southbound aunt window")
end
assert(searches[1].ticks_since_crossing == 0,
  "banana collection did not begin on the observed southbound crossing")
for _, talk in ipairs(talks) do
  assert(talk.window > 0 and talk.ticks_since_crossing <= 2,
    "child dialogue started outside the southbound aunt window")
end
assert(bananas_given_window and talks[#talks].window > bananas_given_window,
  "the final talisman dialogue did not wait for the next aunt round")
for _, action in ipairs(actions) do
  assert(action.type ~= "ui.close",
    "aunt retreat used an unnecessary dialogue-close action")
end

print("monkey madness child timing tests passed")
