package com.genericclient.scripts.events;

import com.genericclient.script.ScriptScope;
import com.genericclient.script.ScriptSettings;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.Interfaces;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.map.Area;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

@ScriptManifest(name="Prison Pete",author="GenericClient",category=Category.UTILITY,version=1,
	description="Match balloons to the lever model, return the keys, and leave with the reward.")
@ScriptSettings(id="prison-pete",randomEvents={6754})
public final class PrisonPete extends WorkflowScript
{
	private static final Area PRISON = new Area(2070,4440,2120,4490);
	private static final Map<Integer,List<Integer>> BALLOONS = Map.of(10749,List.of(369,5493),10750,List.of(371,5489),
		11028,List.of(370,5488),11034,List.of(5491,5492));
	@Override protected Object runWorkflow()
	{
		long started = EventSupport.begin(6754);
		EventSupport.enter("prison_pete.accept_game",() -> PRISON.contains(player()),"Yes, that seems like a good idea.");
		Sleep.sleepTicks(2);
		Conversations.finish("Okay.");
		int attempts = 0;
		while (attempts < 8 && !EventSupport.message(started,"got all the keys right"))
		{
			if (!Inventory.contains(6966)) collectKey();
			long tick = ScriptScope.current().tick();
			require(Inventory.interact(6966,"Return"),"Prison key could not be returned");
			await(() -> EventSupport.message(tick,"got all the keys right") || EventSupport.message(tick,"you got the right one") ||
				EventSupport.message(tick,"that was the wrong key"),36000,"Key result was not observed");
			Conversations.finish("Okay.");
			attempts++;
		}
		require(EventSupport.message(started,"got all the keys right"),"Prison key attempt limit reached");
		Travel.to(new Tile(2096,4466),1,"general",NO_DISCRETIONARY);
		require(SnapshotData.action("walk.click",Map.of("x",2101,"y",4466,"plane",0)),"Prison exit interaction failed");
		await(() -> !PRISON.contains(player()),48000,"Prison exit was not observed");
		Conversations.finish("Okay.");
		require(EventSupport.message(started,"your reward is:"),"Prison reward was not observed");
		return Map.of("status","solved","attempts",attempts);
	}
	private void collectKey()
	{
		int model = targetModel();
		List<Integer> ids = BALLOONS.get(model);
		require(ids != null,"Unknown balloon model: " + model);
		Interfaces.click(17891333);
		NPC balloon = NPCs.closest(npc -> ids.contains(npc.getId()) && !npc.isDead() && npc.isOnScreen());
		require(balloon != null && balloon.interact("Pop"),"Matching balloon was not available");
		await(() -> Inventory.contains(6966),21000,"Prison key was not obtained");
		Conversations.finish("Okay.");
	}
	private int targetModel()
	{
		for (int attempt = 0; attempt < 3; attempt++)
		{
			GameObject lever = GameObjects.closest(24296);
			require(lever != null && lever.interact("Pull"),"Prison lever interaction failed");
			await(() -> Interfaces.widget(17891332) != null || Dialogues.inDialogue(),12000,"Balloon target did not appear");
			if (Interfaces.widget(17891332) != null) return Interfaces.widget(17891332).getModelId();
			Conversations.finish("Okay.");
		}
		throw new IllegalStateException("Balloon target model was not observed");
	}
}
