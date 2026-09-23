package com.genericclient.scripts.quests;

import org.dreambot.api.methods.settings.PlayerSettings;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Supply;
import java.util.ArrayList;
import java.util.List;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Area;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;

final class Waterfall extends QuestWorkflow
{
	static final Area GNOME = new Area(2497,9552,2559,9593);
	static final Area GOLRIE = new Area(2502,9576,2523,9593);
	static final Area TOMB = new Area(2524,9801,2557,9849);
	static final Area HUDON = new Area(2510,3476,2515,3482);
	static final Area TREE = new Area(2512,3465,2513,3475);
	static final Area LEDGE = new Area(2510,3462,2513,3464);
	static final Area UPSTAIRS = new Area(2516,3424,2520,3431,1);
	static final Area FALLS = new Area(2556,9861,2595,9920);
	static final Area PILLARS = new Area(2561,9902,2570,9917);
	static final Area CHALICE = new Area(2599,9890,2608,9916);
	private boolean initialPrepared;
	private boolean gnomePrepared;
	private boolean tombPrepared;
	private boolean finalPrepared;
	Waterfall() { super("waterfall_quest"); }
	@Override int stage() { return PlayerSettings.getConfig(65); }
	@Override void validate() { require(Skills.getRealLevel(Skill.HITPOINTS) >= 15,"Waterfall requires at least 15 Hitpoints for this route"); foodGuard(true); }
	@Override int checkpoint()
	{
		if (finished()) return 7;
		if (stage() == 0) return 0;
		if (stage() <= 2) return 1;
		if (carried(295) && carried(296) || finalPrepared) return 4;
		if (TOMB.contains(tile()) || carried(294)) return 3;
		return 2;
	}
	@Override String phase()
	{
		if (stage() == 0) return initialPrepared ? "accept" : "prepare_initial";
		if (stage() == 1) return HUDON.contains(tile()) ? "talk_hudon" : "raft";
		if (stage() == 2) return investigation();
		if (stage() >= 3 && stage() <= 8) return treasures();
		throw new IllegalStateException("Unexpected Waterfall stage: " + stage());
	}
	private String investigation()
	{
		if (Inventory.contains(292)) return "read_book";
		if (UPSTAIRS.contains(tile())) return "book";
		if (LEDGE.contains(tile())) return "barrel";
		if (TREE.contains(tile())) return "descend_tree";
		if (HUDON.contains(tile())) return "cross_rock";
		return "tourist_stairs";
	}
	private String treasures()
	{
		if (CHALICE.contains(tile())) return "finish";
		if (TOMB.contains(tile())) return tombPhase();
		if (Supplies.owned(295) > 0 && Supplies.owned(296) > 0)
		{
			if (GNOME.contains(tile())) return "leave_gnome";
			return finale();
		}
		if (carried(294) || Supplies.owned(294) > 0)
		{
			if (GNOME.contains(tile())) return "leave_gnome";
			return tombPrepared ? "enter_tomb" : "prepare_tomb";
		}
		if (GOLRIE.contains(tile())) return "pebble";
		if (GNOME.contains(tile())) return Inventory.contains(293) ? "golrie_gate" : "golrie_key";
		if (UPSTAIRS.contains(tile())) return "downstairs";
		return gnomePrepared ? "gnome_dungeon" : "prepare_gnome";
	}
	private String tombPhase()
	{
		if (!Inventory.contains(295)) return "amulet";
		return Inventory.contains(296) ? "leave_tomb" : "urn";
	}

	private String finale()
	{
		if (PILLARS.contains(tile()))
		{
			require(carried(295),"Glarial's amulet is missing in the pillar room");
			return Equipment.contains(295) ? "remove_amulet" : "pillars";
		}
		if (FALLS.contains(tile())) return Inventory.contains(298) ? "inner_door" : "falls_key";
		if (LEDGE.contains(tile())) return Equipment.contains(295) ? "enter_falls" : "equip_amulet";
		if (TREE.contains(tile())) return "descend_tree";
		if (HUDON.contains(tile())) return "cross_rock";
		return finalPrepared ? "raft" : "prepare_final";
	}
	@Override void execute(String phase)
	{
		switch (phase)
		{
			case "prepare_initial": prepare(List.of(new Supply(954,"Rope",1,1000),necklace(),wine(6))); initialPrepared = true; break;
			case "prepare_gnome": prepareGnome(); break;
			case "prepare_tomb": prepareTomb(); break;
			case "prepare_final": prepareFinal(); break;
			case "enter_tomb": enterTomb(); break;
			case "amulet":
				interact(GameObjects.closest(1995) == null ? 1994 : 1995,"Open",new Tile(2530,9844),() -> Inventory.contains(295),true); break;
			case "urn": interact(1993,"Search",new Tile(2542,9812),() -> Inventory.contains(296),true); break;
			case "falls_key": case "inner_door": case "remove_amulet": case "pillars": case "finish": new WaterfallRitual(this).execute(phase); break;
			default: new WaterfallNavigation(this).execute(phase);
		}
	}
	private void prepareGnome()
	{
		List<Supply> stock = new ArrayList<>(List.of(duelingRing(),wine(10)));
		if (Supplies.owned(293) > 0) stock.add(questItem(293,"Key"));
		prepare(stock); gnomePrepared = true;
	}
	private void prepareTomb()
	{
		List<Supply> stock = new ArrayList<>(List.of(questItem(294,"Glarial's pebble"),necklace(),wine(10)));
		if (Supplies.owned(295) > 0) stock.add(questItem(295,"Glarial's amulet"));
		prepare(stock); tombPrepared = true;
	}
	private void prepareFinal()
	{
		List<Supply> stock = new ArrayList<>(List.of(new Supply(954,"Rope",1,1000),necklace(),wine(8),
			new Supply(555,"Water rune",6,50),new Supply(556,"Air rune",6,50),new Supply(557,"Earth rune",6,50),
			questItem(295,"Glarial's amulet"),questItem(296,"Glarial's urn")));
		if (Supplies.owned(298) > 0) stock.add(questItem(298,"Key"));
		prepare(stock); finalPrepared = true;
	}
	private void enterTomb()
	{
		if (new Tile(2559,3445).distance() > 200) Jewellery.teleport(Jewellery.Destination.BARBARIAN_OUTPOST);
		walk(new Tile(2559,3445),3,false);
		require(Inventory.get(294).useOn(GameObjects.closest(1992)),"Glarial's tomb could not be entered");
		await(() -> TOMB.contains(tile()),30,"Glarial's tomb entry was not observed");
	}
	@Override void escape()
	{
		Jewellery.teleport(GNOME.contains(tile()) ? Jewellery.Destination.CASTLE_WARS : Jewellery.Destination.BURTHORPE);
	}
}
