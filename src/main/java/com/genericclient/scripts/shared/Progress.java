package com.genericclient.scripts.shared;

import com.genericclient.script.Automation;
import java.util.LinkedHashMap;
import java.util.Map;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;

public final class Progress
{
	private Progress() {}
	public static void training(Skill skill, int target, String state)
	{
		Map<String, String> rows = new LinkedHashMap<>();
		rows.put("Level", Skills.getRealLevel(skill) + " / " + target);
		rows.put("XP", Integer.toString(Skills.getExperience(skill)));
		rows.put("State", state);
		Automation.overlay(rows);
	}
}
