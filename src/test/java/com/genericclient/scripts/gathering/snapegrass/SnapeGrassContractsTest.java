package com.genericclient.scripts.gathering.snapegrass;

import static org.junit.Assert.*;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.junit.Test;

public class SnapeGrassContractsTest
{
    @Test public void routeCoordinatesMatchTheRecoveredWorkflowNotANearestItemHeuristic()
    {
        assertEquals(List.of(GrassScenario.point(2540,3765),GrassScenario.point(2542,3765),
            GrassScenario.point(2546,3763),GrassScenario.point(2552,3757),GrassScenario.point(2553,3754),
            GrassScenario.point(2553,3751)),SnapeRoute.SPAWNS.stream()
                .map(tile -> GrassScenario.point(tile.getX(),tile.getY())).collect(Collectors.toList()));
    }

    @Test public void bankDestinationsRespectObservedQuestAndVarbitPrerequisites()
    {
        GrassScenario scene=new GrassScenario();
        scene.quests.put("corsair",Map.of("name","The Corsair Curse","state","finished","progress",100));
        scene.varbits.put(5800L,1);
        com.genericclient.script.ScriptScope scope=new com.genericclient.script.ScriptScope(scene);
        try(scope)
        {
            BankRequirements requirements=new BankRequirements();
            assertTrue(requirements.allows("finished","THE_CORSAIR_CURSE"));
            assertFalse(requirements.allows("finished","CHILDREN_OF_THE_SUN"));
            assertTrue(requirements.allows("bit_eq","5800:1"));
            assertFalse(requirements.allows("bit_eq","99999:1"));
            assertTrue(BankLocations.available().contains(GrassScenario.point(2442,3084)));
        }
    }

    @Test public void noRingFallbackWalksToThePlannedBankBeforeRestocking()
    {
        GrassScenario scene=new GrassScenario(); scene.equipment.clear();
        scene.world=GrassScenario.point(2460,3100); scene.nearestDestination=GrassScenario.point(2442,3084);
        scene.bank.put(GrassScenario.RING,1); scene.run();
        assertEquals(1,scene.calls("walk.nearest").size());
        assertEquals(1,scene.calls("walk.to").size());
        assertTrue(scene.actions.indexOf("walk.to") < scene.actions.indexOf("bank.withdraw"));
        assertTrue(scene.equipment.containsKey(GrassScenario.RING));
    }

    @Test public void failedNoRingRouteDoesNotPretendToArriveOrWithdraw()
    {
        GrassScenario scene=new GrassScenario(); scene.equipment.clear();
        scene.world=GrassScenario.point(2460,3100); scene.nearestDestination=GrassScenario.point(2442,3084);
        scene.routeFails=true; scene.run();
        assertTrue(scene.calls("bank.withdraw").isEmpty());
        assertTrue(scene.calls("item.interact").isEmpty());
        assertEquals(GrassScenario.point(2460,3100),scene.world);
    }

    @Test public void collectsExactNorthToSouthRouteAndOnlyAdvancesWhenTargetIsAbsent()
    {
        GrassScenario scene=new GrassScenario();
        SnapeRoute.SPAWNS.forEach(tile -> scene.spawn(tile.getX(),tile.getY()));
        for (int i=0;i<11;i++) assertEquals(30,scene.run());
        assertEquals(SnapeRoute.SPAWNS.stream().map(tile -> GrassScenario.point(tile.getX(),tile.getY())).collect(Collectors.toList()),
            scene.calls("ground_item.take").stream().map(row -> row.get("world")).collect(Collectors.toList()));
        assertEquals(6,scene.inventory.get(GrassScenario.GRASS).intValue());
        assertEquals("6",scene.overlay.get("Collected"));
    }

    @Test public void ignoresUnlistedGrassAndWalksNorthWithoutResettingThePass()
    {
        GrassScenario scene=new GrassScenario();
        scene.spawn(2553,3751);
        for(int i=0;i<5;i++) scene.run();
        scene.ground.clear(); scene.spawn(2541,3764);
        scene.run();
        assertEquals(GrassScenario.point(2540,3765),scene.world);
        scene.spawn(2553,3751); scene.spawn(2540,3765); scene.run();
        assertEquals(GrassScenario.point(2553,3751),scene.calls("ground_item.take").get(0).get("world"));
    }

    @Test public void waitsWhileMovingAndDoesNotCountDispatchAsCollection()
    {
        GrassScenario scene=new GrassScenario(); scene.spawn(2540,3765); scene.moving=true;
        scene.run(); assertTrue(scene.calls("ground_item.take").isEmpty());
        scene.moving=false; scene.delayPickup=true; scene.run();
        assertEquals(1,scene.calls("ground_item.take").size()); assertEquals("0",scene.overlay.get("Collected"));
        scene.rejectTake=true; scene.run();
        assertEquals("0",scene.overlay.get("Collected"));
    }

