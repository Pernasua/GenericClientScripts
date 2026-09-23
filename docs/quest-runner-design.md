# Quest workflows

`QuestRunner` selects one of eight Java workflows. Each resolves its next phase
from observed quest variables, inventory, equipment, location, dialogue, and
entities. The client provides those snapshots and executes input; quest policy
stays in the catalog.

Romeo & Juliet resumes both conversations and their cutscenes, including an
already-consumed potion. Goblin Diplomacy reuses banked armour and buys only
missing mail and dyes. Its final hand-in waits for the quest journal to report
completion before considering any further preparation. See [free quests](free-quests.md).

Conversations enter an intent after their approach. Item sequences, books,
container searches, and paired equipment changes keep their input and observed
postcondition inside the same scope. Nested dialogue helpers preserve that
boundary. Long journeys and encounters keep their own activity and safety policy.
Failure unwinds the scope before propagating to the workflow's recovery logic.

An NPC approach first reaches its known area, then walks to its observed tile
before resolving the actor again for input. An arrival radius alone can leave
the player behind a closed door. A Continue control disappearing during a page
transition yields to the next observed frame; other rejected inputs still fail.

Each workflow owns its checkpoint definition. Fight Arena separates conversation
and fight checkpoints even when the same varp covers both. Tree Gnome Village
groups the tracker/ballista work and separates the first orb from the warlord.
Witch's House checkpoint scope stops at the ready shed or completed experiment.
Monkey Madness checkpoint scope completes one observed workflow phase; its
prison-cell scope stops at the specified prison position.

Preparation buys only missing supplies when Grand Exchange restocking is enabled.
Bank-only mode rejects missing stock. Food protection is configured before the
hazardous phases that require it. A failed warlord setup attempts the carried
escape before reporting failure. Manual cancellation does not trigger that
recovery.

Order placement, partial fills, and collection are separate outcomes. Shared
preparation resumes pending orders with their original requested quantity until
collection is verified. The client validates the matching offer and its price
ceiling, and checks available cash before each new bid.

Monkey Madness carries route constraints as complete journeys. Its upkeep loop
refreshes poison, stamina, prayer, and food predicates, then resumes a client
continuation. The carried zoo monkey suppresses discretionary breaks and automatic
escape across shared travel helpers. Trapdoor arrival alternatives are permitted
endpoints, not an ordered list of steps.

The workflow tests cover concrete stage, inventory, combat, and transport
regressions. Offline route checks cover the declared geometry. Neither is a claim
that every Java quest branch has been completed on a live account.
