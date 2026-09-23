package com.genericclient.scripts.shared;

import com.genericclient.script.Automation;
import com.genericclient.script.Banking;
import com.genericclient.script.ScriptScope;
import com.genericclient.script.SnapshotData;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.bank.Bank;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.wrappers.interactive.NPC;
import org.dreambot.api.wrappers.items.Item;

public final class Supplies
{
	public static final long CASH_RESERVE = 5_000_000;
	private Supplies() {}

	public static void openBank()
	{
		Automation.activity("banking");
		Automation.intent("bank.open", () ->
		{
			WorkflowScript.require(Bank.open(), "Bank did not open");
			return null;
		});
	}

	public static void ensure(List<Supply> requested, boolean purchase)
	{
		openBank();
		List<Supply> missing = new ArrayList<>();
		for (Supply supply : requested)
		{
			int owned = java.util.Arrays.stream(supply.ids).map(Supplies::owned).sum();
			if (owned < supply.quantity)
			{
				WorkflowScript.require(purchase && supply.maximumPrice > 0, "Missing supply: " + supply.name);
				missing.add(new Supply(supply.id, supply.name, supply.quantity - owned, supply.maximumPrice));
			}
		}
		if (missing.isEmpty()) return;
		buy(missing);
		openBank();
		for (Supply supply : requested)
			WorkflowScript.require(java.util.Arrays.stream(supply.ids).map(Supplies::owned).sum() >= supply.quantity,
				"Supply purchase was not verified: " + supply.name);
	}

	public static int owned(int id)
	{
		return Bank.count(id) + Inventory.count(id) + Equipment.all().stream().filter(item -> item.getId() == id).mapToInt(Item::getAmount).sum();
	}

	public static void prepare(List<Supply> supplies, boolean purchase)
	{
		ensure(supplies,purchase);
		Map<Integer,Integer> loadout = new java.util.LinkedHashMap<>();
		for (Supply supply : supplies)
		{
			int remaining = supply.quantity;
			for (int id : supply.ids)
			{
				int quantity = Math.min(remaining,owned(id));
				if (quantity > 0) loadout.merge(id,quantity,Integer::sum);
				remaining -= quantity;
			}
			WorkflowScript.require(remaining == 0,"Missing prepared supply: " + supply.name);
		}
		loadout(loadout,0);
	}

	private static void buy(List<Supply> requested)
	{
		long maximumSpend = 0;
		for (Supply supply : requested) maximumSpend = Math.addExact(maximumSpend, Math.multiplyExact((long) supply.quantity, supply.maximumPrice));
		Map<?, ?> cash = SnapshotData.read("cash");
		WorkflowScript.require(Boolean.TRUE.equals(cash.get("complete")), "Cash state is incomplete");
		WorkflowScript.require(((Number) cash.get("known_total_value")).longValue() - maximumSpend >= CASH_RESERVE,
			"Purchases would breach the cash reserve");
		WorkflowScript.require(Banking.loadout(Map.of(995, Math.toIntExact(maximumSpend)), 27, true), "Coin withdrawal failed");
		Automation.activity("trading");
		NPC clerk = NPCs.closest("Grand Exchange Clerk");
		WorkflowScript.require(clerk != null && clerk.interact("Exchange"), "Grand Exchange interaction failed");
		WorkflowScript.await(org.dreambot.api.methods.grandexchange.GrandExchange::isOpen,6000,"Grand Exchange did not open");
		for (Supply supply : requested)
		{
			Map<String,Object> request = Map.of(
				"item_id", supply.id, "item_name", supply.name, "quantity", supply.quantity,
				"maximum_unit_price", supply.maximumPrice, "minimum_cash_reserve", CASH_RESERVE,
				"collect_mode", "bank");
			while (true)
			{
				Map<String,Object> receipt = ScriptScope.current().execute("ge.buy",request,240_000);
				if ("complete".equals(receipt.get("status"))) break;
				WorkflowScript.require("placed".equals(receipt.get("status")) && "ge_offer_pending".equals(receipt.get("result")),
					"Purchase failed: " + supply.name + " (" + receipt.get("status") + ": " + receipt.get("result") + ")");
			}
		}
		WorkflowScript.require(SnapshotData.action("ui.close", Map.of()), "Exchange did not close");
	}

	public static void loadout(Map<Integer, Integer> items, int freeSlots)
	{
		openBank();
		WorkflowScript.require(Banking.loadout(items, freeSlots, true), "Inventory preparation failed");
	}

	public static void equip(int id)
	{
		if (Equipment.contains(id)) return;
		Item item = Inventory.get(id);
		WorkflowScript.require(item != null, "Equipment is missing: " + id);
		String action = item.hasAction("Wield") ? "Wield" : item.hasAction("Wear") ? "Wear" : "Hold";
		WorkflowScript.require(item.interact(action), "Could not equip item " + id);
		WorkflowScript.await(() -> Equipment.contains(id), 6000, "Equipment change was not observed: " + id);
	}
}
