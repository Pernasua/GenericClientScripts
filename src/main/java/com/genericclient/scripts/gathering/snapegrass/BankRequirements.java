package com.genericclient.scripts.gathering.snapegrass;

import com.genericclient.script.ScriptScope;
import com.genericclient.script.SnapshotData;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;

/** Source bank gameplay requirements; these never buy supplies or change an account objective. */
final class BankRequirements
{
    private final Map<String,Map<?,?>> quests = new HashMap<>();
    private final Map<Integer,Integer> bits = new HashMap<>();

    BankRequirements()
    {
        for (Object entry : SnapshotData.read("quests").values())
        {
            if (!(entry instanceof Map)) continue;
            Map<?,?> quest = (Map<?,?>)entry;
            Object name = quest.get("name");
            if (name instanceof String) quests.put(key((String)name),quest);
        }
    }

    boolean allows(String requirement,String argument)
    {
        String[] parts = argument.split(":");
        switch (requirement)
        {
            case "none": return true;
            case "finished": return finished(argument);
            case "started": return started(argument);
            case "level": return level(parts[0]) >= Integer.parseInt(parts[1]);
            case "bit_eq": return bit(Integer.parseInt(parts[0])) == Integer.parseInt(parts[1]);
            case "bit_gt": return bit(Integer.parseInt(parts[0])) > Integer.parseInt(parts[1]);
            case "progress_ge": return progress(parts[0]) >= Integer.parseInt(parts[1]);
            default: return compound(requirement,parts);
        }
    }

    private boolean compound(String requirement,String[] parts)
    {
        switch (requirement)
        {
            case "progress_gt": return finished(parts[0]) || started(parts[0]) && progress(parts[0]) > Integer.parseInt(parts[1]);
            case "quest_or_bit_gt": return finished(parts[0]) || bit(Integer.parseInt(parts[1])) > Integer.parseInt(parts[2]);
            case "quest_and_level": return finished(parts[0]) && level(parts[1]) >= Integer.parseInt(parts[2]);
            case "near": return new Tile(Integer.parseInt(parts[0]),Integer.parseInt(parts[1]),Integer.parseInt(parts[2]))
                .distance() < Integer.parseInt(parts[3]);
            case "warriors": return level("ATTACK") == 99 || level("STRENGTH") == 99 || level("ATTACK") + level("STRENGTH") >= 130;
            default: throw new IllegalArgumentException("Unknown bank requirement: "+requirement);
        }
    }

    private boolean finished(String name) { return "finished".equals(quest(name).get("state")); }
    private boolean started(String name) { return finished(name) || "in_progress".equals(quest(name).get("state")); }
    private Map<?,?> quest(String name) { return quests.getOrDefault(key(name),Map.of()); }
    private int progress(String name)
    {
        Object value = quest(name).get("progress");
        return value instanceof Number ? ((Number)value).intValue() : -1;
    }
    private static int level(String skill) { return Skills.getRealLevel(Skill.valueOf(skill)); }
    private static String key(String value) { return value.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]",""); }
    private int bit(int id)
    {
        return bits.computeIfAbsent(id,value ->
        {
            Map<?,?> snapshot = SnapshotData.map(ScriptScope.current().read("vars",Map.of("varbits",List.of(value))));
            Object observed = SnapshotData.map(snapshot.get("varbits")).get((long)value);
            return observed instanceof Number ? ((Number)observed).intValue() : -1;
        });
    }
}
