package com.genericclient.scripts.events;

import com.genericclient.script.ScriptSettings;
import com.genericclient.script.SnapshotData;
import com.genericclient.script.Automation;
import com.genericclient.script.Navigation;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.map.Area;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

@ScriptManifest(name="Evil Bob",author="GenericClient",category=Category.UTILITY,version=1,
	description="Catch and uncook the correct fish, feed Evil Bob, and leave ScapeRune.")
@ScriptSettings(id="evil-bob",randomEvents={390})
public final class EvilBob extends WorkflowScript
{
	private static final Area ISLAND = new Area(2500,4750,2555,4805);
	private static final Tile CENTRE = new Tile(2522,4773);
	private static final Tile[] APPROACH = {new Tile(2525,4770),new Tile(2527,4785),new Tile(2516,4775),new Tile(2537,4777)};
	private static final Tile[] SPOTS = {new Tile(2525,4764),new Tile(2527,4791),new Tile(2510,4775),new Tile(2543,4777)};
	@Override protected Object runWorkflow()
	{
		long started = EventSupport.begin(390);
		EventSupport.enter("evil_bob.accept_invitation",() -> ISLAND.contains(player()),"Yes, that seems like a good idea.");
		Sleep.sleepTicks(2);
		Conversations.finish();
		obtainNet();
		List<Integer> tried = obtainFish();
		reach(CENTRE,5);
		if (!Inventory.contains(6200))
		{
			GameObject pot = GameObjects.closest(23113);
			require(pot != null && Inventory.get(6202).useOn(pot),"Correct fish could not be uncooked");
			await(() -> Inventory.contains(6200),18000,"Raw fish was not observed");
		}
		NPC bob = NPCs.closest(391);
		require(bob != null && Inventory.get(6200).useOn(bob),"Evil Bob could not be fed");
		for (int tick = 0; tick < 80 && !EventSupport.message(started,"catnap"); tick++)
		{
			Conversations.advance();
			Sleep.sleepTicks(1);
		}
		require(EventSupport.message(started,"catnap"),"Evil Bob did not begin his catnap");
		Conversations.finish();
		reach(CENTRE,5);
		GameObject portal = GameObjects.closest(23115);
		require(portal != null && portal.interact("Enter"),"ScapeRune portal was not available");
		await(() -> !ISLAND.contains(player()),48000,"ScapeRune exit was not observed");
		return Map.of("status","solved","fishing_spots_tried",tried);
	}
	private void obtainNet()
	{
		if (Inventory.contains(6209)) return;
		require(Inventory.emptySlotCount() >= 2,"Evil Bob requires two free inventory slots");
		reach(new Tile(2533,4784),3);
		require(SnapshotData.action("ground_item.take",Map.of("id",6209,
			"world",Map.of("x",2533,"y",4784,"plane",0),"within",8)),"Fishing net could not be taken");
		await(() -> Inventory.contains(6209),12000,"Fishing net was not observed");
	}
	private List<Integer> obtainFish()
	{
		List<Integer> tried = new ArrayList<>();
		if (Inventory.contains(6202) || Inventory.contains(6200)) return tried;
		destroyWrongFish();
		for (int spot = 0; spot < SPOTS.length; spot++)
		{
			reach(CENTRE,4);
			NPC servant = NPCs.closest(393);
			require(servant != null && servant.interact("Talk-to"),"Servant dialogue failed");
			await(Dialogues::inDialogue,12000,"Servant did not explain the fish");
			Conversations.finish();
			reach(APPROACH[spot],2);
			Tile tile = SPOTS[spot];
			GameObject fishing = GameObjects.closest(object -> object.getId() == 23114 && object.getTile().equals(tile));
			require(fishing != null && fishing.interact("Net"),"Fishing interaction failed");
			for (int tick = 0; tick < 35 && !Inventory.contains(6202,6206); tick++)
			{
				Conversations.advance();
				Sleep.sleepTicks(1);
			}
			require(Inventory.contains(6202,6206),"Fishing result was not observed");
			tried.add(spot);
			if (Inventory.contains(6202)) return tried;
			destroyWrongFish();
		}
		throw new IllegalStateException("No correct fishing spot was found");
	}
	private void destroyWrongFish()
	{
		if (!Inventory.contains(6206)) return;
		require(Inventory.interact(6206,"Destroy"),"Wrong fish could not be destroyed");
		for (int tick = 0; tick < 30; tick++)
		{
			if (!Inventory.contains(6206)) return;
			String[] options = Dialogues.getOptions();
			if (options.length > 0)
			{
				String yes = Arrays.stream(options).filter(option -> option.equalsIgnoreCase("yes") ||
					option.equalsIgnoreCase("yes.") || option.toLowerCase(java.util.Locale.ROOT).startsWith("yes,")).findFirst().orElse(null);
				require(yes != null && Dialogues.chooseOption(yes),"Wrong-fish destruction confirmation was not recognized");
			}
			else Conversations.advance();
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Wrong fish remained in inventory");
	}
	private void reach(Tile destination, int within)
	{
		if (destination.distance() <= within) return;
		Automation.activity("general",WorkflowScript.NO_DISCRETIONARY);
		require(Navigation.walkTo(destination,within,240,List.of()),"ScapeRune travel failed: " + destination);
	}
}
