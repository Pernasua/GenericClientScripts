# GenericClient / genericBoss handoff

Updated: 2026-09-01 13:25 EDT

## Stop point

Live work is stopped. RuneLite reached `LOGIN_SCREEN` during the final handoff
check. GenericClient is idle and owns no safety or combat input.

- Account: `genericBoss`
- Last confirmed location before logout: Castle Wars, `(2439, 3090, 0)`
- Last confirmed HP: `28/28`
- Last confirmed run: enabled, `100%`
- Last confirmed Prayer: level `43`, currently `3`; all three
  protection-prayer varbits were off
- Last confirmed poison varp `102`: `-15` (antipoison protection was active)
- Active Lua script: none
- Global activity/state: `idle` / `idle`
- Safety guard: unarmed, no input ownership
- Combat guard: inactive, no input ownership
- Random event: none
- Progression goal is currently paused in Codex goal tracking

Do not immediately restart Quest Runner. The last prison attempt exposed an
unfixed state-classification and recovery bug that caused an unwanted Castle
Wars teleport.

## Last incident: exact sequence and cause

The teleport was not caused by manually stopping the script. That was an
incorrect initial diagnosis. The RuneLite log proves the teleport was already
underway after the prison walker failed.

Timeline for Quest Runner run `4`:

1. At `13:18:35`, Quest Runner started in phase
   `escape_prison_for_amulet`. The player was on the established safe tile
   `(2769, 2795, 0)`.
2. At `13:18:36`, the new nuisance-spider routine attacked the correct nearby
   level-1 Spider: NPC ID `5238`, index `19009`, then at `(2766, 2797, 0)`.
   A second NPC with ID `5238` was behind prison geometry; the final selector
   correctly ignores spiders that are not in-scene, clickable, and in line of
   sight.
3. Melee combat pulled the player off the safe tile to `(2767, 2795, 0)`.
   The spider kill itself worked: Attack gained 3 XP and Hitpoints gained 1 XP.
4. The player was poisoned at tick `1054`. The script correctly drank the last
   `Superantipoison(1)` only after positive poison was observed. It did not
   drink proactively.
5. `garkor.escape_prison()` treats every location that is neither the exact
   safe tile nor `crossed_jail_door()` as though the player is still inside the
   cell. It therefore attempted to walk back to `prison_start`
   `(2771, 2794, 0)`.
6. At `13:18:41`, the walker returned `unreachable` from `(2767, 2795, 0)`.
7. `amulet_crafting.retreat_after_failure()` classifies the whole prison as a
   hazardous zone and unconditionally used the configured ring escape for this
   local puzzle failure. The player teleported to Castle Wars using one ring
   charge.
8. Quest Runner then returned a failure. The host's broad failure-status
   matcher started the sticky Safety Net, which immediately attempted the same
   escape a second time even though the player was already safe at Castle
   Wars. That second attempt referenced the now-stale `Ring of dueling(4)` item
   ID (`2560`); the ring had become `Ring of dueling(3)` (`2562`), so it was
   rejected as missing.
9. The script was stopped and the client returned to true Idle. No further
   input has been issued.

Primary evidence is in:

- `C:\Users\User\.runelite\logs\client.log`, entries from `13:18:35` through
  `13:18:50`
- `C:\Users\User\Videos\genericclient-monkey-madness-prison-puzzle-20260901-1312.jsonl`
- Recovered video:
  `C:\Users\User\Videos\genericclient-monkey-madness-prison-puzzle-20260901-1312-recovered.mkv`

The recovered video is `648.666` seconds long and has SHA-256
`2af26d6d7e922f9ba204c90955c7a9e0654259ae543ea3d59c466d4e334dfb69`.
The synchronized JSONL has 1,036 frames through game tick `1191` and SHA-256
`a83ca08d3b92430c30390f3d2e35ebbca80b755fedcab3702198afc1b6de87f2`.
The original MKV ended abruptly when the recorder wrapper was cancelled; use
the recovered copy. The orphaned recorder and its exact `ffmpeg` child were
terminated, and no recorder job remains active.

