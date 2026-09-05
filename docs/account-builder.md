# Account training catalog

The Java catalog supplies focused training entry points rather than one script
that silently changes objectives. Prayer, Magic, Melee, Agility, and Thieving each
expose a target and any relevant method or restocking choices. Schedule rules can
select among those entries using observed account facts.

Magic selects combat or bank training from the requested method and current
levels. Superheat requires its Smithing prerequisite; otherwise the bank method
uses low alchemy. Melee selects an unclaimed goblin, tolerates a bounded target
race, and leaves the area on its low-health or cooperative stop condition.
Restocking preserves the 5,000,000-coin reserve and waits for the exchange window
before submitting an offer.

Tests cover these decisions through observable account state and delayed input
results. Java catalog installation and live account progression are distinct
operations.
