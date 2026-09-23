package com.genericclient.scripts.gathering.snapegrass;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** Source-derived bank destinations. Unsupported runtime prerequisites are documented, not guessed. */
final class BankLocations
{
    private static final List<String[]> LOCATIONS = load();

    private BankLocations() {}

    static List<Map<String,Integer>> available()
    {
        BankRequirements requirements = new BankRequirements();
        List<Map<String,Integer>> points = new ArrayList<>();
        for (String[] spot : LOCATIONS)
            if (requirements.allows(spot[4],spot[5]))
                points.add(Map.of("x",Integer.parseInt(spot[1]),"y",Integer.parseInt(spot[2]),
                    "plane",Integer.parseInt(spot[3])));
        return points;
    }

    private static List<String[]> load()
    {
        InputStream stream = BankLocations.class.getResourceAsStream("banks.tsv");
        if (stream == null) throw new IllegalStateException("Missing source bank destinations");
        List<String[]> rows = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream,StandardCharsets.UTF_8)))
        {
            String line;
            while ((line = reader.readLine()) != null)
            {
                if (line.startsWith("#") || line.isBlank()) continue;
                String[] fields = line.split("\t",-1);
                if (fields.length != 6) throw new IOException("Invalid bank record");
                rows.add(fields);
            }
        }
        catch (IOException failure) { throw new IllegalStateException("Unable to read bank destinations",failure); }
        return List.copyOf(rows);
    }
}
