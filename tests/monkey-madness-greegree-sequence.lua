local bundled_config = dofile("scripts/quest-runner/monkey_madness_i/config.lua")
local bones_requirement
for _, requirement in ipairs(bundled_config.greegree_loadout) do
  if requirement.id == bundled_config.items.karamjan_monkey_bones then
    bones_requirement = requirement
    break
  end
end
assert(bones_requirement, "greegree loadout omitted Karamjan monkey bones")
assert(bones_requirement.purchase ~= false,
  "tradeable Karamjan monkey bones were still marked unpurchasable")
assert(type(bones_requirement.maximum_unit_price) == "number",
  "tradeable Karamjan monkey bones need a bounded GE price")
assert(bundled_config.routes.gandius_monkey_search == nil and
  bundled_config.npcs.karamjan_monkey == nil,
  "obsolete Gandius monkey-hunting route was retained")

local config = {
  varp = 365,
  varbits = { zooknock = 127 },
  checkpoints = { zooknock_dungeon_route = "monkey_madness_i.zooknock_dungeon_route" },
  zones = {
    zooknock_dungeon = { x1 = 2690, x2 = 2813, y1 = 9088, y2 = 9149, plane = 0 },
  },
  items = {
    mspeak_amulet = 4021,
    monkey_talisman = 4023,
    karamjan_monkey_bones = 3183,
    karamjan_monkey_corpse = 3166,
    karamjan_greegree = 4031,
  },
}

local carried = {
  [4023] = 1,
  [3183] = 1,
}
local stage = 5
local varp = 3
local dialogue = { type = "closed" }
local events = {}
local teleports = 0

local function inventory()
  local items = {}
  for id, quantity in pairs(carried) do
    if quantity > 0 then items[#items + 1] = { id = id, quantity = quantity } end
  end
  return { items = items }
end

local protection = {
  disable = function(style)
    events[#events + 1] = { type = "protection.disable", style = style }
    return true, { status = "complete", style = style }
  end,
}

gc = {
  require = function(name)
    if name == "monkey_madness_config" then return config end
    if name == "monkey_madness_areas" then return dofile("scripts/quest-runner/monkey_madness_i/areas.lua") end
    if name == "shared_behaviors" then
      return { configure = function() return true, { status = "complete" } end }
    end
    if name == "shared_equipment" then return {} end
    if name == "shared_geometry" then return dofile("scripts/shared/geometry.lua") end
    if name == "shared_items" then return dofile("scripts/shared/items.lua") end
    if name == "shared_movement" then return {} end
    if name == "shared_protection" then return protection end
    if name == "shared_travel" then
      return {
        teleport_to_castle_wars = function(options)
          teleports = teleports + 1
          events[#events + 1] = { type = "teleport.castle_wars", options = options }
          return { status = "complete", result = "castle_wars_teleport_verified" }
        end,
      }
    end
    if name == "shared_wait" then return dofile("scripts/shared/wait.lua") end
    if name == "monkey_madness_preparation" then
      return {
        arm_safety = function()
          events[#events + 1] = { type = "safety.arm" }
          return true, { status = "complete" }
        end,
      }
    end
    if name == "monkey_madness_amulet" then
      return {
        reach_zooknock = function()
          events[#events + 1] = { type = "reach_zooknock" }
          return {
            status = "complete",
            target = { id = 7170, world = { x = 2805, y = 9143, plane = 0 } },
          }
        end,
      }
    end
    if name == "monkey_madness_garkor" then return {} end
    error("unexpected module " .. name)
  end,
  read = function(kind, query)
    if kind == "inventory" then return inventory() end
    if kind == "equipment" then return { items = {} } end
    if kind == "vars" then
      return {
        varps = { [365] = varp },
        varbits = { [127] = stage },
      }
    end
    if kind == "dialogue" then return dialogue end
    if kind == "player" then
      return { world = { x = 2805, y = 9143, plane = 0 } }
    end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    if request.event == "game.tick" then return { status = "observed" } end
    local action = request.action
    events[#events + 1] = action
    if action.type == "item.use_on_npc" and action.item_id == 4023 then
      carried[4023] = 0
      stage = 6
      return { status = "dispatched" }
    end
    if action.type == "item.use_on_npc" and action.item_id == 3183 then
      carried[3183] = 0
      stage = 7
      return { status = "dispatched" }
    end
    if action.type == "npc.interact" and action.action == "Talk-to" then
      dialogue = { type = "continue" }
      return { status = "dispatched" }
    end
    if action.type == "dialogue.continue" then
      dialogue = { type = "closed" }
      carried[4031] = 1
      varp = 4
      return { status = "dispatched" }
    end
    error("unexpected action " .. action.type)
  end,
  activity = function() end,
  clear_checkpoint = function(key)
    events[#events + 1] = { type = "checkpoint.clear", key = key }
  end,
}

local disguise = dofile("scripts/quest-runner/monkey_madness_i/disguise.lua")
local result = disguise.make_greegree()
assert(result.status == "complete", result.status)
assert(result.result == "karamjan_greegree_obtained")
assert(carried[4031] == 1, "Zooknock dialogue did not yield the greegree")
assert(teleports == 1, "greegree sequence did not leave the dangerous dungeon")

local disabled_index
local talisman_index
local bones_index
local talk_index
local teleport_index
local checkpoint_index
for index, event in ipairs(events) do
  if event.type == "protection.disable" then
    disabled_index = index
    assert(event.style == "melee", "wrong protection prayer was disabled")
  elseif event.type == "item.use_on_npc" and event.item_id == 4023 then
    talisman_index = index
    assert(event.npc_id == 7170, "talisman was not used on Zooknock")
  elseif event.type == "item.use_on_npc" and event.item_id == 3183 then
    bones_index = index
    assert(event.npc_id == 7170, "bones were not used on Zooknock")
  elseif event.type == "npc.interact" and event.action == "Talk-to" then
    talk_index = index
  elseif event.type == "teleport.castle_wars" then
    teleport_index = index
    assert(event.options.policy.breaks == false and event.options.keyboard == true, "dungeon exit allowed a break")
  elseif event.type == "checkpoint.clear" then
    checkpoint_index = index
    assert(event.key == config.checkpoints.zooknock_dungeon_route,
      "wrong route checkpoint was cleared")
  end
end
assert(disabled_index and talisman_index and bones_index and talk_index and
  teleport_index,
  "greegree sequence omitted a required action")
assert(talisman_index < bones_index and bones_index < talk_index and
  talk_index < teleport_index and teleport_index < disabled_index,
  "greegree actions did not follow the guide order")

events = {}
teleports = 0
local resumed = disguise.sync_greegree()
assert(resumed.status == "complete", resumed.status)
assert(teleports == 1, "resuming after acquisition did not leave the dangerous dungeon")
assert(events[1].type == "teleport.castle_wars" and events[1].options.policy.breaks == false and events[1].options.keyboard == true,
  "resumed dungeon exit was not immediate hazardous travel")
assert(events[2].type == "protection.disable" and events[2].style == "melee",
  "resumed dungeon exit disabled protection before reaching safety")

print("monkey madness greegree sequence tests passed")
