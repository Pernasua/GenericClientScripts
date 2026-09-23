package com.genericclient.scripts.events;

import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.script.SnapshotData;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.utilities.impl.Condition;
import org.dreambot.api.wrappers.interactive.NPC;

final class EventSupport
{
	private EventSupport() {}
	static Map<?,?> current() { return SnapshotData.read("random_event"); }
	static long begin(int... ids)
	{
		Map<?,?> event = current();
		if (!Boolean.TRUE.equals(event.get("active")) || Arrays.stream(ids).noneMatch(id -> id == ((Number)event.get("npc_id")).intValue()))
			throw new IllegalStateException("Solver does not own this random event");
		Automation.activity("general",WorkflowScript.NO_DISCRETIONARY);
		return ((Number)event.get("detected_tick")).longValue();
	}
	static void talk()
	{
		Map<?,?> event = current();
		int index = ((Number)event.get("npc_index")).intValue();
		int id = ((Number)event.get("npc_id")).intValue();
		NPC npc = NPCs.closest(candidate -> candidate.getIndex() == index && candidate.getId() == id);
		if (npc == null || !npc.interact("Talk-to")) throw new IllegalStateException("Random-event NPC interaction failed");
	}
	static boolean present() { return Boolean.TRUE.equals(current().get("present")); }
	static List<Map<?,?>> messages(long since)
	{
		return SnapshotData.rows("messages",Map.of("since_tick",since,"limit",30));
	}
	static boolean message(long since, String... fragments)
	{
		for (Map<?,?> message : messages(since))
		{
			String text = ((String)message.get("text")).toLowerCase(java.util.Locale.ROOT);
			if (Arrays.stream(fragments).allMatch(text::contains)) return true;
		}
		return false;
	}
	static void await(Condition condition, int ticks, String failure)
	{
		if (!Sleep.sleepUntil(condition,ticks * 600L)) throw new IllegalStateException(failure);
	}
	static void enter(String name, Condition ready, String... choices)
	{
		if (ready.verify()) return;
		Automation.intent(name, () ->
		{
			talk();
			for (int tick = 0; tick < 100; tick++)
			{
				if (ready.verify()) return null;
				Conversations.advance(choices);
				Sleep.sleepTicks(1);
			}
			throw new IllegalStateException("Random-event activity did not open");		});

	}
}
