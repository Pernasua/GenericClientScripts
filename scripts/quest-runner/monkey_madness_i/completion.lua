local behaviors = gc.require("shared_behaviors")
local navigation = gc.require("monkey_madness_navigation")

local function quest_finished()
  local quests = gc.read("quests")
  return quests.monkey_madness_i and quests.monkey_madness_i.state == "finished"
end

local function drain_narnode_dialogue(target)
  local talked = gc.await {
    action = { type = "npc.interact", id = target.id, action = "Talk-to", within = 20 },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if talked.status ~= "dispatched" then return talked end
  for _ = 1, 240 do
    if quest_finished() then
      return { status = "complete", result = "monkey_madness_quest_complete", receipt = talked }
    end
    gc.await { event = "game.tick" }
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      local continued = gc.await {
        action = { type = "dialogue.continue", reading = false },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 30 },
      }
      if continued.status ~= "dispatched" and
        continued.result ~= "dialogue_continue_not_visible" then return continued end
    elseif dialogue.type == "choice" then
      return {
        status = "monkey_madness_narnode_completion_choice_unexpected",
        dialogue = dialogue,
      }
    end
  end
  return {
    status = "monkey_madness_narnode_completion_timeout",
    quests = gc.read("quests"),
    dialogue = gc.read("dialogue"),
  }
end

local function finish()
  if quest_finished() then return { status = "complete", result = "monkey_madness_already_complete" } end
  local configured, behavior_failure = behaviors.configure {
    auto_retaliate = true,
    emergency_escape = true,
  }
  if not configured then return behavior_failure end
  local stronghold = navigation.travel_to_gnome_stronghold()
  if stronghold.status ~= "complete" then return stronghold end
  local target, failure = navigation.reach_narnode()
  if not target then return failure end
  return drain_narnode_dialogue(target)
end

return { finish = finish }
