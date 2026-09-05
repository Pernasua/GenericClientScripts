package com.genericclient.scripts.quests;

import com.genericclient.script.SnapshotData;
import com.genericclient.script.Automation;
import com.genericclient.script.Navigation;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Travel;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.wrappers.interactive.GameObject;

final class MonkeyAmulet
{
	private final QuestWorkflow quest;
	private final MonkeyPrison prison;
	MonkeyAmulet(QuestWorkflow quest, MonkeyPrison prison) { this.quest = quest; this.prison = prison; }
	void craft()
	{
		if (!QuestWorkflow.carried(4021) && !Inventory.contains(4022))
		{
			enterTemple();
			MonkeySurvival.protection("melee",true,12);
			Travel.to(MonkeyMap.TEMPLE_FLAME_STAGING,0,"hazardous_travel");
			GameObject flame = QuestWorkflow.object(4766,MonkeyMap.TEMPLE_FLAME_EDGE);
			QuestWorkflow.require(flame != null && Inventory.get(4007).useOn(flame),"Enchanted bar could not be used on the flame");
			quest.dialogue(() -> Inventory.contains(4022),40);
		}
		if (!QuestWorkflow.carried(4021))
		{
			QuestWorkflow.require(Inventory.contains(1759),"Ball of wool is missing");
			QuestWorkflow.require(Inventory.get(1759).useOn(Inventory.get(4022)),"M'speak amulet could not be strung");
			QuestWorkflow.await(() -> Inventory.contains(4021),30,"M'speak amulet was not observed");
		}
		Supplies.equip(4021);
		if (MonkeyAreas.TEMPLE_DUNGEON.contains(QuestWorkflow.tile()) || MonkeyAreas.north()) leaveTemple();
	}
	void leaveTemple()
	{
		if (MonkeyAreas.TEMPLE_DUNGEON.contains(QuestWorkflow.tile()))
		{
			MonkeySurvival.protection("melee",true,12);
			GameObject rope = GameObjects.closest(4881);
			QuestWorkflow.require(rope != null,"Temple exit rope was not observed");
			Travel.to(rope.getTile(),2,"hazardous_travel");
			QuestWorkflow.require(rope.interact("Climb"),"Temple rope interaction failed");
			QuestWorkflow.await(() -> !MonkeyAreas.TEMPLE_DUNGEON.contains(QuestWorkflow.tile()),40,"Temple exit was not observed");
		}
		if (MonkeyMap.PRISON_CLEAR.distance() <= 4)
		{
			MonkeySurvival.behavior(false);
			Automation.activity("questing");
			Map<String,Object> moved = Navigation.walk(new Navigation.Journey(MonkeyMap.MONKEY_CHILD_STAGING,0).timeout(120),
				Map.of("area",Map.of("name","prison","bounds",MonkeyAreas.PRISON_BOUNDS)),null);
			QuestWorkflow.require("arrived".equals(moved.get("status")) && !MonkeyAreas.prison(),"Monkey child travel failed: " + moved);
			return;
		}
		MonkeySurvival.route(MonkeyRoutes.TEMPLE_TO_MONKEY_CHILD,"melee");
		Travel.to(MonkeyMap.MONKEY_CHILD_STAGING,0,"hazardous_travel");
	}
	private void enterTemple()
	{
		if (MonkeyAreas.TEMPLE_DUNGEON.contains(QuestWorkflow.tile())) return;
		if (MonkeyAreas.south()) prison.enter();
		if (MonkeyAreas.prison()) prison.escape(false);
		QuestWorkflow.require(MonkeyAreas.north(),"Temple route must start on northern Ape Atoll");
		if (!MonkeyAreas.TEMPLE_GUARD_BUILDING.contains(QuestWorkflow.tile())) MonkeySurvival.route(MonkeyRoutes.PRISON_TO_TEMPLE_ENTRY,"missiles");
		MonkeySurvival.protection("melee",true,24);
		approachTrapdoor();
		GameObject trapdoor = GameObjects.closest(object -> (object.getId() == 4879 || object.getId() == 4880) && object.hasAction("Climb-down"));
		if (trapdoor == null)
		{
			GameObject closed = GameObjects.closest(4879);
			QuestWorkflow.require(closed != null && closed.interact("Open"),"Temple trapdoor did not open");
			QuestWorkflow.await(() -> GameObjects.closest(object -> (object.getId() == 4879 || object.getId() == 4880) && object.hasAction("Climb-down")) != null,
				8,"Open temple trapdoor was not observed");
			trapdoor = GameObjects.closest(object -> (object.getId() == 4879 || object.getId() == 4880) && object.hasAction("Climb-down"));
		}
		QuestWorkflow.require(trapdoor.interact("Climb-down"),"Temple descent failed");
		QuestWorkflow.await(() -> MonkeyAreas.TEMPLE_DUNGEON.contains(QuestWorkflow.tile()),40,"Temple arrival was not observed");
	}
	private void approachTrapdoor()
	{
		Map<String,Object> moved = MonkeySurvival.traverse(
			() -> MonkeyRoutes.TEMPLE_TRAPDOOR_APPROACH.avoiding(guardTiles()),"melee",false);
		QuestWorkflow.require("arrived".equals(moved.get("status")),"Temple trapdoor approach failed: " + moved);
	}
	private List<Tile> guardTiles()
	{
		List<Tile> occupied = new ArrayList<>();
		for (Map<?,?> npc : SnapshotData.rows("npcs",Map.of("within",30,"limit",100)))
		{
			int id = SnapshotData.integer(npc,"id");
			if (id != 5275 && id != 5276) continue;
			Map<?,?> world = SnapshotData.map(npc.get("world"));
			int size = SnapshotData.integer(npc,"size");
			for (int x = 0; x < size; x++) for (int y = 0; y < size; y++) occupied.add(new Tile(
				SnapshotData.integer(world,"x")+x,SnapshotData.integer(world,"y")+y,SnapshotData.integer(world,"plane")));
		}
		return occupied;
	}
}
