package com.genericclient.scripts.quests;

import com.genericclient.script.Automation;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import java.util.List;
import java.util.function.Consumer;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.magic.Magic;
import org.dreambot.api.methods.magic.Normal;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.utilities.impl.Condition;
import org.dreambot.api.wrappers.interactive.NPC;

final class QuestCombat
{
	private QuestCombat() {}
	static void configure(int staff, Normal spell)
	{
		Automation.activity("combat",WorkflowScript.NO_DISCRETIONARY);
		Supplies.equip(staff);
		QuestWorkflow.require(Magic.setAutocastSpell(spell),"Quest autocast could not be configured");
	}
	static void foodGuard(int minimumHitpoints)
	{
		QuestWorkflow.require(SnapshotData.action("client.behaviors.configure",Map.of("auto_retaliate",false,"emergency_escape",true)),
			"Quest combat behavior could not be configured");
		QuestWorkflow.require(SnapshotData.action("safety.configure",Map.of("minimum_hitpoints",minimumHitpoints,
			"consumables",List.of(Map.of("id",379,"action","Eat","heal_amount",12)),"continue_after_consumable",true,"allow_overheal",false)),
			"Quest combat food guard could not be configured");
	}

	static boolean lineOfSight(NPC npc)
	{
		return SnapshotData.rows("npcs",Map.of("id",npc.getId(),"within",32,"limit",100)).stream()
			.anyMatch(row -> ((Number)row.get("index")).intValue() == npc.getIndex() && Boolean.TRUE.equals(row.get("line_of_sight")));
	}
	static void monitor(int[] ids, Condition complete, int ticks, Consumer<NPC> maintainPosition)
	{
		int missing = 0;
		boolean reattack = true;
		for (int tick = 0; tick < ticks; tick++)
		{
			if (complete.verify()) return;
			if (Dialogues.canContinue()) { QuestWorkflow.require(Dialogues.continueDialogue(),"Combat dialogue failed"); reattack = true; }
			NPC npc = QuestWorkflow.npc(ids);
			if (npc == null || npc.isDead())
			{
				QuestWorkflow.require(++missing < 45,"Combat target disappeared without its completion state");
			}
			else
			{
				missing = 0;
				maintainPosition.accept(npc);
				if (reattack || !WorkflowScript.player().isInCombat())
				{
					QuestWorkflow.require(npc.interact("Attack"),"Quest attack failed");
					reattack = false;
				}
			}
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Quest encounter timed out");
	}
}
