package com.genericclient.scripts.tools;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;

@ScriptManifest(name="Walk Stress",author="GenericClient",category=Category.UTILITY,version=1,
	description="Perform three nearby walk interactions and report completion.")
@ScriptSettings(id="walk-stress")
public final class WalkStress extends WorkflowScript
{
	@Override protected Object runWorkflow()
	{
		Automation.activity("manual");
		for (int attempt = 0; attempt < 3; attempt++)
		{
			Automation.overlay(Map.of("State","Walking","Attempts",attempt + " / 3"));
			require(SnapshotData.action("walk.random",Map.of()),"Walk interaction failed");
			Sleep.sleepTicks(3);
		}
		return Map.of("status","complete","attempts",3);
	}
}
