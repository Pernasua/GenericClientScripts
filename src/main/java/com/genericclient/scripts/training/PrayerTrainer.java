package com.genericclient.scripts.training;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Supply;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.wrappers.items.Item;

@ScriptManifest(name="AIO Prayer Trainer", author="GenericClient", category=Category.PRAYER, version=1,
	description="Train Prayer to a target with verified bone consumption and bank trips.")
@ScriptSettings(id="aio-prayer", inputs={
	@ScriptSettings.Input(id="target_level", label="Target level", choices={"43","70","77"}, defaultValue="43"),
	@ScriptSettings.Input(id="restock", label="Restock", choices={"ge","bank_only"}, labels={"Grand Exchange","Bank only"}, defaultValue="ge")
}, actions=@ScriptSettings.Button(id="stop_after_bone", label="Stop after bone"))
public final class PrayerTrainer extends WorkflowScript
{
	private static final int DRAGON_BONES = 536;
	@Override protected Object runWorkflow()
	{
		int target = Integer.parseInt(Automation.input("target_level"));
		int targetXp = Skills.getExperienceForLevel(target);
		int initialXp = Skills.getExperience(Skill.PRAYER);
		if (initialXp >= targetXp) return result("already_complete", 0);
		Travel.to(Travel.GRAND_EXCHANGE, 8);
		int required = (int) Math.ceil((targetXp - initialXp) / 72.0);
		Supplies.ensure(List.of(new Supply(DRAGON_BONES, "Dragon bones", required, 5000)), Automation.input("restock").equals("ge"));
		int buried = 0;
		while (Skills.getExperience(Skill.PRAYER) < targetXp)
		{
			int remaining = (int) Math.ceil((targetXp - Skills.getExperience(Skill.PRAYER)) / 72.0);
			Automation.intent("prayer.withdraw_bones", () ->
			{
				Supplies.loadout(Map.of(DRAGON_BONES, Math.min(27, remaining)), 1);
				return null;
			});
			Automation.activity("skilling");
			Automation.phase("prayer.burying");
			while (Inventory.contains(DRAGON_BONES) && Skills.getExperience(Skill.PRAYER) < targetXp)
			{
				boolean stop = "stop_after_bone".equals(Automation.nextAction());
				int beforeXp = Skills.getExperience(Skill.PRAYER);
				int beforeCount = Inventory.count(DRAGON_BONES);
				Item bone = Inventory.get(DRAGON_BONES);
				require(bone.interact("Bury"), "Bone interaction failed");
				await(() -> Skills.getExperience(Skill.PRAYER) > beforeXp && Inventory.count(DRAGON_BONES) < beforeCount,
					6000, "Bone consumption and Prayer XP were not observed");
				buried++;
				if (stop) return result("stopped", buried);
			}
		}
		return result("complete", buried);
	}

	private Map<String, Object> result(String status, int buried)
	{
		return Map.of("status", status, "final_level", Skills.getRealLevel(Skill.PRAYER),
			"final_xp", Skills.getExperience(Skill.PRAYER), "bones_buried", buried);
	}
}
