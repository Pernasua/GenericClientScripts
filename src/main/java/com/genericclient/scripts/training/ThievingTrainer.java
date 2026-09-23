package com.genericclient.scripts.training;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.Progress;
import com.genericclient.scripts.shared.Safety;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.bank.Bank;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

@ScriptManifest(name="AIO Thieving Trainer",author="GenericClient",category=Category.THIEVING,version=1,
	description="Train Thieving to level 25 at the Ardougne bakery and bank the loot.")
@ScriptSettings(id="aio-thieving",inputs={
	@ScriptSettings.Input(id="target_level",label="Target level",choices={"25"},defaultValue="25"),
	@ScriptSettings.Input(id="method",label="Method",choices={"auto","ardougne_bakery"},labels={"Auto","East Ardougne bakery"},defaultValue="auto")
},actions=@ScriptSettings.Button(id="stop_after_steal",label="Stop after steal"))
public final class ThievingTrainer extends WorkflowScript
{
	private static final Tile MARKET = new Tile(2668,3310);
	private static final Tile BANK = new Tile(2653,3283);
	private static final List<Map<String, Object>> FOOD = List.of(
		food(1891,4),food(1893,4),food(1895,4),food(1897,5),food(1899,5),food(1901,5),food(2309,5));
	@Override protected Object runWorkflow()
	{
		int target = Integer.parseInt(Automation.input("target_level"));
		int goal = Skills.getExperienceForLevel(target);
		require(Skills.getRealLevel(Skill.THIEVING) >= 5, "The bakery stall requires Thieving 5");
		if (Skills.getExperience(Skill.THIEVING) >= goal) return Map.of("status","already_complete");
		position();
		Safety.configure(FOOD, BANK, 7, false);
		int steals = 0;
		String outcome = "complete";
		while (Skills.getExperience(Skill.THIEVING) < goal)
		{
			if ("stop_after_steal".equals(Automation.nextAction())) { outcome = "stopped"; break; }
			if (Inventory.isFull()) { bankLoot(); position(); }
			Automation.activity("skilling");
			Conversations.finish();
			await(() -> stall() != null, 9600, "Bakery stall did not respawn");
			int beforeXp = Skills.getExperience(Skill.THIEVING);
			int beforeSlots = Inventory.emptySlotCount();
			Progress.training(Skill.THIEVING, target, "Stealing baked goods");
			require(stall().interact("Steal-from"), "Stall interaction failed");
			await(() -> Skills.getExperience(Skill.THIEVING) > beforeXp && Inventory.emptySlotCount() < beforeSlots,
				7200, "Thieving XP and stolen goods were not observed");
			steals++;
		}
		bankLoot();
		return Map.of("status",outcome,"final_level",Skills.getRealLevel(Skill.THIEVING),
			"final_xp",Skills.getExperience(Skill.THIEVING),"steals",steals);
	}

	private void position()
	{
		Travel.westernTraining(MARKET, 5);
		GameObject stall = GameObjects.closest(11730);
		require(stall != null, "Bakery stall was not observed");
		NPC baker = NPCs.closest(npc -> npc.getName().equals("Baker") && npc.distance(stall) <= 15, stall.getTile());
		require(baker != null, "Baker was not observed");
		Travel.to(baker.getTile(), 0);
		require(stall() != null, "Safe bakery position was not reached");
	}
	private GameObject stall() { return GameObjects.closest(object -> object.getId() == 11730 && object.distance() <= 4); }
	private void bankLoot()
	{
		Travel.to(BANK, 7);
		Supplies.openBank();
		require(Bank.depositAllItems() && Bank.close(), "Stolen goods were not banked");
	}
	private static Map<String, Object> food(int id, int healing) { return Map.of("id",id,"action","Eat","heal_amount",healing); }
}
