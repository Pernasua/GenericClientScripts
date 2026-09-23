package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.script.Navigation;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Jewellery;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.wrappers.interactive.GameObject;

final class MonkeyTravel
{
	static final int[] DAERO = {1444,1445,2020};
	static final int[] WAYDAR = {1446,6675};
	static final int[] LUMDO = {1453,1454,1438};
	private final QuestWorkflow quest;
	MonkeyTravel(QuestWorkflow quest) { this.quest = quest; }

	void stronghold()
	{
		if (MonkeyAreas.tree() || MonkeyAreas.STRONGHOLD_TRANSPORT.contains(QuestWorkflow.tile())) return;
		if (Inventory.contains(4033))
		{
			MonkeyFavor.transport(MonkeyRoutes.ZOO_TO_GRAND_TREE);
			return;
		}
		if (MonkeyAreas.GANDIUS.contains(QuestWorkflow.tile())) { king(); return; }
		if (MonkeyMap.GE_SPIRIT_TREE.distance() > 120)
		{
			if (Jewellery.carried(Jewellery.Destination.GRAND_EXCHANGE)) Jewellery.teleport(Jewellery.Destination.GRAND_EXCHANGE);
			else if (Jewellery.carried(Jewellery.Destination.EMIRS_ARENA)) Jewellery.teleport(Jewellery.Destination.EMIRS_ARENA);
			else throw new IllegalStateException("Stronghold travel requires teleport jewellery from this location");
		}
		journey(MonkeyMap.STRONGHOLD_ARRIVAL,1,600);
	}

	void king()
	{
		if (QuestWorkflow.npc(GnomeTravel.KING) != null) return;
		if (MonkeyAreas.SHIPYARD.contains(QuestWorkflow.tile()))
		{
			quest.walk(MonkeyMap.SHIPYARD_GATE_INSIDE,1,false);
			GameObject gate = GameObjects.closest(2438);
			WorkflowScript.require(gate != null && gate.interact("Open"),"Shipyard exit gate did not open");
			quest.walk(MonkeyMap.SHIPYARD_GATE_OUTSIDE,0,false);
			WorkflowScript.require(!MonkeyAreas.SHIPYARD.contains(QuestWorkflow.tile()),"Shipyard exit was not observed");
		}
		WorkflowScript.require(QuestWorkflow.tile().getZ() == 0 || MonkeyAreas.tree(),"King Narnode travel cannot resume from this location");
		journey(MonkeyMap.KING_NARNODE,3,600);
		WorkflowScript.require(QuestWorkflow.npc(GnomeTravel.KING) != null,"King Narnode was not observed after travel");
	}

	void daero()
	{
		if (QuestWorkflow.npc(DAERO) != null) return;
		WorkflowScript.require(MonkeyAreas.tree() || MonkeyAreas.STRONGHOLD_TRANSPORT.contains(QuestWorkflow.tile()),
			"Daero travel cannot resume from this location");
		journey(MonkeyMap.DAERO,5,600);
		WorkflowScript.require(QuestWorkflow.npc(DAERO) != null,"Daero was not observed after travel");
	}

	void shipyardGate() { journey(MonkeyMap.SHIPYARD_GATE,3,600); }

	private void journey(Tile destination, int within, int ticks)
	{
		Automation.activity("travel",Inventory.contains(4033) ? WorkflowScript.NO_DISCRETIONARY : Map.of());
		Map<String,Object> receipt = Navigation.walk(new Navigation.Journey(destination,within).timeout(ticks),Map.of("dialogue",true),null);
		WorkflowScript.require("arrived".equals(receipt.get("status")),"Travel did not reach " + destination);
	}

	void ape()
	{
		if (MonkeyAreas.ape()) return;
		if (Inventory.contains(4033)) Automation.activity("questing",WorkflowScript.NO_DISCRETIONARY);
		MonkeySurvival.arm(4);
		if (!MonkeyAreas.CRASH_ISLAND.contains(QuestWorkflow.tile()))
		{
			if (!MonkeyAreas.POST_PUZZLE_HANGAR.contains(QuestWorkflow.tile()))
			{
				stronghold();
				journey(MonkeyMap.POST_PUZZLE_LANDING,1,600);
			}
			journey(MonkeyMap.CRASH_ISLAND_LANDING,1,300);
		}
		if (quest.bit(125) < 2) quest.talk(LUMDO,null,() -> quest.bit(125) >= 2,false);
		if (quest.bit(125) < 3) quest.talk(WAYDAR,null,() -> quest.bit(125) >= 3,false,"I cannot convince Lumdo to take us to the island...");
		sail();
	}

	private void sail()
	{
		String continuation = null;
		for (int attempt = 0; attempt < 24; attempt++)
		{
			WorkflowScript.require(SnapshotData.action("consumable.cure_poison",Map.of()),"Poison could not be cured before sailing");
			Automation.activity("travel",Inventory.contains(4033) ? WorkflowScript.NO_DISCRETIONARY : Map.of());
			Map<String,Object> receipt = Navigation.walk(new Navigation.Journey(MonkeyMap.APE_ATOLL_LANDING,1).timeout(300),
				Map.of("dialogue",true,"poisoned",true),continuation);
			if ("arrived".equals(receipt.get("status"))) return;
			WorkflowScript.require("interrupted".equals(receipt.get("status")) && "poisoned".equals(receipt.get("reason")) &&
				receipt.get("continuation") instanceof String,"Ape Atoll sailing did not arrive: " + receipt);
			continuation = (String)receipt.get("continuation");
		}
		throw new IllegalStateException("Ape Atoll sailing interruption limit reached");
	}
}
