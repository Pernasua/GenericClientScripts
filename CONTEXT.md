# Catalog workflows

The catalog defines account objectives in terms of observed progress and results.

## Language

**Workflow:** The decisions for one training, quest, recovery, or event objective.

**Catalog entry:** A named automation the operator can select and configure.

**Script artifact:** One distributable `<catalog-id>.jar` containing exactly one
catalog entry plus its transitive local helpers and package resources. The
GenericClient SDK remains client-owned. A workflow option inside an entry, such
as one quest in Quest Runner, is not a separate artifact.

**Snapshot:** The observed account and scene state at a game tick.

**Receipt:** The observed result of an input operation, distinct from the game
change that input may cause.

**Journey:** Travel to one destination with an arrival radius and any required
via points, arrival alternatives, or avoided tiles.

**Continuation:** Permission to resume an interrupted journey with its observed
progress intact.

**Checkpoint:** A meaningful observed quest boundary selected by the operator.
It can be finer than a quest stage variable changing.

**Stage:** The quest's progression value. Each workflow selects its native source;
a packed varp may also contain flags that are not part of the stage.

**Cooperative stop:** A request to finish the current bounded action before ending
the workflow.

**Escape:** A quest's way out of its hazardous area when it stops safely or a
recovery fails: carried teleport jewellery, otherwise a walk to a known safe tile.
Without a hazardous area or a walking route out of it, the quest stops in place.

**Cash reserve:** The 5,000,000 coins that restocking must leave available.

**Intent:** A short action sequence that shares one behavior boundary. Nested
intents keep the outer boundary, and failure releases the scope. Long travel
and training loops remain outside.

**Behavior policy:** Independent choices for discretionary breaks, cursor
release, fidgeting, mouse input, safety ownership, and navigation refresh.
Suppressing discretionary behavior does not make an activity manual.
