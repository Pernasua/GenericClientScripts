local target_xp = {
  ["13"] = 1833,
  ["20"] = 4470,
  ["30"] = 13363,
  ["50"] = 101333,
}

local spells = {
  {
    id = "wind_strike",
    label = "Wind Strike",
    minimum_level = 1,
    unlock_xp = 0,
    base_xp = 5.5,
    staff_id = 1381,
    staff_name = "air staff",
    runes = {
      { id = 558, name = "Mind rune", quantity = 1, maximum_unit_price = 10 },
    },
  },
  {
    id = "water_strike",
    label = "Water Strike",
    minimum_level = 5,
    unlock_xp = 388,
    base_xp = 7.5,
    staff_id = 1381,
    staff_name = "air staff",
    runes = {
      { id = 558, name = "Mind rune", quantity = 1, maximum_unit_price = 10 },
      { id = 555, name = "Water rune", quantity = 1, maximum_unit_price = 10 },
    },
  },
  {
    id = "earth_strike",
    label = "Earth Strike",
    minimum_level = 9,
    unlock_xp = 969,
    base_xp = 9.5,
    staff_id = 1381,
    staff_name = "air staff",
    runes = {
      { id = 558, name = "Mind rune", quantity = 1, maximum_unit_price = 10 },
      { id = 557, name = "Earth rune", quantity = 2, maximum_unit_price = 10 },
    },
  },
  {
    id = "fire_strike",
    label = "Fire Strike",
    minimum_level = 13,
    unlock_xp = 1833,
    base_xp = 11.5,
    staff_id = 1387,
    staff_name = "fire staff",
    runes = {
      { id = 558, name = "Mind rune", quantity = 1, maximum_unit_price = 10 },
      { id = 556, name = "Air rune", quantity = 2, maximum_unit_price = 10 },
    },
  },
  {
    id = "fire_bolt",
    label = "Fire Bolt",
    minimum_level = 35,
    unlock_xp = 22406,
    base_xp = 22.5,
    staff_id = 1387,
    staff_name = "fire staff",
    runes = {
      { id = 562, name = "Chaos rune", quantity = 1, maximum_unit_price = 250 },
      { id = 556, name = "Air rune", quantity = 3, maximum_unit_price = 10 },
    },
  },
}

local methods = {
  port_sarim_jail = {
    label = "Port Sarim jail corridor",
    destination = { x = 3012, y = 3189, plane = 0 },
    route = {
      { x = 3104, y = 3420, plane = 0 },
      { x = 3070, y = 3359, plane = 0 },
      { x = 3052, y = 3294, plane = 0 },
      { x = 3038, y = 3245, plane = 0 },
      { x = 3024, y = 3205, plane = 0 },
      { x = 3012, y = 3189, plane = 0 },
    },
    escape = { x = 3020, y = 3210, plane = 0, within = 3 },
    disengage = { x = 3012, y = 3190, plane = 0 },
    within = 0,
    npc_names = { "Pirate", "Thief", "Mugger", "Black knight" },
    npc_radius = 15,
    maximum_level = 50,
  },
}

local superheat = {
  minimum_level = 43,
  minimum_smithing_level = 15,
  unlock_xp = 50339,
  xp_per_cast = 53,
  spell = "superheat_item",
  staff_id = 1387,
  staff_name = "fire staff",
  nature_rune = {
    id = 561,
    name = "Nature rune",
    maximum_unit_price = 250,
  },
  ore = {
    id = 440,
    name = "Iron ore",
    maximum_unit_price = 150,
  },
  batch_size = 26,
}

local low_alchemy = {
  minimum_level = 21,
  xp_per_cast = 31,
  spell = "low_alchemy",
  staff_id = 1387,
  staff_name = "fire staff",
  nature_rune = {
    id = 561,
    name = "Nature rune",
    maximum_unit_price = 250,
  },
  item = {
    id = 890,
    name = "Adamant arrow",
    maximum_unit_price = 50,
  },
}

local plans = {
  ["13"] = {
    { id = 1381, name = "Staff of air", quantity = 1, maximum_unit_price = 2000 },
    { id = 1993, name = "Jug of wine", quantity = 6, maximum_unit_price = 10 },
  },
  ["20"] = {
    { id = 1381, name = "Staff of air", quantity = 1, maximum_unit_price = 2000 },
    { id = 1387, name = "Staff of fire", quantity = 1, maximum_unit_price = 2000 },
    { id = 1993, name = "Jug of wine", quantity = 6, maximum_unit_price = 10 },
  },
  ["30"] = {
    { id = 1381, name = "Staff of air", quantity = 1, maximum_unit_price = 2000 },
    { id = 1387, name = "Staff of fire", quantity = 1, maximum_unit_price = 2000 },
    { id = 1993, name = "Jug of wine", quantity = 6, maximum_unit_price = 10 },
  },
  ["50"] = {
    { id = 1381, name = "Staff of air", quantity = 1, maximum_unit_price = 2000 },
    { id = 1387, name = "Staff of fire", quantity = 1, maximum_unit_price = 2000 },
    { id = 1993, name = "Jug of wine", quantity = 6, maximum_unit_price = 10 },
  },
}

return {
  target_xp = target_xp,
  spells = spells,
  methods = methods,
  plans = plans,
  superheat = superheat,
  low_alchemy = low_alchemy,
}
