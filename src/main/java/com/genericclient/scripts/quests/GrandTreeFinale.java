package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supply;
import com.genericclient.scripts.shared.Travel;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.magic.Normal;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

final class GrandTreeFinale
{
	private final GrandTree quest;
	private final GnomeTravel travel;
	GrandTreeFinale(GrandTree quest, GnomeTravel travel) { this.quest = quest; this.travel = travel; }
	void execute(String phase)
	{
		switch (phase)
		{
			case "prepare_combat": quest.prepare(List.of(new Supply(1387,"Staff of fire",1,5000),new Supply(558,"Mind rune",300,20),
				new Supply(556,"Air rune",600,20),new Supply(379,"Lobster",6,500),QuestWorkflow.duelingRing())); break;
			case "demon": fight(); break;
			case "cave_king": reachCaveKing(); quest.talk(GnomeTravel.KING,null,() -> quest.stage() >= 150,false); break;
			case "rock": findRock(); break;
			case "return_rock": reachCaveKing(); quest.talk(GnomeTravel.KING,null,quest::finished,false); break;
			default:throw new IllegalArgumentException("Unknown Grand Tree finale phase: " + phase);
		}
	}
	private boolean inCave() { return QuestWorkflow.tile().getY() >= 9800 || QuestWorkflow.tile().getX() >= 10000; }
	private void enterCave(boolean afterFight)
	{
		if (inCave()) return;
		travel.watchtower();
		GameObject hatch = GameObjects.closest(afterFight ? 26243 : 2444);
		QuestWorkflow.require(hatch != null,"Glough's trapdoor was not observed");
		String action = hatch.hasAction("Climb-down") ? "Climb-down" : "Open";
		QuestWorkflow.require(hatch.interact(action),"Glough's trapdoor interaction failed");
		QuestWorkflow.await(this::inCave,40,"Demon tunnel entry was not observed");
	}
	private void fight()
	{
		QuestCombat.configure(1387,Normal.FIRE_STRIKE);
		QuestWorkflow.require(SnapshotData.action("safety.configure",Map.of("minimum_hitpoints",18,
			"consumables",List.of(Map.of("id",379,"action","Eat","heal_amount",12)),"continue_after_consumable",true,"allow_overheal",true)),
			"Black demon food guard could not be configured");
		for (int attempt = 0; attempt < 2; attempt++)
		{
			enterCave(false);
			for (int tick = 0; tick < 80 && QuestWorkflow.npc(1432) == null; tick++) { Conversations.finish(); Sleep.sleepTicks(1); }
			if (QuestWorkflow.npc(1432) != null) break;
			Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
		}
		QuestWorkflow.require(QuestWorkflow.npc(1432) != null,"Black demon did not spawn");
		Tile safe = QuestWorkflow.mapped(new Tile(2492,9865));
		Travel.to(safe,0,"combat",WorkflowScript.NO_DISCRETIONARY);
		NPC demon = QuestWorkflow.npc(1432);
		QuestWorkflow.require(demon.distance() >= 4 && QuestCombat.lineOfSight(demon),"Black demon safespot was not established");
		QuestCombat.monitor(new int[]{1432},() -> quest.stage() >= 140,900,
			target -> QuestWorkflow.require(QuestWorkflow.tile().equals(safe),"Black demon safespot was lost"));
	}
	private void reachCaveKing()
	{
		enterCave(true);
		if (QuestWorkflow.npc(GnomeTravel.KING) == null) quest.walk(QuestWorkflow.mapped(new Tile(2465,9895)),6,false);
		QuestWorkflow.require(QuestWorkflow.npc(GnomeTravel.KING) != null,"Cave king was not observed");
	}
	private void findRock()
	{
		enterCave(true);
		Set<Tile> searched = new HashSet<>();
		for (int scan = 0; scan < 3; scan++)
		{
			List<GameObject> roots = GameObjects.all(object -> (object.getId() == 1985 || object.getId() == 1986) && object.hasAction("Search") && object.distance() <= 32);
			roots.sort(java.util.Comparator.comparingDouble(GameObject::distance));
			for (GameObject root : roots)
			{
				if (!searched.add(root.getTile())) continue;
				quest.walk(root.getTile(),6,false);
				QuestWorkflow.require(root.interact("Search"),"Daconia root search failed");
				for (int tick = 0; tick < 20; tick++)
				{
					Sleep.sleepTicks(1); Conversations.finish();
					if (Inventory.contains(793)) return;
					if (tick >= 4) break;
				}
			}
		}
		throw new IllegalStateException("Daconia rock was not found in the observed roots");
	}
}
