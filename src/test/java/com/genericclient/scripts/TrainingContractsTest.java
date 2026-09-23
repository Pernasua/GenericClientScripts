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
	@Test public void prayerReturnsToTheBankUntilItReachesItsTarget()
	{
		CatalogEnvironment account = prayer(48_000);
		account.bank.put(536,50);
		account.run();
		assertEquals(50_376,(int)account.experience.get(Skill.PRAYER));
		assertEquals(2L,account.actions.stream().filter("bank.loadout"::equals).count());
	}

	@Test public void prayerStopsAfterTheBoneThatReachesItsTarget()
	{
		CatalogEnvironment account = prayer(50_300);
		account.bank.put(536,20);
		account.run();
		assertEquals(19,(int)account.bank.get(536));
		assertEquals("complete",((Map<?,?>)account.result).get("status"));
		assertEquals(1L,account.actions.stream().filter("item.interact"::equals).count());
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
		CatalogEnvironment account = magic(1,false);
		account.bank.put(890,2);
		account.run();
		assertEquals("low_alchemy",account.lastSpell);
		assertEquals(2L,account.actions.stream().filter("spell.cast_on_item"::equals).count());
		assertEquals("complete",((Map<?,?>)account.result).get("status"));
	}

	@Test public void magicUsesSuperheatOnlyAfterItsSmithingRequirement()
	{
		CatalogEnvironment account = magic(15,false);
		account.bank.put(440,1);
		account.run();
		assertEquals("superheat_item",account.lastSpell);
		assertEquals(1,(int)account.inventory.get(2351));
		assertEquals(1L,account.actions.stream().filter("spell.cast_on_item"::equals).count());
	}

	@Test public void magicBankTrainingStopsAfterTheCastConsumesItsMaterialAndAwardsXp()
	{
		for (int smithing : new int[]{1,15})
		{
			boolean superheat = smithing == 15;
			int material = superheat ? 440 : 890;
			CatalogEnvironment account = magic(smithing,true);
			account.experience.put(Skill.MAGIC,101_200);
			account.bank.put(561,5); account.bank.put(material,5);
			account.run();
			assertEquals("stopped",((Map<?,?>)account.result).get("status"));
			assertEquals(superheat ? 53 : 31,((Map<?,?>)account.result).get("gained_xp"));
			assertEquals(superheat ? 2 : 4,(int)account.inventory.get(material));
			assertEquals(1L,account.actions.stream().filter("spell.cast_on_item"::equals).count());
		}
	}

	@Test public void magicBankTrainingDoesNotStartAnotherCastAfterAQueuedStop()
	{
		for (int smithing : new int[]{1,15})
		{
			CatalogEnvironment account = magic(smithing,false);
			account.experience.put(Skill.MAGIC,101_200);
			account.bank.put(561,5); account.bank.put(smithing == 15 ? 440 : 890,5);
			account.buttons.add("stop_after_cast");
			account.run();
			assertEquals("stopped",((Map<?,?>)account.result).get("status"));
			assertEquals(0,((Map<?,?>)account.result).get("gained_xp"));
			assertFalse(account.actions.contains("spell.cast_on_item"));
		}
	}

	private CatalogEnvironment prayer(int experience)
	{
		CatalogEnvironment account = new CatalogEnvironment(new PrayerTrainer(), Map.of("target_level","43","restock","bank_only"));
		account.experience.put(Skill.PRAYER,experience);
		return account;
	}
	private CatalogEnvironment magic(int smithing, boolean stopDuringCast)
	{
		CatalogEnvironment account = new CatalogEnvironment(new MagicTrainer(), Map.of("target_level","50","restock","bank_only","method","auto"))
		{
			@Override public Map<String,Object> execute(String action, Map<String,Object> arguments, long timeout)
			{
				Map<String,Object> receipt = super.execute(action,arguments,timeout);
				if (stopDuringCast && action.equals("spell.cast_on_item")) buttons.add("stop_after_cast");
				return receipt;
			}
		};
		account.experience.put(Skill.MAGIC,101_300);
		account.experience.put(Skill.SMITHING,Skills.getExperienceForLevel(smithing));
		account.bank.put(1387,1); account.bank.put(561,2);
		return account;
	}
}
