package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.training.MagicTrainer;
import com.genericclient.scripts.training.PrayerTrainer;
import java.util.Map;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.junit.Test;

public class TrainingContractsTest
{
	@Test public void prayerReopensTheBankInsideTheNextWithdrawalBoundary()
	{
		CatalogEnvironment account = prayer(48_000);
		account.bank.put(536,50);
		account.run();
		assertEquals(50_376,(int)account.experience.get(Skill.PRAYER));
		assertEquals(java.util.List.of("prayer.withdraw_bones"),account.intents.actions.get("npc.interact"));
		assertEquals(java.util.List.of("prayer.withdraw_bones","prayer.withdraw_bones"),account.intents.actions.get("bank.loadout"));
		assertTrue(account.intents.actions.get("item.interact").stream().allMatch(java.util.Objects::isNull));
		assertEquals(java.util.List.of("bank.open","prayer.withdraw_bones","prayer.withdraw_bones"),account.intents.entries);
		assertNull(account.intents.current);
	}

	@Test public void prayerStopsAfterTheBoneThatReachesItsTarget()
	{
		CatalogEnvironment account = prayer(50_300);
		account.bank.put(536,20);
		account.run();
		assertEquals(50_372,(int)account.experience.get(Skill.PRAYER));
		assertEquals(19,(int)account.bank.get(536));
		assertEquals("complete",((Map<?,?>)account.result).get("status"));
		assertEquals(1L,account.actions.stream().filter("item.interact"::equals).count());
		assertEquals(java.util.List.of("prayer.withdraw_bones"),account.intents.actions.get("bank.loadout"));
		assertEquals(java.util.Collections.singletonList(null),account.intents.actions.get("item.interact"));
		assertNull(account.intents.current);
	}

	@Test public void prayerCooperativeStopWaitsForConsumptionAndXp()
	{
		CatalogEnvironment account = prayer(49_500);
		account.bank.put(536,30);
		account.buttons.add("stop_after_bone");
		account.run();
		assertEquals(49_572,(int)account.experience.get(Skill.PRAYER));
		assertEquals("stopped",((Map<?,?>)account.result).get("status"));
		assertEquals(1,((Map<?,?>)account.result).get("bones_buried"));
	}

	@Test public void purchaseBudgetCannotConsumeTheCashReserve()
	{
		CatalogEnvironment account = new CatalogEnvironment(new PrayerTrainer(), Map.of("target_level","43","restock","ge"));
		account.experience.put(Skill.PRAYER,50_300);
		account.bank.put(995,5_000_100);
		try { account.run(); fail("Reserve was not enforced"); }
		catch (IllegalStateException expected) { assertTrue(expected.getMessage().contains("cash reserve")); }
		assertTrue(account.actions.isEmpty());
		assertEquals(5_000_100,(int)account.bank.get(995));
	}

	@Test public void magicUsesLowAlchemyWhenSmithingDoesNotPermitIronSuperheat()
	{
		CatalogEnvironment account = magic(1);
		account.bank.put(890,2);
		account.run();
		assertEquals("low_alchemy",account.lastSpell);
		assertEquals(101_362,(int)account.experience.get(Skill.MAGIC));
		assertEquals(2L,account.actions.stream().filter("spell.cast_on_item"::equals).count());
		assertEquals("complete",((Map<?,?>)account.result).get("status"));
	}

	@Test public void magicUsesSuperheatOnlyAfterItsSmithingRequirement()
	{
		CatalogEnvironment account = magic(15);
		account.bank.put(440,1);
		account.run();
		assertEquals("superheat_item",account.lastSpell);
		assertEquals(101_353,(int)account.experience.get(Skill.MAGIC));
		assertEquals(1,(int)account.inventory.get(2351));
		assertEquals(1L,account.actions.stream().filter("spell.cast_on_item"::equals).count());
		assertEquals(java.util.List.of("magic.load_superheat_batch"),account.intents.actions.get("bank.loadout"));
		assertEquals(java.util.Collections.singletonList(null),account.intents.actions.get("spell.cast_on_item"));
		assertNull(account.intents.current);
	}

	private CatalogEnvironment prayer(int experience)
	{
		CatalogEnvironment account = new CatalogEnvironment(new PrayerTrainer(), Map.of("target_level","43","restock","bank_only"));
		account.experience.put(Skill.PRAYER,experience);
		return account;
	}
	private CatalogEnvironment magic(int smithing)
	{
		CatalogEnvironment account = new CatalogEnvironment(new MagicTrainer(), Map.of("target_level","50","restock","bank_only","method","auto"));
		account.experience.put(Skill.MAGIC,101_300);
		account.experience.put(Skill.SMITHING,Skills.getExperienceForLevel(smithing));
		account.bank.put(1387,1); account.bank.put(561,2);
		return account;
	}
}
