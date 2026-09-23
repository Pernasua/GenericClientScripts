# Romeo & Juliet and Goblin Diplomacy

Both workflows run through the Java Quest Runner with `scope=complete` or
`scope=checkpoint`. Bank-only mode uses owned supplies; Grand Exchange mode
retains the existing 5,000,000 gp reserve.

Romeo & Juliet uses quest key `romeo__juliet` and varp 144. Its stages cover the
letter, Father Lawrence, the Apothecary, the potion, and the final visit to Romeo.
Cutscene recovery continues the current scene and waits for the return to the
ordinary world. Goblin Diplomacy uses `goblin_diplomacy` and the native quest
progress value, supplying
orange, blue, and brown mail in order. Consumed colours are not prepared again.
Its raw varp 62 also carries flags: the live value `516` represents stage `4`.
The game defines that stage in varbit 2378. Runner results report `stage`.

Stage and item references were checked against the maintained Quest Helper
[Romeo & Juliet](https://github.com/Zoinkwiz/quest-helper/blob/master/src/main/java/com/questhelper/helpers/quests/romeoandjuliet/RomeoAndJuliet.java)
and [Goblin Diplomacy](https://github.com/Zoinkwiz/quest-helper/blob/master/src/main/java/com/questhelper/helpers/quests/goblindiplomacy/GoblinDiplomacy.java)
sources. NPC and object IDs were checked against RuneLite's game-value tables.
The live client places Juliet's lower staircase 11797 at `(3157,3435,0)`;
the upstairs staircase 11799 is at `(3156,3435,1)`.

Regression scenarios distinguish dispatched input from subsequent item, plane,
dialogue, and journal changes. They cover approaching Juliet through doors,
resuming her cutscene, banked supplies, dye rejection, the delayed completion
frame, and stopping without spending supplies.

## Live completion and validation

On 2026-09-05, genericBoss completed both quests through the Java runner. The
quest journal reports Romeo & Juliet finished at progress 100 and Goblin
Diplomacy finished at progress 6. The completion screens showed 33 total Quest
Points. Crafting reached level 5 at 404 XP, and the gold bar reward remains in
inventory. No Grand Exchange offers remain active.

Both new quest implementations have 100% measured JaCoCo line, branch, method,
and instruction coverage. Their focused PIT run killed all 110 mutations with
none uncovered. Scenario coverage includes packed stage flags, stale dialogue
pages, missing supplies, item changes during an intent boundary, pending orders,
cutscene recovery, and completion before the scene finishes loading.

The full client suite passed 676 tests and the catalog suite passed 115 tests.
Configured PMD checks pass, including cyclomatic and cognitive limits below 22.
The client route audit
passes 38 journeys, 66 account checks, and 56 directed transport entries. The
production registry loads all 24 catalog entries. CPD reports no duplicate groups
at its configured 100-token threshold.

Statement coverage, Halstead Difficulty, CRAP, and whole-program dead-code
reachability have no configured analyzer. The wider existing client and catalog
still have coverage and mutation gaps; the complete measurements above apply to
the two new quest implementations.
