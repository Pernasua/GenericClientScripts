local guards = {
  { id = 5247, label = "Trefaji" },
  { id = 5248, label = "Aberab" },
}

local markers = {
  { npc_id = 5247, label = "Trefaji", color = "#ffb347" },
  { npc_id = 5248, label = "Aberab", color = "#57d7ff" },
}

local geometry = gc.require("shared_geometry")

return {
  run = function()
    gc.activity("manual")
    gc.state("guard_observer")
    local previous_signature

    while true do
      local rows = {}
      local observed_guards = {}
      for _, guard in ipairs(guards) do
        local npc = gc.read("npcs", { id = guard.id, within = 24, limit = 1 })[1]
        observed_guards[guard.label] = {
          id = guard.id,
          world = npc and geometry.copy_point(npc.world) or nil,
        }
        rows[#rows + 1] = {
          label = guard.label,
          value = npc and (npc.world.x .. ", " .. npc.world.y) or "not visible",
        }
      end
      gc.overlay(rows, markers)

      local runtime = gc.read("runtime")
      local player = gc.read("player")
      local dialogue = gc.read("dialogue")
      local signature = table.concat({
        geometry.point_key(player.world),
        geometry.point_key(player.destination),
        tostring(player.animation),
        tostring(player.current_hitpoints),
        geometry.point_key(observed_guards.Trefaji.world),
        geometry.point_key(observed_guards.Aberab.world),
        tostring(dialogue.type),
      }, "|")
      if signature ~= previous_signature then
        gc.log("info", "prison-guard-snapshot", {
          tick = runtime.game_tick,
          player = {
            world = geometry.copy_point(player.world),
            destination = geometry.copy_point(player.destination),
            animation = player.animation,
            current_hitpoints = player.current_hitpoints,
            max_hitpoints = player.max_hitpoints,
          },
          guards = observed_guards,
          dialogue = dialogue.type,
        })
        previous_signature = signature
      end
      gc.await { event = "game.tick" }
    end
  end,
}
