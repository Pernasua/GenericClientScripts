-- Developer-only export; run from the catalog root with lua5.4.
local output = assert(arg[1], "usage: lua5.4 tools/export-routes.lua output.tsv")
local routes = {}
local points = {}
local starts = dofile("tools/route-starts.lua")
local function point(value)
  return type(value) == "table" and type(value.x) == "number"
    and type(value.y) == "number" and type(value.plane) == "number"
end
local function collect_points(prefix, values)
  for name, value in pairs(values or {}) do
    if point(value) then points[prefix .. "." .. name] = value end
  end
end
local function add_route(name, route, within)
  local first = assert(route.start or starts[name], "missing audit start for " .. name)
  local tiles = { first }
  for _, via in ipairs(route.via or {}) do tiles[#tiles + 1] = via end
  tiles[#tiles + 1] = assert(route.destination, "missing route destination " .. name)
  assert(point(tiles[#tiles]), "invalid route " .. name)
  routes[name] = { points = tiles, within = route.within or within,
    arrival_tiles = route.arrival_tiles or {}, avoid_tiles = route.avoid_tiles or {},
    account = route.account or "ALL" }
end
local configs = assert(io.popen("rg --files scripts/quest-runner -g config.lua"))
local paths = {}
for path in configs:lines() do paths[#paths + 1] = path end
assert(configs:close())
table.sort(paths)
for _, path in ipairs(paths) do
  local name = assert(path:match("quest%-runner/([^/]+)/config.lua$"))
  local config = dofile(path)
  collect_points(name, config.points)
  for route_name, route in pairs(config.routes or {}) do
    add_route(name .. "." .. route_name, route, 2)
  end
  if config.points and config.points.maze_inside then
    add_route(name .. ".maze_route", { destination = config.points.maze_inside }, 0)
  end
end
for name, route in pairs(dofile("tools/transport-routes.lua")) do add_route(name, route) end
local stream = assert(io.open(output, "w"))
stream:write("# name\tindex\tx\ty\tplane\twithin\tkind\taccount\n")
local names = {}
for name in pairs(routes) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
  local route = routes[name]
  for index, tile in ipairs(route.points) do
    stream:write(string.format("%s\t%d\t%d\t%d\t%d\t%d\troute\t%s\n",
      name, index, tile.x, tile.y, tile.plane, route.within, route.account))
  end
  for index, tile in ipairs(route.arrival_tiles) do
    assert(point(tile), "invalid arrival tile " .. name)
    stream:write(string.format("%s\t%d\t%d\t%d\t%d\t%d\tarrival\t%s\n",
      name, index, tile.x, tile.y, tile.plane, route.within, route.account))
  end
  for index, tile in ipairs(route.avoid_tiles) do
    assert(point(tile), "invalid avoid tile " .. name)
    stream:write(string.format("%s\t%d\t%d\t%d\t%d\t%d\tavoid\t%s\n",
      name, index, tile.x, tile.y, tile.plane, route.within, route.account))
  end
end
local point_names = {}
for name in pairs(points) do point_names[#point_names + 1] = name end
table.sort(point_names)
for _, name in ipairs(point_names) do
  local tile = points[name]
  stream:write(string.format("%s\t1\t%d\t%d\t%d\t0\tpoint\tALL\n", name, tile.x, tile.y, tile.plane))
end
assert(stream:close())
print(string.format("Exported %d routes and %d declared points", #names, #point_names))
