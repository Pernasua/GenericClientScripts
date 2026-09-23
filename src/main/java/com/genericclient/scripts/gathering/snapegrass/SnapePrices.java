package com.genericclient.scripts.gathering.snapegrass;

import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Read-only public price lookup; neither the script worker nor paint waits on the network. */
final class SnapePrices implements AutoCloseable
{
    private static final String ENDPOINT = "https://prices.runescape.wiki/api/v1/osrs/latest?id=231";
    private static final Pattern ITEM = Pattern.compile("\\\"231\\\"\\s*:\\s*\\{([^{}]*)}");
    private ScheduledExecutorService worker;
    private volatile int price;

    synchronized void start()
    {
        if (worker != null) return;
        worker = Executors.newSingleThreadScheduledExecutor(task ->
        {
            Thread thread = new Thread(task,"snape-grass-price");
            thread.setDaemon(true);
            return thread;
        });
        worker.scheduleWithFixedDelay(this::refresh,0,60,TimeUnit.SECONDS);
    }

    int get() { return price; }

    private void refresh()
    {
        HttpURLConnection connection = null;
        try
        {
            connection = (HttpURLConnection)new URL(ENDPOINT).openConnection();
            connection.setConnectTimeout(3000);
            connection.setReadTimeout(3000);
            connection.setRequestProperty("User-Agent","GenericClient-SnapeGrass/1.0 (read-only collection overlay)");
            if (connection.getResponseCode() != 200) return;
            try (InputStream stream = connection.getInputStream())
            {
                byte[] body = stream.readNBytes(65_537);
                if (body.length <= 65_536) price = parse(new String(body,StandardCharsets.UTF_8));
            }
        }
        catch (IOException ignored)
        {
            // Retain the last quote on an unavailable feed; a price failure never changes gameplay.
        }
        finally { if (connection != null) connection.disconnect(); }
    }

    static int parse(String response) throws IOException
    {
        Matcher item = ITEM.matcher(response);
        if (!item.find()) throw new IOException("Snape grass price is absent");
        String fields = item.group(1);
        return (int)((field(fields,"high") + field(fields,"low")) / 2L);
    }

    private static long field(String json, String name) throws IOException
    {
        Matcher matcher = Pattern.compile("\\\""+name+"\\\"\\s*:\\s*(null|[0-9]+)(?=\\s*[,}])").matcher(json+"}");
        if (!matcher.find()) throw new IOException("Missing price field: " + name);
        if (matcher.group(1).equals("null")) return 0;
        try
        {
            long value = Long.parseLong(matcher.group(1));
            if (value > Integer.MAX_VALUE) throw new IOException("Price exceeds the item-price range");
            return value;
        }
        catch (NumberFormatException invalid) { throw new IOException("Invalid price",invalid); }
    }

    @Override public synchronized void close()
    {
        if (worker != null) worker.shutdownNow();
        worker = null;
    }
}
