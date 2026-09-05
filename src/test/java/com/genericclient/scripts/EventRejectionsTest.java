package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.events.Certer;
import com.genericclient.scripts.events.CaptArnav;
import com.genericclient.scripts.events.CountCheck;
import com.genericclient.scripts.events.EvilBob;
import com.genericclient.scripts.events.Mime;
import com.genericclient.scripts.events.Molly;
import com.genericclient.scripts.events.Pinball;
import com.genericclient.scripts.events.PrisonPete;
import java.util.List;
import java.util.Map;
import org.junit.Test;

public class EventRejectionsTest
{
	@Test public void prisonPeteStopsIfTheLeverKeepsOpeningDialogueWithoutATarget()
	{
		EventScenario game = prison();
		game.input = (type,args) ->
		{
			if (type.equals("object.interact"))
			{
				assertEquals("Pull",args.get("action"));
				game.nextTick = game::continueDialogue;
			}
			else
			{
				assertEquals("dialogue.continue",type);
				game.nextTick = game::closeDialogue;
			}
		};
		fails(game,"Balloon target model was not observed");
		assertEquals(6,game.gameInputs);
	}

	@Test public void prisonPeteRejectsAnUnknownModelAndUnavailableMatchingBalloons()
	{
		for (boolean unknown : List.of(false,true))
		{
			EventScenario game = prison();
			game.npc(371,"Wrong balloon",2095,4465,"Pop");
			game.npc(369,"Dead balloon",2095,4465,"Pop").put("dead",true);
			game.npc(5493,"Hidden balloon",2095,4465,"Pop").put("clickable",false);
			game.input = (type,args) ->
			{
				if (type.equals("object.interact")) game.nextTick = () ->
				{
					game.widget(17891332,"").put("model_id",unknown ? 999999 : 10749);
					game.widget(17891333,"");
				};
				else
				{
					assertEquals("ui.click",type);
					assertEquals(17891333,args.get("widget_id"));
				}
			};
			fails(game,unknown ? "Unknown balloon model" : "Matching balloon was not available");
			assertEquals(unknown ? 1 : 2,game.gameInputs);
		}
	}
	@Test public void arnavRejectsUnknownLabelsAndUnresponsiveDials()
	{
		for (boolean unknown : List.of(false,true))
		{
			EventScenario game = arnav();
			game.widget(1703958,unknown ? "AMULET" : "COINS");
			game.varbits.put(9585L,1);
			game.widget(1703942,"");
			game.input = (type,args) ->
			{
				assertFalse("Unknown labels cannot select a dial",unknown);
				assertEquals("ui.click",type);
				assertEquals(1703942,args.get("widget_id"));
			};
			fails(game,unknown ? "Unknown chest label" : "Chest dial did not align");
			assertEquals(unknown ? 0 : 4,game.gameInputs);
		}
	}

	@Test public void arnavWaitsForARewardAfterSubmittingTheAlignedDials()
	{
		EventScenario game = arnav();
		for (int dial = 0; dial < 3; dial++) game.widget(1703958+dial,"COINS");
		game.input = (type,args) ->
		{
			assertEquals("ui.click",type);
			assertEquals(1703961,args.get("widget_id"));
		};
		fails(game,"Chest reward was not observed");
		assertEquals(1,game.gameInputs);
	}

	@Test public void mimeAndCountCheckDoNotReportUnobservedOutcomes()
	{
		EventScenario mime = new EventScenario(new Mime(),6753);
		mime.npc(321,"Mime",3166,3491);
		mime.maximumSleeps = 1200;
		fails(mime,"Mime show completion was not observed");
		assertEquals(0,mime.gameInputs);

		EventScenario count = new EventScenario(new CountCheck(),12551);
		count.input = (type,args) -> assertEquals("npc.interact",type);
		fails(count,"Count Check's outcome was not observed");
		assertEquals(1,count.gameInputs);
		assertNull(count.intents.current);
	}

	@Test public void anUnobservedInvitationDoesNotStartTheMimeShow()
	{
		EventScenario game = new EventScenario(new Mime(),6753);
		game.input = (type,args) -> assertEquals("npc.interact",type);
		fails(game,"Random-event activity did not open");
		assertEquals(1,game.gameInputs);
		assertNull(game.intents.current);
	}

	@Test public void mollyRejectsAMissingActorAndUnknownAppearance()
	{
		for (boolean missing : List.of(false,true))
		{
			EventScenario game = new EventScenario(new Molly(),6738);
			game.world = Map.of("x",10001,"y",10001,"plane",0);
			if (!missing) game.npc(999,"Molly",10001,10001,"Talk-to");
			game.input = (type,args) ->
			{
				if (type.equals("npc.interact")) game.nextTick = game::continueDialogue;
				else
				{
					assertEquals("dialogue.continue",type);
					game.nextTick = game::closeDialogue;
				}
			};
			fails(game,missing ? "Molly was not available" : "Unknown Molly appearance");
			assertEquals(missing ? 0 : 2,game.gameInputs);
			assertNull(game.intents.current);
		}
	}

	@Test public void certerRejectsAnUnknownModelOrMissingAnswerWithoutInput()
	{
		for (boolean unknownModel : List.of(false,true))
		{
			EventScenario game = certer(unknownModel ? 999999 : 8837);
			fails(game,unknownModel ? "Unrecognized Certer model" : "answer label was not found");
			assertEquals(0,game.gameInputs);
			assertNull(game.intents.current);
		}
	}

