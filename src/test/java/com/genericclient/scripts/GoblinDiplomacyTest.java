package com.genericclient.scripts;

import static org.junit.Assert.*;

import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;
import org.junit.Test;

public class GoblinDiplomacyTest
{
    @Test public void missingDyesAreLoadedWithoutReplacingCarriedMail()
    {
        for (Map<Integer,Integer> stock : List.of(Map.of(1769,1,1767,1,288,3),Map.of(1767,1,288,2)))
        {
            QuestScenario game = unknownBank(stock);
            game.stage = stock.containsKey(1769) ? 3 : 4;
            game.inventory.put(288,game.bank.remove(288));
            game.run();
            assertTrue(game.finished);
            assertTrue(game.inventory.isEmpty());
        }
    }

    @Test public void itemsRemovedDuringTheIntentBoundaryCannotBeUsed()
    {
        for (int removed : List.of(1769,288))
        {
            QuestScenario game = village();
            game.stage = 3;
            game.inventory.putAll(Map.of(1769,1,288,2,287,1));
            game.enteringIntent = name ->
            {
                if (name.equals("goblin_diplomacy.dye")) game.inventory.remove(removed);
            };
            try { game.run(); fail("The action used an item removed after the phase was selected"); }
            catch (IllegalStateException expected) { assertEquals("Goblin mail dyeing failed",expected.getMessage()); }
            assertTrue(game.actions.isEmpty());
            assertEquals(3,game.stage);
        }
    }

    @Test public void resumesAtTheRequestedColourWithoutRepeatingConsumedArmour()
    {
        for (int stage : List.of(3,4))
        {
            QuestScenario game = village();
            game.stage = stage;
            game.varpFlags = 512;
            game.inventory.put(288,2);
            game.inventory.put(stage == 3 ? 1769 : 1767,1);
            if (stage == 3) game.inventory.put(287,1);
            game.run();
            assertTrue(game.finished);
            assertTrue(game.inventory.isEmpty());
            assertEquals(1,game.actions.stream().filter("item.use_on_item"::equals).count());
        }
    }

    @Test public void openingAnUnknownBankReusesColouredMailAndWithdrawsOnlyTheMissingMaterials()
    {
        for (Map<Integer,Integer> stock : List.of(Map.of(286,1,1767,1,288,2),Map.of(1769,1,1767,1,288,3)))
        {
            QuestScenario game = unknownBank(stock);
            game.run();
            assertTrue(game.finished);
            assertTrue(game.inventory.isEmpty());
            assertFalse(game.actions.contains("ge.buy"));
        }
    }

    private static QuestScenario unknownBank(Map<Integer,Integer> stock)
    {
        QuestScenario game = village();
        game.stage = 3;
        game.position = new Tile(3165,3491);
        game.bankKnown = false;
        game.bank.putAll(stock);
        game.npc(1633,"Banker",new Tile(3164,3491),"Bank");
        java.util.function.BiConsumer<String,Map<String,Object>> conversations = game.input;
        game.input = (type,args) ->
        {
            if (type.equals("npc.interact") && args.get("action").equals("Bank"))
            {
                game.bankOpen = true;
                game.bankKnown = true;
            }
            else if (type.equals("bank.loadout"))
            {
                assertTrue("The bank must be observed before calculating supplies",game.bankKnown);
                Map<Integer,Integer> loadout = new java.util.LinkedHashMap<>();
                for (Object value : (List<?>)args.get("items"))
                {
                    Map<?,?> item = (Map<?,?>)value;
                    loadout.put(((Number)item.get("id")).intValue(),((Number)item.get("quantity")).intValue());
                }
                assertEquals(stock,loadout);
                game.inventory.putAll(loadout);
                game.bank.clear();
                game.bankOpen = false;
                game.receipt = Map.of("status","complete");
            }
            else if (type.equals("walk.to")) game.position = new Tile(2958,3512);
            else conversations.accept(type,args);
        };
        return game;
    }

    @Test public void dyeRejectionAndAnUnobservedItemChangeStopBeforePresentingArmour()
    {
        for (boolean rejected : List.of(false,true))
        {
            QuestScenario game = village();
            game.stage = 3;
            game.inventory.put(288,3);
            game.inventory.put(1769,1);
            game.inventory.put(1767,1);
            game.input = (type,args) ->
            {
                assertEquals("item.use_on_item",type);
                if (rejected) game.receipt = Map.of("status","rejected");
            };
            try { game.run(); fail("Dyeing without an observed result advanced the quest"); }
            catch (IllegalStateException expected)
            {
                assertEquals(rejected ? "Goblin mail dyeing failed" : "Dyed goblin mail was not observed",expected.getMessage());
            }
            assertEquals(3,game.stage);
            assertEquals(3,(int)game.inventory.get(288));
            assertFalse(game.actions.contains("npc.interact"));
        }
    }

    @Test public void aSafeStopDoesNotStartEitherQuestOrSpendSupplies()
    {
        for (String quest : List.of("romeo__juliet","goblin_diplomacy"))
        {
            QuestScenario game = new QuestScenario(quest,quest.equals("romeo__juliet") ? 144 : 62,0,new Tile(3211,3422));
            game.buttons.add("stop_safely");
            game.run();
            assertEquals(Map.of("status","stopped","quest",quest),game.result);
            assertEquals(0,game.stage);
            assertTrue(game.actions.isEmpty());
        }
    }

