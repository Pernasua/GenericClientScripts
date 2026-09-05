package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.recovery.SafetyNet;
import java.util.List;
import java.util.Map;
import org.junit.Test;

public class SafetyNetContractsTest
{
    @Test public void aLoggedOutAccountDoesNotAttemptRecovery()
    {
        SceneScenario game=attackedAccount();
        game.loggedIn=false;
        assertEquals(600,game.run());
        assertEquals(0,game.gameInputs);
        assertNull(game.activity);
        assertNull(game.result);
    }

    @Test public void recoveryRequiresBothActiveCombatAndHealthBelowThirtyPercent()
    {
        for (boolean attacked : List.of(false,true))
        {
            SceneScenario game=attackedAccount();
            if (attacked) game.hitpoints=30;
            else game.npcs.get(0).put("interacting","Another player");
            assertEquals(600,game.run());
            assertEquals(0,game.gameInputs);
            assertEquals("manual",game.activity);
        }
    }

    @Test public void aConfirmedEscapeCompletesTheSafetyNet()
    {
        for (String result : List.of("emergency_escape_complete","emergency_food_and_escape_complete"))
        {
            SceneScenario game=attackedAccount();
            game.input=(type,args) ->
            {
                assertEquals("safety.recover",type);
                game.receipt=Map.of("status","complete","result",result);
            };
            assertEquals(-1,game.run());
            assertEquals(Map.of("status","complete","result","safety_net_active_combat_escape"),game.result);
            assertEquals(1,game.gameInputs);
        }
    }

    @Test public void pendingRecoveryAndDispatchedFoodDoNotCauseAnotherMeal()
    {
        for (String result : List.of("emergency_consumable_dispatched","safety_recovery_already_running"))
        {
            SceneScenario game=attackedAccount();
            game.input=(type,args) ->
            {
                assertEquals("safety.recover",type);
                game.receipt=Map.of("status","complete","result",result);
            };
            assertEquals(600,game.run());
            assertEquals(1,game.gameInputs);
            assertNull(game.result);
            assertEquals(Map.of("Safety Net","Awaiting manual control","HP","29%"),game.overlayRows);
        }
    }

    @Test public void unavailableEmergencyRecoveryUsesOnlyCarriedEdibleFood()
    {
        for (boolean food : List.of(false,true))
        {
            SceneScenario game=attackedAccount();
            if (!food) game.inventory.remove(379);
            game.inventory.put(6206,1);
            game.input=(type,args) ->
            {
                if (type.equals("safety.recover")) game.receipt=Map.of("status","rejected","result","no_emergency_route");
                else
                {
                    assertEquals("item.interact",type);
                    assertEquals(379,args.get("id"));
                    assertEquals("Eat",args.get("action"));
                }
            };
            assertEquals(600,game.run());
            assertEquals(food ? 2 : 1,game.gameInputs);
            assertNull(game.result);
        }
    }

    private static SceneScenario attackedAccount()
    {
        SceneScenario game=new SceneScenario(new SafetyNet());
        game.hitpoints=29; game.maximumHitpoints=100;
        game.inventory.put(379,1);
        game.inventoryActions.put(379,List.of("Eat"));
        game.npc(123,"Attacker",3166,3491,"Attack").put("interacting","Player");
        return game;
    }
}
