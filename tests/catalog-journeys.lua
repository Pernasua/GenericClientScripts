local config
local player
local requests
local teleport_result
local teleports
local journey_result

local function point(x, y, plane) return { x = x, y = y, plane = plane or 0 } end
local function same(first, second)
  return first.x == second.x and first.y == second.y and first.plane == second.plane
end

gc = {
  require = function(name)
    if name == "waterfall_config" then return config end
    local shared = {
      shared_movement = "movement", shared_geometry = "geometry", shared_items = "items",
      shared_wait = "wait", shared_equipment = "equipment",
    }
    if shared[name] then return dofile("scripts/shared/" .. shared[name] .. ".lua") end
    if name == "shared_travel" then
      local function teleport()
        teleports = teleports + 1
        return teleport_result
      end
      return {
        teleport_to_castle_wars = teleport,
        teleport_to_barbarian_outpost = teleport,
      }
    end
    error("unexpected module " .. name)
  end,
  read = function(kind)
    if kind == "player" then return { world = player } end
    if kind == "dialogue" then return { type = "closed", open = false } end
    error("unexpected read " .. kind)
  end,
  await = function(request)
    requests[#requests + 1] = request
    assert(request.action.type == "walk.to", "catalog journey still dispatched " .. request.action.type)
    return journey_result
  end,
}

local function reset(world)
  player = world
  requests = {}
  teleports = 0
  teleport_result = { status = "rejected", result = "transport_item_missing" }
  journey_result = { status = "arrived", transports = { { status = "arrived" } } }
end

local function assert_journey(receipt, destination, breaks)
  assert(receipt == journey_result, "journey receipt was replaced or accepted without arrival")
  assert(#requests == 1, "transition was split into multiple Lua actions")
  local request = requests[1]
  assert(same(request.action.destination, destination), "journey stops on the wrong side of the transition")
  assert(request.action.within <= 1 and request.breaks == nil)
  if breaks then
    assert(request.policy == nil, "ordinary travel unexpectedly overrides the activity policy")
  else
    assert(request.policy.breaks == false and request.policy.cursor_release == "none" and request.policy.fidget == "none",
      "urgent travel allowed discretionary behavior")
  end
end

local witch = dofile("scripts/quest-runner/witchs_house/quest.lua")
reset(point(2902, 3473))
assert_journey(witch.execute("descend_basement"), point(2906, 9876), true)
reset(point(2901, 9874))
assert_journey(witch.execute("return_upstairs"), point(2906, 3476), true)
reset(point(2906, 3476))
journey_result = { status = "interrupted", reason = "dialogue", continuation = "basement" }
assert_journey(witch.execute("descend_basement"), point(2906, 9876), true)

config = dofile("scripts/quest-runner/waterfall/config.lua")
local navigation = dofile("scripts/quest-runner/waterfall/navigation.lua")
for _, phase in ipairs({ "reach_hudon", "reach_falls" }) do
  reset(point(2521, 3495))
  assert_journey(navigation.execute(phase), point(2512, 3481), true)
end
reset(point(2519, 3430))
assert_journey(navigation.execute("reach_tourist_stairs"), point(2518, 3431, 1), true)
reset(point(2518, 3427, 1))
assert_journey(navigation.execute("leave_tourist_house"), point(2519, 3430), true)
reset(point(2448, 3090))
assert_journey(navigation.execute("reach_gnome_dungeon"), point(2533, 9556), false)
reset(point(2548, 9565))
assert_journey(navigation.execute("leave_gnome_dungeon"), point(2533, 3156), false)
assert(teleports == 1, "dungeon exit skipped its preferred resource teleport")
reset(point(2548, 9565))
teleport_result = { status = "complete", result = "castle_wars_teleport_verified" }
assert(navigation.execute("leave_gnome_dungeon") == teleport_result and #requests == 0)

local tomb = dofile("scripts/quest-runner/waterfall/tomb.lua")
reset(point(2542, 9812))
assert_journey(tomb.execute("leave_glarial_tomb"), point(2557, 3444), false)
assert(teleports == 1 and journey_result.teleport == teleport_result)
reset(point(2542, 9812))
teleport_result = { status = "complete", result = "barbarian_outpost_teleport_verified" }
assert(tomb.execute("leave_glarial_tomb").status == "complete" and #requests == 0)

print("catalog journey tests passed")
