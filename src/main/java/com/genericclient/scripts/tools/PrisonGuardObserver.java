package com.genericclient.scripts.tools;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.dreambot.api.Client;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.script.AbstractScript;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.wrappers.interactive.NPC;

@ScriptManifest(name="Prison Guard Observer",author="GenericClient",category=Category.UTILITY,version=1,
	description="Observe and highlight Trefaji and Aberab without issuing input.")
@ScriptSettings(id="prison-guard-observer")
public final class PrisonGuardObserver extends AbstractScript
{
	private Map<String,Object> previous;
	@Override public int onLoop()
	{
		if (!Client.isLoggedIn()) return 600;
		Automation.activity("manual");
		Map<String,String> rows = new LinkedHashMap<>();
		for (int id : new int[]{5247,5248})
		{
			NPC npc = NPCs.closest(id);
			rows.put(id == 5247 ? "Trefaji" : "Aberab",npc == null ? "Out of view" : npc.getTile().toString());
		}
		rows.put("Player",com.genericclient.scripts.shared.WorkflowScript.player().getTile().toString());
		Automation.overlay(rows);
		Automation.markers(List.of(Map.of("npc_id",5247,"label","Trefaji","color","#ffb347"),
			Map.of("npc_id",5248,"label","Aberab","color","#57d7ff")));
		Map<String,Object> observation = Map.of("guards",rows,
			"player",com.genericclient.script.SnapshotData.read("player"),
			"dialogue",com.genericclient.script.SnapshotData.read("dialogue"));
		if (!observation.equals(previous)) { log(observation); previous = observation; }
		return 600;
	}
}
