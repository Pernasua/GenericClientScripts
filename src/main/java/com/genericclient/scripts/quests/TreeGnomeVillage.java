package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supply;
import com.genericclient.scripts.shared.Travel;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.magic.Normal;
import org.dreambot.api.methods.map.Area;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

final class TreeGnomeVillage extends QuestWorkflow
{
	private static final Area VILLAGE = new Area(2514,3158,2542,3175);
	private static final Area TOWER = new Area(2500,3251,2508,3260);
	private boolean prepared;
	TreeGnomeVillage() { super("tree_gnome_village",111); }
	@Override void validate() { require(Skills.getRealLevel(Skill.MAGIC) >= 29 && Skills.getRealLevel(Skill.HITPOINTS) >= 20,"Tree Gnome Village requires Magic 29 and 20 Hitpoints for this route"); QuestCombat.foodGuard(Math.max(4,Skills.getRealLevel(Skill.HITPOINTS)/4)); }
	@Override String phase()
	{
		int stage = varp();
		if (stage == 0 && !prepared || stage == 2 && Inventory.count(1511) < 6 ||
			stage == 7 && !carried(588) && groundOrbs() == null && !combatReady()) return "prepare";
		return questPhase(stage);
	}
	private String questPhase(int stage)
	{
		switch (stage)
		{
			case 0:return "accept";
			case 1:return "montai";
			case 2:return "logs";
			case 3:return "montai_again";
			case 4:return bit(599) == 0 ? "tracker_one" : bit(600) == 0 ? "tracker_two" : bit(601) == 0 ? "tracker_three" : "ballista";
			case 5:return Inventory.contains(587) ? "return_first_orb" : tile().getZ() == 1 ? "chest" : "tower";
			case 6:return "return_first_orb";
			case 7:case 8:return Inventory.contains(588) || bit(598) > 0 ? "return_orbs" : groundOrbs() != null ? "take_orbs" : "warlord";
			default:throw new IllegalStateException("Unexpected Tree Gnome Village stage: " + stage);
		}
	}
	@Override int checkpoint()
	{
		switch (questPhase(varp()))
		{
			case "accept":return 0;
			case "montai":case "logs":case "montai_again":return 1;
			case "tracker_one":case "tracker_two":case "tracker_three":case "ballista":return 2;
			case "tower":case "chest":return 3;
			case "return_first_orb":return 4;
			case "warlord":case "take_orbs":return 5;
			case "return_orbs":return 6;
			default:throw new IllegalStateException("Unexpected quest checkpoint");
		}
	}

	@Override void execute(String phase)
	{
		switch (phase)
		{
			case "prepare": prepareStock(); break;
			case "accept": enterVillage(true); talk(new int[]{4963},new Tile(2541,3170),() -> varp() >= 1,false,"Can I help at all?","I would be glad to help.","Yes."); break;
			case "montai": montai(2,"Ok, I'll gather some wood."); break;
			case "logs": require(Inventory.count(1511) >= 6,"Six logs are not carried"); montai(3); break;
			case "montai_again": montai(4,"I'll try my best."); break;
			case "tracker_one": talk(new int[]{4975},new Tile(2501,3261),() -> bit(599) > 0,false); break;
			case "tracker_two": talk(new int[]{4976},new Tile(2524,3257),() -> bit(600) > 0,false); break;
			case "tracker_three": talk(new int[]{4977},new Tile(2497,3234),() -> bit(601) > 0,false); break;
			case "ballista": fireBallista(); break;
			case "tower": enterTower(); break;
			case "chest": searchChest(); break;
			case "return_first_orb": leaveTower(); enterVillage(false); talk(new int[]{4963},new Tile(2541,3170),() -> varp() >= 7,false,"I will find the warlord and bring back the orbs."); break;
			case "warlord": fightWarlord(); break;
			case "take_orbs": takeOrbs(); break;
			case "return_orbs": enterVillage(false); talk(new int[]{4963},new Tile(2541,3170),this::finished,false); break;
			default:throw new IllegalArgumentException("Unknown Tree Gnome Village phase: " + phase);
		}
	}
	private boolean combatReady()
	{
		return carried(1381) && Inventory.count(562) >= 40 && Inventory.count(557) >= 120 && Inventory.count(379) >= 10;
	}

