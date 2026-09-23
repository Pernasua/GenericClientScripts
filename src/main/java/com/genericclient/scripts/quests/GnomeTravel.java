package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.wrappers.interactive.GameObject;

final class GnomeTravel
{
	static final int[] KING = {8019,8020,1423};
	static final int[] GLOUGH = {2061,1424};
	static final int[] CHARLIE = {1428,122};
	static final Tile KING_TILE = new Tile(2466,3495);
	static final Tile TOP = new Tile(2466,3495,3);
	static final Tile GLOUGH_ROOM = new Tile(2483,3463,1);
	static final Tile HAZELMERE = new Tile(2677,3087,1);
	static final Tile ANITA = new Tile(2390,3513,1);
	private final QuestWorkflow quest;
	GnomeTravel(QuestWorkflow quest) { this.quest = quest; }

	void king(boolean banned)
	{
		if (QuestWorkflow.npc(KING) != null && QuestWorkflow.tile().getZ() == 0) return;
		Tile current = QuestWorkflow.tile();
		if (new Tile(KING_TILE.getX(),KING_TILE.getY(),current.getZ()).distance(current) > 150)
			Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
		if (banned && QuestWorkflow.tile().getY() < 3384)
		{
			Travel.to(new Tile(2461,3381),1);
			quest.talk(new int[]{1431},null,() -> QuestWorkflow.tile().getY() >= 3384,false);
		}
		Travel.to(KING_TILE,2);
		WorkflowScript.require(QuestWorkflow.npc(KING) != null,"King Narnode was not observed after travel");
	}

	void top() { Travel.to(TOP,1); }
	void glough() { Travel.to(GLOUGH_ROOM,2); }
	void anita() { Travel.to(ANITA,1); }

	void watchtower()
	{
		if (QuestWorkflow.tile().getY() >= 9800 || QuestWorkflow.tile().getX() >= 10000 || QuestWorkflow.tile().getZ() == 2) return;
		glough();
		Travel.to(new Tile(2482,3463,1),0);
		GameObject tree = GameObjects.closest(candidate -> candidate.getId() == 2447 && candidate.hasAction("Climb-up"));
		WorkflowScript.require(tree != null && tree.interact("Climb-up"),"Glough's watchtower tree could not be climbed");
		WorkflowScript.awaitTicks(() -> QuestWorkflow.tile().getZ() == 2,40,"Watchtower arrival was not observed");
	}

	void hazelmere()
	{
		if (QuestWorkflow.npc(1422,13610) != null && QuestWorkflow.tile().getZ() == 1) return;
		if (new Tile(2677,3088).distance() > 120 && HAZELMERE.distance() > 120)
			Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
		Travel.to(HAZELMERE,1);
	}
}
