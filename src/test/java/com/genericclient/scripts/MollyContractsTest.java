package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.events.Molly;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.BiConsumer;
import org.junit.Test;

public class MollyContractsTest
{
    @Test public void mollyAcceptsTheInvitationBeforeOperatingTheGame()
    {
        EventScenario game = mollyGame(Map.of("x",10001,"y",10001,"plane",0));
        game.world = Map.of("x",3165,"y",3491,"plane",0);
        BiConsumer<String,Map<String,Object>> input = game.input;
        game.input = (type,args) ->
        {
            if (type.equals("npc.interact") && args.get("id").equals(6738))
                game.nextTick = () -> game.dialogue = Map.of("open",true,"type","choice",
                    "options",List.of(Map.of("index",1L,"text","Sure, anything for Molly.")));
            else if (type.equals("dialogue.choose"))
            {
                assertEquals("Sure, anything for Molly.",args.get("text"));
                assertEquals("molly.accept_invitation",game.intents.current);
                game.nextTick = () ->
                {
                    game.world = Map.of("x",10001,"y",10001,"plane",0);
                    game.closeDialogue();
                };
            }
            else input.accept(type,args);
        };
        game.run();
        assertEquals("solved",((Map<?,?>)game.result).get("status"));
        assertEquals("molly.accept_invitation",game.intents.entries.get(0));
    }

    @Test public void rejectedDoorPanelAndRewardInputsStopTheGame()
    {
        for (String rejected : List.of("door","panel","reward"))
        {
            EventScenario game = mollyGame(Map.of("x",10001,"y",10001,"plane",0));
            BiConsumer<String,Map<String,Object>> input = game.input;
            game.input = (type,args) ->
            {
                input.accept(type,args);
                boolean reject = rejected.equals("door") && type.equals("object.interact") && args.get("id").equals(20817) ||
                    rejected.equals("panel") && type.equals("object.interact") && args.get("id").equals(20813) ||
                    rejected.equals("reward") && type.equals("npc.interact") && game.intents.current.equals("molly.claim_reward");
                if (reject) { game.receipt = Map.of("status","rejected"); game.nextTick = null; }
            };
            String reason = rejected.equals("door") ? "Molly's door did not open" : rejected.equals("panel") ?
                "Claw control panel did not open" : "Molly's reward dialogue failed";
            try { game.run(); fail("The rejected interaction was ignored"); }
            catch (IllegalStateException failure) { assertEquals(reason,failure.getMessage()); }
            assertNull(game.intents.current);
        }
    }

    @Test public void missingClawOrTwinCannotCauseBlindControlInputs()
    {
        for (int missing : new int[]{20811,5468})
        {
            EventScenario game = mollyGame(Map.of("x",10001,"y",10001,"plane",0));
            game.objects.removeIf(row -> row.get("id").equals(missing));
            game.npcs.removeIf(row -> row.get("id").equals(missing));
            try { game.run(); fail("The missing scene entity was ignored"); }
            catch (IllegalStateException failure) { assertEquals("Molly's twin was not captured",failure.getMessage()); }
            assertFalse(game.intents.actions.containsKey("ui.click"));
            assertNull(game.intents.current);
        }
    }

    @Test public void leavingTheGameWithoutARewardDoesNotCompleteMolly()
    {
        EventScenario game = mollyGame(Map.of("x",10001,"y",10001,"plane",0));
        BiConsumer<String,Map<String,Object>> input = game.input;
        game.input = (type,args) ->
        {
            input.accept(type,args);
            if (type.equals("npc.interact") && game.intents.current.equals("molly.claim_reward"))
                game.nextTick = () ->
                {
                    game.world = Map.of("x",3165,"y",3491,"plane",0);
                    game.depart();
                };
        };
        try { game.run(); fail("Leaving without the reward completed the event"); }
        catch (IllegalStateException failure) { assertEquals("Molly's reward was not observed",failure.getMessage()); }
        assertNull(game.intents.current);
    }

