package com.genericclient.scripts.events;

import com.genericclient.script.Automation;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import java.util.function.LongPredicate;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.utilities.Sleep;

abstract class GiftEvent extends WorkflowScript
{
	protected Object solve(String name, int npc, LongPredicate reward)
	{
		long tick = EventSupport.begin(npc);
		return Automation.intent(name, () ->
		{
			boolean talked = false;
			for (int step = 0; step < 80; step++)
			{
				if (Dialogues.inDialogue()) EventSupport.dialogue();
				else if (!EventSupport.present() && reward.test(tick)) return Map.of("status","solved");
				else if (!talked && EventSupport.present()) { EventSupport.talk(); talked = true; }
				Sleep.sleepTicks(1);
			}
			throw new IllegalStateException("Random-event reward was not observed");		});

	}
}
