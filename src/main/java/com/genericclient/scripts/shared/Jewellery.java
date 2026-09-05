package com.genericclient.scripts.shared;

import java.util.Arrays;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.map.Area;
import org.dreambot.api.wrappers.items.Item;

public final class Jewellery
{
	public enum Destination
	{
		BURTHORPE("Burthorpe",new Area(2860,3500,2920,3580),3853,3855,3857,3859,3861,3863,3865,3867),
		BARBARIAN_OUTPOST("Barbarian Outpost",new Area(2500,3550,2540,3600),3853,3855,3857,3859,3861,3863,3865,3867),
		CASTLE_WARS("Castle Wars Arena",new Area(2425,3075,2455,3105),2552,2554,2556,2558,2560,2562,2564,2566),
		EMIRS_ARENA("Emir's Arena",new Area(3290,3210,3340,3260),2552,2554,2556,2558,2560,2562,2564,2566),
		GRAND_EXCHANGE("Grand Exchange",new Area(3150,3465,3180,3505),11980,11982,11984,11986,11988);
		final String option;
		final Area arrival;
		final int[] ids;
		Destination(String option, Area arrival, int... ids) { this.option = option; this.arrival = arrival; this.ids = ids; }
	}
	private Jewellery() {}
	public static boolean carried(Destination destination)
	{
		return Inventory.contains(destination.ids) || Equipment.contains(destination.ids);
	}
	public static void teleport(Destination destination)
	{
		Item item = Inventory.get(candidate -> Arrays.stream(destination.ids).anyMatch(id -> id == candidate.getId()));
		if (item == null)
		{
			Item worn = Equipment.get(candidate -> Arrays.stream(destination.ids).anyMatch(id -> id == candidate.getId()));
			WorkflowScript.require(worn != null && worn.interact("Remove"),"Teleport jewellery is not available");
			WorkflowScript.await(() -> Inventory.contains(destination.ids),6000,"Teleport jewellery was not removed");
			item = Inventory.get(candidate -> Arrays.stream(destination.ids).anyMatch(id -> id == candidate.getId()));
		}
		WorkflowScript.require(item.interact("Rub"),"Teleport jewellery could not be rubbed");
		WorkflowScript.await(() -> Dialogues.getOptions().length > 0,12000,"Teleport choices did not open");
		String choice = Arrays.stream(Dialogues.getOptions()).filter(option -> option.equals(destination.option) ||
			option.equals(destination.option+".")).findFirst().orElse(null);
		WorkflowScript.require(choice != null && Dialogues.chooseOption(choice),"Teleport destination was not offered: " + destination.option);
		WorkflowScript.await(() -> destination.arrival.contains(WorkflowScript.player()),12000,"Teleport arrival was not observed");
	}
}
