package com.genericclient.scripts.events;

import com.genericclient.scripts.shared.Conversations;
import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;

@ScriptManifest(name="Count Check",author="GenericClient",category=Category.UTILITY,version=1,description="Complete Count Check's dialogue and verify the outcome.")
@ScriptSettings(id="count-check",randomEvents={12551,12552})
public final class CountCheck extends WorkflowScript
{
	@Override protected Object runWorkflow()
	{
		long tick = EventSupport.begin(12551,12552);
		return Automation.intent("count_check.reward", () ->
		{
			boolean talked = false;
			for (int step = 0; step < 60; step++)
			{
				if (Dialogues.inDialogue())
				{
					Conversations.advance("Check my account, Count Check!","I'll see you another time.");
					Sleep.sleepTicks(1);
					continue;
				}
				boolean passed = EventSupport.message(tick,"pass my checks");
				boolean failed = EventSupport.message(tick,"fail my checks");
				if (!EventSupport.present() && (passed || failed)) return Map.of("status","solved","outcome",passed ? "passed" : "failed");
				if (!talked && EventSupport.present()) { EventSupport.talk(); talked = true; }
				Sleep.sleepTicks(1);
			}
			throw new IllegalStateException("Count Check's outcome was not observed");		});

	}
}
