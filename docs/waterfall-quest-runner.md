# Waterfall Quest

`Waterfall` owns progress and loadouts. `WaterfallNavigation` handles the raft,
rope crossings, tourist house, gnome dungeon, and tomb transitions.
`WaterfallRitual` handles the falls key, doors, amulet, six pillars, and chalice.

Preparation distinguishes the initial trip, gnome dungeon, weapon/rune-free tomb,
and final ritual supplies. Each interaction waits for its expected location,
inventory, dialogue, or quest-variable result. Pillar charging recognizes the
observed already-charged response rather than consuming runes repeatedly.

Raft, tourist stairs and gnome dungeon travel each submit one complete destination
journey. Dungeon exits prefer the carried jewellery and can use a native ladder
journey if that trip is unavailable. Rope crossings and tomb entry remain quest
interactions with observed arrival checks. The offline audit covers the declared
destinations against the client's collision and transport data. Complete Java
quest outcomes still require live acceptance.

Book input, dialogue, and closing share the `waterfall.read_book` intent.
The client owns native target resolution, input, navigation, and forced healing;
the catalog owns quest predicates and bounded waits over fresh observations.
