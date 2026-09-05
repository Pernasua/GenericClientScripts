# Witch's House

`WitchsHouse` resolves the key, basement, magnet, mouse, diary, and return-ball
phases. `WitchGarden` owns patrol timing and garden movement. `WitchExperiment`
owns the four experiment forms, lure positions, spell setup, healing, and recoil.

Basement entry and return each submit one destination journey to the native
planner. The quest advances only after arrival; an interrupted trip stops the
phase before further input.

Acceptance dialogue, cheese-to-magnet input, and diary handling use intents.
Their approaches stay outside the scope. Garden and combat activities suppress
discretionary behavior through explicit policy while retaining safety monitoring.

Checkpoint scope leaves the ready shed fight for a completion run. It also stops
after the experiment, before returning the ball. Completion scope proceeds through
the verified fight and reward dialogue.

A phase advances only after its inventory, position, dialogue, or quest-variable
postcondition is observed. The checkpoint regression is covered by a scenario
test; full live completion of the Java workflow is a separate acceptance step.
