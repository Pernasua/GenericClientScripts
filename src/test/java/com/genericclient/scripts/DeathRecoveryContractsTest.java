package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.recovery.DeathRecovery;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.BiConsumer;
import org.junit.Test;

public class DeathRecoveryContractsTest
{
    @Test public void missingRepliesAndRetrievalPanelsStopBeforeTakingItems()
    {
        for (boolean replies : List.of(false,true))
        {
            SceneScenario game=office();
            game.widgets.clear();
            game.input=(type,args) ->
            {
                if (type.equals("npc.interact"))
                {
                    assertEquals("Collect",args.get("action"));
                    if (replies) game.nextTick=game::continueDialogue;
                }
                else
                {
                    assertEquals("dialogue.continue",type);
                    game.nextTick=game::closeDialogue;
                }
            };
            try { game.run(); fail("The missing retrieval interface was ignored"); }
            catch (IllegalStateException failure)
            {
                assertEquals(replies ? "Death's retrieval interface did not open" : "Death did not respond",failure.getMessage());
            }
            assertEquals(replies ? 2 : 1,game.gameInputs);
            assertNull(game.result);
        }
    }

    @Test public void rejectedRetrievalAndExitInputsDoNotReportCompletion()
    {
        for (String rejected : List.of("ui.click","ui.close","object.interact"))
        {
            SceneScenario game=office();
            BiConsumer<String,Map<String,Object>> input=game.input;
            game.input=(type,args) ->
            {
                if (type.equals(rejected)) game.receipt=Map.of("status","rejected");
                else input.accept(type,args);
            };
            String reason=Map.of("ui.click","Widget interaction failed","ui.close","Retrieval interface did not close",
                "object.interact","Death's portal was not available").get(rejected);
            try { game.run(); fail("A rejected recovery input was ignored"); }
            catch (IllegalStateException failure) { assertTrue(failure.getMessage(),failure.getMessage().contains(reason)); }
            assertNull(game.result);
        }
    }

    @Test public void clickingThePortalDoesNotProveThatTheOfficeWasLeft()
    {
        SceneScenario game=office();
        BiConsumer<String,Map<String,Object>> input=game.input;
        game.input=(type,args) ->
        {
            if (type.equals("object.interact")) assertEquals(39549,args.get("id"));
            else input.accept(type,args);
        };
        try { game.run(); fail("The unobserved exit completed recovery"); }
        catch (IllegalStateException failure) { assertEquals("Death's Office exit was not observed",failure.getMessage()); }
        assertNull(game.result);
        assertEquals(1,game.objects.size());
    }

    @Test public void recoveryReportsOnlyNewItemsAfterLeavingTheOffice()
    {
        SceneScenario game=office();
        game.inventory.putAll(Map.of(995,100,379,2,6209,1));
        game.run();
        assertEquals(Map.of("status","complete","recovered",Map.of(379,3,2528,1),"quantity",4),game.result);
        assertEquals(Map.of(995,90,379,5,2528,1,6209,1),game.inventory);
        assertTrue(game.objects.isEmpty());
        assertEquals("banking",game.activity);
    }

    @Test public void recoveryEntersTheOfficeAndWaitsForDeathsRetrievalPanel()
    {
        SceneScenario game=office();
        game.world=Map.of("x",3238,"y",3192,"plane",0);
        game.npcs.clear(); game.objects.clear(); game.widgets.clear();
        game.object(38426,3238,3192,"Enter");
        BiConsumer<String,Map<String,Object>> input=game.input;
        game.input=(type,args) ->
        {
            if (type.equals("object.interact") && args.get("id").equals(38426))
            {
                assertEquals("Enter",args.get("action"));
                game.nextTick=() ->
                {
                    game.objects.clear();
                    game.object(39549,10001,10001,"Use");
                    game.npc(9855,"Death",10001,10001,"Collect","Talk-to");
                    game.world=Map.of("x",10001,"y",10001,"plane",0);
                };
            }
            else if (type.equals("npc.interact"))
            {
                assertEquals("Collect",args.get("action"));
                game.nextTick=game::continueDialogue;
            }
            else if (type.equals("dialogue.continue"))
                game.nextTick=() -> { game.closeDialogue(); game.widget(43843594,""); };
            else input.accept(type,args);
        };
        game.run();
        assertEquals(Map.of("status","complete","recovered",Map.of(379,3,2528,1),"quantity",4),game.result);
        assertEquals(List.of("dialogue.finish"),game.intents.entries);
    }

