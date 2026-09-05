package com.genericclient.scripts;

import static org.junit.Assert.*;
import com.genericclient.scripts.training.MeleeTrainer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.skills.Skill;
import org.junit.Test;

public class MeleeContractsTest
{
    @Test public void skipsAnotherPlayersGoblinAndRetriesAClaimRace()
    {
        List<Integer> attacked = new ArrayList<>();
        CatalogEnvironment game = new CatalogEnvironment(new MeleeTrainer(),Map.of("skill","attack","target_level","2"))
        {
            private Map<?,?> position = Map.of("x",3245,"y",3245,"plane",0);
            @Override public Object read(String subject, Map<String,Object> query)
            {
                if (subject.equals("player"))
                {
                    Map<String,Object> player = new LinkedHashMap<>();
                    ((Map<?,?>)super.read(subject,query)).forEach((key,value) -> player.put((String)key,value));
                    player.put("world",position);
                    return player;
                }
                if (subject.equals("npcs")) return List.of(goblin(1,"Other player",3245),goblin(2,null,3246));
                return super.read(subject,query);
            }
            @Override public Map<String,Object> execute(String type, Map<String,Object> arguments, long timeout)
            {
                if (type.equals("client.behaviors.configure") || type.equals("combat.set_style")) return Map.of("status","set");
                if (type.equals("walk.to")) { position=(Map<?,?>)arguments.get("destination"); return Map.of("status","arrived"); }
                if (type.equals("npc.interact"))
                {
                    assertEquals("combat",activity);
                    assertEquals(Map.of("breaks",true),policy);
                    int index=((Number)arguments.get("index")).intValue();
                    attacked.add(index);
                    if (index==1 || attacked.size()==1) return Map.of("status","rejected","result","matching_npc_not_found");
                    experience.put(Skill.ATTACK,83);
                    return Map.of("status","dispatched");
                }
                return super.execute(type,arguments,timeout);
            }
        };
        game.run();
        assertEquals(List.of(2,2),attacked);
        assertEquals("complete",((Map<?,?>)game.result).get("status"));
        assertEquals(2,((Map<?,?>)game.result).get("final_level"));
    }

    private static Map<String,Object> goblin(int index, String opponent, int x)
    {
        Map<String,Object> row=new LinkedHashMap<>();
        row.put("identity",10L+index); row.put("id",6553); row.put("index",index); row.put("name","Goblin");
        row.put("world",Map.of("x",x,"y",3245,"plane",0)); row.put("dead",false); row.put("interacting",opponent);
        row.put("animation",-1); row.put("actions",List.of("Attack"));
        return row;
    }
}
