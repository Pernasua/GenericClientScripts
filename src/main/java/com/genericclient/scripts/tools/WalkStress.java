package com.genericclient.scripts.tools;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.script.ScriptScope;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.LinkedHashMap;
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
		Automation.phase("diagnostics.walk-stress",Map.of("policy",NO_DISCRETIONARY));
		for (int attempt = 0; attempt < 3; attempt++)
		{
			Automation.overlay(Map.of("State","Walking","Attempts",attempt + " / 3"));
			Map<String,Object> receipt = new LinkedHashMap<>(ScriptScope.current().execute("walk.random",Map.of(),4_800));
			receipt.put("attempt",attempt + 1);
			log(receipt);
			Sleep.sleepTicks(3);
		}
		Automation.overlay(Map.of("State","Complete","Attempts","3 / 3"));
		return Map.of("status","complete","attempts",3);
	}
}
