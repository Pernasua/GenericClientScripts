package com.genericclient.scripts.events;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.Interfaces;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

@ScriptManifest(name="Molly",author="GenericClient",category=Category.UTILITY,version=1,description="Identify Molly's twin, operate the claw, and verify the reward.")
@ScriptSettings(id="molly",randomEvents={6738})
public final class Molly extends WorkflowScript
{
	private static final Map<Integer,Integer> TWINS = Map.ofEntries(
		Map.entry(342,5468),Map.entry(5464,5469),Map.entry(5474,5470),Map.entry(352,357),Map.entry(5478,5477),
		Map.entry(5471,350),Map.entry(356,351),Map.entry(5476,358),Map.entry(5480,346),Map.entry(5467,347),
		Map.entry(5485,5482),Map.entry(5486,5483),Map.entry(361,5484),Map.entry(362,5465),Map.entry(363,343),
		Map.entry(5487,344),Map.entry(364,345),Map.entry(365,354),Map.entry(366,355),Map.entry(367,359));
	@Override protected Object runWorkflow()
	{
		long started = EventSupport.begin(6738);
		EventSupport.enter("molly.accept_invitation",() -> player().getTile().getX() >= 10000,"Sure, anything for Molly.");
		NPC molly = Automation.intent("molly.explanation", () ->
		{
			NPC actor = NPCs.closest("Molly");
			require(actor != null && actor.interact("Talk-to"),"Molly was not available");
			await(Dialogues::inDialogue,6000,"Molly's explanation did not open");
			Conversations.finish("No thanks.");
			return actor;
		});
		Integer twin = TWINS.get(molly.getId());
		require(twin != null,"Unknown Molly appearance: " + molly.getId());
		openDoor();
		GameObject panel = GameObjects.closest(20813);
		require(panel != null && panel.interact("Use"),"Claw control panel did not open");
		await(() -> Interfaces.widget(18153475) != null,12000,"Claw controls were not observed");
		int steps = capture(twin,started);
		Automation.intent("molly.finish_dialogue", () ->
		{
			await(Dialogues::inDialogue,12000,"Capture dialogue did not open");
			Conversations.finish();
			return null;
		});
		openDoor();
		return Automation.intent("molly.claim_reward", () ->
		{
			NPC actor = NPCs.closest("Molly");
			require(actor != null && actor.interact("Talk-to"),"Molly's reward dialogue failed");
			for (int tick = 0; tick < 120; tick++)
			{
				Conversations.advance();
				Sleep.sleepTicks(1);
				if (player().getTile().getX() < 10000 && EventSupport.message(started,"your reward is:"))
					return Map.of("status","solved","twin_id",twin,"control_steps",steps);
			}
			throw new IllegalStateException("Molly's reward was not observed");
		});
	}
	private void openDoor()
	{
		GameObject door = GameObjects.closest(object -> object.getId() == 20817 && object.hasAction("Open"));
		require(door != null && door.interact("Open"),"Molly's door did not open");
		Sleep.sleepTicks(15);
	}
	private int capture(int twin, long started)
	{
		for (int step = 0; step < 200; step++)
		{
			if (EventSupport.message(started,"caught the evil twin")) return step;
			GameObject claw = GameObjects.closest(20811);
			NPC target = NPCs.closest(twin);
			if (claw == null || target == null) { Sleep.sleepTicks(1); continue; }
			Interfaces.click(control(claw.getTile(),target.getTile()));
			Sleep.sleepTicks(3);
		}
		throw new IllegalStateException("Molly's twin was not captured");
	}
	static int control(Tile claw, Tile target)
	{
		if (claw.getX() < target.getX()) return 18153481;
		if (claw.getX() > target.getX()) return 18153479;
		if (claw.getY() < target.getY()) return 18153482;
		if (claw.getY() > target.getY()) return 18153480;
		return 18153475;
	}
}
