package com.genericclient.scripts.quests;

import org.dreambot.api.methods.settings.PlayerSettings;
import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Supply;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;

final class MonkeyMadness extends QuestWorkflow
{
	private static final int[] RETAINED = {4006,4020,4007,4022,4021,4023,3183,3166,4031,4033,4035};
	private final MonkeyTravel travel = new MonkeyTravel(this);
	private final MonkeyPrison prison = new MonkeyPrison();
	private final MonkeyDungeon dungeon = new MonkeyDungeon(this);
	private final MonkeyAmulet amulet = new MonkeyAmulet(this,prison);
	private int completedSteps;
	MonkeyMadness() { super("monkey_madness_i"); }
	@Override int stage() { return PlayerSettings.getConfig(365); }
	@Override void validate()
	{
		require("finished".equals(com.genericclient.script.SnapshotData.map(com.genericclient.script.SnapshotData.read("quests").get("the_grand_tree")).get("state")) &&
			"finished".equals(com.genericclient.script.SnapshotData.map(com.genericclient.script.SnapshotData.read("quests").get("tree_gnome_village")).get("state")),
			"Monkey Madness requires The Grand Tree and Tree Gnome Village");
		require(Skills.getRealLevel(Skill.PRAYER) >= 43 && Skills.getRealLevel(Skill.MAGIC) >= 35,"This Monkey Madness route requires Prayer 43 and Magic 35");
		if (Inventory.contains(4033)) Automation.activity("questing",WorkflowScript.NO_DISCRETIONARY);
		MonkeySurvival.behavior(true);
	}
	@Override Object run()
	{
		if (!scope.equals("prison_cell")) return super.run();
		validate();
		if (!MonkeyAreas.prison())
		{
			if (!MonkeyAreas.south()) { prepareApe(); travel.ape(); }
			prison.enter();
		}
		prison.escape(true);
		return Map.of("status","prison_checkpoint","quest",key,"position",tile().toString());
	}
	@Override int checkpoint() { return completedSteps; }
	@Override String phase()
	{
		if (stage() == 0) return "start";
		if (stage() <= 2)
		{
			String phase = preludePhase();
			if (phase != null) return phase;
		}
		if (stage() <= 3 && bit(126) < 2 && Arrays.stream(RETAINED).noneMatch(id -> Supplies.owned(id) > 0))
			return MonkeyAreas.ape() ? "garkor" : matches(MonkeyLoadouts.APE_ATOLL_LOADOUT) ? "ape" : "prepare_ape";
		if (stage() == 3) return amuletPhase();
		if (stage() == 4) return favorPhase();
		if (stage() == 5) return battlePhase();
		if (stage() >= 6) return "finish";
		throw new IllegalStateException("Unexpected Monkey Madness stage: " + stage());
	}
	private String battlePhase()
	{
		if (MonkeyAreas.demon()) return "battle";
		if (!carried(4035) && Supplies.owned(4035) == 0) return "sigil";
		return matches(MonkeyLoadouts.DEMON_LOADOUT) ? "enter_battle" : "prepare_demon";
	}

	private String preludePhase()
	{
		if (bit(122) < 3) return "shipyard";
		if (bit(121) < 7) return "report";
		if (bit(123) < 1) return "daero";
		if (bit(123) < 5) return "hangar";
		if (bit(123) < 6) return "puzzle";
		if (bit(123) < 7) return "confirm";
		return null;
	}

	private String amuletPhase()
	{
		if (carried(4031)) return MonkeyAreas.ZOOKNOCK_DUNGEON.contains(tile()) ? "exit_dungeon" : "sync_greegree";
		if (Supplies.owned(4021) > 0)
		{
			if (Supplies.owned(4023) > 0) return greegreePhase();
			if (!carried(4021)) return "prepare_ape";
			return northernPhase(tile().equals(MonkeyMap.MONKEY_CHILD_STAGING) ? "talisman" : "finish_amulet");
		}
		if (Supplies.owned(4022) > 0) return carried(4022) && Inventory.contains(1759) ? "craft_amulet" : "prepare_crafting";
		if (Supplies.owned(4007) > 0)
		{
			if (MonkeyAreas.ZOOKNOCK_DUNGEON.contains(tile())) return "exit_dungeon";
			if (!carried(4007) || !carried(4020) || !carried(1759)) return "prepare_crafting";
			return northernPhase("craft_amulet");
		}
		return amuletMaterialsPhase();
	}

	private String northernPhase(String destinationPhase)
	{
		if (!MonkeyAreas.ape()) return "ape";
		if (MonkeyAreas.south()) return "prison";
		if (MonkeyAreas.prison()) return "escape_prison";
		return destinationPhase;
	}

	private String greegreePhase()
	{
		if (MonkeyAreas.ZOOKNOCK_DUNGEON.contains(tile())) return "greegree";
		if (!matches(MonkeyLoadouts.GREEGREE_LOADOUT)) return "prepare_greegree";
		return MonkeyAreas.south() ? "greegree" : "ape";
	}

	private String amuletMaterialsPhase()
	{
		if (MonkeyAreas.ZOOKNOCK_DUNGEON.contains(tile())) return "bar";
		if (Supplies.owned(4006) > 0 && Supplies.owned(4020) > 0)
		{
			if (!matches(MonkeyLoadouts.AMULET_BAR_LOADOUT)) return "prepare_bar";
			return MonkeyAreas.south() ? "bar" : "ape";
		}
		if (MonkeyAreas.AMULET_MOULD_ROOM.contains(tile()) || MonkeyAreas.DENTURE_BUILDING.contains(tile()) || MonkeyAreas.north() || MonkeyAreas.prison()) return "infiltrate";
		if (MonkeyAreas.south()) return "prison";
		return matches(MonkeyLoadouts.APE_ATOLL_LOADOUT) ? "ape" : "prepare_ape";
	}