    @Test public void preparationUsesBankedDyedMailAndDoesNotRepeatEarlierColours()
    {
        for (int stage : List.of(0,4,5))
        {
            QuestScenario game = village();
            game.stage = stage;
            game.position = new Tile(3170,3488);
            game.bankOpen = true;
            game.bank.put(288,1);
            game.bank.put(286,1);
            game.bank.put(287,1);
            java.util.function.BiConsumer<String,Map<String,Object>> conversations = game.input;
            game.input = (type,args) ->
            {
                if (type.equals("bank.loadout"))
                {
                    assertEquals("Preparation must reach the bank counters",new Tile(3165,3491),game.position);
                    for (Object value : (List<?>)args.get("items"))
                    {
                        Map<?,?> item = (Map<?,?>)value;
                        int id = ((Number)item.get("id")).intValue();
                        assertEquals(1,item.get("quantity"));
                        assertTrue("Only unfinished colours should be withdrawn",id == 288 || (id == 287 && stage < 5) || stage == 0);
                        game.inventory.put(id,game.bank.remove(id));
                    }
                    game.bankOpen = false;
                    game.receipt = Map.of("status","complete");
                }
                else if (type.equals("walk.to"))
                {
                    Map<?,?> destination = (Map<?,?>)args.get("destination");
                    if (destination.get("x").equals(3165))
                    {
                        assertEquals(2,args.get("within"));
                        game.position = new Tile(3165,3491);
                    }
                    else game.position = new Tile(2958,3512);
                }
                else conversations.accept(type,args);
            };
            game.run();
            assertEquals(Map.of("status","complete","quest","goblin_diplomacy","stage",6),game.result);
            assertTrue(game.inventory.isEmpty());
            assertFalse(game.actions.contains("ge.buy"));
            assertFalse(game.actions.contains("item.use_on_item"));
        }
    }

    @Test public void presentsOrangeBlueAndBrownMailInOrder()
    {
        QuestScenario game = village();
        game.inventory.put(288,1);
        game.inventory.put(286,1);
        game.inventory.put(287,1);
        game.run();
        assertEquals(Map.of("status","complete","quest","goblin_diplomacy","stage",6),game.result);
        assertTrue(game.inventory.isEmpty());
        assertEquals(4,game.actions.stream().filter("npc.interact"::equals).count());
    }

    @Test public void dyesTwoMailsAndKeepsOneBrown()
    {
        QuestScenario game = village();
        game.inventory.put(288,3);
        game.inventory.put(1767,1);
        game.inventory.put(1769,1);
        game.run();
        assertEquals(Map.of("status","complete","quest","goblin_diplomacy","stage",6),game.result);
        assertTrue(game.inventory.isEmpty());
        assertEquals(2,game.actions.stream().filter("item.use_on_item"::equals).count());
    }

    private static QuestScenario village()
    {
        QuestScenario game = new QuestScenario("goblin_diplomacy",62,0,new Tile(2958,3512));
        game.scope = "complete";
        game.npc(669,"General Bentnoze",game.position,"Talk-to");
        game.input = (type,args) ->
        {
            if (type.equals("item.use_on_item"))
            {
                int dye = ((Number)args.get("item_id")).intValue();
                assertEquals(288,args.get("target_item_id"));
                assertTrue(dye == 1767 || dye == 1769);
                game.transitions.add(() ->
                {
                    assertEquals(1,(int)game.inventory.remove(dye));
                    game.inventory.compute(288,(id,count) -> count-1);
                    game.inventory.put(dye == 1767 ? 287 : 286,1);
                });
            }
            else if (type.equals("npc.interact"))
            {
                assertEquals(Map.of(0,"begin",3,"orange_mail",4,"blue_mail",5,"brown_mail").get(game.stage),game.overlayRows.get("Phase"));
                game.transitions.add(() -> game.dialogue = Map.of("open",true,"type","choice",
                    "options",List.of(Map.of("index",1L,"text",choice(game.stage)))));
            }
            else
            {
                assertEquals("dialogue.choose",type);
                assertEquals(choice(game.stage),args.get("text"));
                game.transitions.add(() ->
                {
                    game.dialogue = Map.of("open",false,"type","closed","options",List.of());
                    if (game.stage == 0) game.stage = 3;
                    else
                    {
                        int mail = game.stage + 283;
                        assertEquals(1,(int)game.inventory.remove(mail));
                        game.stage++;
                        if (game.stage == 6)
                        {
                            game.transitions.add(() -> {});
                            game.transitions.add(() -> {});
                            game.transitions.add(() -> game.finished = true);
                        }
                    }
                });
            }
        };
        return game;
    }

    private static String choice(int stage)
    {
        switch (stage)
        {
            case 0: return "Yes, he looks fat.";
            case 3: return "I have some orange armour here.";
            case 4: return "I have some blue armour here.";
            case 5: return "I have some brown armour here.";
            default: throw new AssertionError("Unexpected goblin stage " + stage);
        }
    }
}
