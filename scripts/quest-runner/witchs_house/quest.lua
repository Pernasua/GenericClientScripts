local movement = gc.require("shared_movement")
local geometry = gc.require("shared_geometry")
local equipment_actions = gc.require("shared_equipment")
local urgent_policy = { breaks = false, cursor_release = "none", fidget = "none" }

local accepted_choices = {
  ["What's the matter?"] = true,
  ["Ok, I'll see what I can do."] = true,
  ["Yes."] = true,
}

local function handle_accept()
  local travel = movement.walk({ x = 2928, y = 3456, plane = 0 }, 5, { ticks = 900 })
  if travel.status ~= "arrived" then
    return travel
  end
  return gc.intent("witchs_house.accept", function()
    local talk = gc.await {
      action = { type = "npc.interact", name = "Boy", action = "Talk-to", within = 10 },
    }
    if talk.status ~= "dispatched" then
      return talk
    end
    for _ = 1, 30 do
      gc.await { event = "game.tick" }
      local dialogue = gc.read("dialogue")
      if dialogue.type == "continue" then
        gc.await { action = { type = "dialogue.continue" } }
      elseif dialogue.type == "choice" then
        local selected = nil
        for _, option in ipairs(dialogue.options) do
          if accepted_choices[option.text] then
            selected = option.text
            break
          end
        end
        if not selected then
          return { status = "rejected", result = "unexpected_witch_acceptance_dialogue", dialogue = dialogue }
        end
        gc.await { action = { type = "dialogue.choose", text = selected } }
      end
      local vars = gc.read("vars", { varps = { 226 } })
      if vars.varps[226] ~= 0 then
        return { status = "complete", result = "witch_acceptance_verified" }
      end
    end
    return { status = "timed_out", result = "witch_acceptance_timeout" }
  end)
end

local function object_action(id, action, world, within, policy)
  local interaction_radius = math.min(within or 3, 3)
  if geometry.distance(gc.read("player").world, world) > interaction_radius then
    local approach = movement.walk(world, 3, { ticks = 900, policy = policy })
    if approach.status ~= "arrived" then
      return approach
    end
  end
  return gc.await {
    action = {
      type = "object.interact",
      id = id,
      action = action,
      world = world,
      within = interaction_radius,
    },
    policy = policy,
  }
end

local function open_and_cross(id, world, destination, result)
  local opened = object_action(id, "Open", world, 12, urgent_policy)
  if opened.status ~= "dispatched" then
    return opened
  end
  local crossed = movement.walk(destination, 0, { ticks = 900, policy = urgent_policy })
  if crossed.status ~= "arrived" then
    return crossed
  end
  return { status = "complete", result = result, open = opened, walk = crossed }
end

local function execute(phase)
  if phase == "accept" then
    return handle_accept()
  elseif phase == "obtain_house_key" then
    local travel = movement.walk({ x = 2900, y = 3474, plane = 0 }, 3, { ticks = 900 })
    return travel.status == "arrived" and
      object_action(2867, "Look-under", { x = 2900, y = 3474, plane = 0 }, 8) or travel
  elseif phase == "enter_house" then
    local travel = movement.walk({ x = 2900, y = 3473, plane = 0 }, 3, { ticks = 900 })
    return travel.status == "arrived" and
      open_and_cross(
        2861,
        { x = 2900, y = 3473, plane = 0 },
        { x = 2902, y = 3473, plane = 0 },
        "witch_house_entered") or travel
  elseif phase == "descend_basement" then
    return movement.walk({ x = 2906, y = 9876, plane = 0 }, 0, { ticks = 900 })
  elseif phase == "equip_gloves" then
    return equipment_actions.equip(1059, "Wear", { policy = {} })
  elseif phase == "open_gate" then
    return open_and_cross(
      2866,
      { x = 2902, y = 9873, plane = 0 },
      { x = 2901, y = 9874, plane = 0 },
      "basement_gate_crossed")
  elseif phase == "open_cupboard" then
    return object_action(2868, "Open", { x = 2898, y = 9873, plane = 0 }, 12)
  elseif phase == "obtain_magnet" then
    return object_action(2869, "Search", { x = 2898, y = 9873, plane = 0 }, 12)
  elseif phase == "return_upstairs" then
    return movement.walk({ x = 2906, y = 3476, plane = 0 }, 0, { ticks = 900 })
  elseif phase == "lure_mouse" then
    local approach = movement.walk({ x = 2903, y = 3467, plane = 0 }, 3, { ticks = 900, policy = urgent_policy })
    if approach.status ~= "arrived" then
      return approach
    end
    return gc.intent("witchs_house.lure_mouse", function()
      local cheese = gc.await {
        action = {
          type = "item.use_on_object",
          item_id = 1985,
          object_id = 2870,
          world = { x = 2903, y = 3466, plane = 0 },
          within = 10,
        },
      }
      if cheese.status ~= "dispatched" then
        return cheese
      end
      for _ = 1, 8 do
        gc.await { event = "game.tick" }
        local mice = gc.read("npcs", { id = 4000, within = 12, limit = 1 })
        if #mice > 0 then
          return gc.await {
            action = {
              type = "item.use_on_npc",
              item_id = 2410,
              npc_id = 4000,
              npc_name = "Mouse",
              within = 12,
            },
          }
        end
      end
      return { status = "timed_out", result = "mouse_spawn_timeout" }
    end)
  elseif phase == "take_diary" then
    return gc.await {
      action = {
        type = "ground_item.take",
        id = 2408,
        world = { x = 2903, y = 3471, plane = 0 },
        within = 12,
      },
    }
  elseif phase == "read_diary" then
    return gc.intent("witchs_house.read_diary", function()
      local read = gc.await { action = { type = "item.interact", id = 2408, action = "Read" } }
      if read.status == "dispatched" then
        gc.await { ticks = 2 }
        gc.await { action = { type = "ui.close" } }
      end
      return read
    end)
  end
  return { status = "rejected", result = "phase_has_no_automatic_handler:" .. phase }
end

return { execute = execute }
