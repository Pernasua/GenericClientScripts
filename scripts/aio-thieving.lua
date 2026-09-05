-- genericclient-interface: 2

local config = gc.require("config")
local runner = gc.require("runner")

return {
  inputs = {
    {
      id = "target_level",
      label = "Target level",
      type = "choice",
      default = "25",
      choices = {
        { value = "25", label = "25" },
      },
    },
    {
      id = "method",
      label = "Method",
      type = "choice",
      default = "auto",
      choices = {
        { value = "auto", label = "Auto" },
        { value = "ardougne_bakery", label = "East Ardougne bakery" },
      },
    },
  },

  actions = {
    { id = "stop_after_steal", label = "Stop after steal" },
  },

  run = function(input)
    local target = assert(tonumber(input.target_level), "Invalid Thieving target")
    assert(config.target_xp[input.target_level], "Unsupported Thieving target")
    local method = input.method == "auto" and "ardougne_bakery" or input.method
    assert(method == "ardougne_bakery", "Unsupported Thieving method: " .. tostring(method))
    return runner.run(target, method)
  end,
}
