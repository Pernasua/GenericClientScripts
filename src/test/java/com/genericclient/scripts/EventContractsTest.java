package com.genericclient.scripts;

import static org.junit.Assert.*;
import com.genericclient.scripts.events.CaptArnav;
import com.genericclient.scripts.events.CountCheck;
import com.genericclient.scripts.events.DrunkenDwarf;
import com.genericclient.scripts.events.Genie;
import com.genericclient.scripts.events.RickTurpentine;
import java.util.List;
import java.util.Map;
import org.junit.Test;

public class EventContractsTest
{
    @Test public void genieRequiresANewLampAndTheRewardReceipt()
    {
        EventScenario game=new EventScenario(new Genie(),326);
        game.inventory.put(2528,1);
        gift(game,() -> { game.inventory.put(2528,2); game.message("Your reward is: 1 x Lamp."); });
        game.run();
        assertEquals(Map.of("status","solved"),game.result);
        assertEquals(2,game.gameInputs);
        assertEquals("general",game.activity);
        assertEquals(Map.of("breaks",false,"cursor_release","none","fidget","none"),game.policy);
        assertEquals(List.of("genie.reward"),game.intents.entries);
        assertEquals(List.of("genie.reward"),game.intents.actions.get("npc.interact"));
        assertEquals(List.of("genie.reward"),game.intents.actions.get("dialogue.continue"));
        assertNull(game.intents.current);
    }

    @Test public void aRewardMessageWithoutTheNewLampDoesNotCompleteGenie()
    {
        EventScenario game=new EventScenario(new Genie(),326);
        game.inventory.put(2528,1);
        gift(game,() -> game.message("Your reward is: 1 x Lamp."));
        try { game.run(); fail("Missing lamp was accepted"); }
        catch (IllegalStateException expected) { assertEquals("Random-event reward was not observed",expected.getMessage()); }
        assertNull(game.intents.current);
    }

    @Test public void giftsDoNotUseRewardsFromBeforeTheEventWasDetected()
    {
        for (EventScenario game : List.of(new EventScenario(new Genie(),326),new EventScenario(new RickTurpentine(),375)))
        {
            game.sleepTicks(9,Map.of());
            game.message("Your reward is: 1 x Lamp.");
            game.sleep(600);
            game.event.put("detected_tick",game.tick());
            gift(game,() -> game.inventory.put(2528,1));
            try { game.run(); fail("An old reward completed the new event"); }
            catch (IllegalStateException expected) { assertEquals("Random-event reward was not observed",expected.getMessage()); }
            assertEquals(2,game.gameInputs);
            assertNull(game.intents.current);
        }
    }

    @Test public void solverCannotClaimAnotherEventsNpc()
    {
        EventScenario game=new EventScenario(new Genie(),375);
        try { game.run(); fail("Different event owner was accepted"); }
        catch (IllegalStateException expected) { assertEquals("Solver does not own this random event",expected.getMessage()); }
        assertEquals(0,game.gameInputs);
    }

    @Test public void giftTalkUsesBothTheDetectedNpcIdAndIndex()
    {
        EventScenario game=new EventScenario(new Genie(),326);
        game.npcs.get(0).put("world",Map.of("x",3167,"y",3491,"plane",0));
        game.npc(326,"Another genie",3165,3491,"Talk-to");
        game.npc(375,"Another event",3165,3491,"Talk-to").put("index",7);
        gift(game,() -> { game.inventory.put(2528,1); game.message("Your reward is: 1 x Lamp."); });
        game.run();
        assertEquals(Map.of("status","solved"),game.result);
        assertEquals(2,game.gameInputs);
    }

    @Test public void anInactiveEventCannotClaimItsPreviousNpc()
    {
        EventScenario game=new EventScenario(new Genie(),326);
        game.event.put("active",false);
        try { game.run(); fail("An inactive event retained solver ownership"); }
        catch (IllegalStateException failure) { assertEquals("Solver does not own this random event",failure.getMessage()); }
        assertEquals(0,game.gameInputs);
    }

    @Test public void rickWaitsForTheRewardAndDwarfForTheCompletedConversation()
    {
        EventScenario rick=new EventScenario(new RickTurpentine(),375);
        gift(rick,() -> rick.message("Your reward is: 10 x Coins."));
        rick.run();
        assertEquals(Map.of("status","solved"),rick.result);
        EventScenario dwarf=new EventScenario(new DrunkenDwarf(),322);
        gift(dwarf,() -> {});
        dwarf.run();
        assertEquals(Map.of("status","solved"),dwarf.result);
        assertEquals(2,dwarf.gameInputs);
    }

