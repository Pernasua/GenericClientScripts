package com.genericclient.scripts;

import static org.junit.Assert.*;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Supply;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.Test;

public class SupplyContractsTest
{
    @Test public void purchasesOnlyAfterTheExchangeWindowOpensAndPreservesTheReserve()
    {
        java.util.concurrent.atomic.AtomicInteger offerChecks = new java.util.concurrent.atomic.AtomicInteger();
        CatalogEnvironment game = exchange(offerChecks,Map.of("status","placed","result","ge_offer_pending","quantity_bought",1,"spent",3000),1);
        game.run();
        assertEquals(Map.of("supplied",2),game.result);
        assertEquals(5_000_000,(int)game.bank.get(995));
        assertFalse(game.inventory.containsKey(995));
        assertEquals("Pending offers must be resumed before supplies are declared ready",2,offerChecks.get());
    }

    @Test public void terminalRejectionsAreNotRetriedOrReportedAsSupplied()
    {
        for (String status : List.of("rejected","placed"))
        {
            java.util.concurrent.atomic.AtomicInteger checks = new java.util.concurrent.atomic.AtomicInteger();
            CatalogEnvironment game = exchange(checks,Map.of("status",status,"result","invalid_offer"),1);
            try { game.run(); fail("A terminal purchase result was retried"); }
            catch (IllegalStateException expected)
            {
                assertEquals("Purchase failed: Dragon bones (" + status + ": invalid_offer)",expected.getMessage());
            }
            assertEquals(1,checks.get());
            assertFalse(game.bank.containsKey(536));
            assertNull(game.result);
        }
    }

    @Test public void anOfferThatStaysOpenStopsAfterThreeChecks()
    {
        java.util.concurrent.atomic.AtomicInteger checks = new java.util.concurrent.atomic.AtomicInteger();
        CatalogEnvironment game = exchange(checks,Map.of("status","placed","result","ge_offer_pending"),3);
        try { game.run(); fail("An open offer was checked without a bound"); }
        catch (IllegalStateException expected) { assertEquals("Purchase offer was still open after three checks: Dragon bones",expected.getMessage()); }
        assertEquals(3,checks.get());
        assertFalse(game.bank.containsKey(536));
        assertNull(game.result);
    }

    private static CatalogEnvironment exchange(java.util.concurrent.atomic.AtomicInteger offerChecks, Map<String,Object> reply, int replies)
    {
        CatalogEnvironment game = new CatalogEnvironment(new WorkflowScript()
        {
            @Override protected Object runWorkflow()
            {
                Supplies.ensure(List.of(new Supply(536,"Dragon bones",2,3000)),true);
                return Map.of("supplied",Supplies.owned(536));
            }
        },Map.of())
        {
            private int opening;
            private boolean exchangeOpen;
            @Override public Object read(String subject, Map<String,Object> query)
            {
                if (subject.equals("npcs"))
                {
                    List<Object> rows=new ArrayList<>((List<?>)super.read(subject,query));
                    rows.add(Map.of("identity",3L,"id",2148,"index",2,"name","Grand Exchange Clerk",
                        "world",Map.of("x",3165,"y",3491,"plane",0),"actions",List.of("Exchange")));
                    return rows;
                }
                if (subject.equals("widgets")) return exchangeOpen ? List.of(Map.of("id",30474240,"index",-1,"visible",true)) : List.of();
                return super.read(subject,query);
            }
            @Override public void sleep(long millis)
            {
                super.sleep(millis);
                if (opening > 0 && --opening == 0) exchangeOpen=true;
            }
            @Override public Map<String,Object> execute(String type, Map<String,Object> arguments, long timeout)
            {
                if (type.equals("npc.interact") && arguments.get("action").equals("Exchange"))
                {
                    opening=3;
                    return Map.of("status","dispatched");
                }
                if (type.equals("ge.buy"))
                {
                    assertTrue("The purchase must wait for visible exchange state",exchangeOpen);
                    assertEquals(2,arguments.get("quantity"));
                    assertEquals(3000,arguments.get("maximum_unit_price"));
                    assertEquals(5_000_000L,arguments.get("minimum_cash_reserve"));
                    if (offerChecks.incrementAndGet() <= replies)
                    {
                        // A terminal response can follow an offer that already reserved the coins.
                        inventory.remove(995);
                        return reply;
                    }
                    bank.put(536,2);
                    return Map.of("status","complete");
                }
                if (type.equals("ui.close")) { exchangeOpen=false; return Map.of("status","complete"); }
                return super.execute(type,arguments,timeout);
            }
        };
        game.bank.put(995,5_006_000);
        return game;
    }
}
