# Prayer training

`PrayerTrainer` supports targets 43, 70, and 77. It uses dragon bones, computes the
remaining amount from the XP target, verifies both bone consumption and XP gain,
and honors Stop after bone after a completed action. Restocking can use the bank
only or purchase missing bones while preserving the catalog cash reserve.

The scenario tests verify the final bone reaches the target, cooperative stopping
waits for its observed result, and an insufficient purchase budget makes no trade.
