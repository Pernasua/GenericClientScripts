local varp_ids = {
  witchs_house = 226,
  waterfall = 65,
  tree_gnome_village = 111,
  fight_arena = 17,
  the_grand_tree = 150,
  monkey_madness_i = 365,
}

local varbit_ids = {
  waterfall = { 9110 },
  tree_gnome_village = { 598, 599, 600, 601, 602 },
  fight_arena = { 14717, 14718, 14719, 14720, 14721 },
  monkey_madness_i = { 121, 122, 123, 125, 126, 127 },
}

local function read(quest)
  local varp_id = assert(varp_ids[quest], "Unknown quest state: " .. tostring(quest))
  local vars = gc.read("vars", {
    varps = { varp_id },
    varbits = varbit_ids[quest] or {},
  })
  return {
    quest = quest,
    varp = vars.varps[varp_id],
    varbits = vars.varbits or {},
    player = gc.read("player"),
    skills = gc.read("skills"),
    inventory = gc.read("inventory"),
    equipment = gc.read("equipment"),
    bank = gc.read("bank"),
    quests = gc.read("quests"),
    dialogue = gc.read("dialogue"),
  }
end

return { read = read }
