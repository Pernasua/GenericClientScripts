# GenericClient Scripts

Java automations for [GenericClient](https://github.com/JarrettOneSource/GenericClient).
The client owns snapshots, input, navigation, and script execution. This catalog
owns training, quest, recovery, and random-event decisions.

## Build and install

Use a JDK 11 or newer and keep the GenericClient checkout beside this repository:

```bash
./gradlew build -PgenericClientDir=../GenericClient
```

The build produces **one JAR per selectable script** in `build/libs/`, such as
`snape-grass-collector.jar`, `aio-magic.jar`, and `quest-runner.jar`. Each contains
its required helper classes and resources; no shared-library JAR is needed.
The SDK is provided by GenericClient, not bundled in these files. `jar` and
`scriptJars` also generate the individual files. The old combined
`GenericClientScripts.jar` is no longer produced.

Compilation uses `GenericClient-script-api.jar`, built by the client project.
To use an already built SDK, pass
`-PscriptApiJar=/absolute/path/GenericClient-script-api.jar`.

Stop active scripts before replacing their JAR. Install from Bash:

```bash
./install.sh
```

Or from PowerShell:

```powershell
.\install.ps1
```

These commands install the full set from `build/libs/`, verifying `scripts.sha256`
before changing installed files. An existing combined `GenericClientScripts.jar`
is moved to a backup outside the scanned script directory. Replaced individual
JARs are backed up too; unrelated user JARs are preserved. Failed copies restore
the affected installed files.

To install just one script after migration, pass its JAR:

```bash
./install.sh build/libs/snape-grass-collector.jar
```

```powershell
.\install.ps1 -Source .\build\libs\snape-grass-collector.jar
```

A single-file install refuses to proceed while the old combined catalog exists,
rather than remove its other scripts or create duplicate registrations.
Use the full-directory installer once to migrate an existing catalog.

### Sharing a script

Give the recipient only the desired `<script-id>.jar`. They need a compatible
GenericClient installation and authorization, but no compiler or SDK download.
With scripts stopped, copy the file into
`%USERPROFILE%\.runelite\genericclient\scripts` on Windows, or
`~/.runelite/genericclient/scripts` elsewhere. Then use **Scripts → Reload list**.
Do not extract or double-click the JAR. Do not leave the old combined catalog or
renamed copies of the same script in that folder.

Quest Runner remains one selectable script with its existing quest choices.
Safety/recovery scripts and random-event solvers are separate catalog entries,
not additional entry points silently bundled in another script's JAR.

## Included scripts

- [Snape Grass Collector](docs/snape-grass.md): the recovered Waterbirth/Castle Wars
  workflow, preserving its original equipment deposits and withdraw-all tablets
- AIO Prayer, Magic, Melee, Agility, and Thieving
- Quest Runner: Witch's House, Waterfall, Tree Gnome Village, Fight Arena,
  The Grand Tree, Monkey Madness I, Romeo & Juliet, and Goblin Diplomacy
- Account Auditor, Walker, Walk Stress, Prison Guard Observer, and XP Lamp
- Death Recovery and Safety Net
- Genie, Rick Turpentine, Drunken Dwarf, Count Check, Certer, Capt' Arnav, Mime,
  Pinball, Molly, Prison Pete, and Evil Bob event solvers

Training target levels, restocking choices, quest scope, and cooperative stop
buttons are declared beside each Java entry point. Grand Exchange restocking
preserves a 5,000,000-coin reserve. Quest progression comes from observed game
state, with explicit checkpoints and verified action results.

## Writing scripts

Scripts extend DreamBot's `AbstractScript` and use `@ScriptManifest`.
GenericClient `@ScriptSettings` declares the catalog ID, inputs, buttons, and
random-event NPC IDs. Every entry in this maintained catalog must have a unique
kebab-case ID; that ID is its JAR filename. New annotated scripts are discovered
automatically, with no second packaging list to maintain.

The build computes local class dependencies from compiled class references,
descriptors, and literal reflection names. Put resources alongside their owning
Java package under `src/main/resources/`; package subdirectories and root-level
resources are included. Runtime-computed class names need an explicit class
reference to their helper. A script must not depend on another annotated entry
point: extract common behavior into an unannotated helper instead. Packaging
never executes script constructors or lifecycle callbacks.

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
./gradlew build -PgenericClientDir=../GenericClient
python3 tests/test_install.py
../GenericClient/gradlew -p ../GenericClient routeAudit scriptCatalogAudit -PscriptCatalog="$PWD"
```

Tests simulate observable inventory, dialogue, entity, and quest transitions.
The offline route audit uses the client's bundled collision graph, ordered via
points, arrival alternatives, and avoided tiles. The catalog audit loads the
packaged JARs individually and together through the client's production registry
and verifies every entry point, input, action, and random-event binding. Packaging
tests additionally use a classloader containing only one JAR and the SDK, and
check reproducible output and resource inclusion. Installer tests exercise real
temporary directories; use `--powershell /path/to/pwsh` for PowerShell or the
Windows executable from WSL with `--temp-root` set to a Windows-mounted directory.

These checks do not establish live completion of a quest, encounter, or journey.
A live account completed Romeo & Juliet and Goblin Diplomacy on 2026-09-05 (see
[free quests](docs/free-quests.md)); every other workflow needs its own live
acceptance.