    @Test public void mollyAlignsTheClawWithTheMatchingTwinAndReturnsForTheReward()
    {
        for (Map<String,Integer> target : List.of(Map.of("x",10003,"y",10002,"plane",0),Map.of("x",10000,"y",10000,"plane",0)))
        {
            EventScenario game = mollyGame(target);
            game.run();
            int expectedSteps = Math.abs(target.get("x")-10001)+Math.abs(target.get("y")-10001)+1;
            assertEquals(Map.of("status","solved","twin_id",5468,"control_steps",expectedSteps),game.result);
        }
    }

    @Test public void mollyWaitsForTheClawAndTwinToLoadBeforeUsingTheControls()
    {
        for (String delayed : List.of("claw","twin"))
        {
            EventScenario game = mollyGame(Map.of("x",10001,"y",10001,"plane",0));
            List<Map<String,Object>> scene = delayed.equals("claw") ? game.objects : game.npcs;
            int id = delayed.equals("claw") ? 20811 : 5468;
            Map<String,Object> missing = scene.stream().filter(row -> row.get("id").equals(id)).findFirst().orElseThrow();
            scene.remove(missing);
            BiConsumer<String,Map<String,Object>> input = game.input;
            game.input = (type,args) ->
            {
                if (type.equals("ui.click")) assertTrue(scene.contains(missing));
                input.accept(type,args);
                if (type.equals("object.interact") && args.get("id").equals(20813))
                    game.nextTick = () ->
                    {
                        game.widget(18153475,"");
                        game.nextTick = () -> scene.add(missing);
                    };
            };
            game.run();
            assertEquals("solved",((Map<?,?>)game.result).get("status"));
            assertEquals(1,game.intents.actions.get("ui.click").size());
        }
    }

    private static EventScenario mollyGame(Map<String,Integer> target)
    {
        EventScenario game=new EventScenario(new Molly(),6738);
        game.world=Map.of("x",10001,"y",10001,"plane",0);
        game.npc(342,"Molly",10001,10001,"Talk-to");
        game.npc(5468,"Evil twin",target.get("x"),target.get("y"));
        game.npc(5469,"Evil twin",10001,10001);
        game.object(20817,10001,10001,"Open"); game.object(20813,10001,10001,"Use");
        Map<String,Object> claw=game.object(20811,10001,10001);
        AtomicInteger talks=new AtomicInteger();
        game.input=(type,args) ->
        {
            switch (type)
            {
                case "npc.interact":
                    assertEquals(342,args.get("id"));
                    if (talks.incrementAndGet()==1) game.nextTick=game::continueDialogue;
                    else game.nextTick=() ->
                    {
                        game.world=Map.of("x",3165,"y",3491,"plane",0);
                        game.depart(); game.message("Your reward is: 10 x Coins.");
                    };
                    break;
                case "dialogue.continue":game.nextTick=game::closeDialogue; break;
                case "object.interact":
                    if (args.get("id").equals(20813))
                        game.nextTick=() -> { for (int id=18153475;id<=18153482;id++) game.widget(id,""); };
                    else assertEquals("Open",args.get("action"));
                    break;
                case "ui.click":moveClaw(game,claw,((Number)args.get("widget_id")).intValue(),target); break;
                default:throw new AssertionError("Unexpected Molly input: "+type);
            }
        };
        return game;
    }

    private static void moveClaw(EventScenario game, Map<String,Object> claw, int control, Map<String,Integer> target)
    {
        Map<?,?> position=(Map<?,?>)claw.get("world");
        int x=((Number)position.get("x")).intValue();
        int y=((Number)position.get("y")).intValue();
        if (control==18153475)
        {
            assertEquals(target,position);
            game.nextTick=() -> { game.message("You caught the evil twin!"); game.continueDialogue(); };
        }
        else
        {
            assertTrue(control>=18153479 && control<=18153482);
            int dx=control==18153481 ? 1 : control==18153479 ? -1 : 0;
            int dy=control==18153482 ? 1 : control==18153480 ? -1 : 0;
            game.nextTick=() -> claw.put("world",Map.of("x",x+dx,"y",y+dy,"plane",0));
        }
    }

}