    @Test public void anEmptyInitialRetrievalTransfersTheGravestoneBeforeTakingItems()
    {
        SceneScenario game=office();
        AtomicInteger collections=new AtomicInteger();
        BiConsumer<String,Map<String,Object>> input=game.input;
        game.input=(type,args) ->
        {
            if (type.equals("ui.click") && collections.incrementAndGet()==1) return;
            if (type.equals("npc.interact"))
            {
                assertEquals("Talk-to",args.get("action"));
                game.nextTick=() -> game.dialogue=Map.of("type","choice","open",true,"options",
                    List.of(Map.of("index",1L,"text","Can I collect the items from that gravestone now?")));
            }
            else if (type.equals("dialogue.choose")) transferDialogue(game,(String)args.get("text"));
            else input.accept(type,args);
        };
        game.run();
        assertEquals(2,collections.get());
        assertEquals(Map.of("status","complete","recovered",Map.of(379,3,2528,1),"quantity",4),game.result);
        assertEquals(2,game.intents.actions.get("dialogue.choose").size());
    }

    @Test public void anAdditionalTakeAllConfirmationStopsRecovery()
    {
        SceneScenario game=office();
        game.input=(type,args) ->
        {
            assertEquals("ui.click",type);
            assertEquals(43843594,args.get("widget_id"));
            game.nextTick=game::continueDialogue;
        };
        try { game.run(); fail("Recovery bypassed a new confirmation"); }
        catch (IllegalStateException failure) { assertEquals("Death recovery requires confirmation",failure.getMessage()); }
        assertEquals(1,game.gameInputs);
        assertNull(game.result);
    }

    private static void transferDialogue(SceneScenario game, String choice)
    {
        if (choice.equals("Can I collect the items from that gravestone now?"))
            game.nextTick=() -> game.dialogue=Map.of("type","choice","open",true,"options",
                List.of(Map.of("index",1L,"text","Bring my items here now; I'll pay your fee.")));
        else
        {
            assertEquals("Bring my items here now; I'll pay your fee.",choice);
            game.nextTick=() -> { game.closeDialogue(); game.widget(43843594,""); };
        }
    }

    private static SceneScenario office()
    {
        SceneScenario game=new SceneScenario(new DeathRecovery());
        game.world=Map.of("x",10001,"y",10001,"plane",0);
        game.npc(9855,"Death",10001,10001,"Collect","Talk-to");
        game.object(39549,10001,10001,"Use");
        game.widget(43843594,"");
        game.input=(type,args) ->
        {
            switch (type)
            {
                case "ui.click":
                    assertEquals(43843594,args.get("widget_id"));
                    game.nextTick=() ->
                    {
                        game.inventory.merge(379,3,Integer::sum); game.inventory.put(2528,1);
                        game.inventory.computeIfPresent(995,(id,quantity) -> quantity-10);
                    };
                    break;
                case "ui.close":game.widgets.clear(); break;
                case "object.interact":
                    assertEquals(39549,args.get("id")); assertEquals("Use",args.get("action"));
                    assertTrue(game.widgets.isEmpty());
                    game.nextTick=() -> { game.npcs.clear(); game.objects.clear(); game.world=Map.of("x",3238,"y",3192,"plane",0); };
                    break;
                default:throw new AssertionError("Unexpected recovery input: "+type);
            }
        };
        return game;
    }
}
