package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.training.ThievingTrainer;
import java.util.Map;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.junit.Test;

public class ThievingContractsTest
{
	@Test public void selectsTheBakerNearestTheStallAndBanksTheObservedLoot()
	{
		BakeryScenario scene = new BakeryScenario();
		scene.run();
		assertEquals("complete", ((Map<?,?>) scene.result).get("status"));
		assertEquals(25, ((Map<?,?>) scene.result).get("final_level"));
		assertEquals(1, ((Map<?,?>) scene.result).get("steals"));
		assertEquals(1, (int) scene.bank.get(1891));
		assertTrue(scene.inventory.isEmpty());
		assertFalse(scene.bankOpen);
		assertEquals(Map.of("x",2653,"y",3283,"plane",0), scene.world);
	}

	private static final class BakeryScenario extends SceneScenario
	{
		private boolean bankOpen;
		private boolean guarded;

		BakeryScenario()
		{
			super(new ThievingTrainer());
			world = Map.of("x",2665,"y",3310,"plane",0);
			experience.put(Skill.THIEVING, Skills.getExperienceForLevel(25) - 16);
			object(11730,2668,3310,"Steal-from");
			npc(3297,"Baker",2669,3310,"Talk-to");
			npc(3298,"Baker",2664,3310,"Talk-to");
			npc(1633,"Banker",2653,3283,"Bank");
			input = this::interact;
		}

		@Override public Object read(String subject, Map<String,Object> query)
		{
			if (subject.equals("bank")) return Map.of("open",bankOpen);
			return super.read(subject,query);
		}

		private void interact(String type, Map<String,Object> args)
		{
			switch (type)
			{
				case "walk.to":
					Map<?,?> destination = (Map<?,?>) args.get("destination");
					world = Map.of("x",((Number)destination.get("x")).intValue(),
						"y",((Number)destination.get("y")).intValue(),"plane",0);
					break;
				case "client.behaviors.configure": receipt = Map.of("status","set"); break;
				case "safety.configure": guarded = true; receipt = Map.of("status","complete"); break;
				case "object.interact":
					assertTrue(guarded);
					assertEquals(Map.of("x",2669,"y",3310,"plane",0), world);
					nextTick = () -> { inventory.put(1891,1); experience.merge(Skill.THIEVING,16,Integer::sum); };
					break;
				case "npc.interact":
					assertEquals("Bank",args.get("action"));
					nextTick = () -> bankOpen = true;
					break;
				case "bank.deposit_inventory":
					inventory.forEach((id,count) -> bank.merge(id,count,Integer::sum));
					inventory.clear(); receipt = Map.of("status","complete");
					break;
				case "bank.close": bankOpen = false; receipt = Map.of("status","complete"); break;
				default: throw new AssertionError("Unexpected bakery input: " + type);
			}
		}
	}
}