    @Test public void countCheckPreservesPassAndFailOutcomes()
    {
        for (boolean passed : List.of(false,true))
        {
            EventScenario game=new EventScenario(new CountCheck(),12551);
            game.input=(type,args) ->
            {
                if (type.equals("npc.interact")) game.nextTick=() -> game.dialogue=Map.of("open",true,"type","choice",
                    "options",List.of(Map.of("index",1L,"text","Check my account, Count Check!")));
                else
                {
                    assertEquals("dialogue.choose",type);
                    assertEquals("Check my account, Count Check!",args.get("text"));
                    game.nextTick=() -> { game.depart(); game.message(passed ? "You pass my checks." : "You fail my checks."); };
                }
            };
            game.run();
            assertEquals(Map.of("status","solved","outcome",passed ? "passed" : "failed"),game.result);
        }
    }

    @Test public void countCheckUsesTheCurrentOutcomeAfterAnEarlierPass()
    {
        EventScenario game=new EventScenario(new CountCheck(),12551);
        game.sleepTicks(9,Map.of());
        game.message("You pass my checks.");
        game.sleep(600);
        game.event.put("detected_tick",game.tick());
        gift(game,() -> game.message("You fail my checks."));
        game.run();
        assertEquals(Map.of("status","solved","outcome","failed"),game.result);
        assertEquals(2,game.gameInputs);
    }

    @Test public void arnavAlignsTheObservedDialLabelsBeforeConfirming()
    {
        EventScenario game=new EventScenario(new CaptArnav(),5426);
        game.varbits.putAll(Map.of(9585L,2,9593L,2,9594L,0));
        game.widget(1703958,"RING"); game.widget(1703959,"COINS"); game.widget(1703960,"BAR");
        game.widget(1703961,"");
        for (int id : new int[]{1703941,1703942,1703944,1703945,1703947,1703948}) game.widget(id,"");
        game.input=(type,args) ->
        {
            assertEquals("ui.click",type);
            int id=((Number)args.get("widget_id")).intValue();
            if (id==1703961)
            {
                assertEquals(Map.of(9585L,3,9593L,0,9594L,2),game.varbits);
                game.nextTick=() -> { game.depart(); game.message("Your reward is: 1 x Gold bar."); };
            }
            else
            {
                long bit=id<1703944 ? 9585L : id<1703947 ? 9593L : 9594L;
                int change=id==1703941 || id==1703944 || id==1703947 ? 1 : -1;
                game.nextTick=() -> game.varbits.put(bit,Math.floorMod(game.varbits.get(bit)+change,4));
            }
        };
        game.run();
        assertEquals(Map.of("status","solved"),game.result);
        assertEquals(6,game.gameInputs);
    }

    @Test public void arnavWaitsForLoadedControlsToBecomeVisibleBeforeUsingThem()
    {
        EventScenario game=new EventScenario(new CaptArnav(),5426);
        game.varbits.putAll(Map.of(9585L,3,9593L,0,9594L,2));
        game.widget(1703958,"RING"); game.widget(1703959,"COINS"); game.widget(1703960,"BAR");
        Map<String,Object> confirm=game.widget(1703961,"");
        confirm.put("visible",false);
        game.input=(type,args) ->
        {
            if (type.equals("npc.interact"))
            {
                assertEquals("Talk-to",args.get("action"));
                game.nextTick=()->confirm.put("visible",true);
            }
            else
            {
                assertEquals("ui.click",type);
                assertEquals(1703961,args.get("widget_id"));
                assertEquals(true,confirm.get("visible"));
                game.nextTick=()->{game.depart();game.message("Your reward is: 1 x Gold bar.");};
            }
        };
        game.run();
        assertEquals(Map.of("status","solved"),game.result);
        assertEquals(2,game.gameInputs);
    }

    @Test public void arnavAcceptsTheDialAlignmentObservedAfterItsLastRetry()
    {
        EventScenario game=new EventScenario(new CaptArnav(),5426);
        game.varbits.putAll(Map.of(9585L,1,9593L,0,9594L,0));
        for (int dial=0;dial<3;dial++) game.widget(1703958+dial,"COINS");
        game.widget(1703961,""); game.widget(1703942,"");
        game.input=(type,args) ->
        {
            assertEquals("ui.click",type);
            if (args.get("widget_id").equals(1703942))
            {
                if (game.gameInputs==4) game.nextTick=() -> game.varbits.put(9585L,0);
            }
            else
            {
                assertEquals(1703961,args.get("widget_id"));
                assertEquals(0,game.varbits.get(9585L).intValue());
                game.nextTick=() -> game.message("You successfully unlock the chest.");
            }
        };
        game.run();
        assertEquals(Map.of("status","solved"),game.result);
        assertEquals(5,game.gameInputs);
    }

    private static void gift(EventScenario game, Runnable reward)
    {
        game.input=(type,args) ->
        {
            if (type.equals("npc.interact"))
            {
                assertEquals("Talk-to",args.get("action"));
                assertEquals(7,args.get("index"));
                assertEquals(game.event.get("npc_id"),args.get("id"));
                game.nextTick=() -> game.dialogue=Map.of("open",true,"type","continue","options",List.of());
            }
            else
            {
                assertEquals("dialogue.continue",type);
                game.nextTick=() -> { game.depart(); reward.run(); };
            }
        };
    }
}
