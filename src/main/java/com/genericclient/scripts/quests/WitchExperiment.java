package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Safety;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Travel;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.magic.Magic;
import org.dreambot.api.methods.magic.Normal;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.NPC;

final class WitchExperiment
{
	private static final int[] FORMS = {3996,3997,3998,3999};
	private static final Tile NORTH = new Tile(2937,3466);
	private static final Tile UNDER = new Tile(2937,3465);
	private static final Tile NORTH_SAFE = new Tile(2936,3465);
	private static final Tile SOUTH_SAFE = new Tile(2936,3459);
	private final WitchsHouse quest;
	WitchExperiment(WitchsHouse quest) { this.quest = quest; }
	void fight()
	{
		Supplies.equip(1387); Supplies.equip(2550);
		WorkflowScript.require(Magic.setAutocastSpell(Normal.FIRE_STRIKE),"Experiment autocast failed");
		Safety.configure(Safety.wine(),new Tile(2933,3463),0,false);
		Automation.activity("combat",WorkflowScript.NO_DISCRETIONARY);
		new WitchGarden(quest).shed();
		if (!WitchsHouse.SHED.contains(QuestWorkflow.tile()))
		{
			WorkflowScript.require(Inventory.contains(2411),"Shed key is not carried");
			WorkflowScript.require(Inventory.get(2411).useOn(QuestWorkflow.object(2863,new Tile(2934,3463))),"Shed could not be unlocked");
			if (!Sleep.sleepUntil(() -> WitchsHouse.SHED.contains(QuestWorkflow.tile()),4800))
			{
				WorkflowScript.require(QuestWorkflow.object(2863,new Tile(2934,3463)).interact("Open"),"Shed door did not open");
				move(new Tile(2935,3463));
			}
		}
		if (current() < 0)
		{
			WorkflowScript.require(SnapshotData.action("ground_item.take",Map.of("id",2407,
				"world",Map.of("x",2935,"y",3460,"plane",0),"within",10)),"Experiment did not respond to the ball");
			WorkflowScript.awaitTicks(() -> current() >= 0,20,"Experiment did not spawn");
		}
		for (int form = current(); form < FORMS.length && quest.stage() < 6; form++)
		{
			if (next(form)) continue;
			if (!Equipment.contains(2550) && Inventory.contains(2550)) Supplies.equip(2550);
			Tile safe = form < 2 ? NORTH_SAFE : SOUTH_SAFE;
			if (form < 2) lureNorth(form); else move(safe);
			if (!next(form)) defeat(form,safe);
		}
		WorkflowScript.require(quest.stage() >= 6,"Experiment completion was not observed");
	}
	private void lureNorth(int form)
	{
		for (int cycle = 0; cycle < 8; cycle++)
		{
			if (next(form)) return;
			move(NORTH); heal(); attack(form);
			WorkflowScript.awaitTicks(() -> next(form) || at(form,UNDER),24,"Experiment did not approach the lure tile");
			if (next(form)) return;
			move(UNDER);
			if (Sleep.sleepUntil(() -> next(form) || at(form,NORTH),3600))
			{
				if (next(form)) return;
				move(NORTH_SAFE);
				Sleep.sleepTicks(2);
				WorkflowScript.require(at(form,NORTH) && QuestWorkflow.tile().equals(NORTH_SAFE),"North safespot was not established");
				return;
			}
		}
		throw new IllegalStateException("North lure attempt limit reached");
	}
	private void defeat(int form, Tile safe)
	{
		attack(form);
		int limit = form == 0 ? 300 : form == 1 ? 420 : form == 2 ? 600 : 720;
		for (int tick = 0; tick < limit; tick++)
		{
			Sleep.sleepTicks(1);
			if (next(form)) return;
			WorkflowScript.require(QuestWorkflow.tile().equals(safe),"Experiment safespot was lost");
			if (Dialogues.canContinue())
			{
				Conversations.continuePage();
				attack(form);
			}
		}
		throw new IllegalStateException("Experiment form did not finish");
	}
	private void attack(int form)
	{
		if (next(form)) return;
		NPC target = QuestWorkflow.npc(FORMS[form]);
		WorkflowScript.require(target != null && target.interact("Attack"),"Experiment attack failed");
	}
	private void heal()
	{
		for (int attempt = 0; attempt < 6 && Skills.getBoostedLevel(Skill.HITPOINTS) < Skills.getRealLevel(Skill.HITPOINTS); attempt++)
		{
			WorkflowScript.require(Inventory.interact(1993,"Drink"),"Lure preparation ran out of wine");
			Sleep.sleepTicks(1);
		}
		WorkflowScript.require(Skills.getBoostedLevel(Skill.HITPOINTS) >= Skills.getRealLevel(Skill.HITPOINTS),"Hitpoints did not recover for the lure");
	}
	private void move(Tile point) { Travel.to(point,0,"combat",WorkflowScript.NO_DISCRETIONARY); }
	private boolean at(int form, Tile point) { NPC target = QuestWorkflow.npc(FORMS[form]); return target != null && target.getTile().equals(point); }
	private boolean next(int form) { return form == 3 ? quest.stage() >= 6 && QuestWorkflow.npc(FORMS[form]) == null : QuestWorkflow.npc(FORMS[form+1]) != null; }
	private int current() { for (int i = 0; i < FORMS.length; i++) if (QuestWorkflow.npc(FORMS[i]) != null) return i; return -1; }
}
