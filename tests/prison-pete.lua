gc = {
  require = function()
    return {}
  end,
}

local event = dofile("scripts/prison-pete/event.lua")

local function same(actual, expected)
  assert(#actual == #expected)
  for index, value in ipairs(expected) do
    assert(actual[index] == value)
  end
end

assert(event.invitation_npc_id == 6754)
same(event.balloon_ids_for_model(10749), { 369, 5493 })
same(event.balloon_ids_for_model(10750), { 371, 5489 })
same(event.balloon_ids_for_model(11028), { 370, 5488 })
same(event.balloon_ids_for_model(11034), { 5491, 5492 })
assert(event.balloon_ids_for_model(1) == nil)
assert(event.on_prison({ x = 2093, y = 4465, plane = 0 }))
assert(not event.on_prison({ x = 3012, y = 3189, plane = 0 }))

print("Prison Pete tests passed")
