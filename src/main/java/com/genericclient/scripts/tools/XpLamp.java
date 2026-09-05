package com.genericclient.scripts.tools;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.Interfaces;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;

@ScriptManifest(name="XP Lamp",author="GenericClient",category=Category.UTILITY,version=1,description="Use one Genie lamp on a selected skill within the account's level caps.")
@ScriptSettings(id="xp-lamp",inputs=@ScriptSettings.Input(id="skill",label="Skill",
	choices={"prayer","thieving","slayer","firemaking","agility","herblore","ranged","magic","hitpoints","attack","strength","defence"},defaultValue="prayer"))
public final class XpLamp extends WorkflowScript
{
	private static final Map<Skill,Integer> WIDGETS = Map.ofEntries(
		Map.entry(Skill.ATTACK,15728642),Map.entry(Skill.STRENGTH,15728643),Map.entry(Skill.RANGED,15728644),
		Map.entry(Skill.MAGIC,15728645),Map.entry(Skill.DEFENCE,15728646),Map.entry(Skill.HITPOINTS,15728648),
		Map.entry(Skill.PRAYER,15728649),Map.entry(Skill.AGILITY,15728650),Map.entry(Skill.HERBLORE,15728651),
		Map.entry(Skill.THIEVING,15728652),Map.entry(Skill.SLAYER,15728655),Map.entry(Skill.FIREMAKING,15728661));
	@Override protected Object runWorkflow()
	{
		Skill skill = Skill.valueOf(Automation.input("skill").toUpperCase(java.util.Locale.ROOT));
		int cap = skill == Skill.ATTACK ? 80 : skill == Skill.DEFENCE ? 75 : skill == Skill.PRAYER ? 77 : 99;
		if (Skills.getRealLevel(skill) >= cap) return Map.of("status","hard_cap_reached","cap",cap);
		int beforeXp = Skills.getExperience(skill);
		int lamps = Inventory.count(2528);
		if (lamps == 0) return Map.of("status","lamp_not_carried");
		Automation.activity("general",WorkflowScript.NO_DISCRETIONARY);
		return Automation.intent("xp_lamp.use", () ->
		{
			require(Inventory.interact(2528,"Rub"),"Lamp interface did not open");
			int widget = WIDGETS.get(skill);
			await(() -> Interfaces.widget(widget) != null && Interfaces.widget(15728667) != null,12000,"Lamp choices did not appear");
			Interfaces.click(widget);
			Sleep.sleepTicks(1);
			Interfaces.click(15728667);
			await(() -> Skills.getExperience(skill) > beforeXp && Inventory.count(2528) < lamps,12000,"Lamp reward was not verified");
			return Map.of("status","complete","skill",skill.name(),"gained_xp",Skills.getExperience(skill)-beforeXp,
				"final_level",Skills.getRealLevel(skill),"lamps_after",Inventory.count(2528));		});

	}
}
