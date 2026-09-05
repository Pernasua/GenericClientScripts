# GenericClient Scripts

Java automations for [GenericClient](https://github.com/JarrettOneSource/GenericClient).
The client owns snapshots, input, navigation, and script execution. This catalog
owns training, quest, recovery, and random-event decisions.

## Build and install

Use a JDK 11 or newer and keep the GenericClient checkout beside this repository:

```bash
./gradlew build -PgenericClientDir=../GenericClient
```

The build produces `build/libs/GenericClientScripts.jar`. It compiles against
`GenericClient-script-api.jar`, built by the client project. To use an already
built SDK, pass `-PscriptApiJar=/absolute/path/GenericClient-script-api.jar`.

Stop active scripts before replacing their JAR. Install from Bash:

```bash
./install.sh
```

Or from PowerShell:

```powershell
.\install.ps1
```

The installer places the JAR in `~/.runelite/genericclient/scripts/` and removes
retired interpreter sources and their manifest. Other Java script JARs remain.
Reload the catalog in GenericClient, call the MCP `script_reload` tool, or restart
the client. No backup of the retired catalog is created.

## Included scripts

- AIO Prayer, Magic, Melee, Agility, and Thieving
- Quest Runner: Witch's House, Waterfall, Tree Gnome Village, Fight Arena,
  The Grand Tree, and Monkey Madness I
- Account Auditor, Walker, Walk Stress, Prison Guard Observer, and XP Lamp
- Death Recovery and Safety Net
- Genie, Rick Turpentine, Drunken Dwarf, Count Check, Certer, Capt' Arnav, Mime,
  Pinball, Molly, Prison Pete, and Evil Bob event solvers

Training target levels, restocking choices, quest scope, and cooperative stop
buttons are declared beside each Java entry point. Grand Exchange restocking
preserves a 5,000,000-coin reserve. Quest progression comes from observed game
state, with explicit checkpoints and verified action results.

## Writing scripts

Scripts extend DreamBot's `AbstractScript` and use `@ScriptManifest`. The optional
GenericClient `@ScriptSettings` declares the catalog ID, inputs, buttons, and
random-event NPC IDs. Each JAR may contain several entry points and shared classes.

Use the supported DreamBot methods for queries and interactions. GenericClient's
`Automation`, `Banking`, and `Navigation` classes add workflow controls and complete
journeys. `Walking.walk()` requests one route step; `Navigation.walkTo()` waits for
arrival. The SDK's supported API and worker rules are documented in the client
repository's `docs/java-scripting.md`.

The catalog requires the matching Java SDK and client with runtime API 3.
Declare activity and independent behavior overrides with
`Automation.activity(name, policy)`. Use `Automation.intent(name, body)` for a
short conversation, item sequence, or bank transaction. Finish long approaches
before entering the intent. Nested intents share one boundary; completion and
failure both release it.

Urgent operations suppress discretionary behavior with `breaks = false`,
`cursor_release = "none"`, and `fidget = "none"` in their policy. Gameplay remains
an owned activity so time accounting and safety continue. The `manual` activity
is reserved for observation, diagnostics, and waiting for operator control.
Journey interruptions use `Navigation.walk(journey, interruptOn, continuation)`.

## Verification

```bash
./gradlew test pmdMain pmdTest pmdRouteAudit -PgenericClientDir=../GenericClient
../GenericClient/gradlew -p ../GenericClient routeAudit scriptCatalogAudit -PscriptCatalog="$PWD"
```

Tests simulate observable inventory, dialogue, entity, and quest transitions.
The offline route audit uses the client's bundled collision graph, ordered via
points, arrival alternatives, and avoided tiles. These checks do not establish
live completion of every quest, encounter, or journey.
The catalog audit loads the packaged JAR through the client's production registry
and verifies every entry point, input, action, and random-event binding.
