package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.script.Navigation;
import com.genericclient.scripts.shared.Supplies;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

final class MonkeyTalisman
{
	private static final String[] CHOICES = {"Well I'll be a monkey's uncle!","How many bananas did Aunty want?",
		"Ok, I promise!","I've lost that toy you gave me...","Wow - can I borrow it?"};
	private final MonkeyPrison prison;
	MonkeyTalisman(MonkeyPrison prison) { this.prison = prison; }
	void obtain()
	{
		if (Inventory.contains(4023)) return;
		MonkeySurvival.arm(12); Supplies.equip(4021); MonkeySurvival.behavior(false);
		if (MonkeyAreas.prison()) prison.escape(false);
		reach(MonkeyMap.MONKEY_CHILD_STAGING,0,120);
		Automation.activity("questing",WorkflowScript.NO_DISCRETIONARY);
		for (int window = 0; window < 12 && Inventory.count(1963) < 5; window++)
		{
			waitForAunt();
			while (!auntNear() && Inventory.count(1963) < 5)
			{
				GameObject tree = GameObjects.closest(object -> object.getId() >= 4749 && object.getId() <= 4753 && object.hasAction("Search"));
				WorkflowScript.require(tree != null,"Banana tree was not observed");
				int before = Inventory.count(1963);
				WorkflowScript.require(tree.interact("Search"),"Banana search failed");
				WorkflowScript.awaitTicks(() -> Inventory.count(1963) > before || auntNear(),20,"Banana search result was not observed");
			}
			hide();
		}
		WorkflowScript.require(Inventory.count(1963) >= 5,"Five bananas were not obtained");
		for (int window = 0; window < 12; window++)
		{
			waitForAunt();
			for (int conversation = 0; conversation < 8 && !auntNear() && !Inventory.contains(4023); conversation++)
			{
				int bananas = Inventory.count(1963);
				talkChild();
				if (Inventory.count(1963) < bananas) break;
			}
			hide();
			if (Inventory.contains(4023)) return;
		}
		throw new IllegalStateException("Monkey talisman was not received");
	}
	private void waitForAunt()
	{
		Tile previous = null;
		for (int tick = 0; tick < 240; tick++)
		{
			Sleep.sleepTicks(1);
			NPC aunt = QuestWorkflow.npc(5270);
			if (aunt == null) { previous = null; continue; }
			Tile now = aunt.getTile();
			if (previous != null && now.equals(MonkeyMap.MONKEY_AUNT_SOUTH_CROSSING) && previous.getX() == now.getX() && previous.getY() > now.getY()) return;
			previous = now;
		}
		throw new IllegalStateException("Monkey aunt's southbound crossing was not observed");
	}
	private void talkChild()
	{
		reach(MonkeyMap.MONKEY_CHILD,3,40);
		if (auntNear()) return;
		NPC child = QuestWorkflow.npc(5268);
		WorkflowScript.require(child != null && child.interact("Talk-to"),"Monkey child dialogue failed");
		boolean opened = false;
		int closed = 0;
		for (int tick = 0; tick < 100; tick++)
		{
			if (Inventory.contains(4023) || auntNear()) return;
			if (Conversations.advance(CHOICES)) { opened = true; closed = 0; }
			else if (opened && ++closed >= 3) return;
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Monkey child dialogue timed out");
	}
	private boolean auntNear() { NPC aunt = QuestWorkflow.npc(5270); return aunt != null && aunt.distance() <= 6; }
	private void hide() { reach(MonkeyMap.MONKEY_CHILD_STAGING,0,40); }
	private void reach(Tile destination, int within, int ticks)
	{
		if (destination.distance() <= within) return;
		Automation.activity("questing",WorkflowScript.NO_DISCRETIONARY);
		Map<String,Object> moved = Navigation.walk(new Navigation.Journey(destination,within).timeout(ticks),
			Map.of("area",Map.of("name","prison","bounds",MonkeyAreas.PRISON_BOUNDS)),null);
		WorkflowScript.require("arrived".equals(moved.get("status")) && !MonkeyAreas.prison(),"Monkey child travel failed: " + moved);
	}
}
