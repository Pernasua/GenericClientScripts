-- genericclient-interface: 2

local event = gc.require("event")

return {
  run = function()
    local random_event = gc.read("random_event")
    if not random_event.active or random_event.npc_id ~= event.invitation_npc_id then
      error("Prison Pete solver started without its owned event")
    end

    gc.activity("general")
    return event.solve(random_event.detected_tick)
  end,
}