	private String favorPhase()
	{
		if (Inventory.contains(4033)) return MonkeyAreas.ape() || MonkeyAreas.throne() ? "favor" : "carry_monkey";
		if (MonkeyAreas.north() || MonkeyAreas.throne() || MonkeyAreas.APE_ATOLL_BRIDGE.contains(tile()) || MonkeyAreas.APE_ATOLL_OVER_BRIDGE.contains(tile())) return "sigil";
		if (MonkeyAreas.pen() || MonkeyMap.ARDOUGNE_ZOO_MINDER.distance() <= 30) return "zoo";
		return matches(MonkeyLoadouts.ZOO_LOADOUT) ? "zoo" : "prepare_zoo";
	}
	@Override void execute(String phase)
	{
		if (List.of("start","shipyard","report","daero","hangar","puzzle","confirm").contains(phase)) new MonkeyPrelude(this,travel).execute(phase);
		else if (phase.startsWith("prepare_")) preparePhase(phase);
		else executeJourney(phase);
		completedSteps++;
	}
	private void executeJourney(String phase)
	{
		MonkeyFavor favor = new MonkeyFavor(this,travel);
		switch (phase)
		{
			case "ape": travel.ape(); break;
			case "prison": prison.enter(); break;
			case "escape_prison": prison.escape(false); break;
			case "garkor": garkor(); break;
			case "infiltrate": new MonkeyInfiltration(this,prison).obtain(); break;
			case "bar": dungeon.enchantedBar(); break;
			case "exit_dungeon": dungeon.exit(); break;
			case "craft_amulet": amulet.craft(); break;
			case "finish_amulet": amulet.leaveTemple(); break;
			case "talisman": new MonkeyTalisman(prison).obtain(); break;
			case "greegree": greegree(); break;
			case "sync_greegree": await(() -> stage() >= 4,30,"Greegree quest progress did not synchronize"); break;
			case "zoo": favor.zoo(); break;
			case "carry_monkey": favor.carry(); break;
			case "favor": favor.favor(); break;
			case "sigil": favor.sigil(); break;
			case "enter_battle": new MonkeyBattle(this).enter(); break;
			case "battle": new MonkeyBattle(this).fight(); break;
			case "finish": travel.king(); talk(GnomeTravel.KING,null,this::finished,false); break;
			default:throw new IllegalArgumentException("Unknown Monkey Madness phase: " + phase);
		}
	}
	private void preparePhase(String phase)
	{
		switch (phase)
		{
			case "prepare_ape": prepareApe(); return;
			case "prepare_bar": prepare(MonkeyLoadouts.AMULET_BAR_LOADOUT); break;
			case "prepare_crafting":
				List<Supply> crafting = new ArrayList<>(MonkeyLoadouts.AMULET_CRAFTING_LOADOUT);
				if (Supplies.owned(4022) > 0) { crafting.removeIf(item -> item.id == 4007); crafting.add(questItem(4022,"Unstrung M'speak amulet")); }
				prepare(crafting); break;
			case "prepare_greegree": prepare(MonkeyLoadouts.GREEGREE_LOADOUT); break;
			case "prepare_zoo": prepare(MonkeyLoadouts.ZOO_LOADOUT); break;
			case "prepare_demon": prepare(MonkeyLoadouts.DEMON_LOADOUT); break;
			default:throw new IllegalArgumentException("Unknown Monkey Madness loadout: " + phase);
		}
		MonkeySurvival.arm(4);
	}
	private void prepareApe()
	{
		toExchange(); Supplies.openBank();
		List<Supply> retained = new ArrayList<>();
		for (int id : RETAINED) if (Supplies.owned(id) > 0) retained.add(questItem(id,"Monkey Madness item"));
		List<Supply> stock = new ArrayList<>();
		for (Supply item : MonkeyLoadouts.APE_ATOLL_LOADOUT)
			stock.add(item.id == 379 ? new Supply(379,item.name,Math.max(1,item.quantity-retained.size()),item.maximumPrice) : item);
		stock.addAll(retained); Supplies.prepare(stock,purchase); MonkeySurvival.arm(4);
	}
	private void garkor()
	{
		MonkeySurvival.arm(4);
		if (MonkeyAreas.south()) prison.enter();
		if (MonkeyAreas.prison()) prison.escape(false);
		if (MonkeyMap.GARKOR.distance() > 8) MonkeySurvival.route(MonkeyRoutes.PRISON_TO_GARKOR,"missiles");
		talk(new int[]{7158},null,() -> bit(126) >= 2,false);
	}
	private void greegree()
	{
		dungeon.reach();
		dungeon.deliver(4023); dungeon.deliver(Inventory.contains(3183) ? 3183 : 3166);
		if (!carried(4031)) talk(new int[]{7170},null,() -> carried(4031),false,"What do we need for the monkey talisman?");
		dungeon.exit();
	}
	private boolean matches(List<Supply> stock)
	{
		for (Supply item : stock)
		{
			int quantity = Arrays.stream(item.ids).map(id -> Inventory.count(id) + Equipment.all().stream()
				.filter(worn -> worn.getId() == id).mapToInt(org.dreambot.api.wrappers.items.Item::getAmount).sum()).sum();
			if (quantity < item.quantity) return false;
		}
		return true;
	}
	@Override void walk(org.dreambot.api.methods.map.Tile point, int within, boolean hazardous)
	{
		if (Inventory.contains(4033)) MonkeyFavor.transport(new com.genericclient.script.Navigation.Journey(point,within));
		else super.walk(point,within,hazardous);
	}
	@Override void escape()
	{
		if (!Inventory.contains(4033)) Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
	}
}