	@Test public void certerStopsWhenTheAnswerClickIsRejectedOrTheRewardNeverArrives()
	{
		for (boolean reject : List.of(false,true))
		{
			EventScenario game = certer(8834);
			game.widget(12058632,"");
			game.input = (type,args) ->
			{
				assertEquals("ui.click",type);
				assertEquals(12058632,args.get("widget_id"));
				if (reject) game.receipt = Map.of("status","rejected");
			};
			fails(game,reject ? "Widget interaction failed" : "Certer reward was not observed");
			assertEquals(1,game.gameInputs);
			assertNull(game.intents.current);
		}
	}

	@Test public void pinballRejectsInvalidPostIndicesAndMissingTargets()
	{
		for (int post : new int[]{-1,0,5})
		{
			EventScenario game = pinball(post,0);
			fails(game,post == 0 ? "Pinball tag failed" : "Unknown pinball post");
			assertEquals(0,game.gameInputs);
		}
	}

	@Test public void pinballRequiresAcceptedInputAndObservedScoreProgress()
	{
		for (String outcome : List.of("rejected","unchanged","reset","premature_finish"))
		{
			EventScenario game = pinball(0,3);
			game.object(8982,3166,3491,"Tag");
			game.input = (type,args) ->
			{
				assertEquals("object.interact",type);
				assertEquals("Tag",args.get("action"));
				if (outcome.equals("rejected")) game.receipt = Map.of("status","rejected");
				else if (outcome.equals("reset")) game.nextTick = () -> game.varbits.put(2121L,2);
				else if (outcome.equals("premature_finish")) game.nextTick = () -> game.varbits.put(2122L,1);
			};
			String failure = outcome.equals("rejected") ? "Pinball tag failed" : outcome.equals("reset") ? "Pinball score reset" :
				outcome.equals("premature_finish") ? "Pinball did not reach its completion state" : "Pinball score did not change";
			fails(game,failure);
			assertEquals(1,game.gameInputs);
		}
	}

	@Test public void mollyCannotEnterTheGameAfterARejectedInvitation()
	{
		EventScenario game = new EventScenario(new Molly(),6738);
		game.input = (type,args) ->
		{
			assertEquals("npc.interact",type);
			assertEquals(6738,args.get("id"));
			assertEquals("molly.accept_invitation",game.intents.current);
			game.receipt = Map.of("status","rejected");
		};
		fails(game,"Random-event NPC interaction failed");
		assertEquals(1,game.gameInputs);
		assertNull(game.intents.current);
	}

	@Test public void evilBobRequiresTwoFreeSlotsBeforeObtainingTheNet()
	{
		for (int slots : new int[]{26,27})
		{
			EventScenario game = island();
			for (int slot = 0; slot < slots; slot++) game.inventory.put(1000+slot,1);
			game.input = (type,args) ->
			{
				if (type.equals("walk.to")) game.moveTo((Map<?,?>)args.get("destination"));
				else
				{
					assertEquals("ground_item.take",type);
					game.receipt = Map.of("status","rejected");
				}
			};
			fails(game,slots == 27 ? "requires two free inventory slots" : "Fishing net could not be taken");
			assertEquals(slots == 27 ? 0 : 2,game.gameInputs);
		}
	}

	@Test public void evilBobCannotFinishAfterMissingOrRejectedFeeding()
	{
		for (String outcome : List.of("missing_bob","rejected","no_catnap"))
		{
			EventScenario game = island();
			game.inventory.putAll(Map.of(6209,1,6200,1));
			if (!outcome.equals("missing_bob")) game.npc(391,"Evil Bob",2522,4773);
			game.input = (type,args) ->
			{
				assertEquals("item.use_on_npc",type);
				assertEquals(6200,args.get("item_id"));
				assertEquals(391,args.get("npc_id"));
				if (outcome.equals("rejected")) game.receipt = Map.of("status","rejected");
			};
			fails(game,outcome.equals("no_catnap") ? "did not begin his catnap" : "Evil Bob could not be fed");
			assertEquals(outcome.equals("missing_bob") ? 0 : 1,game.gameInputs);
		}
	}

	private static EventScenario certer(int model)
	{
		EventScenario game = new EventScenario(new Certer(),5436);
		game.widget(12058631,"").put("model_id",model);
		game.widget(12058625,"A ring."); game.widget(12058626,"A bowl."); game.widget(12058627,"A helmet.");
		return game;
	}

	private static EventScenario arnav()
	{
		EventScenario game = new EventScenario(new CaptArnav(),5426);
		game.widget(1703961,"");
		game.varbits.putAll(Map.of(9585L,0,9593L,0,9594L,0));
		return game;
	}

	private static EventScenario pinball(int post, int score)
	{
		EventScenario game = new EventScenario(new Pinball(),6744);
		game.object(9293,3165,3491,"Exit");
		game.varbits.putAll(Map.of(2119L,post,2121L,score,2122L,0));
		return game;
	}

	private static EventScenario island()
	{
		EventScenario game = new EventScenario(new EvilBob(),390);
		game.world = Map.of("x",2522,"y",4773,"plane",0);
		return game;
	}

	private static EventScenario prison()
	{
		EventScenario game = new EventScenario(new PrisonPete(),6754);
		game.world = Map.of("x",2095,"y",4465,"plane",0);
		game.object(24296,2095,4465,"Pull");
		return game;
	}

	private static void fails(EventScenario game, String reason)
	{
		try { game.run(); fail("Unobserved event outcome was accepted"); }
		catch (IllegalStateException failure) { assertTrue(failure.getMessage(),failure.getMessage().contains(reason)); }
	}
}
