package com.genericclient.scripts;

import static org.junit.Assert.*;

import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import com.genericclient.script.ScriptScope;
import com.genericclient.scripts.shared.Conversations;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class QuestDialogueContractsTest
{
    @Test public void anUnchangingConversationStopsAtItsBoundedLimit()
    {
        QuestScenario game = new QuestScenario("goblin_diplomacy",62,0,new Tile(2958,3512));
        game.dialogue = Map.of("open",true,"type","continue","options",List.of());
        game.input = (type,args) -> assertEquals("dialogue.continue",type);
        ScriptScope scope = new ScriptScope(game);
        try (scope)
        {
            try { Conversations.finish(); fail("An unchanging conversation was reported as finished"); }
            catch (IllegalStateException expected) { assertEquals("Dialogue did not finish",expected.getMessage()); }
        }
        assertTrue(game.actions.size() <= 80);
    }

    @Test public void conversationHistoryRecordsOnlyTheReplyThatWasApplied()
    {
        for (boolean changed : List.of(false,true))
        {
            QuestScenario game = new QuestScenario("monkey_madness_i",365,0,new Tile(2464,3492,1));
            List<Map<String,Object>> options = List.of(Map.of("index",1L,"text","Leave..."),Map.of("index",2L,"text","How will I travel?"));
            game.input = (type,args) ->
            {
                assertEquals("dialogue.choose",type);
                assertEquals(Map.of("index",2L,"text","How will I travel?"),args);
                if (changed) game.receipt = Map.of("status","rejected","result","exact_dialogue_choice_not_visible");
                else game.stage = 3;
            };
            ScriptScope scope = new ScriptScope(game);
            try (scope)
            {
                assertEquals(changed ? null : "How will I travel?",Conversations.choose(options,"How will I travel?","Leave..."));
            }
            assertEquals(changed ? 0 : 3,game.stage);
        }
    }

    @Test public void aContinueChangingToAChoiceIsRetriedButOtherRejectionsStop()
    {
        for (boolean changed : List.of(false,true))
        {
            QuestScenario game = new QuestScenario("goblin_diplomacy",62,0,new Tile(2958,3512));
            game.inventory.putAll(Map.of(286,1,287,1,288,1));
            game.npc(669,"General Bentnoze",game.position,"Talk-to");
            game.input = (type,args) ->
            {
                if (type.equals("npc.interact"))
                    game.dialogue = Map.of("open",true,"type","continue","options",List.of());
                else if (type.equals("dialogue.continue"))
                {
                    game.receipt = Map.of("status","rejected","result",changed ? "dialogue_is_choice" : "hover_has_no_matching_action");
                    game.dialogue = Map.of("open",true,"type","choice","options",List.of(Map.of("index",1L,"text","Yes, he looks fat.")));
                }
                else
                {
                    assertEquals("dialogue.choose",type);
                    assertEquals("Yes, he looks fat.",args.get("text"));
                    game.transitions.add(() -> game.stage = 3);
                }
            };
            if (changed)
            {
                game.run();
                assertEquals(Map.of("status","checkpoint","quest","goblin_diplomacy","stage",3),game.result);
            }
            else
            {
                try { game.run(); fail("An input rejection was ignored"); }
                catch (IllegalStateException expected) { assertTrue(expected.getMessage().startsWith("Dialogue did not continue:")); }
                assertEquals(0,game.stage);
            }
        }
    }

    @Test public void aChoiceChangingToContinueBetweenReadsDoesNotBecomeAnEmptyChoiceFailure()
    {
        QuestScenario game = new QuestScenario("goblin_diplomacy",62,0,new Tile(2958,3512));
        game.inventory.putAll(Map.of(286,1,287,1,288,1));
        game.npc(669,"General Bentnoze",game.position,"Talk-to");
        AtomicInteger reads = new AtomicInteger();
        game.beforeRead = subject ->
        {
            if (subject.equals("dialogue") && reads.incrementAndGet() >= 2)
                game.dialogue = Map.of("open",true,"type","continue","options",List.of());
        };
        game.input = (type,args) ->
        {
            if (type.equals("npc.interact"))
                game.dialogue = Map.of("open",true,"type","choice","options",
                    List.of(Map.of("index",1L,"text","Do you want me to pick an armour colour for you?")));
            else if (type.equals("dialogue.choose"))
                game.receipt = Map.of("status","rejected","result","exact_dialogue_choice_not_visible");
            else
            {
                assertEquals("dialogue.continue",type);
                game.transitions.add(() -> game.stage = 3);
            }
        };
        game.run();
        assertEquals(Map.of("status","checkpoint","quest","goblin_diplomacy","stage",3),game.result);
        assertEquals(List.of("npc.interact","dialogue.choose","dialogue.continue"),game.actions);
    }

    @Test public void anAlreadyCompletedQuestDoesNotPrepareOrReplayItsStages()
    {
        QuestScenario game=new QuestScenario("witchs_house",226,0,new Tile(3165,3491));
        game.finished=true;
        game.scope="complete";
        game.run();
        assertEquals(Map.of("status","complete","quest","witchs_house"),game.result);
        assertTrue(game.actions.isEmpty());
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

    @Test public void stoppingSafelyWithoutJewelleryWalksOutOfTheQuestArea()
    {
        QuestScenario game=montai();
        game.buttons.add("stop_safely");
        game.input=(type,args) ->
        {
            assertEquals("walk.to",type);
            assertEquals(Map.of("x",2505,"y",3190,"plane",0),args.get("destination"));
            game.position=new Tile(2505,3190);
        };
        game.run();
        assertEquals(Map.of("status","stopped","quest","tree_gnome_village"),game.result);
        assertEquals(new Tile(2505,3190),game.position);
        assertEquals(1,game.actions.stream().filter("walk.to"::equals).count());
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
        assertEquals(Map.of("status","checkpoint","quest","tree_gnome_village","stage",4),game.result);
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
            catch (IllegalStateException failure)
            {
                assertEquals(offered ? "Dialogue choice failed: " + choice : "Unexpected dialogue choices: [" + choice + "]",failure.getMessage());
            }
            assertEquals(offered ? 1 : 0,game.actions.stream().filter("dialogue.choose"::equals).count());
            assertEquals(3,game.stage);
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
        assertEquals(Map.of("status","complete","quest","tree_gnome_village","stage",9),game.result);
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
