package com.genericclient.scripts.quests;

import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

final class MonkeyDungeon
{
	private final QuestWorkflow quest;
	MonkeyDungeon(QuestWorkflow quest) { this.quest = quest; }
	void reach()
	{
		MonkeySurvival.behavior(false); MonkeySurvival.arm(4);
		MonkeySurvival.protection("melee",true,12);
		if (!MonkeyAreas.ZOOKNOCK_DUNGEON.contains(QuestWorkflow.tile()))
		{
			Travel.to(MonkeyMap.ZOOKNOCK_DUNGEON_ENTRANCE,1,"hazardous_travel");
			GameObject ladder = GameObjects.closest(4780);
			QuestWorkflow.require(ladder != null && ladder.interact("Climb-down"),"Zooknock dungeon entrance failed");
			QuestWorkflow.await(() -> MonkeyAreas.ZOOKNOCK_DUNGEON.contains(QuestWorkflow.tile()),40,"Dungeon entry was not observed");
		}
		Map<String,Object> moved = MonkeySurvival.traverse(() -> MonkeyRoutes.ZOOKNOCK_DUNGEON,"melee",true);
		QuestWorkflow.require("arrived".equals(moved.get("status")),"Zooknock journey failed: " + moved);
		clearAttacker();
		QuestWorkflow.require(QuestWorkflow.npc(7170) != null,"Zooknock was not observed");
	}
	void enchantedBar()
	{
		reach();
		if (quest.bit(127) < 5) quest.talk(new int[]{7170},null,() -> quest.bit(127) >= 5,false,"What do we need for the monkey amulet?","I'll be back later.");
		for (int item : new int[]{4006,4020,2357}) deliver(item);
		if (!Inventory.contains(4007)) quest.talk(new int[]{7170},null,() -> Inventory.contains(4007),false,"What do we need for the monkey amulet?");
		exit();
	}
	void deliver(int id)
	{
		if (!Inventory.contains(id)) return;
		clearAttacker();
		NPC zooknock = QuestWorkflow.npc(7170);
		QuestWorkflow.require(zooknock != null && Inventory.get(id).useOn(zooknock),"Zooknock item delivery failed: " + id);
		quest.dialogue(() -> !Inventory.contains(id),40);
	}
	void exit()
	{
		Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
		MonkeySurvival.protection("melee",false,0);
	}
	private void clearAttacker()
	{
		String name = WorkflowScript.player().getName();
		Map<?,?> attacker = SnapshotData.rows("npcs",Map.of("within",8,"limit",20)).stream()
			.filter(npc -> name.equals(npc.get("interacting")) && ((List<?>)npc.get("actions")).contains("Attack")).findFirst().orElse(null);
		if (attacker == null) return;
		int id = SnapshotData.integer(attacker,"id");
		int index = SnapshotData.integer(attacker,"index");
		NPC target = org.dreambot.api.methods.interactive.NPCs.closest(npc -> npc.getId() == id && npc.getIndex() == index);
		QuestWorkflow.require(target != null && target.interact("Attack"),"Dungeon attacker could not be cleared");
		QuestWorkflow.await(() -> org.dreambot.api.methods.interactive.NPCs.closest(npc -> npc.getId() == id && npc.getIndex() == index && !npc.isDead()) == null,
			60,"Dungeon attacker did not clear");
	}
}
