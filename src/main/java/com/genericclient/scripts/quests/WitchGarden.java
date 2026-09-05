package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.scripts.shared.Travel;
import java.util.function.IntPredicate;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.walking.impl.Walking;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.NPC;

final class WitchGarden
{
	private final WitchsHouse quest;
	WitchGarden(WitchsHouse quest) { this.quest = quest; }
	void fountain()
	{
		eastCover();
		move(2927,3466);
		absent();
		move(2920,3466);
		moving(true,2928);
		move(2913,3466); move(2912,3466); move(2911,3467); move(2911,3468);
		quest.interact(2864,"Check",new Tile(2909,3470),() -> Inventory.contains(2411),false);
	}
	void shed()
	{
		if (WitchsHouse.SHED.contains(QuestWorkflow.tile())) return;
		if (QuestWorkflow.tile().getX() == 2933) { move(2933,3463); return; }
		if (QuestWorkflow.tile().getX() > 2902 && QuestWorkflow.tile().getX() < 2933 &&
			QuestWorkflow.tile().getY() >= 3459 && QuestWorkflow.tile().getY() <= 3475)
			quest.escape();
		eastCover(); move(2933,3463);
	}
	private void eastCover()
	{
		Automation.activity("questing",WorkflowScript.NO_DISCRETIONARY);
		Travel.to(new Tile(2928,3456),0,"questing",WorkflowScript.NO_DISCRETIONARY);
		move(2901,3464);
		QuestWorkflow.await(() -> Walking.getRunEnergy() >= 20,100,"Garden run energy did not recover");
		move(2901,3460); absent(); move(2908,3460); moving(false,2908);
		move(2916,3460); position(x -> x <= 2910,50);
		move(2924,3460); position(x -> x <= 2918,60);
		move(2931,3460); moving(false,2918); move(2933,3466);
	}
	private void move(int x, int y)
	{
		Travel.to(new Tile(x,y),0,"questing",WorkflowScript.NO_DISCRETIONARY);
		Tile reached = QuestWorkflow.tile();
		QuestWorkflow.require(reached.getX() >= 2900 && reached.getX() <= 2933 && reached.getY() >= 3459 && reached.getY() <= 3475,
			"The witch caught the player");
	}
	private void absent()
	{
		int absent = 0;
		for (int tick = 0; tick < 140; tick++)
		{
			Sleep.sleepTicks(1);
			absent = NPCs.closest(3995) == null ? absent+1 : 0;
			if (absent >= 3) return;
		}
		throw new IllegalStateException("Garden patrol window did not open");
	}
	private void moving(boolean east, int boundary)
	{
		Integer previous = null;
		for (int tick = 0; tick < 140; tick++)
		{
			Sleep.sleepTicks(1);
			NPC witch = NPCs.closest(3995);
			if (witch == null) continue;
			int x = witch.getTile().getX();
			if (previous != null && (east ? x >= boundary && x > previous : x <= boundary && x < previous)) return;
			previous = x;
		}
		throw new IllegalStateException("Witch movement window was not observed");
	}
	private void position(IntPredicate allowed, int ticks)
	{
		QuestWorkflow.await(() -> { NPC witch = NPCs.closest(3995); return witch != null && allowed.test(witch.getTile().getX()); },
			ticks,"Witch did not reach the required patrol position");
	}
}
