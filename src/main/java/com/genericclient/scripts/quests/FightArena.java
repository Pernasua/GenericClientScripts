package com.genericclient.scripts.quests;

import org.dreambot.api.methods.settings.PlayerSettings;
import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Supply;
import com.genericclient.scripts.shared.Travel;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.magic.Normal;
import org.dreambot.api.methods.map.Area;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

final class FightArena extends QuestWorkflow
{
	private static final int[] LADY = {12029,1203};
	private static final int[] SAMMY = {12031,12033,12030,1204};
	private static final Area ARENA = new Area(2583,3152,2606,3170);
	private static final Area CELL = new Area(2597,3142,2601,3144);
	private boolean prepared;
	FightArena() { super("fight_arena"); }
	@Override int stage() { return PlayerSettings.getConfig(17); }
	@Override void validate() { require(Skills.getRealLevel(Skill.MAGIC) >= 29 && Skills.getRealLevel(Skill.HITPOINTS) >= 20,"Fight Arena requires Magic 29 and 20 Hitpoints for this route"); QuestCombat.foodGuard(6); }
	@Override String phase()
	{
		int stage = stage();
		if (stage == 0 && !prepared || (stage == 6 || stage == 9 || stage == 10) && tile().getX() < 10000 && !combatReady()) return "prepare";
		return questPhase(stage);
	}
	private String questPhase(int stage)
	{
		if (stage >= 6) return encounterPhase(stage);
		if (stage >= 2 && stage <= 5)
		{
			if (!carried(74) || !carried(75)) return "armour";
			if (!Equipment.contains(74) || !Equipment.contains(75)) return "equip_armour";
		}
		switch (stage)
		{
			case 0:return "accept";
			case 1:return "armour";
			case 2:return "guard";
			case 3:return Inventory.contains(77) ? "give_brew" : "buy_brew";
			case 4:case 5:return Inventory.contains(76) ? "free_sammy" : "keys";

			default:throw new IllegalStateException("Unexpected Fight Arena stage: " + stage);
		}
	}
	private String encounterPhase(int stage)
	{
		switch (stage)
		{
			case 6:return npc(1225) == null ? "sammy_ogre" : "ogre";
			case 7:case 8:return "general";
			case 9:return CELL.contains(tile()) ? "hengrad" : npc(1226) == null ? "sammy_scorpion" : "scorpion";
			case 10:return npc(1224) == null ? "sammy_bouncer" : "bouncer";
			case 11:case 12:case 13:case 14:return tile().getX() >= 10000 || ARENA.contains(tile()) ? "exit" : "finish";
			default:throw new IllegalStateException("Unexpected Fight Arena encounter stage: " + stage);
		}
	}

	@Override int checkpoint()
	{
		return List.of("accept","armour","equip_armour","guard","buy_brew","give_brew","keys","free_sammy",
			"sammy_ogre","ogre","general","hengrad","sammy_scorpion","scorpion","sammy_bouncer","bouncer","exit","finish")
			.indexOf(questPhase(stage()));
	}

