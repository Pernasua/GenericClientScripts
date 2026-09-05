package com.genericclient.scripts.quests;

import com.genericclient.script.Automation;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supplies;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.widget.Widgets;
import org.dreambot.api.wrappers.interactive.GameObject;

final class WaterfallNavigation
{
	static final Tile HUDON_LANDING = new Tile(2512,3481);
	static final Tile TOURIST_UPSTAIRS = new Tile(2518,3431,1);
	static final Tile TOURIST_GROUND = new Tile(2519,3430);
	static final Tile GNOME_SURFACE = new Tile(2533,3156);
	static final Tile GNOME_BASEMENT = new Tile(2533,9556);
	static final Tile TOMB_SURFACE = new Tile(2557,3444);
	private final Waterfall quest;
	WaterfallNavigation(Waterfall quest) { this.quest = quest; }
	void execute(String phase)
	{
		switch (phase)
		{
			case "accept": nearFalls(); quest.talk(new int[]{4181},new Tile(2521,3495),() -> quest.varp() >= 1,false,"Yes."); break;
			case "raft": nearFalls(); quest.walk(HUDON_LANDING,1,false); break;
			case "talk_hudon": quest.talk(new int[]{4182},new Tile(2511,3484),() -> quest.varp() >= 2,false); break;
			case "cross_rock": crossRock(); break;
			case "descend_tree": useRope(2020,new Tile(2512,3465),Waterfall.LEDGE); break;
			case "barrel": quest.interact(2022,"Get in",new Tile(2512,3463),() -> !Waterfall.LEDGE.contains(QuestWorkflow.tile()),false); break;
			case "tourist_stairs": quest.walk(TOURIST_UPSTAIRS,0,false); break;
			case "book": quest.interact(1989,"Search",new Tile(2520,3426,1),() -> Inventory.contains(292),false); break;
			case "read_book":
				Automation.intent("waterfall.read_book", () ->
				{
					QuestWorkflow.require(Inventory.interact(292,"Read"),"Waterfall book did not open");
					quest.dialogue(() -> quest.varp() >= 3,30);
					QuestWorkflow.require(Widgets.closeAll(),"Waterfall book did not close");
					return null;
				}); break;
			case "downstairs": quest.walk(TOURIST_GROUND,0,false); break;
			case "gnome_dungeon": gnomeDungeon(); break;
			case "golrie_key": quest.interact(1990,"Search",new Tile(2548,9565),() -> Inventory.contains(293),true); break;
			case "golrie_gate": openGolrieGate(); break;
			case "pebble": quest.talk(new int[]{4183},new Tile(2514,9580),() -> Inventory.contains(294),true); break;
			case "leave_gnome": leave(Jewellery.Destination.CASTLE_WARS,GNOME_SURFACE); break;
			case "leave_tomb": leave(Jewellery.Destination.BARBARIAN_OUTPOST,TOMB_SURFACE); break;
			case "equip_amulet": Supplies.equip(295); break;
			case "enter_falls": quest.interact(2010,"Open",new Tile(2511,3464),() -> Waterfall.FALLS.contains(QuestWorkflow.tile()),true); break;
			default: throw new IllegalArgumentException("Unknown Waterfall navigation phase: " + phase);
		}
	}
	private void nearFalls() { if (new Tile(2521,3495).distance() > 150) Jewellery.teleport(Jewellery.Destination.BARBARIAN_OUTPOST); }
	private void crossRock()
	{
		quest.walk(new Tile(2512,3476),0,false);
		useRope(1996,new Tile(2512,3468),Waterfall.TREE);
	}
	private void useRope(int id, Tile point, org.dreambot.api.methods.map.Area arrival)
	{
		GameObject target = QuestWorkflow.object(id,point);
		QuestWorkflow.require(target != null && Inventory.get(954).useOn(target),"Rope crossing failed");
		QuestWorkflow.await(() -> arrival.contains(QuestWorkflow.tile()),30,"Rope crossing arrival was not observed");
	}
	private void gnomeDungeon()
	{
		if (GNOME_SURFACE.distance() > 150) Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
		quest.walk(GNOME_BASEMENT,1,true);
	}
	private void leave(Jewellery.Destination destination, Tile surface)
	{
		IllegalStateException teleportFailure = null;
		if (Jewellery.carried(destination))
		{
			try { Jewellery.teleport(destination); return; }
			catch (IllegalStateException failure) { teleportFailure = failure; }
		}
		try { quest.walk(surface,1,true); }
		catch (IllegalStateException failure)
		{
			if (teleportFailure != null) failure.addSuppressed(teleportFailure);
			throw failure;
		}
	}
	private void openGolrieGate()
	{
		quest.walk(new Tile(2515,9575),3,true);
		GameObject gate = GameObjects.closest(1991);
		QuestWorkflow.require(gate != null && gate.interact("Open"),"Golrie's gate did not open");
		quest.walk(new Tile(2514,9580),0,true);
	}
}
