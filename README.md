# GenericClient Scripts

Standalone Lua automations for [GenericClient](https://github.com/JarrettOneSource/GenericClient).
The client owns snapshots, semantic actions, pathfinding, behavior, safety, UI,
and the MCP bridge. This repository owns script-specific decisions and quest or
training state machines.

## Install

Install GenericClient first, stop any active script, then run from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer copies `scripts` into:

```text
~/.runelite/genericclient/scripts/
```

Press **Reload list** in GenericClient's Automations page, call
`script_reload_manifest`, or restart RuneLite.

## Included automations

- Account inspection and global walking
- AIO Agility, Magic, Melee, and Prayer
- A modular quest runner with per-quest folders
- Standalone random-event solvers
- A bounded movement stress script

## Add a script

Create a Lua file under `scripts` and register it in
[`scripts/manifest.json`](scripts/manifest.json). A standalone entry returns a
descriptor with a `run` function:

```lua
return {
  run = function(input)
    gc.log("info", "player", gc.read("player"))
  end,
}
```

Larger scripts keep related files in a directory and declare each module in the
manifest. Load declared modules with `gc.require("name")`.

The script-specific design and live-validation notes are under [`docs`](docs):

- [`account-builder.md`](docs/account-builder.md)
- [`quest-runner-design.md`](docs/quest-runner-design.md)
- [`aio-agility.md`](docs/aio-agility.md)
- [`aio-prayer.md`](docs/aio-prayer.md)
- [`waterfall-quest-runner.md`](docs/waterfall-quest-runner.md)
- [`witchs-house-quest-runner.md`](docs/witchs-house-quest-runner.md)

Lua files should contain script policy only. Reusable client interaction,
world-state capture, collision, walking, safety, and input primitives belong in
GenericClient.
