local function configure(options)
  local receipt = gc.await {
    action = {
      type = "client.behaviors.configure",
      emergency_consumables = options.emergency_consumables ~= false,
      emergency_escape = options.emergency_escape ~= false,
      combat_prayer = options.combat_prayer ~= false,
      auto_retaliate = options.auto_retaliate ~= false,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
  }
  if receipt.status ~= "complete" then
    return nil, {
      status = "client_behavior_configuration_failed",
      receipt = receipt,
    }
  end
  return true, receipt
end

return { configure = configure }
