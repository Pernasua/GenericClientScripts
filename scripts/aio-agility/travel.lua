local config = gc.require("config")
local movement = gc.require("shared_movement")

local course = config.course

local function in_course(world)
  return world and world.x >= course.zone.x1 and world.x <= course.zone.x2 and
    world.y >= course.zone.y1 and world.y <= course.zone.y2
end

local function drain_femi()
  for _ = 1, 80 do
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      local receipt = gc.await {
        action = { type = "dialogue.continue" },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 20 },
      }
      if receipt.status ~= "dispatched" then return nil, receipt end
      gc.await { event = "game.tick" }
    elseif dialogue.type == "choice" then
      local found = false
      for _, option in ipairs(dialogue.options or {}) do
        if option.text == "Okay then." then found = true end
      end
      if not found then return nil, { status = "unexpected_femi_dialogue", dialogue = dialogue } end
      local receipt = gc.await {
        action = { type = "dialogue.choose", text = "Okay then." },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 20 },
      }
      if receipt.status ~= "dispatched" then return nil, receipt end
      gc.await { event = "game.tick" }
    else
      return true
    end
  end
  return nil, { status = "femi_dialogue_timeout", dialogue = gc.read("dialogue") }
end

local function ensure()
  if in_course(gc.read("player").world) then return true end
  gc.activity("travel")
  local continuation
  for _ = 1, 4 do
    local moved = movement.walk(course.arrival, 4, {
      ticks = 900,
      resume = continuation,
      interrupt_on = { dialogue = true },
    })
    if moved.status == "arrived" then
      if not in_course(gc.read("player").world) then
        return nil, { status = "agility_course_arrival_unverified", receipt = moved, player = gc.read("player") }
      end
      return true, moved
    end
    if moved.status ~= "interrupted" or moved.reason ~= "dialogue" or not moved.continuation then
      return nil, { status = "agility_travel_failed", receipt = moved }
    end
    local drained, failure = drain_femi()
    if not drained then return nil, failure end
    continuation = moved.continuation
    gc.await { event = "game.tick" }
  end
  return nil, { status = "agility_travel_dialogue_limit", player = gc.read("player") }
end

return { ensure = ensure, in_course = in_course }
