package com.genericclient.scripts.quests;

import static org.junit.Assert.*;

import com.genericclient.script.ScriptScope;
import com.genericclient.scripts.QuestScenario;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class QuestTransportJourneysTest
{
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
                    assertEquals(carrying ? WorkflowScript.NO_DISCRETIONARY : Map.of(),game.policy);
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

    @Test public void sailingStopsAtTheInterruptionLimit()
    {
        QuestScenario game = sailing(new Tile(2894,2726));
        List<String> calls = new ArrayList<>();
        game.input = (type,args) -> {
            calls.add(type);
            if (type.equals("walk.to")) game.receipt=Map.of("status","interrupted","reason","poisoned","continuation","sailing");
        };
        ScriptScope scope = new ScriptScope(game);
        try (scope) { new MonkeyTravel(new MonkeyMadness()).ape(); fail("Endless poison interruptions were accepted"); }
        catch (IllegalStateException expected) { assertEquals("Ape Atoll sailing interruption limit reached",expected.getMessage()); }
        assertEquals(24,calls.stream().filter("walk.to"::equals).count());
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

    private static QuestScenario sailing(Tile origin)
    {
        QuestScenario game = new QuestScenario("monkey_madness_i",365,3,origin);
        game.inventory.put(2552,1);
        game.varbits.put(125L,3);
        return game;
    }

    private static Tile tile(Map<?,?> value)
    {
        return new Tile(((Number)value.get("x")).intValue(),((Number)value.get("y")).intValue(),((Number)value.get("plane")).intValue());
    }
}
