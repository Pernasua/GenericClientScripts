package com.genericclient.scripts;

import static org.junit.Assert.*;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class MonkeyHazardsTest
{
    @Test public void captureObservedAfterAnArrivalReceiptPreventsTheNextJourney()
    {
        QuestScenario game = new QuestScenario("monkey_madness_i",365,3,new Tile(2802,2788));
        game.equipment.put(4021,1);
        game.inventory.putAll(Map.of(2552,1,379,8));
        game.input = (type,args) ->
        {
            assertNotEquals("Capture must be checked before any further input",new Tile(2771,2794),game.position);
            if (type.equals("walk.to"))
            {
                game.position = new Tile(2771,2794);
                game.receipt = Map.of("status","arrived");
            }
            else assertTrue(type,List.of("prayer.set","consumable.cure_poison").contains(type));
        };
        try { game.run(); fail("An arrival receipt hid the observed capture"); }
        catch (IllegalStateException expected) { assertTrue(expected.getMessage(),expected.getMessage().contains("prison")); }
        assertEquals(1,game.actions.stream().filter("walk.to"::equals).count());
    }

    @Test public void aResumedAmuletRunWalksDirectlyFromPrisonClearToChildStaging()
    {
        QuestScenario game = new QuestScenario("monkey_madness_i",365,3,new Tile(2762,2804));
        game.equipment.put(4021,1);
        game.inventory.putAll(Map.of(2552,1,379,8));
        game.input = (type,args) ->
        {
            if (type.equals("walk.to"))
            {
                assertEquals("Resuming after prison escape must not return through the temple",List.of(),args.get("via"));
                assertEquals(120,args.get("timeout_ticks"));
                assertEquals(new Tile(2746,2799),tile((Map<?,?>)args.get("destination")));
                assertPrisonInterrupt(args);
                game.position = tile((Map<?,?>)args.get("destination"));
            }
            else assertTrue(type,List.of("prayer.set","consumable.cure_poison").contains(type));
        };
        game.run();
        assertEquals("checkpoint",((Map<?,?>)game.result).get("status"));
        assertEquals(new Tile(2746,2799),game.position);
        assertEquals(1,game.actions.stream().filter("walk.to"::equals).count());
    }

    @Test public void recaptureEndsInfiltrationBeforeAnyDoorOrCrateInput()
    {
        QuestScenario game=infiltration(new Tile(2762,2804));
        game.input=(type,args) ->
        {
            assertNotEquals("No further action may run after capture",new Tile(2771,2794),game.position);
            if (type.equals("walk.to"))
            {
                assertEquals(3,((List<?>)args.get("via")).size());
                assertPrisonInterrupt(args);
                game.position=new Tile(2771,2794);
                game.receipt=Map.of("status","interrupted","reason","area","detail","prison","continuation","captured");
            }
            else assertTrue(type,List.of("prayer.set","consumable.cure_poison").contains(type));
        };
        try { game.run(); fail("Recapture was treated as arrival"); }
        catch (IllegalStateException expected) { assertTrue(expected.getMessage(),expected.getMessage().contains("prison")); }
        assertFalse(game.actions.contains("object.interact"));
    }

    @Test public void dentureCratesUseTheSafeArrivalAndShortInteractionRadius()
    {
        QuestScenario game=infiltration(new Tile(2764,2764));
        game.object(4715,"Crate",new Tile(2768,2770),"Search");
        game.object(4714,"Crate",new Tile(2769,2765),"Search");
        game.object(4724,"Crate",new Tile(2782,9172),"Search");
        game.input=(type,args) ->
        {
            if (type.equals("walk.to"))
            {
                assertEquals("hazardous_travel",game.activity);
                assertEquals(WorkflowScript.NO_DISCRETIONARY,game.policy);
                Tile target=tile((Map<?,?>)args.get("destination"));
                if (target.getY()<9000)
                {
                    assertEquals(0,args.get("within"));
                    assertEquals(5,((List<?>)args.get("avoid_tiles")).size());
                    assertPrisonInterrupt(args);
                }
                game.position=target;
            }
            else if (type.equals("object.interact"))
            {
                int id=((Number)args.get("id")).intValue();
                assertEquals("Search",args.get("action"));
                if (id==4715)
                {
                    assertEquals(new Tile(2768,2769),game.position);
                    assertEquals("Crate interaction must not auto-path over the light floor",2,args.get("within"));
                    game.transitions.add(() -> game.inventory.put(4006,1));
                }
                else if (id==4714)
                {
                    assertEquals(new Tile(2769,2765),game.position);
                    assertEquals(2,args.get("within"));
                    game.transitions.add(() -> game.position=new Tile(2782,9171));
                }
                else { assertEquals(4724,id); game.transitions.add(() -> game.inventory.put(4020,1)); }
            }
            else assertTrue(type,List.of("prayer.set","consumable.cure_poison").contains(type));
        };
        game.run();
        assertEquals("checkpoint",((Map<?,?>)game.result).get("status"));
        assertTrue(game.inventory.keySet().containsAll(List.of(4006,4020)));
    }

    @Test public void childApproachAndRetreatAreTimedJourneysWithCaptureInterruption()
    {
        QuestScenario game=new QuestScenario("monkey_madness_i",365,3,new Tile(2746,2799));
        game.inventory.putAll(Map.of(2552,1,1963,5)); game.equipment.put(4021,1);
        game.npc(5268,"Monkey Child",new Tile(2743,2794),"Talk-to");
        game.npc(5270,"Monkey's Aunt",new Tile(2743,2792));
        Map<String,Object> aunt=game.npcs.get(1);
        game.transitions.add(() -> aunt.put("world",Map.of("x",2743,"y",2792,"plane",0)));
        game.transitions.add(() -> aunt.put("world",Map.of("x",2743,"y",2791,"plane",0)));
        game.input=(type,args) ->
        {
            switch (type)
            {
                case "walk.to":
                    assertEquals(40,args.get("timeout_ticks"));
                    assertPrisonInterrupt(args);
                    game.position=tile((Map<?,?>)args.get("destination"));
                    aunt.put("world",Map.of("x",2743,"y",2784,"plane",0));
                    break;
                case "npc.interact":
                    assertEquals(5268,args.get("id"));
                    game.transitions.add(() -> game.dialogue=Map.of("open",true,"type","choice",
                        "options",List.of(Map.of("index",1L,"text","Wow - can I borrow it?"))));
                    break;
                case "dialogue.choose":
                    assertEquals("Wow - can I borrow it?",args.get("text"));
                    game.transitions.add(() -> { game.inventory.put(4023,1); game.dialogue=Map.of("open",false,"type","closed","options",List.of()); });
                    break;
                default:throw new AssertionError("Unexpected child input: " + type);
            }
        };
        game.run();
        assertEquals("checkpoint",((Map<?,?>)game.result).get("status"));
        assertTrue(game.inventory.containsKey(4023));
        assertEquals(new Tile(2746,2799),game.position);
    }

    private static QuestScenario infiltration(Tile start)
    {
        QuestScenario game=new QuestScenario("monkey_madness_i",365,3,start);
        game.varbits.put(126L,2); game.inventory.putAll(Map.of(2552,1,379,8));
        return game;
    }

    private static void assertPrisonInterrupt(Map<String,Object> args)
    {
        Map<?,?> interrupts=(Map<?,?>)args.get("interrupt_on");
        assertNotNull("Capture must interrupt hazardous movement",interrupts.get("area"));
        assertEquals("prison",((Map<?,?>)interrupts.get("area")).get("name"));
    }

    private static Tile tile(Map<?,?> value)
    {
        return new Tile(((Number)value.get("x")).intValue(),((Number)value.get("y")).intValue(),((Number)value.get("plane")).intValue());
    }
}
