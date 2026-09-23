package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.training.MagicTrainer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.junit.Test;

public class MagicCombatContractsTest
{
	@Test public void cooperativeStopWaitsForTheActiveCastsXpBeforeDisengaging()
	{
		CombatScenario account = new CombatScenario(100);
		account.stopAfterAttack = true;
		account.run();
		assertEquals("stopped", ((Map<?,?>) account.result).get("status"));
		assertEquals(12, ((Map<?,?>) account.result).get("gained_xp"));
		assertEquals(12, account.xpAtDisengage);
		assertEquals(1, account.attackedIndexes.size());
	}

	@Test public void waitsForDelayedCombatEngagementWithoutRestartingTheAttack()
	{
		CombatScenario account = new CombatScenario(10);
		account.engageDelay = 3;
		account.castDelay = 4;
		account.run();
		assertEquals("complete", ((Map<?,?>) account.result).get("status"));
		assertEquals(13, ((Map<?,?>) account.result).get("final_level"));
		assertEquals(12, account.xpAtDisengage);
		assertEquals(1, account.attackedIndexes.size());
	}

	@Test public void aStopDuringAutocastingWaitsForXpAfterTheRequest()
	{
		CombatScenario account = new CombatScenario(100);
		account.stopDelay = 6;
		account.secondCastDelay = 8;
		account.run();
		assertEquals("stopped", ((Map<?,?>) account.result).get("status"));
		assertEquals(24, ((Map<?,?>) account.result).get("gained_xp"));
		assertEquals(24, account.xpAtDisengage);
		assertEquals(1, account.attackedIndexes.size());
	}

	@Test public void anActiveCastGetsItsFullObservationWindowBeforeRetrying()
	{
		CombatScenario account = new CombatScenario(10);
		account.castDelay = 6;
		account.run();
		assertEquals("complete", ((Map<?,?>) account.result).get("status"));
		assertEquals(1, account.attackedIndexes.size());
	}

	@Test public void aQueuedStopDoesNotStartANewCombatCast()
	{
		CombatScenario account = new CombatScenario(100);
		account.buttons.add("stop_after_cast");
		account.run();
		assertEquals("stopped", ((Map<?,?>) account.result).get("status"));
		assertEquals(0, ((Map<?,?>) account.result).get("gained_xp"));
		assertTrue(account.attackedIndexes.isEmpty());
	}

	@Test public void disengagesBeforeReportingRepeatedUnconfirmedCasts()
	{
		CombatScenario account = new CombatScenario(100);
		account.castDelay = 20;
		try { account.run(); fail("Unconfirmed casting must stop"); }
		catch (IllegalStateException expected) { assertEquals("Combat casts did not produce Magic XP", expected.getMessage()); }
		assertEquals(0, account.xpAtDisengage);
		assertNull(((Map<?,?>) account.read("player",Map.of())).get("interacting"));
		assertEquals(5, account.attackedIndexes.size());
	}

	@Test public void aFailedDisengageWalkDoesNotHideTheTrainingFailure()
	{
		CombatScenario account = new CombatScenario(100);
		account.castDelay = 20;
		account.disengageFails = true;
		try { account.run(); fail("Unconfirmed casting must stop"); }
		catch (IllegalStateException expected)
		{
			assertEquals("Combat casts did not produce Magic XP", expected.getMessage());
			assertEquals(1, expected.getSuppressed().length);
			assertTrue(expected.getSuppressed()[0].getMessage().startsWith("Travel did not reach"));
		}
	}

	@Test public void manualCancellationPreventsFurtherScriptInput()
	{
		CombatScenario account = new CombatScenario(100);
		account.cancelDelay = 2;
		try { account.run(); fail("Manual cancellation must end the workflow"); }
		catch (java.util.concurrent.CancellationException expected) { }
		assertEquals(1, account.attackedIndexes.size());
		assertEquals(-1, account.xpAtDisengage);
		assertNull(account.result);
	}

	@Test public void theFinalAllowedAttackRetryCanStillCompleteTraining()
	{
		CombatScenario account = new CombatScenario(10);
		account.rejectAttacks = 4;
		account.run();
		assertEquals("complete", ((Map<?,?>) account.result).get("status"));
		assertEquals(5, account.attackedIndexes.size());
		assertEquals(12, account.xpAtDisengage);
	}

	@Test public void skipsCloserTargetsThatAreDeadClaimedObstructedOrNotEligible()
	{
		for (Map<String,Object> excluded : List.of(Map.<String,Object>of("dead",true),
			Map.<String,Object>of("interacting","Other player"), Map.<String,Object>of("line_of_sight",false),
			Map.<String,Object>of("name","Banker","id",1633)))
		{
			CombatScenario account = new CombatScenario(10);
			Map<String,Object> nearer = new LinkedHashMap<>(account.npcs.get(0));
			nearer.putAll(excluded);
			nearer.put("identity",4L); nearer.put("index",1);
			nearer.put("world",Map.of("x",3012,"y",3189,"plane",0));
			account.npcs = List.of(nearer,account.npcs.get(0));
			account.run();
			assertEquals("complete", ((Map<?,?>) account.result).get("status"));
			assertEquals(List.of(2), account.attackedIndexes);
		}
	}

