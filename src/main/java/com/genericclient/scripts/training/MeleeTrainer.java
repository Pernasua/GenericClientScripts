package com.genericclient.scripts.training;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Progress;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.NPC;

@ScriptManifest(name="AIO Melee Trainer",author="GenericClient",category=Category.COMBAT,version=1,
	description="Train Attack, Strength, or Defence on Lumbridge goblins through level 30.")
@ScriptSettings(id="aio-melee",inputs={
	@ScriptSettings.Input(id="skill",label="Skill",choices={"attack","strength","defence"},labels={"Attack","Strength","Defence"},defaultValue="attack"),
	@ScriptSettings.Input(id="target_level",label="Target level",choices={"2","5","10","20","30"},defaultValue="2"),
	@ScriptSettings.Input(id="method",label="Method",choices={"auto","lumbridge_goblins"},labels={"Auto","Lumbridge goblins"},defaultValue="auto")
},actions=@ScriptSettings.Button(id="stop_after_kill",label="Stop after kill"))
public final class MeleeTrainer extends WorkflowScript
{
	@Override protected Object runWorkflow()
	{
		Skill skill = Skill.valueOf(Automation.input("skill").toUpperCase(java.util.Locale.ROOT));
		int target = Integer.parseInt(Automation.input("target_level"));
		int targetXp = Skills.getExperienceForLevel(target);
		int initialXp = Skills.getExperience(skill);
		if (initialXp >= targetXp) return result("already_complete", skill, initialXp);
		require(SnapshotData.action("client.behaviors.configure", Map.of("auto_retaliate", false, "emergency_escape", true)),
			"Combat behavior configuration failed");
		int style = skill == Skill.ATTACK ? 0 : skill == Skill.STRENGTH ? 1 : 3;
		require(SnapshotData.action("combat.set_style", Map.of("style", style)), "Combat style was not set");
		Travel.to(new Tile(3245,3245), 8);
		Automation.activity("combat",Map.of("breaks",true));
		boolean stop = false;
		String outcome = "complete";
		int targetAttempts = 0;
		while (Skills.getExperience(skill) < targetXp)
		{
			if (Skills.getBoostedLevel(Skill.HITPOINTS) <= 4) { outcome = "low_hitpoints"; break; }
			stop |= "stop_after_kill".equals(Automation.nextAction());
			if (stop) { outcome = "stopped"; break; }
			Progress.training(skill, target, "Finding target");
			NPC goblin = NPCs.closest(npc -> npc.getName().equals("Goblin") && !npc.isInCombat() && npc.distance() <= 15);
			if (goblin == null || !goblin.interact("Attack"))
			{
				require(++targetAttempts <= 30,"No eligible goblin became available");
				Sleep.sleepTicks(1);
				continue;
			}
			targetAttempts = 0;
			stop = waitForKill(skill,target,targetXp);
		}
		Travel.to(new Tile(3222,3218), 4);
		return result(outcome, skill, initialXp);
	}

	private boolean waitForKill(Skill skill, int target, int targetXp)
	{
		boolean stop = false;
		Sleep.sleepTicks(2);
		int idleTicks = 0;
		while (idleTicks < 2 && Skills.getExperience(skill) < targetXp)
		{
			Sleep.sleepTicks(1);
			Progress.training(skill, target, "In combat");
			stop |= "stop_after_kill".equals(Automation.nextAction());
			if (Skills.getBoostedLevel(Skill.HITPOINTS) <= 4) break;
			idleTicks = com.genericclient.scripts.shared.WorkflowScript.player().isInCombat() ? 0 : idleTicks + 1;
		}
		return stop;
	}

	private Map<String, Object> result(String status, Skill skill, int initialXp)
	{
		return Map.of("status", status, "skill", skill.name().toLowerCase(java.util.Locale.ROOT),
			"final_level", Skills.getRealLevel(skill), "final_xp", Skills.getExperience(skill),
			"gained_xp", Skills.getExperience(skill) - initialXp);
	}
}
