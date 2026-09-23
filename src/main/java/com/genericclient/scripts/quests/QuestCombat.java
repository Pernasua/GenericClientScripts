package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.Conversations;
import com.genericclient.script.Automation;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Safety;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
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
		WorkflowScript.require(Magic.setAutocastSpell(spell),"Quest autocast could not be configured");
	}
	static void foodGuard(int minimumHitpoints)
	{
		Safety.behaviors(false,true,true);
		Safety.guard(minimumHitpoints,Safety.lobster(),false,null);
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
			if (Dialogues.canContinue()) { Conversations.continuePage(); reattack = true; }
			NPC npc = QuestWorkflow.npc(ids);
			if (npc == null || npc.isDead())
			{
				WorkflowScript.require(++missing < 45,"Combat target disappeared without its completion state");
			}
			else
			{
				missing = 0;
				maintainPosition.accept(npc);
				if (reattack || !WorkflowScript.player().isInCombat())
				{
					WorkflowScript.require(npc.interact("Attack"),"Quest attack failed");
					reattack = false;
				}
			}
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Quest encounter timed out");
	}
}
