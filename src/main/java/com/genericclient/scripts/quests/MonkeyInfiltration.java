package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.script.EntityReference;
import com.genericclient.script.Navigation;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Travel;
import java.util.Arrays;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.wrappers.interactive.GameObject;

final class MonkeyInfiltration
{
	private final QuestWorkflow quest;
	private final MonkeyPrison prison;
	MonkeyInfiltration(QuestWorkflow quest, MonkeyPrison prison) { this.quest = quest; this.prison = prison; }
	void obtain()
	{
		MonkeySurvival.arm(4);
		if (!MonkeyAreas.AMULET_MOULD_ROOM.contains(QuestWorkflow.tile()))
		{
			building();
			if (!Inventory.contains(4006))
			{
				MonkeySurvival.route(MonkeyRoutes.DENTURE_SAFE_APPROACH,"missiles");
				searchCrate(4715,"Denture crate search failed");
				quest.dialogue(() -> Inventory.contains(4006),60,"Yes");
			}
			carefulWalk(MonkeyMap.DENTURE_HOLE,0);
			searchCrate(4714,"Denture hole was not found");
			quest.dialogue(() -> MonkeyAreas.AMULET_MOULD_ROOM.contains(QuestWorkflow.tile()),100,"Yes, I'm sure.");
		}
		if (Inventory.contains(4020)) return;
		Travel.to(MonkeyMap.AMULET_MOULD_CRATE,1,"hazardous_travel");
		GameObject crate = GameObjects.closest(4724);
		WorkflowScript.require(crate != null && crate.interact("Search"),"Amulet mould crate search failed");
		quest.dialogue(() -> Inventory.contains(4020),60,"Yes");
	}
	private void building()
	{
		if (MonkeyAreas.DENTURE_BUILDING.contains(QuestWorkflow.tile())) return;
		boolean fromPrison = MonkeyAreas.prison() || MonkeyAreas.south() ||
			MonkeyAreas.PRISON_NORTH_EXIT.contains(QuestWorkflow.tile()) || MonkeyAreas.PRISON_WEST_CLEAR.contains(QuestWorkflow.tile()) || MonkeyMap.PRISON_CLEAR.distance() <= 4;
		if (MonkeyAreas.south()) prison.enter();
		if (MonkeyAreas.prison()) prison.escape(false);
		MonkeySurvival.route(fromPrison ? MonkeyRoutes.PRISON_TO_DENTURES : MonkeyRoutes.GARKOR_TO_DENTURES,"missiles");
		GameObject door = GameObjects.closest(4710);
		WorkflowScript.require(door != null && door.interact("Open"),"Denture building did not open");
		WorkflowScript.awaitTicks(() -> MonkeyAreas.DENTURE_BUILDING.contains(QuestWorkflow.tile()),30,"Denture building entry was not observed");
	}
	private void carefulWalk(org.dreambot.api.methods.map.Tile point, int within)
	{
		Automation.activity("hazardous_travel",WorkflowScript.NO_DISCRETIONARY);
		Map<String,Object> moved = Navigation.walk(new Navigation.Journey(point,within).timeout(40)
			.avoiding(Arrays.asList(MonkeyMap.DENTURE_LIGHT_FLOOR)),
			Map.of("area",Map.of("name","prison","bounds",MonkeyAreas.PRISON_BOUNDS)),null);
		WorkflowScript.require("arrived".equals(moved.get("status")) && !MonkeyAreas.prison(),"Denture aisle route failed: " + moved);
	}
	private void searchCrate(int id, String failure)
	{
		GameObject crate = GameObjects.closest(id);
		WorkflowScript.require(crate != null,failure);
		EntityReference reference = (EntityReference)crate.getReference();
		Map<?,?> observed = reference.read();
		WorkflowScript.require(!observed.isEmpty() && SnapshotData.action("object.interact",Map.of(
			"id",id,"identity",reference.identity,"action","Search","world",observed.get("world"),"within",2)),failure);
	}
}
