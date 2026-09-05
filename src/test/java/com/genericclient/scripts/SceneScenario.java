package com.genericclient.scripts;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.BiConsumer;
import org.dreambot.api.script.AbstractScript;

/** Observed scene changes are driven by accepted inputs and subsequent game ticks. */
class SceneScenario extends CatalogEnvironment
{
    final List<Map<String,Object>> npcs=new ArrayList<>();
    final List<Map<String,Object>> objects=new ArrayList<>();
    final List<Map<String,Object>> widgets=new ArrayList<>();
    final List<Map<String,Object>> messages=new ArrayList<>();
    final Map<Long,Integer> varbits=new LinkedHashMap<>();
    final Map<Integer,List<String>> inventoryActions=new LinkedHashMap<>();
    Map<String,Integer> world=Map.of("x",3165,"y",3491,"plane",0);
    int hitpoints=31;
    int maximumHitpoints=31;
    boolean loggedIn=true;
    Map<String,Object> dialogue=Map.of("open",false,"type","closed","options",List.of());
    BiConsumer<String,Map<String,Object>> input=(type,args) -> { throw new AssertionError("Unexpected scene input: " + type + " " + args); };
    Runnable nextTick;
    int gameInputs;
    Map<String,Object> receipt;
    private long identity=70;

    SceneScenario(AbstractScript script)
    {
        super(script,Map.of());
    }

    @Override public Object read(String subject, Map<String,Object> query)
    {
        switch (subject)
        {
            case "runtime":return Map.of("game_tick",tick(),"game_state",loggedIn ? "LOGGED_IN" : "LOGIN_SCREEN");
            case "npcs":return npcs;
            case "objects":return objects;
            case "widgets":
                List<?> ids=(List<?>)query.getOrDefault("ids",List.of());
                return widgets.stream()
                    .filter(row -> Boolean.TRUE.equals(query.get("include_hidden")) || Boolean.TRUE.equals(row.get("visible")))
                    .filter(row -> !query.containsKey("group") || ((Number)row.get("id")).intValue() >>> 16 == ((Number)query.get("group")).intValue())
                    .filter(row -> ids.isEmpty() || ids.stream().anyMatch(id -> ((Number)id).intValue()==((Number)row.get("id")).intValue()))
                    .collect(java.util.stream.Collectors.toList());
            case "messages":return messages.stream().filter(row -> ((Number)row.get("game_tick")).longValue() >=
                ((Number)query.getOrDefault("since_tick",Long.MIN_VALUE)).longValue()).collect(java.util.stream.Collectors.toList());
            case "dialogue":return dialogue;
            case "player":
                Map<String,Object> player=new LinkedHashMap<>();
                ((Map<?,?>)super.read(subject,query)).forEach((key,value) -> player.put((String)key,value));
                player.put("world",world);
                player.put("logged_in",loggedIn);
                player.put("current_hitpoints",hitpoints);
                player.put("max_hitpoints",maximumHitpoints);
                return player;
            case "vars":return Map.of("available",true,"varbits",varbits,"varps",Map.of());
            case "entity":
                if (query.get("kind").equals("object")) return objects.stream().filter(row ->
                    query.get("identity").equals(row.get("identity"))).findFirst().orElse(null);
                return super.read(subject,query);
            case "inventory":return inventorySnapshot();
            default:return super.read(subject,query);
        }
    }

    private Map<String,Object> inventorySnapshot()
    {
        List<Map<String,Object>> items=new ArrayList<>();
        inventory.forEach((id,quantity) ->
        {
            boolean stackable=id==995;
            for (int slot=0;slot<(stackable ? 1 : quantity);slot++)
                items.add(Map.of("id",id,"quantity",stackable ? quantity : 1,"name",id==2528 ? "Lamp" : "Reward",
                    "slot",items.size(),"actions",inventoryActions.getOrDefault(id,List.of("Return","Destroy","Use")),"stackable",stackable));
        });
        return Map.of("available",true,"items",items,"occupied_slots",items.size());
    }

    @Override public Map<String,Object> execute(String type, Map<String,Object> arguments, long timeout)
    {
        gameInputs++;
        intents.observe(type);
        receipt=Map.of("status",type.equals("walk.to") ? "arrived" : "dispatched");
        input.accept(type,arguments);
        return receipt;
    }

    @Override public void sleep(long millis)
    {
        super.sleep(millis);
        Runnable transition=nextTick;
        nextTick=null;
        if (transition!=null) transition.run();
    }
    @Override public long activeTimeNanos() { return tick()*600_000_000L; }

    void message(String text) { messages.add(Map.of("game_tick",tick(),"text",text,"type","game")); }
    Map<String,Object> widget(int id, String text)
    {
        Map<String,Object> row=new LinkedHashMap<>(Map.of("id",id,"index",-1,"text",text,"actions",List.of(),"visible",true));
        widgets.add(row);
        return row;
    }
    Map<String,Object> npc(int id, String name, int x, int y, String... actions)
    {
        Map<String,Object> row=entity(id,name,x,y,actions);
        row.put("index",npcs.size()+8); row.put("animation",-1); row.put("dead",false); row.put("clickable",true);
        npcs.add(row);
        return row;
    }
    Map<String,Object> object(int id, int x, int y, String... actions)
    {
        Map<String,Object> row=entity(id,"Object",x,y,actions);
        objects.add(row);
        return row;
    }
    private Map<String,Object> entity(int id, String name, int x, int y, String[] actions)
    {
        return new LinkedHashMap<>(Map.of("identity",++identity,"id",id,"name",name,
            "world",Map.of("x",x,"y",y,"plane",0),"actions",List.of(actions)));
    }
    void closeDialogue() { dialogue=Map.of("open",false,"type","closed","options",List.of()); }
    void continueDialogue() { dialogue=Map.of("open",true,"type","continue","options",List.of()); }
    void moveTo(Map<?,?> tile)
    {
        world=Map.of("x",((Number)tile.get("x")).intValue(),"y",((Number)tile.get("y")).intValue(),
            "plane",((Number)tile.get("plane")).intValue());
    }
}
