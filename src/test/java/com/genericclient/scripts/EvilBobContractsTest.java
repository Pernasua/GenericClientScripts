package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.events.EvilBob;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.BiConsumer;
import org.junit.Test;

public class EvilBobContractsTest
{
    @Test public void evilBobAcceptsTheInvitationBeforeStartingOnScapeRune()
    {
        EventScenario game=islandGame();
        game.world=Map.of("x",3165,"y",3491,"plane",0);
        BiConsumer<String,Map<String,Object>> input=game.input;
        game.input=(type,args) ->
        {
            if (type.equals("npc.interact") && args.get("id").equals(390))
                game.nextTick=() -> game.dialogue=Map.of("open",true,"type","choice",
                    "options",List.of(Map.of("index",1L,"text","Yes, that seems like a good idea.")));
            else if (type.equals("dialogue.choose") && args.get("text").equals("Yes, that seems like a good idea."))
            {
                assertEquals("evil_bob.accept_invitation",game.intents.current);
                game.nextTick=() ->
                {
                    game.world=Map.of("x",2522,"y",4773,"plane",0);
                    game.closeDialogue();
                };
            }
            else input.accept(type,args);
        };
        game.run();
        assertEquals(Map.of("status","solved","fishing_spots_tried",List.of(0,1)),game.result);
        assertEquals("evil_bob.accept_invitation",game.intents.entries.get(0));
    }

    @Test public void rejectedFishAndPortalInteractionsCannotCompleteTheEvent()
    {
        for (String rejected : List.of("item.interact","dialogue.choose","item.use_on_object","portal"))
        {
            EventScenario game=islandGame();
            BiConsumer<String,Map<String,Object>> input=game.input;
            game.input=(type,args) ->
            {
                input.accept(type,args);
                if (type.equals(rejected) || rejected.equals("portal") && type.equals("object.interact") && args.get("action").equals("Enter"))
                {
                    game.receipt=Map.of("status","rejected");
                    game.nextTick=null;
                }
            };
            String reason=Map.of("item.interact","Wrong fish could not be destroyed","dialogue.choose",
                "Wrong-fish destruction confirmation was not recognized","item.use_on_object","Correct fish could not be uncooked",
                "portal","ScapeRune portal was not available").get(rejected);
            try { game.run(); fail("The rejected interaction was ignored"); }
            catch (IllegalStateException failure) { assertEquals(reason,failure.getMessage()); }
            assertNull(game.result);
        }
    }

    @Test public void fishingStopsAfterEverySpotProducesTheWrongFish()
    {
        EventScenario game=islandGame();
        game.object(23114,2510,4775,"Net"); game.object(23114,2543,4777,"Net");
        BiConsumer<String,Map<String,Object>> input=game.input;
        game.input=(type,args) ->
        {
            input.accept(type,args);
            if (type.equals("object.interact") && args.get("action").equals("Net"))
                game.nextTick=() -> game.inventory.put(6206,1);
        };
        try { game.run(); fail("The event completed without a correct fish"); }
        catch (IllegalStateException failure) { assertEquals("No correct fishing spot was found",failure.getMessage()); }
        assertEquals(4,game.intents.actions.get("object.interact").size());
        assertEquals(Map.of(6209,1),game.inventory);
    }

    @Test public void anUnobservedDestructionStopsBeforeFishingAgain()
    {
        EventScenario game=islandGame();
        game.inventory.putAll(Map.of(6209,1,6206,1));
        game.input=(type,args) ->
        {
            assertEquals("item.interact",type);
            assertEquals(6206,args.get("id"));
            assertEquals("Destroy",args.get("action"));
        };
        try { game.run(); fail("Fishing continued with the wrong fish still present"); }
        catch (IllegalStateException failure) { assertEquals("Wrong fish remained in inventory",failure.getMessage()); }
        assertEquals(1,game.gameInputs);
        assertEquals(Map.of(6209,1,6206,1),game.inventory);
    }

    @Test public void evilBobDestroysWrongFishThenUncooksAndFeedsTheCorrectFish()
    {
        EventScenario game=islandGame();
        game.run();
        assertEquals(Map.of("status","solved","fishing_spots_tried",List.of(0,1)),game.result);
        assertEquals(Map.of(6209,1),game.inventory);
        assertFalse((Boolean)game.event.get("present"));
    }

    private static EventScenario islandGame()
    {
        EventScenario game=new EventScenario(new EvilBob(),390);
        game.world=Map.of("x",2522,"y",4773,"plane",0);
        game.npc(391,"Evil Bob",2522,4773); game.npc(393,"Servant",2522,4773,"Talk-to");
        game.object(23113,2522,4773,"Use"); game.object(23115,2522,4773,"Enter");
        game.object(23114,2525,4764,"Net"); game.object(23114,2527,4791,"Net");
        AtomicInteger catches=new AtomicInteger();
        game.input=(type,args) ->
        {
            switch (type)
            {
                case "walk.to":game.moveTo((Map<?,?>)args.get("destination")); break;
                case "ground_item.take":
                    assertEquals(6209,args.get("id")); game.nextTick=() -> game.inventory.put(6209,1); break;
                case "npc.interact":game.nextTick=game::continueDialogue; break;
                case "dialogue.continue":game.nextTick=game::closeDialogue; break;
                case "object.interact":
                    if (args.get("action").equals("Net"))
                        game.nextTick=() -> game.inventory.put(catches.incrementAndGet()==1 ? 6206 : 6202,1);
                    else
                    {
                        assertEquals("Enter",args.get("action"));
                        game.nextTick=() -> { game.world=Map.of("x",3165,"y",3491,"plane",0); game.depart(); };
                    }
                    break;
                case "item.interact":
                    assertEquals(6206,args.get("id")); assertEquals("Destroy",args.get("action"));
                    game.nextTick=() -> game.dialogue=Map.of("open",true,"type","choice","options",List.of(Map.of("index",1L,"text","Yes, destroy it.")));
                    break;
                case "dialogue.choose":
                    assertEquals("Yes, destroy it.",args.get("text"));
                    game.nextTick=() -> { game.inventory.remove(6206); game.closeDialogue(); }; break;
                case "item.use_on_object":
                    assertEquals(6202,args.get("item_id")); assertEquals(23113,args.get("object_id"));
                    game.nextTick=() -> { game.inventory.remove(6202); game.inventory.put(6200,1); }; break;
                case "item.use_on_npc":
                    assertEquals(6200,args.get("item_id")); assertEquals(391,args.get("npc_id"));
                    game.nextTick=() -> { game.inventory.remove(6200); game.message("Evil Bob takes a catnap."); }; break;
                default:throw new AssertionError("Unexpected Evil Bob input: "+type);
            }
        };
        return game;
    }
}
