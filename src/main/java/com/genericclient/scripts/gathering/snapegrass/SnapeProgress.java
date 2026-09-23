package com.genericclient.scripts.gathering.snapegrass;

import com.genericclient.script.Automation;
import java.text.NumberFormat;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import org.dreambot.api.Client;
import org.dreambot.api.methods.container.impl.Inventory;

/** Positive observed inventory gains, not accepted clicks; deposits do not reduce the total. */
final class SnapeProgress implements AutoCloseable
{
    private final SnapePrices prices = new SnapePrices();
    private Integer previous;
    private long collected;
    private long started = System.nanoTime();

    synchronized void start()
    {
        previous = null;
        collected = 0;
        started = System.nanoTime();
        prices.start();
    }

    synchronized void observe()
    {
        if (!Client.isLoggedIn()) return;
        int current = Inventory.count(SnapeBanking.GRASS);
        if (previous != null && current > previous) collected += current - previous;
        previous = current;
    }

    synchronized void publish()
    {
        Automation.overlay(rows(collected,prices.get(),System.nanoTime()-started));
    }

    static Map<String,String> rows(long collected, int price, long elapsedNanos)
    {
        long gross = collected * price;
        double hourly = elapsedNanos > 0 ? gross * 3_600_000_000_000.0 / elapsedNanos : 0;
        NumberFormat numbers = NumberFormat.getIntegerInstance(Locale.US);
        Map<String,String> rows = new LinkedHashMap<>();
        rows.put("Collected",Long.toString(collected));
        rows.put("Profit",numbers.format(gross));
        rows.put("Hourly",numbers.format(hourly));
        return rows;
    }

    @Override public void close() { prices.close(); }
}