	@Test public void waitsForAnEligibleTargetToAppear()
	{
		CombatScenario account = new CombatScenario(10);
		account.targetAvailableTick = 5;
		account.run();
		assertEquals("complete", ((Map<?,?>) account.result).get("status"));
		assertEquals(List.of(2), account.attackedIndexes);
		assertEquals(12, account.xpAtDisengage);
	}

	@Test public void aStopWhileWaitingForATargetDoesNotAttackWhenItAppears()
	{
		CombatScenario account = new CombatScenario(100);
		account.targetAvailableTick = 5;
		account.stopAtTick = 2;
		account.run();
		assertEquals("stopped", ((Map<?,?>) account.result).get("status"));
		assertEquals(0, account.xpAtDisengage);
		assertTrue(account.attackedIndexes.isEmpty());
	}

	@Test public void reportsAnAbsentTargetWithoutSendingBlindAttacks()
	{
		CombatScenario account = new CombatScenario(10);
		account.npcs = List.of();
		try { account.run(); fail("The target wait must be bounded"); }
		catch (IllegalStateException expected) { assertEquals("No eligible combat target appeared", expected.getMessage()); }
		assertTrue(account.attackedIndexes.isEmpty());
		assertEquals(0, account.xpAtDisengage);
	}

	private static final class CombatScenario extends CatalogEnvironment
	{
		private final int initialXp;
		private Map<?,?> position = Map.of("x",3165,"y",3491,"plane",0);
		private long attackTick = -1;
		private boolean stopAfterAttack;
		private int engageDelay;
		private int castDelay = 3;
		private int secondCastDelay = -1;
		private int stopDelay = -1;
		private long stopAtTick = -1;
		private int cancelDelay = -1;
		private int rejectAttacks;
		private boolean disengageFails;
		private final List<Integer> attackedIndexes = new ArrayList<>();
		private long targetAvailableTick;
		private List<Map<String,Object>> npcs = List.of(Map.of("identity",3L,"id",266,"index",2,"name","Pirate",
			"world",Map.of("x",3013,"y",3189,"plane",0),"actions",List.of("Attack"),"line_of_sight",true));
		private int xpAtDisengage = -1;

		CombatScenario(int remainingXp)
		{
			super(new MagicTrainer(), Map.of("target_level","13","method","port_sarim_jail","restock","bank_only"));
			initialXp = Skills.getExperienceForLevel(13) - remainingXp;
			experience.put(Skill.MAGIC, initialXp);
			bank.put(1381,1); bank.put(1993,6); bank.put(558,100); bank.put(557,200);
		}

		@Override public Object read(String subject, Map<String,Object> query)
		{
			if (subject.equals("player"))
			{
				Map<String,Object> player = new LinkedHashMap<>();
				((Map<?,?>) super.read(subject,query)).forEach((key,value) -> player.put((String) key,value));
				player.put("world",position);
				player.put("interacting",attackTick >= 0 && tick() - attackTick >= engageDelay ? "Pirate" : null);
				return player;
			}
			if (subject.equals("dialogue")) return Map.of("open",false,"type","closed");
			if (subject.equals("npcs")) return tick() >= targetAvailableTick ? npcs : List.of();
			return super.read(subject,query);
		}

		@Override public Map<String,Object> execute(String type, Map<String,Object> arguments, long timeout)
		{
			checkpoint();
			if (type.equals("client.behaviors.configure") || type.equals("combat.set_autocast")) return Map.of("status","set");
			if (type.equals("safety.configure")) return Map.of("status","complete");
			if (type.equals("walk.to"))
			{
				Map<?,?> destination = (Map<?,?>) arguments.get("destination");
				boolean disengage = destination.get("x").equals(3012) && destination.get("y").equals(3190);
				if (disengage && disengageFails) return Map.of("status","failed");
				position = destination;
				if (disengage)
				{
					xpAtDisengage = experience.get(Skill.MAGIC) - initialXp;
					attackTick = -1;
				}
				return Map.of("status","arrived");
			}
			if (type.equals("npc.interact") && arguments.get("action").equals("Attack"))
			{
				attackedIndexes.add(((Number) arguments.get("index")).intValue());
				if (rejectAttacks > 0)
				{
					rejectAttacks--;
					return Map.of("status","rejected");
				}
				attackTick = tick();
				if (stopAfterAttack) buttons.add("stop_after_cast");
				return Map.of("status","dispatched");
			}
			return super.execute(type,arguments,timeout);
		}

		@Override public long activeTimeNanos() { return tick()*600_000_000L; }

		@Override public void sleep(long millis)
		{
			super.sleep(millis);
			if (tick() == stopAtTick) buttons.add("stop_after_cast");
			long elapsed = tick() - attackTick;
			if (attackTick >= 0 && (elapsed == castDelay || elapsed == secondCastDelay)) experience.merge(Skill.MAGIC,12,Integer::sum);
			if (attackTick >= 0 && elapsed == stopDelay) buttons.add("stop_after_cast");
			if (attackTick >= 0 && tick() - attackTick == cancelDelay) stop();
		}
	}
}
