# Quest Runner design

Status: five modular quest definitions are live-proven end to end: Witch's
House, Waterfall Quest, Tree Gnome Village, Fight Arena, and The Grand Tree.

## Decision

Quest Runner is one standalone Lua script whose descriptor exposes a quest
dropdown and cooperative controls. Lua owns quest facts and phase selection.
Java owns immutable client observations and reusable synthetic interactions.
No quest name, item ID, object ID, coordinate, dialogue answer, or phase order
belongs in the Java plugin.

The existing scripting interface remains the seam:

```lua
gc.read(subject, query)
gc.await(request)
gc.log(level, event, fields)
gc.activity(name, policy)
gc.intent(name, fn)
gc.state(name)
gc.phase(name, options)
gc.overlay(rows)
gc.next_action()
```

New subjects and action types use that interface. A script author uses the same
operations whether a
quest has ten steps or one hundred.

## Ownership

```text
scripts/shared/
  bank, behaviors, consumables, equipment, exchange, failure, geometry, items,
  loadouts, movement, progress, protection, skills, travel, UI, wait

quest-runner.lua
  dropdown, active-quest selection, overlay, orchestration
  |
  +-- quest-runner/shared/
  |     quest state capture and quest loadout preparation
  |
  +-- quest-runner/witchs_house/
  |     config, reducer, quest interactions, garden, combat, completion
  +-- quest-runner/waterfall/
  |     config, reducer, navigation, preparation, ritual, tomb
  +-- quest-runner/tree_gnome_village/
  |     config, reducer, interactions, navigation, combat, runner
  +-- quest-runner/fight_arena/
  |     config, reducer, interactions, navigation, combat, runner
  +-- quest-runner/the_grand_tree/
  |     config, reducer, interactions, navigation, quest, runner
  `-- quest-runner/monkey_madness_i/
        areas, config, reducer, preparation, interactions, navigation, quest modules, runner
                         |
                         | gc.read / gc.await
                         v
GenericClient snapshots and interaction modules
  vars, player vitals, objects, dialogue, item containers
  entity menu selection, item use, dialogue, bank loadout, GE offer
                         |
                         v
