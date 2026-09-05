package com.genericclient.scripts;

import static org.junit.Assert.*;

import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class QuestDialogueContractsTest
{
    @Test public void alreadyCompletedQuestsDoNotPrepareOrReplayTheirStages()
    {
        Map<String,Integer> quests=Map.of("witchs_house",226,"waterfall",65,"tree_gnome_village",111,
            "fight_arena",17,"the_grand_tree",150,"monkey_madness_i",365);
        for (Map.Entry<String,Integer> quest : quests.entrySet())
        {
            QuestScenario game=new QuestScenario(quest.getKey(),quest.getValue(),0,new Tile(3165,3491));
            game.finished=true;
            game.scope="complete";
            game.run();
            assertEquals(Map.of("status","complete","quest",quest.getKey().equals("waterfall") ? "waterfall_quest" : quest.getKey()),game.result);
            assertTrue(game.actions.isEmpty());
        }
    }

    @Test public void stoppingSafelyRequiresAnObservedTeleportArrival()
    {
        for (boolean arrives : List.of(false,true))
        {
            QuestScenario game=montai();
            game.inventory.put(2552,1);
            game.buttons.add("stop_safely");
            game.input=(type,args) ->
            {
                if (type.equals("item.interact"))
                {
                    assertEquals("Rub",args.get("action"));
                    game.transitions.add(() -> game.dialogue=Map.of("type","choice","open",true,
                        "options",List.of(Map.of("index",1L,"text","Castle Wars Arena"))));
                }
                else
                {
                    assertEquals("dialogue.choose",type);
                    assertEquals("Castle Wars Arena",args.get("text"));
                    if (arrives) game.transitions.add(() -> game.position=new Tile(2440,3089));
                }
            };
            if (arrives)
            {
                game.run();
                assertEquals(Map.of("status","stopped","quest","tree_gnome_village"),game.result);
                assertEquals(new Tile(2440,3089),game.position);
            }
            else
            {
                try { game.run(); fail("An unobserved teleport completed the safe stop"); }
                catch (IllegalStateException failure) { assertEquals("Teleport arrival was not observed",failure.getMessage()); }
                assertNull(game.result);
            }
            assertFalse(game.actions.contains("npc.interact"));
        }
    }

    @Test public void messageBoxesAdvanceOncePerNewObservation()
    {
        QuestScenario game=montai();
        game.sleepTicks(4,Map.of());
        game.message("mesbox","An earlier conversation.");
        game.sleep(600);
        AtomicInteger boxes=new AtomicInteger();
        game.input=(type,args) ->
        {
            if (type.equals("npc.interact")) game.message("mesbox","Commander Montai needs help.");
            else
            {
                assertEquals("ui.key",type);
                assertEquals("SPACE",args.get("key"));
                assertEquals("tree_gnome_village.talk",game.intents.current);
                if (boxes.incrementAndGet()==1)
                {
                    game.transitions.add(() -> {});
                    game.transitions.add(() -> game.message("mesbox","Find the trackers."));
                }
                else
                {
                    assertEquals("A box must not advance twice",2,boxes.get());
                    game.transitions.add(() -> game.stage=4);
                }
            }
        };
        game.run();
        assertEquals(2,boxes.get());
        assertEquals(Map.of("status","checkpoint","quest","tree_gnome_village","varp",4),game.result);
        assertNull(game.intents.current);
    }

    @Test public void unexpectedAndRejectedChoicesStopTheConversation()
    {
        for (boolean offered : List.of(false,true))
        {
            QuestScenario game=montai();
            String choice=offered ? "I'll try my best." : "Leave me alone.";
            game.input=(type,args) ->
            {
                if (type.equals("npc.interact")) game.dialogue=Map.of("type","choice","open",true,
                    "options",List.of(Map.of("index",1L,"text",choice)));
                else
                {
                    assertEquals("dialogue.choose",type);
                    assertEquals("I'll try my best.",args.get("text"));
                    game.receipt=Map.of("status","rejected");
                }
            };
            try { game.run(); fail("The failed dialogue was accepted"); }
            catch (IllegalStateException failure) { assertEquals("Unexpected quest dialogue: ["+choice+"]",failure.getMessage()); }
            assertEquals(offered ? 1 : 0,game.actions.stream().filter("dialogue.choose"::equals).count());
            assertEquals(3,game.stage);
            assertNull(game.intents.current);
        }
    }

    @Test public void observedCompletionClearsTheQuestFoodGuard()
    {
        QuestScenario game=new QuestScenario("tree_gnome_village",111,8,new Tile(2541,3170));
        game.inventory.put(588,1);
        game.npc(4963,"King Bolren",new Tile(2541,3170),"Talk-to");
        game.scope="complete";
        game.input=(type,args) ->
        {
            if (type.equals("npc.interact")) game.dialogue=Map.of("type","continue","open",true);
            else
            {
                assertEquals("dialogue.continue",type);
                game.transitions.add(() -> { game.stage=9; game.finished=true; });
            }
        };
        game.run();
        assertEquals(Map.of("status","complete","quest","tree_gnome_village","varp",9),game.result);
        assertTrue(game.safety.isEmpty());
        assertEquals("safety.clear",game.actions.get(game.actions.size()-1));
    }

    private static QuestScenario montai()
    {
        QuestScenario game=new QuestScenario("tree_gnome_village",111,3,new Tile(2523,3208));
        game.npc(4964,"Commander Montai",new Tile(2523,3208),"Talk-to");
        return game;
    }
}
