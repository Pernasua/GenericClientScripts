local function park_mouse()
  return gc.await { action = { type = "mouse.offscreen" }, policy = { breaks = false, cursor_release = "none", fidget = "none" } }
end

local function group_open(group)
  return #gc.read("widgets", { group = group, limit = 1 }) > 0
end

local function close_group(group, ticks)
  if not group_open(group) then
    return { status = "complete", result = "interface_already_closed" }
  end
  local receipt = gc.await {
    action = { type = "ui.close" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  if receipt.status ~= "dispatched" then return receipt end
  for _ = 1, ticks or 10 do
    gc.await { event = "game.tick" }
    if not group_open(group) then
      return { status = "complete", result = "interface_closed", receipt = receipt }
    end
  end
  return {
    status = "interface_close_unverified",
    group = group,
    receipt = receipt,
  }
end

return {
  park_mouse = park_mouse,
  group_open = group_open,
  close_group = close_group,
}
