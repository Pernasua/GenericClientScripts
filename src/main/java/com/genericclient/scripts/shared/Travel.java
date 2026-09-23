package com.genericclient.scripts.shared;

import com.genericclient.script.Automation;
import com.genericclient.script.Navigation;
import org.dreambot.api.methods.map.Tile;

public final class Travel
{
	public static final Tile GRAND_EXCHANGE = new Tile(3165, 3491);
	private Travel() {}

	public static void to(Tile destination, int within)
	{
		to(destination,within,"travel");
	}

	public static void to(Tile destination, int within, String activity)
	{
		to(destination,within,activity,java.util.Map.of());
	}

	public static void to(Tile destination, int within, String activity, java.util.Map<String,Object> policy)
	{
		if (destination.distance() <= within) return;
		Automation.activity(activity,policy);
		if (!Navigation.walkTo(destination, within))
			throw new IllegalStateException("Travel did not reach " + destination);
	}

	public static void via(Tile... destinations)
	{
		Automation.activity("travel");
		Tile destination = destinations[destinations.length-1];
		Navigation.Journey journey = new Navigation.Journey(destination,2)
			.via(java.util.Arrays.copyOf(destinations,destinations.length-1));
		WorkflowScript.require("arrived".equals(Navigation.walk(journey,java.util.Map.of(),null).get("status")),"Travel did not reach " + destination);
	}

	public static void westernTraining(Tile destination, int within)
	{
		if (WorkflowScript.player().getTile().getX() >= 2860)
		{
			to(GRAND_EXCHANGE,8);
			java.util.List<Integer> worn = org.dreambot.api.methods.container.impl.equipment.Equipment.all().stream()
				.map(org.dreambot.api.wrappers.items.Item::getId).collect(java.util.stream.Collectors.toList());
			Supply ring = Jewellery.DUELING_RING;
			Supplies.ensure(java.util.List.of(ring,new Supply(1993,"Jug of wine",6,20)),true);
			java.util.Map<Integer,Integer> items = new java.util.LinkedHashMap<>();
			for (int id : worn) items.put(id,1);
			int chargedRing = java.util.Arrays.stream(ring.ids).filter(id -> Supplies.owned(id) > 0).findFirst().orElseThrow();
			items.put(chargedRing,1); items.put(1993,6);
			Supplies.loadout(items,0);
			for (int id : worn) Supplies.equip(id);
			Safety.configure(Safety.wine(),new Tile(2443,3083),5,true);
			Jewellery.teleport(Jewellery.Destination.CASTLE_WARS);
		}
		to(destination,within);
	}
}
