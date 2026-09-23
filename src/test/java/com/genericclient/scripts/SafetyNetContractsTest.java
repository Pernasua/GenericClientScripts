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

    @Test public void aConfiguredGuardOwnsTheMeal()
    {
        Map<String,String> outcomes=Map.of(
            "emergency_consumable_dispatched","dispatched",
            "emergency_escape_no_longer_needed","dispatched",
            "no_approved_emergency_consumable_available","rejected",
            "safety_recovery_already_running","rejected",
            "safety_recovery_disabled_by_script","complete",
            "safety_recovery_not_needed_no_emergency","complete");
        for (Map.Entry<String,String> outcome : outcomes.entrySet())
        {
            SceneScenario game=attackedAccount();
            game.input=(type,args) ->
            {
                assertEquals("safety.recover",type);
                game.receipt=Map.of("status",outcome.getValue(),"result",outcome.getKey());
            };
            assertEquals(600,game.run());
            assertEquals(1,game.gameInputs);
            assertNull(game.result);
            assertEquals(Map.of("Safety Net","Awaiting manual control","HP","29%"),game.overlayRows);
        }
    }

    @Test public void withoutAConfiguredGuardTheSafetyNetEatsOnlyCarriedEdibleFood()
    {
        for (boolean food : List.of(false,true))
        {
            SceneScenario game=attackedAccount();
            if (!food) game.inventory.remove(379);
            game.inventory.put(6206,1);
            game.input=(type,args) ->
            {
                if (type.equals("safety.recover")) game.receipt=Map.of("status","rejected","result","safety_net_not_configured");
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
