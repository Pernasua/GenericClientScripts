local skills = gc.require("shared_skills")

return {
  target_xp = {
    ["25"] = skills.xp_for_level(25),
  },
  bakery = {
    stall_id = 11730,
    action = "Steal-from",
    arrival = { x = 2668, y = 3310, plane = 0 },
    zone = { x1 = 2652, y1 = 3298, x2 = 2675, y2 = 3318, plane = 0 },
    bank = { x = 2653, y = 3283, plane = 0 },
    bank_within = 7,
    baker_name = "Baker",
  },
  food = {
    { id = 1891, action = "Eat", heal_amount = 4 },
    { id = 1893, action = "Eat", heal_amount = 4 },
    { id = 1895, action = "Eat", heal_amount = 4 },
    { id = 1897, action = "Eat", heal_amount = 5 },
    { id = 1899, action = "Eat", heal_amount = 5 },
    { id = 1901, action = "Eat", heal_amount = 5 },
    { id = 2309, action = "Eat", heal_amount = 5 },
  },
}
