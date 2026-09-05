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
- AIO Agility, Magic, Melee, Prayer, and Thieving
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
manifest. Reusable mechanics shared by otherwise independent scripts live under
`scripts/shared/`; script- or quest-specific policy stays with its owner. Load
declared modules with `gc.require("name")`.

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

## Behavior and validation

This catalog targets scripting API 3, reported by `gc.read("runtime").api_version`.
Install the matching client and catalog together.

Declare the script's activity with `gc.activity(name, policy)`. Use
`gc.intent(name, function() ... end)` for a short conversation, item sequence,
or bank transaction. Finish long approaches before entering the scope. Nested
intents share one boundary; leaving a scope restores ordinary action boundaries.

Individual overrides belong in `policy = { ... }`. Urgent actions that must
suppress all discretionary behavior use `breaks = false`,
`cursor_release = "none"`, and `fidget = "none"` in that policy. The legacy
per-await flag and `interrupt_on_dialogue` alias are rejected by the client.
Use `interrupt_on = { dialogue = true }` for walking.

`shared_movement.walk(destination, within, options)` accepts `ticks`, `policy`,
`activity`, `humanize`, `run`, `via`, `avoid_tiles`, `arrival_tiles`,
`interrupt_on`, and `resume`. `approach` accepts the same options and returns
immediately when already close enough. Equipment helpers accept `options.policy`;
jewelry helpers accept separate `policy` and `keyboard` options.

Run `python3 tools/validate.py` before installing changes. It uses Lua 5.4,
Python 3, and Pygments to check syntax, reject retired behavior fields and combat
activity mismatches, and run the Lua behavior scenarios. The lint checks literal
table and call structure; it does not analyze dynamically constructed aliases.
From the GenericClient repository, `./gradlew --offline scriptCatalogAudit`
loads all registered descriptors and their declared modules through the native
Lua VM. Pass `-PscriptCatalog=/path/to/GenericClientScripts` for another checkout.
