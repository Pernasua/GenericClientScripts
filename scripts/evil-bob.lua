-- genericclient-interface: 2

local island = gc.require("island")

return {
  run = function()
    local event = gc.read("random_event")
    if not event.active or not island.is_invitation_npc(event.npc_id) then
      error("Evil Bob solver started without its owned event")
    end

    gc.activity("general")
    return island.solve(event.detected_tick, event.npc_id)
  end,
}
