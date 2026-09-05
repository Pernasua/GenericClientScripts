package com.genericclient.scripts.tools;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.script.SnapshotData;
import java.util.Map;
import org.dreambot.api.Client;
import org.dreambot.api.script.AbstractScript;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;

@ScriptManifest(name="Account Auditor",author="GenericClient",category=Category.UTILITY,version=1,
	description="Inspect the account and refresh its report without changing it.")
@ScriptSettings(id="account-auditor",actions=@ScriptSettings.Button(id="refresh",label="Refresh"))
public final class AccountAuditor extends AbstractScript
{
	private boolean audited;
	@Override public int onLoop()
	{
		if (!Client.isLoggedIn()) return 600;
		Automation.activity("manual");
		if (!audited || "refresh".equals(Automation.nextAction()))
		{
			Map<?,?> account = SnapshotData.read("account");
			Map<?,?> cash = SnapshotData.map(account.get("cash"));
			Automation.overlay(Map.of("State","Audited","Known cash",String.valueOf(cash.get("known_total_value")),
				"Bank",String.valueOf(SnapshotData.map(account.get("bank")).get("state"))));
			log(account);
			Automation.finish(account);
			audited = true;
		}
		return 600;
	}
}