	@Override void execute(String phase)
	{
		switch (phase)
		{
			case "prepare": prepareStock(); break;
			case "accept": talk(LADY,new Tile(2565,3199),() -> stage() > 0,false,"Yes."); break;
			case "armour": armour(); break;
			case "equip_armour":
				Automation.intent("fight_arena.equip_armour", () ->
				{
					Supplies.equip(74); Supplies.equip(75);
					return null;
				}); break;
			case "guard": case "give_brew": guard(); break;
			case "buy_brew": buyBrew(); break;
			case "keys": talk(new int[]{1209},new Tile(2615,3143),() -> Inventory.contains(76),false); break;
			case "free_sammy": use(76,80,new Tile(2617,3167),() -> stage() >= 6,true); break;
			case "sammy_ogre": sammy(1225); break;
			case "sammy_scorpion": sammy(1226); break;
			case "sammy_bouncer": sammy(1224); break;
			case "general": general(); break;
			case "hengrad": talk(new int[]{1218},new Tile(2599,3143),() -> !CELL.contains(tile()) || npc(1226) != null,true); break;
			case "ogre": fight(1225,8,false); break;
			case "scorpion": fight(1226,10,true); break;
			case "bouncer": fight(1224,11,false); break;
			case "exit": exitArena(); break;
			case "finish": talk(LADY,new Tile(2565,3199),this::finished,false); break;
			default:throw new IllegalArgumentException("Unknown Fight Arena phase: " + phase);
		}
	}
	private boolean combatReady() { return carried(1381) && Inventory.count(562) >= 40 && Inventory.count(557) >= 120 && Inventory.count(379) >= 8; }
	private void prepareStock()
	{
		List<Supply> stock = new ArrayList<>(List.of(new Supply(1381,"Staff of air",1,2000),new Supply(562,"Chaos rune",100,500),
			new Supply(557,"Earth rune",300,100),duelingRing(),new Supply(995,"Coins",5,0),new Supply(379,"Lobster",18,500)));
		for (int id : new int[]{74,75,76,77}) if (carried(id) || Supplies.owned(id) > 0) stock.add(questItem(id,"Fight Arena item"));
		prepare(stock); prepared = true;
		Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
	}
	private void armour()
	{
		walk(new Tile(2612,3190),0,false);
		Automation.intent("fight_arena.obtain_armour", () ->
		{
			GameObject chest = GameObjects.closest(object -> (object.getId() == 75 || object.getId() == 76) && object.hasAction("Search"));
			if (chest == null)
			{
				GameObject closed = GameObjects.closest(75);
				require(closed != null && closed.interact("Open"),"Khazard armour chest did not open");
				await(() -> GameObjects.closest(object -> (object.getId() == 75 || object.getId() == 76) && object.hasAction("Search")) != null,
					30,"Searchable armour chest was not observed");
				chest = GameObjects.closest(object -> (object.getId() == 75 || object.getId() == 76) && object.hasAction("Search"));
			}
			require(chest.interact("Search"),"Khazard armour search failed");
			await(() -> carried(74) && carried(75),40,"Khazard armour was not obtained");			return null;
		});

	}
	private void guard()
	{
		int before = stage();
		talk(new int[]{1209},new Tile(2615,3143),() -> stage() != before,false);
	}
	private void buyBrew()
	{
		walk(new Tile(2569,3150),1,false);
		GameObject door = GameObjects.closest(object -> object.getId() == 1535 && object.hasAction("Open"));
		if (door != null) require(door.interact("Open"),"Arena bar door did not open");
		walk(new Tile(2568,3140),0,false);
		talk(new int[]{1214},null,() -> Inventory.contains(77),false,"I'd like a Khali Brew please.");
	}
	private void sammy(int targetId)
	{
		if (tile().getX() >= 10000 || Dialogues.inDialogue()) { dialogue(() -> npc(targetId) != null,160); return; }
		walk(new Tile(2602,3153),5,false);
		NPC sammy = NPCs.closest(candidate -> Arrays.stream(SAMMY).anyMatch(id -> candidate.getId() == id) && candidate.hasAction("Talk-to"));
		if (sammy != null) require(sammy.interact("Talk-to"),"Sammy dialogue failed");
		else
		{
			walk(new Tile(2585,3141),1,true);
			GameObject door = GameObjects.closest(81);
			require(door != null && door.interact("Open"),"Arena re-entry door did not open");
		}
		dialogue(() -> npc(targetId) != null,160);
	}
	private void general()
	{
		int before = stage();
		if (Dialogues.inDialogue()) dialogue(() -> stage() != before,160);
		else talk(new int[]{3510},null,() -> stage() != before,true);
	}
	private void fight(int id, int nextStage, boolean allowClose)
	{
		QuestCombat.configure(1381,Normal.EARTH_BOLT);
		Tile safe = mapped(new Tile(2598,3162));
		Travel.to(safe,0,"combat",WorkflowScript.NO_DISCRETIONARY);
		NPC target = npc(id);
		require(target != null && QuestCombat.lineOfSight(target) && (allowClose || target.distance() >= 4),"Arena safespot was not established");
		QuestCombat.monitor(new int[]{id},() -> stage() >= nextStage,700,
			current -> require(tile().equals(safe),"Arena safespot was lost"));
	}
	private void exitArena()
	{
		if (tile().getX() >= 10000)
		{
			GameObject exit = GameObjects.closest(object -> object.hasAction("Quick-escape"));
			if (exit == null)
			{
				Travel.to(mapped(new Tile(2606,3152)),6,"combat",WorkflowScript.NO_DISCRETIONARY);
				exit = GameObjects.closest(object -> object.hasAction("Quick-escape"));
			}
			require(exit != null && exit.interact("Quick-escape"),"Arena quick escape was not available");
			await(() -> tile().getX() < 10000,30,"Arena escape was not observed");
		}
		else
		{
			walk(new Tile(2606,3152),2,true);
			GameObject door = GameObjects.closest(82);
			require(door != null && door.interact("Open"),"Arena exit door did not open");
			dialogue(() -> !ARENA.contains(tile()),80,"Yes.");
		}
	}
	@Override void escape() { if (tile().getX() >= 10000) exitArena(); else Jewellery.teleport(Jewellery.Destination.CASTLE_WARS); }
}
