# Snape Grass Collector

Catalog ID: `snape-grass-collector`. The Java entry point is
`com.genericclient.scripts.gathering.snapegrass.SnapeGrassCollector`.
It has no setup inputs, purchasing policy, collection target, or automatic stop.
It requires the native bank-side inventory and `walk.nearest` support introduced
by GenericClient commit `1b2f688`.

## Source and recovery

The source is `C:\Users\User\Downloads\grass.jar` (3,961,997 bytes), SHA-256
`a4e1476764d95d21ad1a6d03b1be319012d23474d2132dc65f32c841fc09325a`.
Its manifest names it “SNAPE GRASS COLLECTOR COMPLETE 100”. Static JDK bytecode
inspection identified an embedded-key AES-GCM payload. Authenticated decoding
and gzip expansion recovered its complete JSON workflow: 116 action nodes and
45 distinct action IDs. The original JAR was not executed. The port does not
load its obfuscated runtime or use DreamBot internals.

The user explicitly requested preserving the original equipment-deposit and
withdraw-all behavior. These are intentional, not proposed fixes.

## Mirrored main workflow

Collect exact-name Snape grass in this fixed north-to-south order, on plane zero:
`(2540,3765)`, `(2542,3765)`, `(2546,3763)`, `(2552,3757)`, `(2553,3754)`,
`(2553,3751)`. The anchor is `(2546,3763)`. Skip an empty target only when another
listed spawn exists; return north when all six are empty, without resetting the
pass index. Do not take grass on other tiles.

Wear a carried Ring of dueling before scanning the banking conditions. Bank when
the inventory is full, fewer than two Waterbirth teleport tablets remain, or
neither inventory nor equipment contains a dueling ring. Use the equipped ring's
Castle Wars option and the original chest ID/location gate.

The bank routine deposits **all equipment, including the ring**, when any
non-ring equipment slot is occupied. It deposits inventory except Waterbirth
tablets when full or when carrying Snape grass. When fewer than two tablets
remain, it withdraws **every available tablet**, not a bounded stack. It withdraws
one replacement ring when necessary, wears it, closes the bank, and returns to
Waterbirth. It does not buy supplies, sell grass, switch accounts, or hop worlds.

The original independent block ordering is retained. In particular, the early
bank-close block can close a ready inventory before equipment or grass is
deposited. Exactly 21 tiles from the Castle Wars reference and exactly 30 tiles
from the Waterbirth anchor retain the original strict-inequality gaps. Failed
teleport attempts still reset the pass index. Insufficient supplies do not
introduce a new purchasing operation or automatic stop.

The script waits one tick after successful pickup/equip/chest actions, six after
Castle Wars teleport, and seven after Waterbirth teleport. Its explicit run
toggle occurs only at 100 energy outside the bank and Grand Exchange. GenericClient
still owns cancellation, safety, input timing, and the native walker's behavior;
this is not a byte-for-byte replacement for DreamBot's input/navigation runtime.

## Display

`Collected` counts observed positive inventory gains, excluding starting stock.
Deposits do not reduce it. `Profit` and `Hourly` intentionally retain the source
labels and show **gross collection value**, not net profit after tablets/rings.
Prices use the public OSRS Wiki high/low quote, cached off the script worker.
An unavailable quote retains the last value, or zero before the first quote;
it never changes gameplay. The “100” in the old manifest is not a stop condition.

## Nearest-bank compatibility boundary

When no ring is available, a loaded bank is attempted first; otherwise the script
asks GenericClient's existing collision/transport graph for a reachable bank,
walks there, and makes the source helper's bounded bank-open attempts. A successful
route query is not treated as arrival. An unreachable result does not fabricate
movement or withdraw supplies.

The fallback table contains 98 source-derived bank destinations with recovered
quest, skill, position, and varbit conditions. Eight original destinations are
not included in global selection because their runtime eligibility predicates
have not been fully mapped: Crafting Guild, Darkmeyer, Lumbridge basement,
Motherlode Mine, Cooks' Guild, Dorgesh-Kaan, Sophanem dungeon, and Quetzacalli Gorge.
A visible bank at those locations can still be opened through the ordinary API.
GenericClient's transport catalog is also narrower than DreamBot's full web
walker. Therefore arbitrary-start/no-ring recovery is **not full DreamBot parity**,
including unqualified boat/island routes. The normal ring-and-tablet loop does
not rely on those global routes. No protected prerequisite was guessed.

## Verification

Scenario tests exercise the production Java SDK against observed inventory,
equipment, location, bank, and delayed game-tick effects. They cover the six-tile
order, moving/depleted targets, rejected and delayed actions, original banking
quirks, all-tablet withdrawals, all-equipment deposits, last ring charge,
strict distance boundaries, run toggling, missing stock, collection beyond 100,
gross-value counters, quote parsing, and failed/successful fallback journeys.
Native tests cover bank-side menu identity and least-cost reachable selection.

These are offline contracts. They do not certify a completed live Waterbirth →
Castle Wars → Waterbirth trip. Source, built JAR, installation, loaded catalog,
and actual live gameplay must be reported separately.
