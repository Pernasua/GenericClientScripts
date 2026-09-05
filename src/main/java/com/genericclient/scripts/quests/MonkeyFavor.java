package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.script.Navigation;
import com.genericclient.script.Navigation.Journey;
import java.util.List;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supplies;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.widget.Widgets;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

final class MonkeyFavor
{
	private static final String GUARD = "monkey_madness_i.awowogei_guard_authorized";
	private final QuestWorkflow quest;
	private final MonkeyTravel travel;
	MonkeyFavor(QuestWorkflow quest, MonkeyTravel travel) { this.quest = quest; this.travel = travel; }
	void zoo()
	{
		MonkeySurvival.arm(12);
		if (MonkeyMap.ARDOUGNE_ZOO_MINDER.distance() > 350) Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
		walk(MonkeyMap.ARDOUGNE_ZOO_MINDER,6); disguise();
		if (!MonkeyAreas.pen())
		{
			NPC minder = QuestWorkflow.npc(5235);
			QuestWorkflow.require(minder != null && minder.interact("Talk-to"),"Zoo minder dialogue failed");
			for (int tick = 0; tick < 160 && !MonkeyAreas.pen(); tick++)
			{
				if (Dialogues.canContinue()) QuestWorkflow.require(Dialogues.continueDialogue(),"Zoo dialogue failed");
				else if (Dialogues.getOptions().length > 0) QuestWorkflow.require(Dialogues.chooseOption(1),"Zoo entry choice failed");
				Sleep.sleepTicks(1);
			}
			QuestWorkflow.require(MonkeyAreas.pen(),"Monkey pen entry was not observed");
		}
		quest.talk(new int[]{5279,5280},null,() -> Inventory.contains(4033),false);
		preserveMonkey(); leavePen();
	}
	void carry()
	{
		QuestWorkflow.require(Inventory.contains(4033),"Zoo monkey is not carried");
		preserveMonkey(); leavePen();
		if (!MonkeyAreas.ape())
		{
			if (!MonkeyAreas.tree() && !MonkeyAreas.STRONGHOLD_TRANSPORT.contains(QuestWorkflow.tile()) &&
				!MonkeyAreas.POST_PUZZLE_HANGAR.contains(QuestWorkflow.tile()) && !MonkeyAreas.CRASH_ISLAND.contains(QuestWorkflow.tile()))
			{
				transport(MonkeyRoutes.ZOO_TO_GRAND_TREE);
			}
			travel.ape();
		}
		disguise(); enterMarim();
	}
	void favor()
	{
		QuestWorkflow.require(Inventory.contains(4033),"Zoo monkey is not carried");
		preserveMonkey(); disguise(); enterMarim();
		if (!MonkeyAreas.throne())
		{
			if (quest.bit(126) < 3)
			{
				transport(MonkeyRoutes.MARIM_GATE_TO_GARKOR);
				quest.talk(new int[]{7158},null,() -> quest.bit(126) >= 3,false);
			}
			if (!Long.valueOf(1).equals(Automation.checkpoint(GUARD)))
			{
				returnFromBridge(); walk(MonkeyMap.ELDER_GUARD,3);
				NPC guard = QuestWorkflow.npc(5278);
				QuestWorkflow.require(guard != null && guard.interact("Talk-to"),"Elder guard dialogue failed");
				QuestWorkflow.await(Dialogues::inDialogue,20,"Elder guard did not respond");
				Conversations.finish(); Automation.checkpoint(GUARD,1);
			}
			if (!MonkeyAreas.APE_ATOLL_BRIDGE.contains(QuestWorkflow.tile()) && !MonkeyAreas.APE_ATOLL_OVER_BRIDGE.contains(QuestWorkflow.tile())) transport(MonkeyRoutes.GARKOR_TO_WEST_LADDER);
			bridge(); walk(MonkeyMap.KRUK,3);
			quest.talk(new int[]{5257},null,MonkeyAreas::throne,false);
		}
		GameObject throne = GameObjects.closest(object -> object.getId() == 4771 && object.hasAction("Talk-to"));
		QuestWorkflow.require(throne != null && throne.interact("Talk-to"),"Awowogei's throne was not available");
		quest.dialogue(() -> !Inventory.contains(4033),180);
		Automation.clearCheckpoint(GUARD); MonkeySurvival.behavior(true);
	}
	void sigil()
	{
		if (Inventory.contains(4035)) return;
		MonkeySurvival.behavior(true); disguise(); enterMarim();
		if (MonkeyAreas.throne()) quest.talk(new int[]{5278},null,() -> !MonkeyAreas.throne(),false);
		var chapter = Widgets.getWidget(225);
		if (chapter != null && chapter.isVisible()) Widgets.closeAll();
		walk(MonkeyMap.GARKOR,2);
		quest.talk(new int[]{7158},null,() -> Inventory.contains(4035),false);
	}
	private void enterMarim()
	{
		if (MonkeyAreas.north() || MonkeyAreas.throne() || MonkeyAreas.APE_ATOLL_BRIDGE.contains(QuestWorkflow.tile()) || MonkeyAreas.APE_ATOLL_OVER_BRIDGE.contains(QuestWorkflow.tile())) return;
		walk(MonkeyMap.MARIM_GATE_SOUTH,1);
		GameObject gate = GameObjects.closest(4788);
		if (gate != null)
		{
			QuestWorkflow.require(gate.interact("Open"),"Marim gate did not open");
			quest.dialogue(() -> GameObjects.closest(object -> object.getId() == 4789 || object.getId() == 4790) != null || MonkeyAreas.north(),60);
		}
		walk(MonkeyMap.MARIM_GATE_NORTH,0);
	}
	private void bridge()
	{
		if (MonkeyAreas.APE_ATOLL_OVER_BRIDGE.contains(QuestWorkflow.tile())) return;
		if (!MonkeyAreas.APE_ATOLL_BRIDGE.contains(QuestWorkflow.tile()))
		{
			walk(MonkeyMap.WEST_WATCHTOWER_LADDER,1); ladder(4775,"Climb-up",2);
		}
		walk(MonkeyMap.EAST_BRIDGE_LADDER_APPROACH,0); ladder(4776,"Climb-down",0);
	}
	private void returnFromBridge()
	{
		if (MonkeyAreas.APE_ATOLL_OVER_BRIDGE.contains(QuestWorkflow.tile()))
		{
			walk(MonkeyMap.EAST_WATCHTOWER_LADDER,1); ladder(4774,"Climb-up",2);
		}
		if (MonkeyAreas.APE_ATOLL_BRIDGE.contains(QuestWorkflow.tile()))
		{
			walk(MonkeyMap.WEST_BRIDGE_LADDER_APPROACH,0); ladder(4777,"Climb-down",0);
		}
	}
	private void ladder(int id, String action, int plane)
	{
		clearChatter(); GameObject ladder = GameObjects.closest(id);
		QuestWorkflow.require(ladder != null && ladder.interact(action),"Monkey bridge ladder failed");
		QuestWorkflow.await(() -> QuestWorkflow.tile().getZ() == plane,30,"Monkey bridge plane change was not observed");
	}
	private void leavePen()
	{
		if (!MonkeyAreas.pen()) return;
		org.dreambot.api.wrappers.items.Item greegree = Equipment.get(item -> item.getId() == 4031);
		if (greegree != null) QuestWorkflow.require(greegree.interact("Remove"),"Greegree could not be removed");
		quest.talk(new int[]{5235},null,() -> !MonkeyAreas.pen(),false);
	}
	private void disguise() { Supplies.equip(4021); Supplies.equip(4031); }
	private void preserveMonkey()
	{
		Automation.activity("questing",WorkflowScript.NO_DISCRETIONARY);
		QuestWorkflow.require(SnapshotData.action("client.behaviors.configure",Map.of("auto_retaliate",true,"emergency_escape",false,"combat_prayer",false)),"Monkey transport policy could not be applied");
	}
	private void walk(Tile point, int within) { transport(new Journey(point,within).timeout(300)); }
	static void transport(Journey journey)
	{
		Automation.activity("questing",WorkflowScript.NO_DISCRETIONARY);
		String continuation = null;
		boolean carrying = Inventory.contains(4033);
		for (int attempt = 0; attempt < 24; attempt++)
		{
			clearChatter();
			QuestWorkflow.require(!Dialogues.inDialogue(),"Monkey transport interrupted by " + SnapshotData.read("dialogue").get("speaker"));
			Map<String,Object> interrupts = carrying ? Map.of("dialogue",true,"missing_item",List.of("Monkey")) : Map.of("dialogue",true);
			Map<String,Object> moved = Navigation.walk(journey,interrupts,continuation);
			if ("arrived".equals(moved.get("status"))) return;
			String reason = String.valueOf(moved.get("reason"));
			boolean recoverable = "unavailable".equals(moved.get("status")) ||
				"interrupted".equals(moved.get("status")) && reason.equals("dialogue");
			QuestWorkflow.require(recoverable && moved.get("continuation") != null,"Monkey transport journey failed: " + moved);
			continuation = (String)moved.get("continuation");
			clearChatter(); Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Monkey transport interruption limit reached");
	}
	private static void clearChatter()
	{
		Map<?,?> dialogue = SnapshotData.read("dialogue");
		if (!"The monkey in your backpack...".equals(dialogue.get("speaker"))) return;
		for (int tick = 0; tick < 8; tick++)
		{
			if ("closed".equals(dialogue.get("type"))) return;
			String speaker = (String)dialogue.get("speaker");
			QuestWorkflow.require("continue".equals(dialogue.get("type")) &&
				("The monkey in your backpack...".equals(speaker) ||
					com.genericclient.scripts.shared.WorkflowScript.player().getName().equals(speaker)),
				"Monkey chatter changed to " + speaker);
			QuestWorkflow.require(SnapshotData.action("dialogue.continue",Map.of("reading",false)),"Monkey chatter did not continue");
			Sleep.sleepTicks(1);
			dialogue = SnapshotData.read("dialogue");
		}
		throw new IllegalStateException("Monkey chatter did not finish");
	}
}
