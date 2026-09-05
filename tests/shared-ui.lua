local open = true
local close_actions = 0

gc = {
  read = function(subject, query)
    assert(subject == "widgets", "shared UI read an unexpected subject")
    assert(query.group == 225, "shared UI queried the wrong interface group")
    return open and { { group_id = 225 } } or {}
  end,
  await = function(request)
    if request.event == "game.tick" then return { status = "observed" } end
    assert(request.action.type == "ui.close", "shared UI dispatched the wrong action")
    close_actions = close_actions + 1
    open = false
    return { status = "dispatched" }
  end,
}

local ui = dofile("scripts/shared/ui.lua")
assert(ui.group_open(225), "shared UI did not observe the open interface")
local closed = ui.close_group(225, 3)
assert(closed.status == "complete" and closed.result == "interface_closed", closed.status)
assert(close_actions == 1, "shared UI did not close the interface exactly once")
local unchanged = ui.close_group(225, 3)
assert(unchanged.status == "complete" and unchanged.result == "interface_already_closed",
  unchanged.status)
assert(close_actions == 1, "shared UI re-closed an absent interface")

print("shared UI tests passed")
