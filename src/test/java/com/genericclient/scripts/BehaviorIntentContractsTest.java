package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.shared.WorkflowScript;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class BehaviorIntentContractsTest
{
	@Test public void questApproachPrecedesOneConversationBoundary()
	{
		QuestScenario game = new QuestScenario("tree_gnome_village",111,3,new Tile(2500,3200));
		game.npc(4964,"Commander Montai",new Tile(2523,3208),"Talk-to");
		game.input = (type,args) ->
		{
			switch (type)
			{
				case "walk.to":
					assertNull(game.intents.current);
					game.position = new Tile(2523,3208);
					break;
				case "npc.interact":
					assertEquals("tree_gnome_village.talk",game.intents.current);
					game.dialogue = Map.of("type","continue","open",true);
					break;
				case "dialogue.continue":
					assertEquals("tree_gnome_village.talk",game.intents.current);
					game.transitions.add(() -> game.stage = 4);
					break;
				default: throw new AssertionError(type);
			}
		};
		game.run();
		assertEquals(4,game.stage);
		assertEquals(List.of(Map.of("policy",WorkflowScript.NO_DISCRETIONARY)),game.phaseOptions);
		assertEquals(List.of("tree_gnome_village.talk"),game.intents.entries);
	}

	@Test public void mouseItemsShareOneIntent()
	{
		QuestScenario game = new QuestScenario("witchs_house",226,2,new Tile(2898,3467));
		game.inventory.putAll(Map.of(1059,1,1985,1,2410,1));
		game.object(2870,"Mouse hole",new Tile(2903,3466),"Use");
		game.input = (type,args) ->
		{
			switch (type)
			{
				case "walk.to":
					assertNull(game.intents.current);
					game.position = new Tile(2903,3467);
					break;
				case "item.use_on_object":
					assertEquals("witchs_house.lure_mouse",game.intents.current);
					game.transitions.add(() -> game.npc(4000,"Mouse",new Tile(2903,3466),"Use"));
					break;
				case "item.use_on_npc":
					assertEquals("witchs_house.lure_mouse",game.intents.current);
					throw new IllegalStateException("Magnet rejected");
				default: throw new AssertionError(type);
			}
		};
		try { game.run(); fail("Rejected magnet was accepted"); }
		catch (IllegalStateException failure) { assertEquals("Magnet rejected",failure.getMessage()); }
		assertEquals(List.of("witchs_house.lure_mouse"),game.intents.entries);
	}
}
