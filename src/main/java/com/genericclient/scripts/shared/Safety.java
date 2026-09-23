package com.genericclient.scripts.shared;

import com.genericclient.script.SnapshotData;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;

public final class Safety
{
	private Safety() {}
	public static void configure(List<Map<String, Object>> food, Tile escape, int within, boolean protectionPrayer)
	{
		behaviors(false, true, protectionPrayer);
		guard(1, food, false, Map.of("x", escape.getX(), "y", escape.getY(), "plane", escape.getZ(), "within", within));
	}
	public static void behaviors(boolean retaliate, boolean escape, boolean protectionPrayer)
	{
		WorkflowScript.require(SnapshotData.action("client.behaviors.configure", Map.of(
			"auto_retaliate", retaliate, "emergency_escape", escape, "combat_prayer", protectionPrayer)), "Client behavior configuration failed");
	}
	public static void guard(int minimumHitpoints, List<Map<String, Object>> food, boolean allowOverheal, Map<String, Object> escape)
	{
		Map<String, Object> request = new HashMap<>(Map.of("minimum_hitpoints", minimumHitpoints, "consumables", food,
			"continue_after_consumable", true, "allow_overheal", allowOverheal));
		if (escape != null) request.put("escape", escape);
		WorkflowScript.require(SnapshotData.action("safety.configure", request), "Emergency guard configuration failed");
	}
	public static List<Map<String, Object>> wine()
	{
		return List.of(Map.of("id", 1993, "action", "Drink", "heal_amount", 11));
	}
	public static List<Map<String, Object>> lobster()
	{
		return List.of(Map.of("id", 379, "action", "Eat", "heal_amount", 12));
	}
}
