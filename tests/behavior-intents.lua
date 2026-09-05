local with_intents = dofile("tests/support/intent.lua")
local player = { world = { x = 2900, y = 3467, plane = 0 } }
local actions = {}
local fail_magnet = false
local scope

gc = {
  require = function(name)
    local modules = { shared_movement = "movement", shared_geometry = "geometry", shared_equipment = "equipment",
      shared_items = "items", shared_wait = "wait" }
    return dofile("scripts/shared/" .. assert(modules[name], name) .. ".lua")
  end,
  read = function(kind)
    if kind == "player" then return player end
    if kind == "npcs" then return { { id = 4000 } } end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event then return { status = "observed" } end
    local action = request.action
    actions[#actions + 1] = action.type
    if action.type == "walk.to" then
      assert(scope.current == nil, "the approach was included in the item sequence")
      return { status = "arrived" }
    end
    assert(scope.current == "witchs_house.lure_mouse", "the cheese and magnet did not share an intent")
    assert(request.policy == nil, "the sequence still repeats its intent policy")
    if fail_magnet and action.type == "item.use_on_npc" then error("magnet rejected", 0) end
    return { status = "dispatched" }
  end,
}
scope = with_intents(gc)
local witch = dofile("scripts/quest-runner/witchs_house/quest.lua")
assert(witch.execute("lure_mouse").status == "dispatched")
assert(table.concat(actions, ",") == "walk.to,item.use_on_object,item.use_on_npc")
assert(#scope.entries == 1 and scope.current == nil)
fail_magnet = true
local succeeded, failure = pcall(witch.execute, "lure_mouse")
assert(not succeeded and failure == "magnet rejected" and scope.current == nil)

local bank_open = false
local carried = 0
local skill = { level = 1, xp = 0 }
local banking_actions = {}
gc = {
  activity = function() end,
  next_action = function() end,
  require = function(name)
    if name == "shared_bank" then return dofile("scripts/shared/bank.lua") end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    if name == "config" then return { bone = { id = 526, xp = 83 }, inventory_size = 28 } end
    if name == "preparation" then return {} end
    if name == "progress" then return { show = function() end } end
    if name == "shared_ui" then return { park_mouse = function() assert(scope.current == nil) end } end
    error("unexpected module " .. name)
  end,
  read = function(kind)
    if kind == "bank" then return { open = bank_open, available = bank_open } end
    if kind == "objects" then return {} end
    if kind == "skills" then return { prayer = skill } end
    if kind == "inventory" then return { items = { { id = 526, quantity = carried } } } end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event then return { status = "observed" } end
    local action = request.action
    if action.type == "item.interact" then
      assert(scope.current == nil, "the training loop remained inside the bank intent")
      skill = { level = 2, xp = 83 }
      carried = 0
      return { status = "dispatched" }
    end
    assert(scope.current == "prayer.withdraw_bones", "bank opening and withdrawal had separate boundaries")
    banking_actions[#banking_actions + 1] = action.type
    if action.type == "npc.interact" then
      bank_open = true
      return { status = "dispatched" }
    end
    assert(action.type == "bank.loadout" and action.close == true)
    carried = action.items[1].quantity
    bank_open = false
    return { status = "complete" }
  end,
}
scope = with_intents(gc)
local prayer = dofile("scripts/aio-prayer/training.lua")
assert(prayer.run(2, 83).status == "complete")
assert(table.concat(banking_actions, ",") == "npc.interact,bank.loadout")
assert(#scope.entries == 1 and scope.current == nil)

local distance = 6
local dialogue = { type = "closed" }
local progressed = false
local talking_actions = {}
gc = {
  require = function(name)
    if name == "tree_gnome_config" then return { varp = 111 } end
    local modules = { shared_movement = "movement", shared_geometry = "geometry", shared_wait = "wait" }
    return dofile("scripts/shared/" .. assert(modules[name], name) .. ".lua")
  end,
  read = function(kind)
    if kind == "player" then return { world = { x = 2500, y = 3200, plane = 0 } } end
    if kind == "npcs" then return {
      { id = 42, distance = distance, clickable = true, line_of_sight = true,
        world = { x = 2506, y = 3200, plane = 0 } },
    } end
    if kind == "objects" or kind == "messages" then return {} end
    if kind == "runtime" then return { game_tick = 1 } end
    if kind == "dialogue" then return dialogue end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event then return { status = "observed" } end
    local action = request.action
    talking_actions[#talking_actions + 1] = action.type
    if action.type == "walk.to" then
      assert(scope.current == nil, "the NPC approach was included in the conversation intent")
      distance = 1
      return { status = "arrived" }
    end
    assert(scope.current == "tree_gnome.talk" and request.policy == nil)
    if action.type == "npc.interact" then
      dialogue = { type = "continue" }
    else
      assert(action.type == "dialogue.continue")
      dialogue = { type = "closed" }
      progressed = true
    end
    return { status = "dispatched" }
  end,
}
scope = with_intents(gc)
local tree_gnome = dofile("scripts/quest-runner/tree_gnome_village/interactions.lua")
assert(tree_gnome.talk(42, { x = 2506, y = 3200, plane = 0 }, function() return progressed end, {}).status == "complete")
assert(table.concat(talking_actions, ",") == "walk.to,npc.interact,dialogue.continue")
assert(#scope.entries == 1 and scope.current == nil)
print("behavior intent placement tests passed")
