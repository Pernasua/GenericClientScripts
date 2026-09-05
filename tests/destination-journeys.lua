local player
local actions
local active_config
local dialogue
local interrupt_dialogue
local femi_entries
local quest_stage

local function point(x, y, plane) return { x = x, y = y, plane = plane or 0 } end
local function same(first, second)
  return first.x == second.x and first.y == second.y and first.plane == second.plane
end

local interactions = {
  npc = function(ids)
    if ids == active_config.npcs.king_narnode and same(player.world, active_config.points.king_narnode) then
      return { id = ids[1] }
    end
  end,
  enter_stronghold_with_femi = function()
    femi_entries = femi_entries + 1
    player.world = active_config.points.stronghold_gate_inside
    return { status = "complete" }
  end,
}

gc = {
  require = function(name)
    if name == "config" or name == "tree_gnome_config" or name == "grand_tree_config" then return active_config end
    local shared = {
      shared_geometry = "geometry", shared_movement = "movement", shared_items = "items",
      shared_wait = "wait", shared_skills = "skills",
    }
    if shared[name] then return dofile("scripts/shared/" .. shared[name] .. ".lua") end
    if name == "tree_gnome_interactions" or name == "grand_tree_interactions" then return interactions end
    if name == "shared_travel" then
      return { has_dueling_ring = function() return false end,
        teleport_to_castle_wars = function() error("unexpected transport") end }
    end
    error("unexpected module " .. name)
  end,
  activity = function() end,
  read = function(kind)
    if kind == "player" then return player end
    if kind == "dialogue" then return dialogue end
    if kind == "vars" then return { varps = { [active_config.varp] = quest_stage } } end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event then return { status = "observed" } end
    local action = request.action
    actions[#actions + 1] = action
    if action.type == "walk.to" then
      if interrupt_dialogue then
        interrupt_dialogue = false
        return { status = "interrupted", reason = "dialogue", continuation = "femi-journey" }
      end
      player.world = action.destination
      return { status = "arrived", reached = player.world }
    end
    if action.type == "dialogue.choose" then
      assert(action.text == "Okay then.", "unexpected Femi choice")
      dialogue = { type = "closed", open = false }
      return { status = "dispatched" }
    end
    error("unexpected action " .. action.type)
  end,
}

local function reset(world)
  player = { world = world }
  actions = {}
  dialogue = { type = "closed", open = false }
  interrupt_dialogue = false
  femi_entries = 0
  quest_stage = 0
end

active_config = dofile("scripts/quest-runner/tree_gnome_village/config.lua")
reset(active_config.points.maze_outside)
local village = dofile("scripts/quest-runner/tree_gnome_village/navigation.lua")
local entered = village.enter_village_through_maze()
assert(entered.status == "complete" and #actions == 1, "maze entry was split into point walks")
assert(same(actions[1].destination, active_config.points.maze_inside) and actions[1].within == 0)
assert(entered.route.status == "arrived", "maze entry did not retain the single journey receipt")
actions = {}
local left = village.leave_village_through_maze()
assert(left.status == "complete" and #actions == 1, "maze exit staged another intermediate walk")
assert(same(actions[1].destination, active_config.points.maze_outside))

active_config = dofile("scripts/quest-runner/the_grand_tree/config.lua")
reset(point(2461, 3376))
local tree = dofile("scripts/quest-runner/the_grand_tree/navigation.lua")
local arrived = tree.return_to_narnode()
assert(arrived and #actions == 1 and same(actions[1].destination, active_config.points.king_narnode),
  "ordinary Stronghold return still walks intermediate points")
reset(point(2461, 3376))
quest_stage = 90
assert(tree.return_to_narnode(), "quest-gated Stronghold entry failed")
assert(femi_entries == 1 and #actions == 2 and same(actions[1].destination, active_config.points.stronghold_gate_outside),
  "quest-specific Femi entry was bypassed by destination routing")

active_config = dofile("scripts/aio-agility/config.lua")
reset(point(2580, 3315))
local agility = dofile("scripts/aio-agility/travel.lua")
assert(agility.ensure() and #actions == 1, "agility travel still follows point arrays")
assert(same(actions[1].destination, active_config.course.arrival))
reset(point(2580, 3315))
dialogue = { type = "choice", open = true, options = { { text = "Okay then." } } }
interrupt_dialogue = true
assert(agility.ensure(), "Femi dialogue interrupted course travel permanently")
assert(#actions == 3 and actions[2].type == "dialogue.choose" and actions[3].resume == "femi-journey",
  "course travel did not resume its existing journey after Femi")
reset(point(2580, 3315))
dialogue = { type = "choice", open = true, options = { { text = "Unexpected choice" } } }
interrupt_dialogue = true
local okay, failure = agility.ensure()
assert(not okay and failure.status == "unexpected_femi_dialogue" and #actions == 1,
  "unknown dialogue was answered or followed by another walk")

print("destination journey tests passed")
