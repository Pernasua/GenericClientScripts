package com.genericclient.scripts.recovery;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptScope;
import com.genericclient.script.ScriptSettings;
import com.genericclient.script.SnapshotData;
import java.util.Map;
import org.dreambot.api.Client;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.script.AbstractScript;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.wrappers.items.Item;

@ScriptManifest(name="Safety Net",author="GenericClient",category=Category.UTILITY,version=1,
	description="Wait for manual control after a failure and retain emergency recovery during active combat.")
@ScriptSettings(id="safety-net")
public final class SafetyNet extends AbstractScript
{
	@Override public int onLoop()
	{
		if (!Client.isLoggedIn()) return 600;
		Automation.activity("manual");
		String name = com.genericclient.scripts.shared.WorkflowScript.player().getName();
		boolean attacked = SnapshotData.rows("npcs",Map.of("within",16,"limit",40)).stream()
			.anyMatch(npc -> name.equals(npc.get("interacting")));
		if (attacked && com.genericclient.scripts.shared.WorkflowScript.player().getHealthPercent() < 30)
		{
			Map<String,Object> result = ScriptScope.current().execute("safety.recover",Map.of(),60_000);
			String outcome = String.valueOf(result.get("result"));
			if (outcome.equals("emergency_escape_complete") || outcome.equals("emergency_food_and_escape_complete"))
			{
				Automation.finish(Map.of("status","complete","result","safety_net_active_combat_escape"));
				return -1;
			}
			// A configured guard owns the meal through its approved consumables, so the safety net eats only when no guard exists.
			if (outcome.equals("safety_net_not_configured"))
			{
				Item food = Inventory.get(item -> item.hasAction("Eat"));
				if (food != null) food.interact("Eat");
			}
		}
		Automation.overlay(Map.of("Safety Net","Awaiting manual control","HP",com.genericclient.scripts.shared.WorkflowScript.player().getHealthPercent() + "%"));
		return 600;
	}
}
