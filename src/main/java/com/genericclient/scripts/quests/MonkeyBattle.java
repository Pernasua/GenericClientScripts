package com.genericclient.scripts.quests;

import com.genericclient.script.Automation;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.WorkflowScript;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.magic.Magic;
import org.dreambot.api.methods.magic.Normal;
import org.dreambot.api.wrappers.interactive.NPC;

final class MonkeyBattle
{
	private final QuestWorkflow quest;
	MonkeyBattle(QuestWorkflow quest) { this.quest = quest; }
	void enter()
	{
		if (MonkeyAreas.demon()) return;
		configure();
		WorkflowScript.require(Inventory.interact(4035,"Wear"),"Squad sigil could not be worn");
		quest.dialogue(MonkeyAreas::demon,50,"Yes","Yes.");
	}
	void fight()
	{
		if (quest.stage() >= 6) return;
		configure();
		WorkflowScript.require(MonkeyAreas.demon(),"Jungle demon room has not been reached");
		Conversations.finish();
		WorkflowScript.awaitTicks(() -> QuestWorkflow.npc(1443) != null,80,"Jungle demon did not appear");
		NPC demon = QuestWorkflow.npc(1443);
		WorkflowScript.require(demon.distance() >= 3 && demon.distance() <= 10 && QuestCombat.lineOfSight(demon),"Jungle demon spawn position is unsafe");
		QuestCombat.monitor(new int[]{1443},() -> quest.stage() >= 6,1400,target ->
		{
			WorkflowScript.require(target.distance() >= 3,"Jungle demon entered melee range");
			if (com.genericclient.script.ScriptScope.current().tick() % 10 == 0) MonkeySurvival.protection("magic",true,12);
		});
		MonkeySurvival.protection("magic",false,0); MonkeySurvival.behavior(true);
	}
	private void configure()
	{
		Automation.activity("combat"); MonkeySurvival.behavior(false); MonkeySurvival.arm(16);
		Supplies.equip(1387); MonkeySurvival.protection("magic",true,35);
		WorkflowScript.require(Magic.setAutocastSpell(Normal.FIRE_BOLT),"Jungle demon autocast could not be configured");
	}
}
