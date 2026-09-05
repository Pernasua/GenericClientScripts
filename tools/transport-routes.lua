-- Representative passable starts for the migrated journeys; destinations come from quest policy.
local waterfall = dofile("scripts/quest-runner/waterfall/config.lua").points
local tree = dofile("scripts/quest-runner/the_grand_tree/config.lua").points
local monkey = dofile("scripts/quest-runner/monkey_madness_i/config.lua").points
local function point(x, y, plane) return { x = x, y = y, plane = plane or 0 } end
local function route(start, destination, within, account)
  return { start = start, destination = destination, within = within, account = account or "ALL" }
end
return {
  ["witchs_house.basement"] = route(point(2902, 3473), point(2906, 9876), 0),
  ["witchs_house.surface"] = route(point(2901, 9874), point(2906, 3476), 0),
  ["waterfall.raft"] = route(point(2510, 3493), waterfall.hudon_landing, 1, "QUEST_ROUTES"),
  ["waterfall.tourist_upstairs"] = route(point(2519, 3430), waterfall.tourist_upstairs, 0),
  ["waterfall.tourist_ground"] = route(point(2518, 3431, 1), waterfall.tourist_ground, 0),
  ["waterfall.gnome_basement"] = route(point(2448, 3090), waterfall.gnome_basement_entrance, 1, "QUEST_ROUTES"),
  ["waterfall.gnome_surface"] = route(point(2548, 9566), waterfall.gnome_surface, 1, "QUEST_ROUTES"),
  ["waterfall.tomb_exit"] = route(point(2542, 9813), waterfall.tomb_surface, 1),
  ["the_grand_tree.hazelmere"] = route(point(2677, 3088), tree.hazelmere_upstairs, 1),
  ["the_grand_tree.glough"] = route(point(2466, 3494), tree.glough_room, 2),
  ["the_grand_tree.return_from_glough"] = route(point(2477, 3463, 1), tree.king_narnode, 2),
  ["the_grand_tree.charlie"] = route(point(2466, 3494), tree.grand_tree_top, 1),
  ["the_grand_tree.anita"] = route(point(2466, 3494, 3), tree.anita_upstairs, 1),
  ["the_grand_tree.invasion_plans"] = route(point(2388, 3513, 1), tree.glough_room, 2),
  ["monkey_madness_i.spirit_tree"] = route(point(3184, 3508), monkey.stronghold_arrival, 1, "QUEST_ROUTES"),
  ["monkey_madness_i.shipyard"] = route(point(2466, 3494), monkey.shipyard_gate, 3, "QUEST_ROUTES"),
  ["monkey_madness_i.return_from_gandius"] = route(point(2970, 2972), monkey.king_narnode, 3, "QUEST_ROUTES"),
  ["monkey_madness_i.daero"] = route(point(2466, 3494, 3), monkey.daero, 5),
  ["monkey_madness_i.repeat_hangar"] = route(point(2461, 3444), monkey.post_puzzle_landing, 1, "QUEST_ROUTES"),
  ["monkey_madness_i.waydar"] = route(point(2649, 4516), monkey.crash_island_landing, 1, "QUEST_ROUTES"),
  ["monkey_madness_i.lumdo"] = route(point(2894, 2726), monkey.ape_atoll_landing, 1, "QUEST_ROUTES"),
}
