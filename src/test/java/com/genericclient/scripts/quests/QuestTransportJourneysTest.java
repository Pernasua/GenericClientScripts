package com.genericclient.scripts.quests;

import static org.junit.Assert.*;

import com.genericclient.script.ScriptScope;
import com.genericclient.scripts.QuestScenario;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class QuestTransportJourneysTest
{
    @Test public void witchBasementTripsUseOneJourneyToTheOtherSide()
    {
        assertJourney(new Tile(2902,3473),new Tile(2906,9876),0,game -> new WitchsHouse().execute("basement"));
        assertJourney(new Tile(2901,9874),new Tile(2906,3476),0,game -> new WitchsHouse().execute("upstairs"));
    }

    @Test public void waterfallUsesNativeBoatsAndStairsAndCanLeaveWithoutJewellery()
    {
        assertJourney(new Tile(2521,3495),new Tile(2512,3481),1,game -> new Waterfall().execute("raft"));
        assertJourney(new Tile(2519,3430),new Tile(2518,3431,1),0,game -> new Waterfall().execute("tourist_stairs"));
        assertJourney(new Tile(2518,3427,1),new Tile(2519,3430),0,game -> new Waterfall().execute("downstairs"));
        assertJourney(new Tile(2448,3090),new Tile(2533,9556),1,game -> new Waterfall().execute("gnome_dungeon"));
        assertJourney(new Tile(2548,9565),new Tile(2533,3156),1,game -> new Waterfall().execute("leave_gnome"));
        assertJourney(new Tile(2542,9812),new Tile(2557,3444),1,game -> new Waterfall().execute("leave_tomb"));
    }

    @Test public void grandTreeJourneysOwnOrdinaryClimbsAcrossEveryLocalFloor()
    {
        assertJourney(new Tile(2677,3088),new Tile(2677,3087,1),1,game -> new GnomeTravel(new GrandTree()).hazelmere());
        assertJourney(new Tile(2466,3494),new Tile(2483,3463,1),2,game -> new GnomeTravel(new GrandTree()).glough());
        assertJourney(new Tile(2483,3463,1),new Tile(2466,3495),2,game -> new GnomeTravel(new GrandTree()).king(false));
        assertJourney(new Tile(2466,3494),new Tile(2466,3495,3),1,game -> new GnomeTravel(new GrandTree()).top());
        assertJourney(new Tile(2466,3495,3),new Tile(2483,3463,1),2,game -> new GnomeTravel(new GrandTree()).glough());
        assertJourney(new Tile(2466,3495,3),new Tile(2390,3513,1),1,game -> new GnomeTravel(new GrandTree()).anita());
        assertJourney(new Tile(2390,3513,1),new Tile(2483,3463,1),2,game -> new GnomeTravel(new GrandTree()).glough());
    }

    @Test public void anInterruptedBasementTripDoesNotBecomeAnArrivalOrASecondRequest()
    {
        QuestScenario game = new QuestScenario("witchs_house",226,2,new Tile(2902,3473));
        List<String> inputs = new ArrayList<>();
        game.input = (type,args) -> {
            inputs.add(type);
            assertEquals("walk.to",type);
            game.receipt=Map.of("status","interrupted","reason","dialogue","continuation","basement");
        };
        ScriptScope scope = new ScriptScope(game);
        try (scope)
        {
            try { new WitchsHouse().execute("basement"); fail("Interrupted travel was accepted"); }
            catch (IllegalStateException expected) { assertTrue(expected.getMessage().contains("Travel did not reach")); }
        }
        assertEquals(List.of("walk.to"),inputs);
        assertEquals(new Tile(2902,3473),game.position);
    }

    @Test public void monkeyTravelDelegatesTheSpiritTreeGliderAndFloorChanges()
    {
        assertJourney(new Tile(3184,3508),new Tile(2461,3444),1,game -> new MonkeyTravel(new MonkeyMadness()).stronghold());
        assertJourney(new Tile(2466,3494),new Tile(2945,3041),3,game -> new MonkeyTravel(new MonkeyMadness()).shipyardGate());
        assertJourney(new Tile(2970,2972),new Tile(2465,3496),3,game -> new MonkeyTravel(new MonkeyMadness()).king());
        assertJourney(new Tile(2466,3494,3),new Tile(2482,3486,1),5,game -> new MonkeyTravel(new MonkeyMadness()).daero());
    }

    @Test public void repeatFlightsUseCompleteJourneysAndKeepTheCarriedMonkeyPolicy()
    {
        List<Tile> destinations=List.of(new Tile(2649,4516),new Tile(2894,2726),new Tile(2803,2706));
        List<Tile> origins=List.of(new Tile(2461,3444),destinations.get(0),destinations.get(1));
        for (boolean carrying : List.of(false,true))
            for (int start=0;start<origins.size();start++)
            {
                QuestScenario game = sailing(origins.get(start));
                if (carrying) game.inventory.put(4033,1);
                List<Tile> reached = new ArrayList<>();
                game.input = (type,args) -> {
                    if (type.equals("consumable.cure_poison")) return;
                    assertEquals("walk.to",type);
                    assertEquals("travel",game.activity);
                    assertEquals(carrying ? Map.of("breaks",false,"cursor_release","none","fidget","none") : Map.of(),game.policy);
                    assertEquals(true,((Map<?,?>)args.get("interrupt_on")).get("dialogue"));
                    assertEquals(1,((Number)args.get("within")).intValue());
                    game.position=tile((Map<?,?>)args.get("destination"));
                    reached.add(game.position);
                };
                ScriptScope scope = new ScriptScope(game);
        try (scope) { new MonkeyTravel(new MonkeyMadness()).ape(); }
                assertEquals(destinations.subList(start,destinations.size()),reached);
            }
    }

    @Test public void poisonRecoveryResumesTheExistingSailingJourney()
    {
        QuestScenario game = sailing(new Tile(2894,2726));
        List<String> calls = new ArrayList<>();
        game.input = (type,args) -> {
            calls.add(type);
            if (type.equals("consumable.cure_poison")) return;
            assertEquals("walk.to",type);
            assertEquals(Map.of("dialogue",true,"poisoned",true),args.get("interrupt_on"));
            assertEquals(new Tile(2803,2706),tile((Map<?,?>)args.get("destination")));
            if (calls.size()==2)
            {
                assertFalse(args.containsKey("resume"));
                game.receipt=Map.of("status","interrupted","reason","poisoned","continuation","sailing");
            }
            else
            {
                assertEquals("sailing",args.get("resume"));
                game.position=tile((Map<?,?>)args.get("destination"));
            }
        };
        ScriptScope scope = new ScriptScope(game);
        try (scope) { new MonkeyTravel(new MonkeyMadness()).ape(); }
        assertEquals(List.of("consumable.cure_poison","walk.to","consumable.cure_poison","walk.to"),calls);
    }

    @Test public void initialLumdoAndWaydarQuestConversationsRemainWithTheQuest()
    {
        QuestScenario game = sailing(new Tile(2894,2726));
        game.varbits.put(125L,0);
        game.npc(1453,"Lumdo",game.position,"Talk-to");
        game.npc(1446,"Waydar",game.position,"Talk-to");
        List<Integer> spoken = new ArrayList<>();
        game.input = (type,args) -> {
            if (type.equals("npc.interact"))
            {
                int id=((Number)args.get("id")).intValue();
                spoken.add(id);
                game.varbits.put(125L,id==1453?2:3);
            }
            else if (type.equals("walk.to")) game.position=tile((Map<?,?>)args.get("destination"));
            else assertEquals("consumable.cure_poison",type);
        };
        ScriptScope scope = new ScriptScope(game);
        try (scope) { new MonkeyTravel(new MonkeyMadness()).ape(); }
        assertEquals(List.of(1453,1446),spoken);
        assertEquals(new Tile(2803,2706),game.position);
    }

    @Test public void dungeonExitUsesTheLadderIfItsPreferredJewelleryInputIsRejected()
    {
        QuestScenario game = new QuestScenario("waterfall",65,3,new Tile(2548,9565));
        game.inventory.put(2552,1);
        List<String> inputs = new ArrayList<>();
        game.input = (type,args) -> {
            inputs.add(type);
            if (type.equals("item.interact")) game.receipt=Map.of("status","rejected");
            else
            {
                assertEquals("walk.to",type);
                game.position=tile((Map<?,?>)args.get("destination"));
            }
        };
        ScriptScope scope = new ScriptScope(game);
        try (scope) { new Waterfall().execute("leave_gnome"); }
        assertEquals(List.of("item.interact","walk.to"),inputs);
        assertEquals(new Tile(2533,3156),game.position);
    }

    @Test public void aVerifiedJewelleryExitNeedsNoLadderTrip()
    {
        QuestScenario game = new QuestScenario("waterfall",65,3,new Tile(2548,9565));
        game.inventory.put(2552,1);
        List<String> inputs = new ArrayList<>();
        game.input = (type,args) -> {
            inputs.add(type);
            if (type.equals("item.interact")) game.dialogue=Map.of("open",true,"type","choice",
                "options",List.of(Map.of("index",1L,"text","Castle Wars Arena")));
            else
            {
                assertEquals("dialogue.choose",type);
                game.position=new Tile(2440,3089);
            }
        };
        ScriptScope scope = new ScriptScope(game);
        try (scope) { new Waterfall().execute("leave_gnome"); }
        assertEquals(List.of("item.interact","dialogue.choose"),inputs);
        assertEquals(new Tile(2440,3089),game.position);
    }

    @Test public void failedExitsKeepBothTransportFailuresForDiagnosis()
    {
        for (boolean jewellery : List.of(false,true))
        {
            QuestScenario game = new QuestScenario("waterfall",65,3,new Tile(2548,9565));
            if (jewellery) game.inventory.put(2552,1);
            game.input = (type,args) -> game.receipt=Map.of("status","rejected");
            ScriptScope scope = new ScriptScope(game);
        try (scope)
            {
                try { new Waterfall().execute("leave_gnome"); fail("No exit was verified"); }
                catch (IllegalStateException expected)
                {
                    assertEquals("Travel did not reach (2533, 3156, 0)",expected.getMessage());
                    assertEquals(jewellery?1:0,expected.getSuppressed().length);
                    if (jewellery) assertEquals("Teleport jewellery could not be rubbed",expected.getSuppressed()[0].getMessage());
                }
            }
            assertEquals(new Tile(2548,9565),game.position);
        }
    }

    private static QuestScenario sailing(Tile origin)
    {
        QuestScenario game = new QuestScenario("monkey_madness_i",365,3,origin);
        game.inventory.put(2552,1);
        game.varbits.put(125L,3);
        return game;
    }

    private static void assertJourney(Tile origin, Tile destination, int within, Consumer<QuestScenario> task)
    {
        QuestScenario game = new QuestScenario("test",0,0,origin);
        List<String> inputs = new ArrayList<>();
        game.input = (type,args) -> {
            inputs.add(type);
            assertEquals("The catalog must submit a complete destination journey", "walk.to",type);
            assertEquals(destination,tile((Map<?,?>)args.get("destination")));
            assertEquals(within,((Number)args.get("within")).intValue());
            game.position=destination;
            game.npc(8019,"King Narnode",destination,"Talk-to");
            game.npc(1444,"Daero",destination,"Talk-to");
        };
        ScriptScope scope = new ScriptScope(game);
        try (scope) { task.accept(game); }
        assertEquals(List.of("walk.to"),inputs);
        assertEquals(destination,game.position);
    }

    private static Tile tile(Map<?,?> value)
    {
        return new Tile(((Number)value.get("x")).intValue(),((Number)value.get("y")).intValue(),((Number)value.get("plane")).intValue());
    }
}
