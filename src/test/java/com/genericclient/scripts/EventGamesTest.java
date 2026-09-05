package com.genericclient.scripts;

import static org.junit.Assert.*;
import com.genericclient.scripts.events.Certer;
import com.genericclient.scripts.events.Mime;
import com.genericclient.scripts.events.Pinball;
import com.genericclient.scripts.events.PrisonPete;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.Test;

public class EventGamesTest
{
    @Test public void certerUsesTheObservedLabelPositionAndRequiresTheReward()
    {
        EventScenario game=new EventScenario(new Certer(),5436);
        game.widget(12058631,"").put("model_id",8837);
        game.widget(12058625,"A ring."); game.widget(12058626,"  A   SPADE! "); game.widget(12058627,"A bowl.");
        game.widget(12058632,""); game.widget(12058633,""); game.widget(12058634,"");
        game.input=(type,args) ->
        {
            assertEquals("ui.click",type);
            assertEquals(12058633,args.get("widget_id"));
            game.nextTick=() -> { game.depart(); game.message("Your reward is: 10 x Lobster."); };
        };
        game.run();
        assertEquals(Map.of("status","solved","model_id",8837,"answer","A spade."),game.result);
        assertEquals(1,game.gameInputs);
    }

    @Test public void certerRejectsAmbiguousAnswersBeforeClicking()
    {
        EventScenario game=new EventScenario(new Certer(),5437);
        game.widget(12058631,"").put("model_id",8834);
        game.widget(12058625,"A ring."); game.widget(12058626,"A ring!"); game.widget(12058627,"A bowl.");
        try { game.run(); fail("Ambiguous answer was accepted"); }
        catch (IllegalStateException expected) { assertEquals("Certer has duplicate matching labels",expected.getMessage()); }
        assertEquals(0,game.gameInputs);
    }

    @Test public void mimeWaitsForEachPanelToCloseAndObservesTheNextEmote()
    {
        EventScenario game=new EventScenario(new Mime(),6753);
        Map<String,Object> mime=game.npc(321,"Mime",3166,3491);
        mime.put("animation",857);
        game.widget(12320770,"");
        AtomicInteger rounds=new AtomicInteger();
        game.input=(type,args) ->
        {
            assertEquals("ui.click",type);
            int round=rounds.getAndIncrement();
            assertEquals(round==0 ? 12320770 : 12320776,args.get("widget_id"));
            assertTrue("One input per prompt",round<2);
            game.nextTick=() ->
            {
                game.widgets.clear(); mime.put("animation",-1);
                if (round==0) game.nextTick=() ->
                {
                    mime.put("animation",1129); game.widget(12320770,""); game.widget(12320776,"");
                };
                else { game.depart(); game.message("You can now use the Glass Wall emote."); }
            };
        };
        game.run();
        assertEquals(Map.of("status","solved","rounds",List.of(12320770,12320776)),game.result);
        assertEquals(2,game.gameInputs);
    }

    @Test public void pinballFollowsChangingPostsAndExitsOnlyAfterTenPoints()
    {
        EventScenario game=new EventScenario(new Pinball(),6744);
        game.object(9293,3165,3491,"Exit");
        int[] posts={8982,8984,9079,9081,9258};
        for (int id : posts) game.object(id,3166,3491,"Tag");
        game.varbits.putAll(Map.of(2119L,0,2121L,0,2122L,0));
        game.input=(type,args) ->
        {
            assertEquals("object.interact",type);
            int score=game.varbits.get(2121L);
            if (args.get("action").equals("Exit"))
            {
                assertEquals(10,score);
                game.nextTick=() -> { game.depart(); game.message("You were awarded 5 sapphires."); };
            }
            else
            {
                assertEquals("Tag",args.get("action"));
                assertEquals(posts[(score*3)%5],args.get("id"));
                game.nextTick=() -> game.varbits.putAll(Map.of(2119L,((score+1)*3)%5,2121L,score+1,2122L,score==9 ? 1 : 0));
            }
        };
        game.run();
        assertEquals(Map.of("status","solved","score",10),game.result);
        assertEquals(11,game.gameInputs);
    }

    @Test public void prisonPeteReturnsThreeMatchingKeysBeforeLeaving()
    {
        EventScenario game=new EventScenario(new PrisonPete(),6754);
        game.world=Map.of("x",2095,"y",4465,"plane",0);
        game.object(24296,2095,4465,"Pull");
        game.npc(369,"Balloon animal",2095,4465,"Pop");
        game.npc(371,"Balloon animal",2094,4465,"Pop");
        AtomicInteger keys=new AtomicInteger();
        AtomicInteger pulls=new AtomicInteger();
        game.input=(type,args) ->
        {
            switch (type)
            {
                case "object.interact":
                    assertEquals("Pull",args.get("action"));
                    if (pulls.incrementAndGet()==1) game.nextTick=game::continueDialogue;
                    else game.nextTick=() -> { game.widget(17891332,"").put("model_id",10749); game.widget(17891333,""); };
                    break;
                case "dialogue.continue":game.nextTick=game::closeDialogue; break;
                case "ui.click":
                    assertEquals(17891333,args.get("widget_id")); game.widgets.clear(); break;
                case "npc.interact":
                    assertEquals(369,args.get("id")); assertEquals("Pop",args.get("action"));
                    game.nextTick=() -> game.inventory.put(6966,1); break;
                case "item.interact":
                    assertEquals("Return",args.get("action"));
                    game.nextTick=() ->
                    {
                        game.inventory.clear();
                        game.message(keys.incrementAndGet()==3 ? "You got all the keys right!" : "You got the right one.");
                    };
                    break;
                case "walk.to":
                    assertEquals(3,keys.get()); game.moveTo((Map<?,?>)args.get("destination")); break;
                case "walk.click":
                    assertEquals(3,keys.get());
                    game.nextTick=() -> { game.world=Map.of("x",3165,"y",3491,"plane",0); game.message("Your reward is: 10 x Coins."); };
                    break;
                default:throw new AssertionError("Unexpected prison input: "+type);
            }
        };
        game.run();
        assertEquals(Map.of("status","solved","attempts",3),game.result);
        assertEquals(3,keys.get());
        assertEquals(4,pulls.get());
    }

}
