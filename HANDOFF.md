# Java catalog cutover

The maintained catalog is implemented in `src/main/java` and packaged as
`build/libs/GenericClientScripts.jar`. The retired source tree, manifest, tests,
and tools have been removed. No backup catalog is retained.

The active client migration checklist is in the sibling GenericClient repository:
`docs/java-scripting-migration.md`. It records integration, validation, and remaining
work. Before final delivery, fetch both repositories, rebase any new main changes,
resolve conflicts, and repeat the affected validation.

Current checks include catalog workflow scenarios, PMD, and Java route export.
The client route audit found all 17 exported journeys. No new catalog artifact has
been installed or exercised on a live account during this migration; do not infer
live quest or training completion from these checks.