## Root causes that remain unfixed

1. Prison progress is inferred from one exact anchor tile. Combat displacement
   is incorrectly interpreted as being back inside the cell.
2. `clear_nearby_spider()` has no caller-provided return anchor, so a successful
   melee kill can invalidate the next puzzle-state assumption.
3. The prison puzzle is included in `in_hazard()`, despite the established
   design that this guard section is a timing puzzle with minor danger, not a
   hazardous-travel phase. Any local failure therefore triggers a full escape.
4. Two recovery owners can act in sequence: quest-local
   `retreat_after_failure()` and the framework Safety Net. Neither tells the
   other that recovery already succeeded.
5. Safety configuration stores the exact charged-ring item ID at arm time.
   Consuming a charge changes the ID and makes a repeated recovery stale.
6. The sticky Safety Net currently calls `safety.recover` unconditionally when
   any script returns a broadly matched failure status. It does not first
   decide whether the player is currently unsafe or already at the configured
   escape destination.

## Required fix before another prison attempt

Keep the solution small, but fix ownership and state rather than adding another
coordinate patch.

1. Replace the exact-tile prison branch with an observed prison topology state:
   cell interior, door threshold, west safe side, and fully clear. Use the live
   player tile plus the exact jail-door object/state. Do not infer “inside cell”
   merely because the player is not on `(2769, 2795, 0)`.
2. Let the nuisance-spider routine accept or preserve a caller anchor. When the
   prison caller begins on the west safe side, kill the accessible spider, make
   one verified return to `(2769, 2795, 0)`, and only then begin the guard
   timing loop. Never restart lockpicking from this state.
3. Remove the prison timing puzzle from unconditional hazardous retreat.
   Puzzle-local `unreachable`, guard-window, and anchor failures should return
   a diagnostic failure while leaving the account in the sticky Safety Net;
   only an observed life-threatening condition should consume the escape.
4. Make recovery idempotent across layers. A failure result should carry
   whether a retreat was attempted/completed, or Safety Net should re-read the
   current player/danger state and decline a duplicate escape when already
   safe.
5. Resolve the current dueling-ring charge ID at escape execution time. The
   accepted family is `2552, 2554, 2556, 2558, 2560, 2562, 2564, 2566`.
6. Preserve true Idle behavior: no prayer, food, escape, combat, or random-event
   input; only the one-time synthetic cursor park on transition to Idle.

Minimum regression cases:

- Start on `(2769, 2795)`, kill Spider `5238`, end combat on `(2767, 2795)`,
  restore the safe anchor, and never request `prison_start` or Pick-lock.
- A local prison walker failure must not rub a ring.
- A failure after an already completed retreat must not produce a second
  Safety Net escape.
- A ring changing from ID `2560` to `2562` remains resolvable.
- Idle continues to own no safety/combat input.

## Last confirmed account state

This snapshot was captured live at Castle Wars before RuneLite returned to the
login screen. Refresh it after logging back in.

Key levels and XP:

| Skill | Level | XP |
| --- | ---: | ---: |
| Attack | 44 | 55,933 |
| Strength | 30 | 14,050 |
| Defence | 1 | 0 |
| Hitpoints | 28 | 11,223 |
| Ranged | 1 | 12 |
| Magic | 33 | 19,729 |
| Prayer | 43 | 50,400 |
| Agility | 31 | 15,788 |
| Thieving | 14 | 2,269 |

Inventory:

- 14 Lobsters
- 1 Stamina potion(4)
- 1 Ring of dueling(3)
- 1 Lockpick
- 4 empty Vials
- 1 Enchanted bar
- 1 M'amulet mould
- 1 Ball of wool
- No antipoison remains
- No prayer potion remains
- Equipment is empty