    @Test public void fullInventoryTeleportsBanksAllGearAndRestocksAllTablets()
    {
        GrassScenario scene=new GrassScenario(); scene.inventory.put(GrassScenario.TABLET,1);
        scene.inventory.put(GrassScenario.GRASS,27); scene.equipment.put(GrassScenario.BOOTS,1);
        scene.bank.put(GrassScenario.TABLET,200); scene.chest();
        scene.run(); assertEquals(GrassScenario.point(2444,3083),scene.world);
        scene.run();
        assertEquals(27,scene.bank.get(GrassScenario.GRASS).intValue());
        assertEquals(1,scene.bank.get(GrassScenario.BOOTS).intValue());
        assertFalse(scene.equipment.containsKey(GrassScenario.BOOTS));
        assertEquals(1,scene.equipment.get(GrassScenario.RING).intValue());
        assertEquals(200,scene.inventory.get(GrassScenario.TABLET).intValue());
        assertFalse(scene.bankOpen);
        assertTrue(scene.calls("bank.withdraw").stream().anyMatch(row -> row.get("id").equals(GrassScenario.TABLET) && Boolean.TRUE.equals(row.get("all"))));
        assertTrue(scene.waits.containsAll(List.of(6,7)));
        assertEquals("0",scene.overlay.get("Collected")); // Starting inventory is not a gain.
    }

    @Test public void earlyClosePreservesTheOriginalSkippedDepositQuirk()
    {
        GrassScenario scene=new GrassScenario(); scene.world=GrassScenario.point(2444,3083); scene.bankOpen=true;
        scene.inventory.put(GrassScenario.GRASS,2); scene.equipment.put(GrassScenario.BOOTS,1);
        scene.run();
        assertTrue(scene.calls("bank.deposit_equipment").isEmpty());
        assertTrue(scene.calls("bank.deposit").isEmpty());
        assertEquals(2,scene.inventory.get(GrassScenario.GRASS).intValue());
        assertTrue(scene.equipment.containsKey(GrassScenario.BOOTS));
        assertEquals("bank.close",scene.actions.get(0));
    }

    @Test public void doesNotTopUpTabletsOrStripRingOnlyEquipmentUnnecessarily()
    {
        GrassScenario scene=new GrassScenario(); scene.world=GrassScenario.point(2444,3083); scene.bankOpen=true;
        scene.inventory.put(GrassScenario.TABLET,2); scene.inventory.put(GrassScenario.GRASS,27);
        scene.bank.put(GrassScenario.TABLET,200); scene.run();
        assertTrue(scene.calls("bank.withdraw").isEmpty());
        assertTrue(scene.calls("bank.deposit_equipment").isEmpty());
        assertEquals(1,scene.inventory.get(GrassScenario.TABLET).intValue());
    }

    @Test public void supplyOnlyBankingDoesNotDepositUnrelatedInventory()
    {
        GrassScenario scene=new GrassScenario(); scene.world=GrassScenario.point(2444,3083); scene.bankOpen=true;
        scene.inventory.put(GrassScenario.TABLET,0); scene.inventory.put(379,1); scene.bank.put(GrassScenario.TABLET,42);
        scene.run();
        assertEquals(1,scene.inventory.get(379).intValue());
        assertTrue(scene.calls("bank.deposit").isEmpty());
        assertEquals(41,scene.inventory.get(GrassScenario.TABLET).intValue());
    }

    @Test public void bankBoundaryAtExactlyTwentyOneTilesHasNoInventedRecovery()
    {
        GrassScenario scene=new GrassScenario(); scene.world=GrassScenario.point(2465,3083);
        scene.inventory.put(GrassScenario.GRASS,27); scene.chest(); scene.run();
        assertTrue(scene.trace.isEmpty());
    }

    @Test public void anchorBoundaryAtExactlyThirtyTilesNeitherTeleportsNorCollects()
    {
        GrassScenario scene=new GrassScenario(); scene.world=GrassScenario.point(2576,3763); scene.spawn(2540,3765);
        scene.run(); assertTrue(scene.trace.isEmpty());
    }

    @Test public void runsOnlyAtOneHundredWithBankAndExchangeClosed()
    {
        GrassScenario scene=new GrassScenario(); scene.moving=true; scene.runEnabled=false; scene.runButton();
        scene.runEnergy=9900; scene.run(); assertTrue(scene.calls("ui.click").isEmpty());
        scene.runEnergy=10000; scene.geOpen=true; scene.run(); assertTrue(scene.calls("ui.click").isEmpty());
        scene.geOpen=false; scene.run(); assertTrue(scene.runEnabled); assertEquals(1,scene.calls("ui.click").size());
        scene.runEnabled=false; scene.bankOpen=true; scene.equipment.clear(); scene.run();
        assertEquals(1,scene.calls("ui.click").size());
    }

