local world = { x = 3222, y = 3221, plane = 0 }
local calls = {}
local inventory = {}
local bank = {}

local function call(name)
  calls[#calls + 1] = name
end

local modules = {
  monkey_madness_config = { items = { mspeak_amulet = 4021 } },
  monkey_madness_navigation = {},
  monkey_madness_interactions = {},
  monkey_madness_puzzle = {},
  monkey_madness_preparation = {
    prepare = function(restock)
      call("prepare:" .. restock)
      if bank[4021] then
        inventory[4021] = bank[4021]
        bank[4021] = nil
      end
      return true
    end,
  },
  monkey_madness_ape_atoll = {
    execute = function()
      call("reach_ape_atoll")
      world = { x = 2770, y = 2707, plane = 0 }
      return { status = "complete", result = "ape_atoll_reached" }
    end,
  },
  monkey_madness_garkor = {},
  monkey_madness_infiltration = {},
  monkey_madness_amulet = {},
  monkey_madness_amulet_crafting = {
    escape_prison = function()
      call("escape_prison")
      world = { x = 2764, y = 2798, plane = 0 }
      return { status = "complete", result = "amulet_prison_escaped" }
    end,
    reach_prison = function()
      call("reach_prison")
      world = { x = 2771, y = 2794, plane = 0 }
      return { status = "complete", result = "ape_atoll_prison_reached" }
    end,
    reach_prison_safe_spot = function()
      call("reach_safe_spot")
      world = { x = 2769, y = 2795, plane = 0 }
      return { status = "complete", result = "ape_atoll_prison_safe_spot_reached" }
    end,
  },
  monkey_madness_disguise = {},
  monkey_madness_favor = {},
  monkey_madness_battle = {},
  monkey_madness_completion = {},
  monkey_madness_areas = {
    in_south = function(point)
      return point.x >= 2687 and point.x <= 2820 and point.y >= 2687 and point.y <= 2737
    end,
    in_north = function(point)
      return point.x >= 2682 and point.x <= 2816 and point.y >= 2766 and point.y <= 2817
    end,
    in_prison = function(point)
      return point.x >= 2764 and point.x <= 2776 and point.y >= 2793 and point.y <= 2802
    end,
  },
  shared_items = dofile("scripts/shared/items.lua"),
  shared_travel = {
    teleport_to_castle_wars = function(options)
      assert(options.policy.breaks == false and options.keyboard == true)
      call("teleport_to_castle_wars")
      world = { x = 2440, y = 3089, plane = 0 }
      return { status = "complete", result = "castle_wars_teleport_verified" }
    end,
  },
}

gc = {
  require = function(name)
    assert(modules[name], "unexpected module " .. name)
    return modules[name]
  end,
  read = function(kind)
    if kind == "player" then return { world = world } end
    local source = kind == "inventory" and inventory or
      kind == "equipment" and {} or kind == "bank" and bank
    assert(source, "unexpected read " .. kind)
    local result = {}
    for id, quantity in pairs(source) do
      result[#result + 1] = { id = id, quantity = quantity }
    end
    return { items = result }
  end,
}

local quest = dofile("scripts/quest-runner/monkey_madness_i/quest.lua")
local staged = quest.reach_prison_cell({ restock = "ge" })
assert(staged.status == "complete", staged.status)
assert(staged.result == "ape_atoll_prison_safe_spot_reached", staged.result)
assert(table.concat(calls, ",") ==
  "prepare:ge,reach_ape_atoll,reach_prison,reach_safe_spot")

calls = {}
world = { x = 2771, y = 2794, plane = 0 }
staged = quest.reach_prison_cell({ restock = "ge" })
assert(staged.status == "complete", staged.status)
assert(table.concat(calls, ",") == "reach_safe_spot")

calls = {}
world = { x = 2771, y = 2794, plane = 0 }
inventory = {}
bank = { [4021] = 1 }
staged = quest.reach_prison_cell({ restock = "bank_only" })
assert(staged.status == "complete", staged.status)
assert(inventory[4021] == 1 and not bank[4021], "banked amulet was not retrieved")
assert(table.concat(calls, ",") ==
  "escape_prison,teleport_to_castle_wars,prepare:bank_only," ..
  "reach_ape_atoll,reach_prison,reach_safe_spot")

print("monkey madness prison scope tests passed")
