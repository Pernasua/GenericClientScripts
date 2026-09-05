-- genericclient-interface: 2

local runner = gc.require("runner")

return {
  run = function()
    return runner.run()
  end,
}
