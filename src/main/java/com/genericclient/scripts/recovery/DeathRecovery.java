package com.genericclient.scripts.recovery;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.Interfaces;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.LinkedHashMap;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.widget.Widgets;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

@ScriptManifest(name="Death Recovery",author="GenericClient",category=Category.UTILITY,version=1,
	description="Collect recoverable items from Death's Office and return through the portal.")
@ScriptSettings(id="death-recovery")
public final class DeathRecovery extends WorkflowScript
{
	private static final int TAKE_ALL = 43843594;
	@Override protected Object runWorkflow()
	{
		enterOffice();
		Automation.activity("banking");
		openRetrieval();
		Map<Integer,Integer> before = quantities();
		takeAll();
		if (gained(before).isEmpty()) transferGravestone();
		Map<Integer,Integer> recovered = gained(before);
		require(Widgets.closeAll(),"Retrieval interface did not close");
		Sleep.sleepTicks(1);
		GameObject portal = GameObjects.closest(39549);
		require(portal != null && portal.interact("Use"),"Death's portal was not available");
		await(() -> !insideOffice(),18000,"Death's Office exit was not observed");
		return Map.of("status","complete","recovered",recovered,"quantity",recovered.values().stream().mapToInt(Integer::intValue).sum());
	}
	private boolean insideOffice() { return GameObjects.closest(39549) != null || NPCs.closest(9855) != null; }
	private void enterOffice()
	{
		if (insideOffice()) return;
		Travel.to(new Tile(3238,3192),6);
		GameObject entrance = GameObjects.closest(38426);
		require(entrance != null && entrance.interact("Enter"),"Death's Office entrance was not available");
		await(this::insideOffice,18000,"Death's Office entry was not observed");
	}
	private void openRetrieval()
	{
		if (Interfaces.widget(TAKE_ALL) != null) return;
		NPC death = NPCs.closest(9855);
		require(death != null && death.interact("Collect"),"Death's retrieval interaction failed");
		await(() -> Interfaces.widget(TAKE_ALL) != null || Dialogues.inDialogue(),6000,"Death did not respond");
		retrievalDialogue();
	}
	private void retrievalDialogue()
	{
		for (int tick = 0; tick < 40; tick++)
		{
			if (Interfaces.widget(TAKE_ALL) != null) return;
			if (Dialogues.inDialogue()) Conversations.finish("Can I collect the items from that gravestone now?","Bring my items here now; I'll pay your fee.");
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Death's retrieval interface did not open");
	}
	private void takeAll()
	{
		Interfaces.click(TAKE_ALL);
		Sleep.sleepTicks(4);
		require(!Dialogues.inDialogue(),"Death recovery requires confirmation");
	}
	private void transferGravestone()
	{
		require(Widgets.closeAll(),"Retrieval interface did not close");
		NPC death = NPCs.closest(9855);
		require(death != null && death.interact("Talk-to"),"Death's gravestone dialogue did not open");
		await(Dialogues::inDialogue,6000,"Gravestone dialogue was not observed");
		retrievalDialogue();
		takeAll();
	}
	private Map<Integer,Integer> quantities()
	{
		Map<Integer,Integer> quantities = new LinkedHashMap<>();
		Inventory.all().forEach(item -> quantities.merge(item.getId(),item.getAmount(),Integer::sum));
		return quantities;
	}
	private Map<Integer,Integer> gained(Map<Integer,Integer> before)
	{
		Map<Integer,Integer> gained = new LinkedHashMap<>();
		quantities().forEach((id,quantity) ->
		{
			int increase = quantity-before.getOrDefault(id,0);
			if (increase > 0) gained.put(id,increase);
		});
		return gained;
	}
}