    @Test public void wearsCarriedRingBeforeTestingFullInventory()
    {
        GrassScenario scene=new GrassScenario(); scene.equipment.clear(); scene.inventory.put(GrassScenario.RING,1);
        scene.inventory.put(GrassScenario.GRASS,26); scene.moving=true; scene.run();
        assertTrue(scene.calls("equipment.interact").isEmpty());
        assertTrue(scene.equipment.containsKey(GrassScenario.RING));
        assertEquals("Wear",scene.calls("item.interact").get(0).get("action"));
    }

    @Test public void lastRingChargeUsesNearestBankFallbackInTheSamePass()
    {
        GrassScenario scene=new GrassScenario(); scene.consumeLastRing=true; scene.inventory.put(GrassScenario.GRASS,27);
        scene.bank.put(GrassScenario.RING,1); scene.chest(); scene.run();
        assertTrue(scene.nearestBankOpens > 0);
        assertEquals(27,scene.bank.get(GrassScenario.GRASS).intValue());
        assertTrue(scene.equipment.containsKey(GrassScenario.RING));
    }

    @Test public void absentSuppliesRemainInBankWithoutPurchasingOrStopping()
    {
        GrassScenario scene=new GrassScenario(); scene.bankOpen=true; scene.inventory.clear(); scene.equipment.clear();
        for(int i=0;i<3;i++) assertEquals(30,scene.run());
        assertTrue(scene.bankOpen); assertTrue(scene.trace.isEmpty());
    }

    @Test public void collectionContinuesWhenBankAttemptCannotProceed()
    {
        GrassScenario scene=new GrassScenario(); scene.inventory.clear(); scene.equipment.clear(); scene.spawn(2540,3765);
        scene.run();
        assertEquals(1,scene.inventory.get(GrassScenario.GRASS).intValue());
    }

    @Test public void rejectedTeleportStillResetsPassAsInSource()
    {
        GrassScenario scene=new GrassScenario(); scene.spawn(2553,3751);
        for(int i=0;i<5;i++) scene.run();
        scene.world=GrassScenario.point(2444,3083); scene.rejectTeleport=true; scene.run();
        scene.world=GrassScenario.point(2546,3763); scene.spawn(2540,3765); scene.run();
        assertEquals(GrassScenario.point(2540,3765),scene.calls("ground_item.take").get(0).get("world"));
    }

    @Test public void collectionCounterSurvivesDepositsAndHasNoHundredItemLimit()
    {
        GrassScenario scene=new GrassScenario(); scene.moving=true; scene.run();
        for(int i=0;i<5;i++)
        {
            scene.inventory.put(GrassScenario.GRASS,25); scene.run();
            scene.inventory.remove(GrassScenario.GRASS); scene.run();
        }
        assertEquals("125",scene.overlay.get("Collected"));
        assertEquals(30,scene.run());
    }

    @Test public void logoutDoesNotIssueInputOrTurnRestoredInventoryIntoGains()
    {
        GrassScenario scene=new GrassScenario(); scene.moving=true; scene.inventory.put(GrassScenario.GRASS,4); scene.run();
        scene.loggedIn=false; assertEquals(300,scene.run());
        scene.loggedIn=true; scene.run();
        assertEquals("0",scene.overlay.get("Collected")); assertTrue(scene.trace.isEmpty());
    }

    @Test public void countersValueGrossCollectionNotNetProfit()
    {
        assertEquals(Map.of("Collected","10","Profit","5,000","Hourly","10,000"),
            SnapeProgress.rows(10,500,1_800_000_000_000L));
        assertEquals("0",SnapeProgress.rows(10,500,0).get("Hourly"));
    }

    @Test public void priceReadsAverageHighAndLowAndNullsLikeOriginal() throws Exception
    {
        assertEquals(501,SnapePrices.parse("{\"data\":{\"231\":{\"high\":503,\"low\":500,\"highTime\":1}}}"));
        assertEquals(250,SnapePrices.parse("{\"data\":{\"231\":{\"high\":null,\"low\":500}}}"));
    }

    @Test public void invalidPricePayloadsAreRejectedRatherThanFabricated()
    {
        for(String invalid:List.of("{}","{\"232\":{\"high\":1,\"low\":2}}",
            "{\"231\":{\"high\":-1,\"low\":2}}","{\"231\":{\"high\":999999999999999999999999,\"low\":2}}"))
        {
            try { SnapePrices.parse(invalid); fail("Accepted an invalid quote"); }
            catch(java.io.IOException expected) { assertNotNull(expected.getMessage()); }
        }
    }
}
