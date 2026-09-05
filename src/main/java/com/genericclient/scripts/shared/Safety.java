package com.genericclient.scripts.shared;

import com.genericclient.script.ScriptScope;
import com.genericclient.script.SnapshotData;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;

public final class Safety
{
	private Safety() {}
	public static void configure(List<Map<String, Object>> food, Tile escape, int within, boolean protectionPrayer)
	{
		WorkflowScript.require(SnapshotData.action("client.behaviors.configure", Map.of(
			"auto_retaliate", false, "emergency_escape", true, "combat_prayer", protectionPrayer)), "Client behavior configuration failed");
		Map<String, Object> result = ScriptScope.current().execute("safety.configure", Map.of(
			"minimum_hitpoints", 1, "consumables", food, "continue_after_consumable", true,
			"escape", Map.of("x", escape.getX(), "y", escape.getY(), "plane", escape.getZ(), "within", within)), 10_000);
		WorkflowScript.require("complete".equals(result.get("status")), "Emergency guard configuration failed");
	}
	public static List<Map<String, Object>> wine()
	{
		return List.of(Map.of("id", 1993, "action", "Drink", "heal_amount", 11));
	}
}
