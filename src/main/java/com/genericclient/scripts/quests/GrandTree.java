package com.genericclient.scripts.quests;

import org.dreambot.api.methods.settings.PlayerSettings;
import com.genericclient.script.Automation;
import com.genericclient.scripts.shared.Jewellery;
import java.util.List;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Area;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.wrappers.interactive.GameObject;

final class GrandTree extends QuestWorkflow
{
	static final Area SHIPYARD = new Area(2945,3015,3007,3070);
	static final Area KARAMJA = new Area(2900,2940,3010,3070);
	private final GnomeTravel travel = new GnomeTravel(this);
	private boolean travelPrepared;
	GrandTree() { super("the_grand_tree"); }
	@Override int stage() { return PlayerSettings.getConfig(150); }
	@Override void validate() { require(Skills.getRealLevel(Skill.AGILITY) >= 25,"The Grand Tree requires Agility 25"); QuestCombat.foodGuard(6); }
	@Override String phase()
	{
		int stage = stage();
		if (stage == 0 && !travelPrepared && !Jewellery.carried(Jewellery.Destination.CASTLE_WARS)) return "prepare_travel";
		if (stage <= 60) return investigation(stage);
		if (stage <= 110) return conspiracy(stage);
		if (stage == 120) return "twigs";
		if (stage == 130) return combatReady() ? "demon" : "prepare_combat";
		if (stage == 140) return "cave_king";
		if (stage >= 150) return Inventory.contains(793) ? "return_rock" : "rock";
		throw new IllegalStateException("Unexpected Grand Tree stage: " + stage);
	}
	private String investigation(int stage)
	{
		switch (stage)
		{
			case 0:return "start";
			case 10:return "hazelmere";
			case 20:return "translation";
			case 30:return "glough";
			case 40:return "king_after_glough";
			case 50:return "charlie";
			case 60:return Inventory.contains(785) ? "confront" : "journal";
			default:throw new IllegalStateException("Unexpected Grand Tree investigation stage: " + stage);
		}
	}
	private String conspiracy(int stage)
	{
		if (stage == 70) return tile().getZ() == 3 ? "charlie_cell" : "confront";
		if (stage == 80) return tile().getZ() == 3 ? "glider" : SHIPYARD.contains(tile()) ? "foreman" : "shipyard";
		if (stage == 90) return "lumber_order";
		if (stage == 100) return !Inventory.contains(788) ? "anita" : !Inventory.contains(794) ? "plans" : "return_plans";
		if (stage == 110) return "return_plans";
		throw new IllegalStateException("Unexpected Grand Tree conspiracy stage: " + stage);
	}
	@Override void execute(String phase)
	{
		if (List.of("prepare_combat","demon","cave_king","rock","return_rock").contains(phase)) { new GrandTreeFinale(this,travel).execute(phase); return; }
		switch (phase)
		{
			case "prepare_travel": prepare(List.of(duelingRing())); travelPrepared = true; break;
			case "start": travel.king(false); talk(GnomeTravel.KING,null,() -> stage() >= 10,false,"You seem worried, what's up?","Yes.","I'd be happy to help!"); break;
			case "hazelmere": travel.hazelmere(); talk(new int[]{1422,13610},null,() -> stage() >= 20,false); break;
			case "translation": travel.king(false); talk(GnomeTravel.KING,null,() -> stage() >= 30,false,"I think so!","A man came to me with the King's seal.","I gave the man Daconia rocks.","And Daconia rocks will kill the tree!","None of the above."); break;
			case "glough": travel.glough(); talk(GnomeTravel.GLOUGH,null,() -> stage() >= 40,false); break;
			case "king_after_glough": travel.king(false); talk(GnomeTravel.KING,null,() -> stage() >= 50,false); break;
			case "charlie": travel.top(); talk(GnomeTravel.CHARLIE,null,() -> stage() >= 60,false); break;
			case "journal": travel.glough(); searchContainer(2434,2435,785); break;
			case "confront": travel.glough(); talk(GnomeTravel.GLOUGH,null,() -> tile().getZ() == 3 && tile().getX() == 2464,true); break;
			case "charlie_cell": talk(GnomeTravel.CHARLIE,null,() -> stage() >= 80,false); break;
			case "glider": talk(new int[]{10467},null,() -> KARAMJA.contains(tile()),false,"Take me to Karamja please!"); break;
			case "shipyard": enterShipyard(); break;
			case "foreman": talk(new int[]{1429},new Tile(3000,3044),() -> stage() >= 90 || Inventory.contains(787),false,"Sadly his wife is no longer with us!","He loves worm holes.","Anita."); break;
			case "lumber_order": travel.king(true); travel.top(); talk(GnomeTravel.CHARLIE,null,() -> stage() >= 100,false); break;
			case "anita": travel.anita(); talk(new int[]{7156},null,() -> Inventory.contains(788),false,"I suppose so."); break;
			case "plans": travel.glough(); searchContainer(2436,2437,794); break;
			case "return_plans": travel.king(false); talk(GnomeTravel.KING,null,() -> stage() >= 120,false); break;
			case "twigs": twigs(); break;
			default:throw new IllegalArgumentException("Unknown Grand Tree phase: " + phase);
		}
	}
	private void enterShipyard()
	{
		walk(new Tile(2943,3041),1,false);
		Automation.intent("grand_tree.enter_shipyard", () ->
		{
			GameObject gate = GameObjects.closest(object -> (object.getId() == 2438 || object.getId() == 2439) && object.hasAction("Open"));
			require(gate != null && gate.interact("Open"),"Shipyard gate did not open");
			dialogue(() -> SHIPYARD.contains(tile()),120,"Glough sent me.","Ka.","Lu.","Min.");			return null;
		});

	}
	private void searchContainer(int closedId, int openId, int item)
	{
		Automation.intent("grand_tree.search_container", () ->
		{
			GameObject closed = GameObjects.closest(object -> object.getId() == closedId && object.hasAction("Open"));
			if (closed != null)
			{
				require(closed.interact("Open"),"Quest container did not open");
				await(() -> GameObjects.closest(openId) != null || Inventory.contains(item),30,"Quest container did not change");
			}
			if (Inventory.contains(item)) return null;
			GameObject open = GameObjects.closest(openId);
			require(open != null && open.interact("Search"),"Quest container search failed");
			await(() -> Inventory.contains(item),30,"Quest item was not obtained: " + item);			return null;
		});

	}
	private void twigs()
	{
		travel.watchtower();
		Automation.intent("grand_tree.place_tuzo_twigs", () ->
		{
			for (int index = 0; index < 4; index++)
			{
				int item = 789+index;
				if (!Inventory.contains(item)) continue;
				GameObject pillar = GameObjects.closest(2440+index);
				require(pillar != null && Inventory.get(item).useOn(pillar),"Tuzo twig placement failed");
				await(() -> !Inventory.contains(item),20,"Tuzo twig was not consumed");
			}
			await(() -> stage() >= 130,30,"Tuzo puzzle completion was not observed");			return null;
		});

	}
	private boolean combatReady() { return carried(1387) && Inventory.count(558) >= 300 && Inventory.count(556) >= 600 && Inventory.count(379) >= 6; }
	@Override void escape() { Jewellery.teleport(Jewellery.Destination.CASTLE_WARS); }
}
