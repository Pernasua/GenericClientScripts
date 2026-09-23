package com.genericclient.scripts;

import static org.junit.Assert.*;

import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class RomeoAndJulietTest
{
    @Test public void recoversALostLetterBeforeReturningToRomeo()
    {
        QuestScenario game = new QuestScenario("romeo__juliet",144,20,new Tile(3158,3427,1));
        game.npc(5035,"Juliet",new Tile(3158,3427,1),"Talk-to");
        game.npc(5037,"Romeo",new Tile(3211,3422),"Talk-to");
        game.object(11799,"Staircase",new Tile(3156,3435,1),"Climb-down");
        game.input = (type,args) ->
        {
            if (type.equals("walk.to"))
            {
                Map<?,?> point = (Map<?,?>)args.get("destination");
                assertEquals(game.position.getZ(),point.get("plane"));
                game.position = new Tile(((Number)point.get("x")).intValue(),((Number)point.get("y")).intValue(),game.position.getZ());
            }
            else if (type.equals("object.interact"))
                game.transitions.add(() -> game.position = new Tile(3156,3435));
            else
            {
                assertEquals("npc.interact",type);
                if (args.get("id").equals(5035)) game.transitions.add(() -> game.inventory.put(755,1));
                else
                {
                    assertEquals(5037,args.get("id"));
                    assertTrue("Romeo must receive the recovered letter",game.inventory.containsKey(755));
                    game.transitions.add(() -> { game.inventory.remove(755); game.stage = 30; });
                }
            }
        };
        game.run();
        assertEquals(Map.of("status","checkpoint","quest","romeo__juliet","stage",30),game.result);
        assertFalse(game.inventory.containsKey(755));
    }

    @Test public void unsupportedQuestStagesFailBeforeIssuingInput()
    {
        for (String quest : List.of("romeo__juliet","goblin_diplomacy"))
        {
            QuestScenario game = new QuestScenario(quest,quest.equals("romeo__juliet") ? 144 : 62,7,new Tile(3211,3422));
            game.inventory.putAll(Map.of(286,1,287,1,288,1));
            try { game.run(); fail("An unsupported quest stage was executed"); }
            catch (IllegalStateException expected) { assertTrue(expected.getMessage().startsWith("Unsupported ")); }
            assertTrue(game.actions.isEmpty());
        }
    }

    @Test public void aFinishedJournalStillWaitsForTheLoadedWorldAfterTheFinalCutscene()
    {
        QuestScenario game = new QuestScenario("romeo__juliet",144,100,new Tile(10317,841,1));
        game.finished = true;
        game.instanced = true;
        game.scope = "complete";
        game.dialogue = Map.of("type","continue","open",true,"options",List.of());
        game.input = (type,args) ->
        {
            assertEquals("dialogue.continue",type);
            game.transitions.add(() ->
            {
                game.position = new Tile(3208,3429);
                game.instanced = false;
                game.sceneAvailable = false;
                game.dialogue = Map.of("type","closed","open",false,"options",List.of());
            });
            game.transitions.add(() -> {});
            game.transitions.add(() -> game.sceneAvailable = true);
        };
        game.run();
        assertTrue("Completion must wait until the ordinary scene is loaded",game.sceneAvailable);
        assertEquals(Map.of("status","complete","quest","romeo__juliet","stage",100),game.result);
    }

    @Test public void resumesThePotionCutsceneAndWaitsForTheReturnToVarrock()
    {
        QuestScenario game = new QuestScenario("romeo__juliet",144,50,new Tile(10317,841,1));
        game.instanced = true;
        game.dialogue = Map.of("type","continue","open",true,"options",List.of());
        java.util.concurrent.atomic.AtomicInteger pages = new java.util.concurrent.atomic.AtomicInteger();
        game.input = (type,args) ->
        {
            assertEquals("A cutscene must not travel or replace its consumed potion","dialogue.continue",type);
            if (pages.incrementAndGet() == 1)
                game.receipt = Map.of("status","rejected","result","dialogue_continue_not_visible");
            else
            {
                game.transitions.add(() ->
                {
                    game.stage = 60;
                    game.dialogue = Map.of("type","closed","open",false,"options",List.of());
                });
                game.transitions.add(() -> { game.position = new Tile(3158,3425,1); game.instanced = false; });
            }
        };
        game.run();
        assertEquals(2,pages.get());
        assertEquals(new Tile(3158,3425,1),game.position);
        assertEquals(Map.of("status","checkpoint","quest","romeo__juliet","stage",60),game.result);
    }

    @Test public void collectsBankedBerriesBeforeAskingForThePotion()
    {
        QuestScenario game = new QuestScenario("romeo__juliet",144,40,new Tile(3165,3491));
        game.bankOpen = true;
        game.bank.put(753,1);
        game.npc(5036,"Apothecary",new Tile(3195,3405),"Talk-to");
        game.input = (type,args) ->
        {
            if (type.equals("bank.loadout"))
            {
                assertEquals(List.of(Map.of("id",753,"quantity",1)),args.get("items"));
                game.inventory.put(753,game.bank.remove(753));
                game.bankOpen = false;
                game.receipt = Map.of("status","complete");
            }
            else if (type.equals("walk.to")) game.position = new Tile(3195,3405);
            else
            {
                assertEquals("npc.interact",type);
                assertEquals(1,(int)game.inventory.get(753));
                game.transitions.add(() -> game.stage = 50);
            }
        };
        game.run();
        assertEquals(Map.of("status","checkpoint","quest","romeo__juliet","stage",50),game.result);
        assertFalse(game.actions.contains("ge.buy"));
    }

    @Test public void approachesJulietThroughTheDoorBeforeTalking()
    {
        QuestScenario game = new QuestScenario("romeo__juliet",144,10,new Tile(3158,3427,1));
        game.npc(5035,"Juliet",new Tile(3158,3425,1),"Talk-to");
        game.input = (type,args) ->
        {
            if (type.equals("walk.to"))
            {
                assertEquals(0,args.get("within"));
                assertEquals(Map.of("x",3158,"y",3425,"plane",1),args.get("destination"));
                game.position = new Tile(3158,3425,1);
            }
            else
            {
                assertEquals("npc.interact",type);
                assertEquals("The room door must be traversed before talking",new Tile(3158,3425,1),game.position);
                game.transitions.add(() -> { game.inventory.put(755,1); game.stage = 20; });
            }
        };
        game.run();
        assertEquals(Map.of("status","checkpoint","quest","romeo__juliet","stage",20),game.result);
    }

    @Test public void completesTheQuestAcrossBothVisitsUpstairsAndThePotionConversation()
    {
        QuestScenario game = new QuestScenario("romeo__juliet",144,0,new Tile(3211,3422));
        game.scope = "complete";
        game.inventory.put(753,1);
        game.npc(5037,"Romeo",new Tile(3211,3422),"Talk-to");
        game.npc(5035,"Juliet",new Tile(3158,3427,1),"Talk-to");
        game.npc(5038,"Father Lawrence",new Tile(3254,3483),"Talk-to");
        game.npc(5036,"Apothecary",new Tile(3195,3405),"Talk-to");
        game.object(11797,"Staircase",new Tile(3157,3435),"Climb-up");
        game.object(11799,"Staircase",new Tile(3156,3435,1),"Climb-down");
        game.input = (type,args) ->
        {
            if (type.equals("walk.to"))
            {
                Map<?,?> point = (Map<?,?>)args.get("destination");
                assertEquals("Walking alone cannot change floors",game.position.getZ(),point.get("plane"));
                if (point.get("y").equals(3435))
                    assertEquals("Stair approaches must cross the room boundary",1,args.get("within"));
                game.position = new Tile(((Number)point.get("x")).intValue(),((Number)point.get("y")).intValue(),
                    ((Number)point.get("plane")).intValue());
            }
            else if (type.equals("object.interact"))
            {
                boolean up = args.get("action").equals("Climb-up");
                game.transitions.add(() -> {});
                game.transitions.add(() -> {});
                game.transitions.add(() -> game.position = new Tile(3156,3435,up ? 1 : 0));
            }
            else if (type.equals("npc.interact"))
                game.transitions.add(() -> game.dialogue = Map.of("open",true,"type","continue"));
            else
            {
                assertEquals("dialogue.continue",type);
                game.dialogue = Map.of("open",false);
                game.transitions.add(() -> advance(game));
            }
        };
        game.run();
        assertEquals(Map.of("status","complete","quest","romeo__juliet","stage",100),game.result);
        assertFalse(game.inventory.containsKey(755));
        assertFalse(game.inventory.containsKey(756));
        assertEquals("finish",game.overlayRows.get("Phase"));
        assertEquals(4,game.actions.stream().filter("object.interact"::equals).count());
    }

    private static void advance(QuestScenario game)
    {
        if (game.stage == 10) game.inventory.put(755,1);
        if (game.stage == 20) game.inventory.remove(755);
        if (game.stage == 50 && !game.inventory.containsKey(756))
        {
            game.inventory.remove(753);
            game.inventory.put(756,1);
        }
        else if (game.stage == 60)
        {
            game.stage = 100;
            game.finished = true;
        }
        else
        {
            if (game.stage == 50) game.inventory.remove(756);
            game.stage += 10;
        }
    }

    @Test public void startingTheQuestWaitsForObservedProgress()
    {
        QuestScenario game = new QuestScenario("romeo__juliet",144,0,new Tile(3211,3422));
        game.npc(5037,"Romeo",game.position,"Talk-to");
        game.input = (type,args) ->
        {
            if (type.equals("npc.interact"))
                game.transitions.add(() -> game.dialogue = Map.of("type","choice","open",true,
                    "options",List.of(Map.of("index",1L,"text","Yes, ok, I'll let her know."))));
            else
            {
                assertEquals("dialogue.choose",type);
                assertEquals("Yes, ok, I'll let her know.",args.get("text"));
                game.transitions.add(() -> { game.stage = 10; game.dialogue = Map.of("open",false); });
            }
        };
        game.run();
        assertEquals(Map.of("status","checkpoint","quest","romeo__juliet","stage",10),game.result);
        assertEquals(10,game.stage);
        assertNull(game.intents.current);
    }
}