RuneLite client thread + recorded synthetic input
```

The deletion test is deliberate: deleting Quest Runner should move quest logic
back into every standalone quest script, while deleting a Java interaction
module should move menu geometry, context selection, event matching, timeout,
and behavior receipts back into every caller. Both modules therefore earn
their depth.

## Quest definition interface

Each quest folder owns its config, pure phase reducer, interactions, recovery,
and quest-specific subsystems. The root descriptor maps the selected dropdown
value to those modules. Adding a quest means adding one cohesive folder and
manifest module entries, not adding quest facts to Java or growing one
cross-quest Lua file.

`resolve(state)` is pure. It returns one phase ID from normalized quest state,
raw quest varps, player zone, inventory, equipment, cached bank contents,
dialogue, and nearby objects. Tests call this interface with table fixtures.
The runtime never increments a local step counter as proof that the game
accepted an action.

Each phase declares:

- a stable ID and compact overlay label;
- its activity and any independent behavior policy overrides;
- a bounded action function;
- a postcondition and game-tick timeout;
- whether `stop_safely` may terminate immediately or must first reach a safe
  checkpoint.

After every action, login, displacement, or timeout, the runner reads a fresh
pinned frame and calls the reducer again.

## Snapshot subjects

Only observations required by the first two quests are added:

| Subject | Result |
| --- | --- |
| `vars` | Requested raw varp values from the tick's copied varp array. IDs are supplied by Lua and bounded to 32 per read. |
| `objects` | Nearby scene objects filtered by ID/name/action/radius, including kind, WorldPoint, distance, and live actions. Same-ID objects at different points remain distinct. |
| `dialogue` | Closed, Continue, or choice state; visible text, speaker, and ordered option text/index. |
| `instance` | Map one canonical template WorldPoint into every matching tile in the current dynamic scene, preserving chunk rotation. |
| `player` | Existing fields plus current/max HP, run energy, run-enabled state, and world destination. |

Normalized quest completion remains `gc.read("quests")`. Raw varps route
in-progress phases but never prove completion.

## Semantic action types

| Action | Interface guarantee |
| --- | --- |
| `object.interact` | Re-resolve an object by ID and optional WorldPoint, validate its live action, face it once if off-camera, use synthetic left/context click, and return the observed menu event. |
| `item.interact` | Re-resolve an inventory slot by item ID and invoke a named action such as `Read`, `Wear`, `Eat`, or `Rub`. |
| `equipment.interact` | Open Equipment, re-resolve the exact worn item, and invoke a semantic action such as `Remove`. |
| `item.use_on_object` | Select `Use` on the requested inventory item, then resolve and click the exact object ID/WorldPoint within one semantic action boundary. |
| `dialogue.continue` | Click the currently visible Continue surface; reject if the dialogue is a choice. |
| `dialogue.choose` | Click an exact visible option string and return its index/text. No substring-first or fixed-index fallback. |
| `bank.loadout` | With a bank open, deposit inventory/equipment as requested, withdraw exact item quantities, verify the resulting allowlist and free slots, and close. |
| `ge.buy` | Preserve existing offers, enforce the configured cash reserve against known cash, place one bounded buy offer, collect it, and return item/quantity/unit-price/reserve receipts. |
| `safety.configure` | Arm the framework guard with a hard HP floor, ordered consumables and heal amounts, automatic exact-fit healing, forced healing below 30% max HP, and an escape fallback. |
| `safety.clear` | Disarm the current emergency guard. |
| `prayer.set` | Open the active-layout Prayer tab, click an exact supported protection prayer, and verify its live varbit. |

Object, NPC, inventory, and widget clicks should share one internal menu-input
implementation. Target resolvers differ; hover verification, context-menu row
selection, `MenuOptionClicked` matching, cancellation, and behavior ordering do
not. This is an internal seam with a live RuneLite adapter and deterministic
test adapter, not another Lua-facing interface.

Lua implements `wait_until` by awaiting game ticks and rereading snapshots.
Lua groups a short conversation, item sequence, or bank transaction with
`gc.intent(name, fn)`. The host opens one boundary at entry and suppresses
discretionary behavior inside it. Nested scopes flatten; errors unwind the
scope and propagate. Long approaches and training loops stay outside intents.
One-off urgent actions use an explicit policy with `breaks = false`,
`cursor_release = "none"`, and `fidget = "none"`. The old per-await flag is
rejected. These policies preserve safety and route ownership.

## Receipts and postconditions

Every mutating action returns:

- `status`: `dispatched`, `complete`, `unchanged`, `rejected`, or `timed_out`;
- the resolved target/item/widget identity;
- dispatch path and actual click count;
- behavior receipts for each semantic action, plus the active intent when scoped;
- an action-specific observed result, never a claim that an unobserved server
  transition succeeded.

Quest phases then prove success separately: zone change, inventory delta, raw
varp change, dialogue change, HP increase, equipment change, or normalized
quest completion. A dispatched click without its phase postcondition is a
retryable or terminal phase failure according to the quest definition.

## Banking and purchases

`bank.loadout` takes an allowlist rather than a tomb denylist. For Glarial's
Tomb the quest definition requests no equipment and only pebble, approved food,
and explicit jewellery. If an amulet is already owned, the observed-state
loadout retains it and skips reacquiring it. The bank module rejects extra
items before the tombstone can be targeted.

`ge.buy` is just-in-time. It accepts item ID, quantity, a maximum unit price,
minimum cash reserve, and optional `items`, `notes`, or `bank` collection mode.
It never cancels or replaces an unrelated offer. An
exact matching zero-fill buy below the requested ceiling may be aborted,
collected, and recreated in the same slot at that ceiling. The first
two quest definitions may buy only their next phase's missing quantities. A
price or reserve failure stops with a receipt for review.

## Safety model

- Auto-retaliate defaults on. Hazardous movement and scripted target selection
  disable it explicitly; ordinary questing restores it so incidental attackers
  are handled without target-specific Lua.
- Each combat script arms `safety.configure` with its own hard floor, approved
  consumables, and optional safe destination. The Java guard preempts breaks and
  active input. It normally chooses a heal that fits, forces an approved heal
  below 30% max HP even when it overheals, and lets the Lua fight continue after
  a successful heal. It stops and escapes only when food is unavailable at the
  forced point or hard floor.
- Safe travel uses the declared travel policy. Hostile travel and escape actions
  declare their independent policy overrides; short interaction sequences use
  intents. Emergency input and physical takeover remain able to interrupt them.
- Mainland travel delegates one destination directly to the global walker.
  It does not insert road waypoints through Varrock buildings; doors and walls
  are costed by the client navigation graph.
- Monkey Madness uses Protect from Missiles from the prison exit to the observed
  west edge of the gorilla temple at `x=2787, y=2784..2789`, then switches
  directly to Protect from Melee before taking another interior step. The
  trapdoor approach replans around live gorilla footprints and changes adjacent
  approach tile after a body-block. The denture-building path supplies Quest
  Helper's light-floor tiles to the generic walker as explicit exclusions.
  The amulet checkpoint keeps Protect from Melee active while using the
  enchanted bar from `(2811,9208)` on the accessible south-center flame segment
  at `(2811,9209)`, stringing and equipping the amulet, climbing the
  rope, and following every Quest Helper waypoint to `(2746,2797)`. It stops
  there before talking to the child. The Zooknock run keeps hazardous travel,
  Protect from Melee, and the emergency food guard active while delivering the
  talisman and bones; it does not stop quest progress to attack dungeon NPCs.
  After receiving the Karamjan greegree it teleports out with the carried ring,
  then disables the dungeon prayer at Castle Wars. Ordinary action failures return to the
  framework safety owner and never invoke a quest-local ring teleport.
  The ordered Zooknock cave route persists its last verified waypoint through
  Stop or client restart, searches only forward from that cursor, clears stale
  progress on a fresh dungeon entry, and clears completed progress after the
  verified dungeon exit.
  The Jungle Demon step requests magic protection through the shared protection
  helper. Capture dialogue is drained before jail
  interactions; prison combat is allowed to settle and the player is
  re-anchored before each timed guard interaction.
- The `prison_cell` scope prepares the required loadout, returns to Ape Atoll,
  opens the cell door on an observed guard window, and terminates on the west
  safe tile. It never enters the separate outer-prison exit loop.
- The runner checks HP/run/food immediately before every hostile transition and
  after every tick while exposed.
- A cooperative stop inside a critical section first exits or reaches the next
  declared safe tile. Hard host Stop still cancels active input immediately.
- Unknown quest stages, missing local player, death, lost dialogue, an
  unexpected zone, or an unverified item delta stop with diagnostics. They do
  not trigger blind repeat clicks.
- Waterfall strict mode requires at least 15 current/max HP for Glarial's Tomb
  and at least 12 for the falls. The current account reaches this through the
  Witch's House definition before Waterfall; no low-HP override is enabled.

## Rejected shapes

- A Java class per quest duplicates quest facts and makes RuneLite updates
  require plugin releases.
- A generic declarative quest DSL attempts to solve unknown future quests before
  two concrete definitions have exercised the seam.
- Direct menu invocation bypasses the recorded cursor and produces no visual or
  interaction receipt.
- Fixed widget coordinates and menu indexes are brittle across layouts and live
  action ordering.
- One long imperative Waterfall coroutine cannot resume safely after a restart.

## Acceptance state

The framework interaction, snapshot, registry, walker, instance-mapping, and
Lua-host surfaces are exercised by the four completed quests. Fight Arena added
the strongest recovery receipt: after a death at Bouncer, the runner restocked,
used the arena's re-entry dialogue, mapped the canonical safespot into the new
private scene, killed Bouncer, crossed the second Khazard instance through its
`Quick-escape` door, and reached normalized `finished` state. The terminal
account snapshot recorded Attack 40, Hitpoints 28, Magic 32, and Thieving 14.

The Grand Tree added live evidence for resumable open dialogue, low-combat quest
confirmation, static-map door staging, Castle Wars return routing, repeated
translation choices, same-ID ladder approaches, hostile-floor safety
preservation, repeated same-varp location reduction, and post-break semantic
target reacquisition. Shipyard proof adds a dialogue-gated object transition,
an in-yard walk, resumable NPC dialogue, and item-plus-varp completion evidence.
The return route now handles the quest-locked Stronghold gate through Femi and
reaches Charlie without consuming another transport charge after a resume. The
completion proof adds large-model staging, bank scrolling, just-in-time GE
restocking, cutscene coordinate stabilization, a camera-zoom NPC retry, the
Black Demon safespot, post-fight cave traversal, root search, and normalized
quest completion.

Quest-specific evidence and exact phase tables live in
[`witchs-house-quest-runner.md`](witchs-house-quest-runner.md) and
[`waterfall-quest-runner.md`](waterfall-quest-runner.md).
