package com.genericclient.scripts;

import static org.junit.Assert.*;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class QuestContractsTest
{
    @Test public void fightArenaCheckpointStopsAfterSammySpawnsTheOgre()
    {
        QuestScenario game = new QuestScenario("fight_arena",17,6,new Tile(2602,3153));
        game.inventory.putAll(Map.of(1381,1,562,100,557,300,379,18));
        game.npc(12031,"Sammy",new Tile(2602,3153),"Talk-to");
        game.input = (type,args) ->
        {
            assertEquals("No additional input is authorized after the next checkpoint","npc.interact",type);
            assertEquals("Talk-to",args.get("action"));
            game.transitions.add(() -> game.npc(1225,"Khazard ogre",new Tile(2600,3162),"Attack"));
        };
        game.run();
        assertEquals("checkpoint",((Map<?,?>)game.result).get("status"));
        assertEquals(6,game.stage);
        assertEquals(1,game.actions.stream().filter("npc.interact"::equals).count());
    }

    @Test public void orbTowerHasFoodProtectionBeforeClimbingOrSearching()
    {
        QuestScenario game = new QuestScenario("tree_gnome_village",111,5,new Tile(2503,3255));
        game.inventory.putAll(Map.of(1381,1,562,100,557,300,379,18));
        game.object(16683,"Ladder",new Tile(2503,3255),"Climb-up");
        game.input = (type,args) ->
        {
            assertEquals("object.interact",type);
            assertEquals(false,game.behavior.get("auto_retaliate"));
            assertEquals(true,game.behavior.get("emergency_escape"));
            assertEquals(10,game.safety.get("minimum_hitpoints"));
            assertEquals(java.util.List.of(Map.of("id",379,"action","Eat","heal_amount",12)),game.safety.get("consumables"));
            if (args.get("action").equals("Climb-up")) game.transitions.add(() ->
            {
                game.position = new Tile(2503,3255,1);
                game.objects.clear();
                game.object(2182,"Chest",new Tile(2503,3255,1),"Search");
            });
            else
            {
                assertEquals("Search",args.get("action"));
                game.transitions.add(() -> game.inventory.put(587,1));
            }
        };
        game.run();
        assertEquals("checkpoint",((Map<?,?>)game.result).get("status"));
        assertEquals(1,(int)game.inventory.get(587));
    }

    @Test public void trackersAreApproachedOnlyWhenOutOfSightAndNeverOntoTheirTile()
    {
        for (boolean sighted : new boolean[]{true,false})
        {
            QuestScenario game = new QuestScenario("tree_gnome_village",111,4,new Tile(2524,3261));
            game.varbits.put(599L,1);
            game.varbits.put(601L,1);
            game.npc(4976,"Tracker gnome 2",new Tile(2524,3257),"Talk-to");
            game.npcs.get(0).put("line_of_sight",sighted);
            game.object(2181,"Ballista",new Tile(2509,3211),"Fire");
            AtomicInteger approaches = new AtomicInteger();
            game.input = (type,args) ->
            {
                if (type.equals("walk.to"))
                {
                    Map<?,?> destination = (Map<?,?>)args.get("destination");
                    if (destination.get("y").equals(3257))
                    {
                        assertEquals("The fenced tracker's own tile is unreachable",1,args.get("within"));
                        approaches.incrementAndGet();
                        game.position = new Tile(2524,3256);
                    }
                    else game.position = new Tile((Integer)destination.get("x"),(Integer)destination.get("y"));
                }
                else if (type.equals("npc.interact")) game.transitions.add(() -> game.varbits.put(600L,1));
                else
                {
                    assertEquals("object.interact",type);
                    game.transitions.add(() -> game.stage = 5);
                }
            };
            game.run();
            assertEquals(Map.of("status","checkpoint","quest","tree_gnome_village","stage",5),game.result);
            assertEquals(sighted ? 0 : 1,approaches.get());
        }
    }

    @Test public void witchCheckpointLeavesTheReadyShedFightForACompletionRun()
    {
        QuestScenario game = new QuestScenario("witchs_house",226,5,new Tile(2933,3463));
        game.inventory.put(2411,1);
        game.run();
        assertEquals("checkpoint",((Map<?,?>)game.result).get("status"));
        assertTrue("Shed checkpoint must not prepare or initiate the experiment",game.actions.isEmpty());
    }

    @Test public void failedWarlordPositioningEscapesBeforeReportingFailure()
    {
        QuestScenario game = new QuestScenario("tree_gnome_village",111,7,new Tile(2456,3301));
        game.inventory.putAll(Map.of(2552,1,562,100,557,300,379,18));
        game.equipment.put(1381,1);
        game.npc(7622,"Khazard warlord",new Tile(2452,3301),"Attack");
        game.input = (type,args) ->
        {
            switch (type)
            {
                case "combat.set_autocast": break;
                case "walk.to": throw new IllegalStateException("Warlord approach rejected");
                case "item.interact":
                    assertEquals("Rub",args.get("action"));
                    assertEquals(2552,args.get("id"));
                    game.dialogue = Map.of("type","choice","open",true,"options",java.util.List.of(Map.of("index",1L,"text","Castle Wars Arena")));
                    break;
                case "dialogue.choose":
                    assertEquals("Castle Wars Arena",args.get("text"));
                    game.position = new Tile(2440,3089);
                    break;
                default: throw new AssertionError("Unexpected encounter input: " + type);
            }
        };
        try { game.run(); fail("Failed positioning was accepted"); }
        catch (IllegalStateException expected) { assertEquals("Warlord approach rejected",expected.getMessage()); }
        assertEquals(new Tile(2440,3089),game.position);
    }
}