Monkey Madness I state:

- Main varp `365 = 3`
- Narnode `121 = 7`
- Caranock `122 = 3`
- Daero `123 = 7`
- Lumdo `125 = 3`
- Garkor `126 = 2`
- Zooknock `127 = 5`
- The next objective remains making the M'speak amulet from the carried
  enchanted bar, mould, and wool.

The current RuneLite account note is stale: it still says the player is beside
Garkor and lists an older loadout. Do not use its location/loadout as live
truth. Preserve its account goal and restrictions.

The current amulet-crafting loadout is short exactly these configured supplies
before returning to Ape Atoll:

- 1 Superantipoison(4)
- 3 Prayer potion(4)

Re-read the bank before purchasing because the bank cache is currently unknown.
Buy only actual deficits. The existing Old school bond sell offer must remain
untouched, and the 5,000,000 coin reserve remains mandatory.

## Larger and mid-term goals

Larger goal: build `genericBoss` into the `med80_77` PvP account:

- 80 Attack, 99 Strength, 75 Defence, 99 Hitpoints
- 99 Ranged, 99 Magic, 77 Prayer
- Piety, Rigour, Augury, and Ancient Magicks

Hard rules:

- Never exceed 80 Attack, 75 Defence, or 77 Prayer.
- Members-first progression.
- Buy only the next required supplies, just in time.
- Never buy/redeem a bond, transfer wealth, drop valuables, or enter risk PvP
  without explicit approval.
- Build reusable, clean standalone AIO Lua scripts; each quest owns a folder
  and uses shared framework mechanics only where genuinely common.

Current mid-term goal: complete Monkey Madness I through resumable, observed
checkpoints. The immediate milestone is the M'speak amulet.

Already completed and live-verified on the account:

- Waterfall Quest
- Witch's House
- Tree Gnome Village
- Fight Arena
- The Grand Tree
- Ernest the Chicken
- X Marks the Spot
- Learning the Ropes
- Monkey Madness I puzzle, Crash Island travel, first Ape Atoll capture, an
  earlier timed jail escape, north-side route, Garkor briefing, dentures/mould
  infiltration, Zooknock route, and enchanted-bar creation
- Prayer training to exactly level 43

## Resume sequence

1. Call `client_status`. Use `session_login` through the active Jagex Launcher
   session if RuneLite is still at `LOGIN_SCREEN`, then call `account_snapshot`
   and read the account note.
2. Fix the prison classifier, anchor restoration, recovery ownership, and live
   ring re-resolution. Add only the focused regression cases above.
3. Run targeted Java/Lua checks. Rebuild/install the client only if Java changed;
   Lua-only fixes can be copied to the installed script tree and manifest-reloaded.
4. At Castle Wars, open the bank to refresh its cache, then use the existing JIT
   preparation path to obtain only the missing antipoison/prayer doses.
5. Run Quest Runner with:

   - `quest = monkey_madness_i`
   - `restock = ge`
   - `scope = checkpoint`

   This should stop after each observed phase transition.
6. Stop and notify the user at the dangerous Ape Atoll landing before the valley
   rush. The user explicitly wants to watch and confirm dangerous travel.
7. After confirmation, run only the valley-to-prison checkpoint and stop again.
8. At jail, start Prison Guard Observer and the synchronized video/data recorder
   together. Then replace the observer with the puzzle run while recording.
9. The user watches each prison attempt. Do not burn repeated attempts silently;
   stop promptly on a novel failure and use the screenshot/log/data evidence.
10. After a successful escape, stop at the checkpoint. Do not continue into the
    temple until the user confirms the next dangerous phase.

For long live operations, use the callback monitor in
`GenericClient/mcp/scripts/wait-client.ps1`. It must exit nonzero for script
failure, death, or an explicitly selected failure condition. A passive
background job without a callback is not a completion signal.

## User-established behavior requirements

