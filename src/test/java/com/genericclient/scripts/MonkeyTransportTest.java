package com.genericclient.scripts;

import static org.junit.Assert.*;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class MonkeyTransportTest
{
    @Test public void backpackChatterCannotConsumeAForeignSpeakersResponse()
    {
        QuestScenario game=carryingFromZoo();
        game.dialogue=chatter("The monkey in your backpack...");
        game.input=(type,args) ->
        {
            assertEquals("dialogue.continue",type);
            assertEquals("A foreign NPC's dialogue must remain untouched","The monkey in your backpack...",game.dialogue.get("speaker"));
            game.transitions.add(() -> game.dialogue=chatter("Kruk"));
        };
        try { game.run(); fail("Foreign response was accepted"); }
        catch (IllegalStateException expected) { assertTrue(expected.getMessage(),expected.getMessage().contains("Kruk")); }
        assertEquals("Kruk",game.dialogue.get("speaker"));
        assertFalse(game.actions.contains("walk.to"));
    }

    @Test public void anUnownedDialogueStopsAnInterruptedJourneyWithoutAnotherInput()
    {
        QuestScenario game=carryingFromZoo();
        game.input=(type,args) ->
        {
            assertEquals("walk.to",type);
            assertEquals("Only the original journey may dispatch",1,game.actions.stream().filter("walk.to"::equals).count());
            game.dialogue=chatter("Kruk");
            game.receipt=Map.of("status","interrupted","reason","dialogue","continuation","foreign-1");
        };
        try { game.run(); fail("Foreign dialogue was treated as monkey chatter"); }
        catch (IllegalStateException expected) { assertTrue(expected.getMessage(),expected.getMessage().contains("Kruk")); }
        assertEquals("Kruk",game.dialogue.get("speaker"));
        assertFalse(game.actions.contains("dialogue.continue"));
    }

    @Test public void missingContinuationStopsBeforeAdvancingBackpackChatter()
    {
        QuestScenario game=carryingFromZoo();
        game.input=(type,args) ->
        {
            assertEquals("walk.to",type);
            game.dialogue=chatter("The monkey in your backpack...");
            game.receipt=Map.of("status","interrupted","reason","dialogue");
        };
        try { game.run(); fail("Unresumable journey restarted"); }
        catch (IllegalStateException expected) { assertTrue(expected.getMessage().contains("Monkey transport journey failed")); }
        assertFalse(game.actions.contains("dialogue.continue"));
        assertEquals(1,game.actions.stream().filter("walk.to"::equals).count());
    }

    private static QuestScenario carryingFromZoo()
    {
        QuestScenario game=new QuestScenario("monkey_madness_i",365,4,new Tile(2530,3360));
        game.inventory.put(4033,1);
        game.equipment.putAll(Map.of(4021,1,4031,1));
        return game;
    }

    private static Map<String,Object> chatter(String speaker)
    {
        return Map.of("open",true,"type","continue","speaker",speaker,"options",java.util.List.of());
    }

    @Test public void carriedMonkeyResumesOwnedChatterAndPreservesPolicyAcrossTravelHelpers()
    {
        QuestScenario game = new QuestScenario("monkey_madness_i",365,4,new Tile(2530,3360));
        game.inventory.putAll(Map.of(4033,1,379,10,2552,1));
        game.equipment.putAll(Map.of(4021,1,4031,1));
        game.varbits.put(125L,3);
        game.npc(8019,"King Narnode",new Tile(2466,3495),"Talk-to");
        game.object(4458,"Ladder",new Tile(2466,3495),"Climb-up");
        java.util.concurrent.atomic.AtomicInteger zooJourneys=new java.util.concurrent.atomic.AtomicInteger();
        java.util.concurrent.atomic.AtomicInteger chatterLines=new java.util.concurrent.atomic.AtomicInteger();
        game.input = (type,args) ->
        {
            assertNotEquals("Transport must count as owned automation","manual",game.activity);
            assertEquals(WorkflowScript.NO_DISCRETIONARY,game.policy);
            assertEquals(false,game.behavior.get("emergency_escape"));
            switch (type)
            {
                case "object.interact":
                    assertEquals(4458,args.get("id"));
                    game.transitions.add(() ->
                    {
                        game.position=new Tile(2466,3495,1);
                        game.objects.clear(); game.npcs.clear();
                        game.npc(1444,"Daero",new Tile(2482,3486,1),"Travel");
                    });
                    break;
                case "walk.to":
                    Map<?,?> target=(Map<?,?>)args.get("destination");
                    Tile destination=new Tile(((Number)target.get("x")).intValue(),((Number)target.get("y")).intValue(),((Number)target.get("plane")).intValue());
                    if (destination.equals(new Tile(2466,3482)))
                    {
                        assertTrue("The zoo journey starts from the observed position",((java.util.List<?>)args.get("via")).isEmpty());
                        if (zooJourneys.getAndIncrement()==0)
                        {
                            assertFalse(args.containsKey("resume"));
                            game.dialogue=chatter("The monkey in your backpack...");
                            game.receipt=Map.of("status","interrupted","reason","dialogue","continuation","monkey-1","dialogue",game.dialogue);
                            break;
                        }
                        assertEquals("monkey-1",args.get("resume"));
                        assertEquals("closed",game.dialogue.get("type"));
                    }
                    game.position=destination;
                    break;
                case "dialogue.continue":
                    assertEquals(false,args.get("reading"));
                    if (chatterLines.getAndIncrement()==0)
                        game.transitions.add(() -> game.dialogue=chatter("Player"));
                    else game.transitions.add(() -> game.dialogue=Map.of("open",false,"type","closed","options",java.util.List.of()));
                    break;
                case "npc.interact":
                    int id=((Number)args.get("id")).intValue();
                    game.transitions.add(() ->
                    {
                        game.npcs.clear();
                        if (id==1444) { game.position=new Tile(2648,4513); game.npc(1446,"Waydar",game.position,"Talk-to"); }
                        else if (id==1446) { game.position=new Tile(2900,2705); game.npc(1453,"Lumdo",game.position,"Talk-to"); }
                        else { assertEquals(1453,id); game.position=new Tile(2770,2707); }
                    });
                    break;
                case "consumable.cure_poison": break;
                default: throw new AssertionError("Unexpected monkey transport input: " + type);
            }
        };
        game.run();
        assertEquals("checkpoint",((Map<?,?>)game.result).get("status"));
        assertEquals(new Tile(2722,2767),game.position);
        assertTrue(game.inventory.containsKey(4033));
        assertTrue(game.phaseActivities.stream().noneMatch("manual"::equals));
        assertTrue(game.phaseOptions.stream().allMatch(Map.of("policy",WorkflowScript.NO_DISCRETIONARY)::equals));
        assertEquals(false,game.behavior.get("emergency_escape"));
        assertEquals(2,zooJourneys.get());
        assertEquals(2,chatterLines.get());
    }
}
