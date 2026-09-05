package com.genericclient.scripts.events;

import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.NPC;

@ScriptManifest(name="Mime",author="GenericClient",category=Category.UTILITY,version=1,description="Observe the mime's animations and reproduce each requested emote.")
@ScriptSettings(id="mime",randomEvents={6753})
public final class Mime extends WorkflowScript
{
	private static final Map<Integer,Integer> EMOTES = Map.of(857,12320770,860,12320774,861,12320771,866,12320775,
		1128,12320777,1129,12320776,1130,12320772,1131,12320773);
	@Override protected Object runWorkflow()
	{
		long started = EventSupport.begin(6753);
		EventSupport.enter("mime.accept_show",() -> NPCs.closest(321) != null,"Yeah, I'd love to do a mime show.");
		Integer answer = null;
		boolean waitingForClose = false;
		List<Integer> rounds = new ArrayList<>();
		for (int tick = 0; tick < 800; tick++)
		{
			NPC mime = NPCs.closest(321);
			if (mime == null)
			{
				if (EventSupport.message(started,"you can now use the","emote")) return Map.of("status","solved","rounds",rounds);
			}
			else
			{
				Integer observed = EMOTES.get(mime.getAnimation());
				if (observed != null) answer = observed;
				boolean panel = com.genericclient.scripts.shared.Interfaces.widget(12320770) != null;
				if (waitingForClose && !panel) { waitingForClose = false; answer = null; }
				else if (!waitingForClose && panel && answer != null)
				{
					com.genericclient.scripts.shared.Interfaces.click(answer);
					rounds.add(answer);
					waitingForClose = true;
				}
			}
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Mime show completion was not observed");
	}
}
