package com.genericclient.scripts;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.dreambot.api.script.AbstractScript;

/** A random-event invitation remains owned by its detected NPC. */
final class EventScenario extends SceneScenario
{
    final Map<String,Object> event=new LinkedHashMap<>();

    EventScenario(AbstractScript script, int eventNpc)
    {
        super(script);
        event.put("active",true); event.put("present",true); event.put("npc_id",eventNpc);
        event.put("npc_index",7); event.put("detected_tick",0L);
        Map<String,Object> npc=new LinkedHashMap<>();
        npc.put("identity",70L); npc.put("index",7); npc.put("id",eventNpc); npc.put("name","Event NPC");
        npc.put("world",Map.of("x",3166,"y",3491,"plane",0)); npc.put("actions",List.of("Talk-to"));
        npc.put("dead",false); npc.put("animation",-1); npc.put("interacting",null);
        npcs.add(npc);
    }

    @Override public Object read(String subject, Map<String,Object> query)
    {
        return subject.equals("random_event") ? event : super.read(subject,query);
    }

    void depart() { event.put("present",false); npcs.clear(); closeDialogue(); }
}