	private void prepareStock()
	{
		List<Supply> stock = new ArrayList<>(List.of(new Supply(1381,"Staff of air",1,2000),
			new Supply(562,"Chaos rune",100,500),new Supply(557,"Earth rune",300,100),duelingRing(),
			new Supply(379,"Lobster",varp() < 3 ? 14 : 20,500)));
		if (varp() < 3) stock.add(new Supply(1511,"Logs",6,500));
		prepare(stock); prepared = true;
		Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
	}
	private void enterVillage(boolean maze)
	{
		if (VILLAGE.contains(tile())) return;
		if (new Tile(2505,3190).distance() > 150) Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
		if (maze) walk(new Tile(2515,3159),0,false);
		else talk(new int[]{4968},new Tile(2505,3191),() -> VILLAGE.contains(tile()),false,"Yes please.");
		require(VILLAGE.contains(tile()),"Gnome village arrival was not observed");
	}
	private void leaveVillage()
	{
		if (!VILLAGE.contains(tile())) return;
		walk(new Tile(2505,3190),0,false);
	}
	private void montai(int stage, String... choices)
	{
		leaveVillage();
		talk(new int[]{4964},new Tile(2523,3208),() -> varp() >= stage,false,choices);
	}
	private void fireBallista()
	{
		walk(new Tile(2509,3211),3,false);
		Automation.intent("tree_gnome.fire_ballista", () ->
		{
			GameObject ballista = GameObjects.closest(2181);
			require(ballista != null && ballista.interact("Fire"),"Ballista could not be fired");
			dialogue(() -> varp() >= 5,100,String.format(java.util.Locale.ROOT,"%04d",bit(602)+1));			return null;
		});

	}
	private void enterTower()
	{
		if (!TOWER.contains(tile()))
		{
			if (GameObjects.closest(2185) == null) talk(new int[]{4964},new Tile(2523,3208),() -> GameObjects.closest(2185) != null,false);
			interact(2185,"Climb-over",new Tile(2509,3253),() -> TOWER.contains(tile()),false);
		}
		Automation.intent("tree_gnome.climb_tower", () ->
		{
			GameObject ladder = GameObjects.closest(object -> object.getId() == 16683 && object.hasAction("Climb-up"));
			require(ladder != null && ladder.interact("Climb-up"),"Orb tower ladder was not available");
			await(() -> tile().getZ() == 1,40,"Orb tower ascent was not observed");			return null;
		});

	}
	private void searchChest()
	{
		Automation.intent("tree_gnome.search_orb_chest", () ->
		{
			GameObject closed = GameObjects.closest(2183);
			if (closed != null)
			{
				require(closed.interact("Open"),"Orb chest did not open");
				await(() -> GameObjects.closest(2182) != null,30,"Open orb chest was not observed");
			}
			require(GameObjects.closest(2182).interact("Search"),"Orb chest search failed");
			await(() -> Inventory.contains(587),40,"First orb was not obtained");			return null;
		});

	}
	private void leaveTower()
	{
		if (tile().getZ() == 1)
		{
			GameObject ladder = GameObjects.closest(object -> object.getName().equals("Ladder") && object.hasAction("Climb-down"));
			require(ladder != null && ladder.interact("Climb-down"),"Orb tower descent failed");
			await(() -> tile().getZ() == 0,40,"Orb tower descent was not observed");
		}
		if (TOWER.contains(tile()))
		{
			GameObject door = GameObjects.closest(2184);
			if (door != null) require(door.interact("Open"),"Orb tower door did not open");
			walk(new Tile(2503,3248),1,false);
		}
	}
	private void fightWarlord()
	{
		try
		{
			QuestCombat.configure(1381,Normal.EARTH_BOLT);
			leaveVillage(); walk(new Tile(2456,3301),2,false);
			if (npc(7622) == null) talk(new int[]{7621},null,() -> npc(7622) != null || groundOrbs() != null,true);
			if (groundOrbs() != null) return;
			positionWarlord();
			QuestCombat.monitor(new int[]{7622},() -> groundOrbs() != null,600,target -> { if (target.distance() < 4) positionWarlord(); });
		}
		catch (RuntimeException failure)
		{
			if (!(failure instanceof java.util.concurrent.CancellationException) && com.genericclient.script.ScriptScope.current().isRunning())
			{
				try { escape(); }
				catch (RuntimeException escapeFailure) { failure.addSuppressed(escapeFailure); }
			}
			throw failure;
		}
	}
	private void positionWarlord()
	{
		Travel.to(new Tile(2443,3303),1,"combat",WorkflowScript.NO_DISCRETIONARY);
		await(() -> { NPC npc = npc(7622); return npc != null && npc.getTile().getX() <= 2448 && npc.distance() <= 5; },20,"Warlord pin was not observed");
		Travel.to(new Tile(2443,3296),1,"combat",WorkflowScript.NO_DISCRETIONARY);
		await(() -> { NPC npc = npc(7622); return npc != null && npc.distance() >= 4 && QuestCombat.lineOfSight(npc); },10,"Warlord safespot was not established");
	}
	private Map<?,?> groundOrbs()
	{
		return SnapshotData.rows("ground_items",Map.of("id",588,"within",32,"limit",3)).stream().findFirst().orElse(null);
	}
	private void takeOrbs()
	{
		Map<?,?> drop = groundOrbs(); require(drop != null,"Remaining orbs were not observed");
		Map<?,?> world = SnapshotData.map(drop.get("world"));
		take(588,new Tile(SnapshotData.integer(world,"x"),SnapshotData.integer(world,"y"),SnapshotData.integer(world,"plane")));
	}
	@Override void escape() { Jewellery.teleport(Jewellery.Destination.CASTLE_WARS); }
}