- Kill the known level-1 Spider before it can repeatedly interrupt critical
  crate or prison interactions. Use exact ID `5238` and only an accessible live
  target.
- Antipoison is consumed only when poison varp is positive. The latest live run
  proved this behavior.
- The prison guard section is a timing puzzle, not hazardous travel.
- No breaks or cursor release during combat, banking, trading, or time-critical
  puzzle input. Ordinary eligible actions still retain the account's microbreak
  behavior; do not globally disable it as a workaround.
- Use stamina and fast repeated navigation only in explicitly hazardous travel,
  not in the prison puzzle or ordinary walking.
- No protection prayer should be forced while Idle. During explicitly dangerous
  travel, the script may own the required protection prayer and consumables.
- On true Idle, perform the synthetic off-screen cursor move once, then leave
  the client completely under manual control.
- Quest Helper may be inspected during development for guidance, but the Lua
  implementation must remain owned and standalone with no runtime dependency.
- Use screenshots whenever memory/snapshots cannot explain the visible state.

## Source and installation state

### GenericClientScripts

- Repository: `/home/user/GenericClientScripts`
- Branch/HEAD: `main` at `9a237e43337978c87fbf9184fc3a971577ca603a`
- Remote: `https://github.com/Pernasua/GenericClientScripts.git`
- Local branch matches `origin/main`, but the worktree contains substantial
  uncommitted quest/AIO/random-event work. Nothing in this worktree is pushed.
- Do not reset, clean, pull over, or discard the dirty tree.

Latest spider refactor:

- `scripts/quest-runner/monkey_madness_i/garkor.lua`
  - One shared `clear_nearby_spider()` routine
  - Exact NPC ID, accessibility filtering, no breaks, bounded kill wait
  - Used in every prison timing cycle
- `scripts/quest-runner/monkey_madness_i/infiltration.lua`
  - Reuses the shared routine before dentures, hidden-floor, and mould crate
  - Removed its duplicate implementation
  - Restores `questing` activity after the combat helper

Source and installed hashes match:

- `garkor.lua`:
  `763d611ae56e87d4073c1ad7cb3013e32a1ac5218233dd07f6b4e7f78419a6c5`
- `infiltration.lua`:
  `0be291fc15f7102dd478901b48e9787a8c60d31de355f1a728371f51fcaa56b0`

Installed script root:
`C:\Users\User\.runelite\genericclient\scripts`

The manifest is currently loaded with 20 scripts. The Certer solver is present
and registered for NPC IDs `5436-5441`; its syntax/model mapping checks passed,
but it has not been live-proven on a new Certer event.

### GenericClient

- Repository: `/home/user/GenericClient`
- Branch/HEAD: `main` at `06309d6d940f713d14d844fd11659870f2f20b9e`
- Remote: `https://github.com/JarrettOneSource/GenericClient.git`
- Local branch reports nine commits behind `origin/main` and has a large dirty
  worktree. Do not pull or merge blindly.
- Built JAR: `/home/user/GenericClient/build/libs/GenericClient.jar`
- Installed JAR:
  `C:\Users\User\AppData\Local\GenericClient\GenericClient.jar`
- Both JARs match SHA-256:
  `266c0122864e887388b6044f4570c2bb4adf249f133afeff68de3f908184aa07`

The installed client includes the current Lua/MCP surface, screenshot support,
chat/system messages, scene markers, global/script state overlays, behavior
profile controls, synthetic cursor behavior, walker changes, death forensics,
combat guard, true Idle input release, and sticky Safety Net framework.

The latest full client gates passed before this JAR was installed:

- Gradle test suite
- Shadow JAR build
- MCP Node test suite
- `git diff --check`

The latest Lua spider changes passed `luac -p` and `git diff --check`, were
copied into the installed script tree, and were manifest-reloaded. Their kill
and poison-triggered antipoison behavior were live-proven; their integration
with prison position recovery failed as described above.

No current changes have been committed or pushed.
