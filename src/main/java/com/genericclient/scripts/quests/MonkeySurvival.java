package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.WorkflowScript;
import com.genericclient.script.Automation;
import com.genericclient.script.SnapshotData;
import com.genericclient.script.Navigation;
import com.genericclient.script.Navigation.Journey;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Safety;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.function.Supplier;
import org.dreambot.api.utilities.Sleep;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.settings.PlayerSettings;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.methods.walking.impl.Walking;
import org.dreambot.api.wrappers.items.Item;

final class MonkeySurvival
{
	private static final int[] PRAYER = {2434,139,141,143};
	private static final int[] STAMINA = {12625,12627,12629,12631};
	private MonkeySurvival() {}
	static void arm(int minimum)
	{
		int[] rings = Jewellery.DUELING_RING.ids;
		Item ring = Inventory.get(item -> Arrays.stream(rings).anyMatch(id -> item.getId() == id));
		WorkflowScript.require(ring != null,"An escape ring must be carried before hazardous travel");
		Safety.guard(minimum,Safety.lobster(),true,Map.of("type","inventory_dialogue","item_id",ring.getId(),
			"alternative_item_ids",Arrays.stream(rings).boxed().collect(java.util.stream.Collectors.toList()),
			"action","Rub","choice","Castle Wars Arena","x",2440,"y",3089,"plane",0,"within",10));
	}
	static void behavior(boolean retaliate)
	{
		Safety.behaviors(retaliate,!Inventory.contains(4033),false);
	}
	static void protection(String style, boolean enabled, int minimum)
	{
		if (enabled) restore(minimum);
		WorkflowScript.require(SnapshotData.action("prayer.set",Map.of("prayer","protect_from_"+style,"enabled",enabled)),"Protection prayer failed: " + style);
	}
	static void restore(int minimum)
	{
		for (int dose = 0; dose < 4 && Skills.getBoostedLevel(Skill.PRAYER) < minimum; dose++)
		{
			Item potion = Inventory.get(item -> Arrays.stream(PRAYER).anyMatch(id -> item.getId() == id));
			WorkflowScript.require(potion != null,"Prayer restoration is unavailable");
			int before = Skills.getBoostedLevel(Skill.PRAYER);
			WorkflowScript.require(potion.interact("Drink"),"Prayer potion interaction failed");
			WorkflowScript.awaitTicks(() -> Skills.getBoostedLevel(Skill.PRAYER) > before,6,"Prayer restoration was not observed");
		}
		WorkflowScript.require(Skills.getBoostedLevel(Skill.PRAYER) >= minimum,"Prayer reserve was not restored");
	}
	static void maintain()
	{
		WorkflowScript.require(SnapshotData.action("consumable.cure_poison",Map.of()),"Poison could not be cured");
		if (PlayerSettings.getBitValue(25) > 0 || Walking.getRunEnergy() >= 60) return;
		Item potion = Inventory.get(item -> Arrays.stream(STAMINA).anyMatch(id -> item.getId() == id));
		WorkflowScript.require(potion != null && potion.interact("Drink"),"Stamina potion is unavailable");
		WorkflowScript.awaitTicks(() -> PlayerSettings.getBitValue(25) > 0,6,"Stamina effect was not observed");
	}
	static void route(Journey journey, String prayer)
	{
		Map<String,Object> receipt = traverse(() -> journey, prayer, false);
		WorkflowScript.require("arrived".equals(receipt.get("status")), "Monkey Madness journey failed: " + receipt);
		WorkflowScript.require(!MonkeyAreas.prison(), "Monkey Madness journey ended in prison");
	}

	static Map<String,Object> traverse(Supplier<Journey> journey, String prayer, boolean dungeon)
	{
		behavior(false);
		Automation.activity("hazardous_travel",WorkflowScript.NO_DISCRETIONARY);
		String continuation = null;
		for (int attempt = 0; attempt < 24; attempt++)
		{
			if (dungeon && Inventory.count(379) <= 3)
			{
				Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
				throw new IllegalStateException("Dungeon food reserve reached; resupply is required");
			}
			maintain();
			if (prayer != null) protection(prayer,true,12);
			Map<String,Object> moved = Navigation.walk(journey.get(), interrupts(prayer,dungeon), continuation);
			String status = String.valueOf(moved.get("status"));
			String reason = String.valueOf(moved.get("reason"));
			boolean upkeep = List.of("poisoned","inventory_below","skill_below","varbit_equals","run_energy_below").contains(reason);
			if (!(status.equals("unavailable") || status.equals("interrupted") && upkeep) || moved.get("continuation") == null) return moved;
			continuation = (String)moved.get("continuation");
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Journey upkeep limit reached");
	}

	static Map<String,Object> interrupts(String prayer, boolean dungeon)
	{
		Map<String,Object> result = new LinkedHashMap<>();
		result.put("poisoned",true);
		List<Map<String,Integer>> bits = new ArrayList<>();
		if (PlayerSettings.getBitValue(25) > 0) bits.add(Map.of("id",25,"value",0));
		else result.put("run_energy_below",60);
		if (prayer != null)
		{
			result.put("skill_below",Map.of("prayer",12));
			int bit = prayer.equals("melee") ? 4118 : prayer.equals("missiles") ? 4117 : 4116;
			bits.add(Map.of("id",bit,"value",0));
		}
		result.put("varbit_equals",bits);
		if (dungeon) result.put("inventory_below",List.of(Map.of("id",379,"quantity",4)));
		else result.put("area",Map.of("name","prison","bounds",MonkeyAreas.PRISON_BOUNDS));
		return result;
	}
}
