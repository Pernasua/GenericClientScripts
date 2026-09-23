package com.genericclient.scripts;

import com.genericclient.script.ScriptEnvironment;
import com.genericclient.script.ScriptScope;
import com.genericclient.scripts.quests.QuestRunner;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CancellationException;
import java.util.function.BiConsumer;
import org.dreambot.api.methods.map.Tile;

/** Observable game boundary for deterministic quest transitions. */
public final class QuestScenario implements ScriptEnvironment
{
	final IntentTrace intents = new IntentTrace();
	java.util.function.Consumer<String> enteringIntent = name -> {};
	@Override public <T> T intent(String name, java.util.function.Supplier<T> body)
	{
		enteringIntent.accept(name);
		return intents.run(name,body);
	}
    final String quest;
    final int varpId;
    int stage;
    int varpFlags;
    public Tile position;
    public final Map<Integer,Integer> inventory = new LinkedHashMap<>();
    final Map<Integer,Integer> bank = new LinkedHashMap<>();
    boolean bankOpen;
    boolean bankKnown = true;
    boolean instanced;
    boolean sceneAvailable = true;
    Map<String,String> overlayRows = Map.of();
    java.util.function.Consumer<String> beforeRead = subject -> {};
    final Map<Integer,Integer> equipment = new LinkedHashMap<>();
    public final Map<Long,Integer> varbits = new LinkedHashMap<>();
    final List<Map<String,Object>> npcs = new ArrayList<>();
    final List<Map<String,Object>> objects = new ArrayList<>();
    final List<Map<String,Object>> messages = new ArrayList<>();
    final ArrayDeque<String> buttons = new ArrayDeque<>();
    final List<String> actions = new ArrayList<>();
    final List<String> phaseActivities = new ArrayList<>();
    final List<Map<String,Object>> phaseOptions = new ArrayList<>();
    final ArrayDeque<Runnable> transitions = new ArrayDeque<>();
    Map<String,Object> safety = Map.of();
    public Map<String,Object> dialogue = Map.of("type","closed","open",false,"options",List.of());
    Map<String,Object> behavior = Map.of();
    public Map<String,Object> receipt;
    public BiConsumer<String,Map<String,Object>> input = (type,arguments) -> { throw new AssertionError("Unexpected game input: " + type + " " + arguments); };
    Object result;
    boolean finished;
    String scope = "checkpoint";
    public String activity;
    public Map<String,Object> policy = Map.of();
    private long tick;
    private long identities = 10;
    private boolean running = true;

    public QuestScenario(String quest, int varpId, int stage, Tile position)
    {
        this.quest=quest;
        this.varpId=varpId;
        this.stage=stage;
        this.position=position;
    }

    void run()
    {
        ScriptScope scope = new ScriptScope(this);
        try (scope) { new QuestRunner().onLoop(); }
    }

    public void npc(int id, String name, Tile tile, String... actions)
    {
        Map<String,Object> row = new LinkedHashMap<>();
        row.put("identity",++identities);
        row.put("index",npcs.size()+1);
        row.put("id",id);
        row.put("name",name);
        row.put("world",world(tile));
        row.put("actions",List.of(actions));
        row.put("dead",false);
        row.put("interacting",null);
        row.put("animation",-1);
        row.put("line_of_sight",true);
        npcs.add(row);
    }

    void object(int id, String name, Tile tile, String... actions)
    {
        objects.add(Map.of("identity",++identities,"id",id,"name",name,"world",world(tile),"actions",List.of(actions)));
    }

    @Override public Object read(String subject, Map<String,Object> query)
    {
        beforeRead.accept(subject);
        switch (subject)
        {
            case "local_player": return Map.of("identity",1L);
            case "player": return player();
            case "entity": return entity(query);
            case "inventory": return container(inventory);
            case "equipment": return container(equipment);
            case "bank": return bankSnapshot();
            case "npcs": return npcs;
            case "objects": return objects;
            case "ground_items": return List.of();
            case "messages": return messages.stream().filter(row -> ((Number)row.get("game_tick")).longValue() >=
                ((Number)query.getOrDefault("since_tick",Long.MIN_VALUE)).longValue()).collect(java.util.stream.Collectors.toList());
            case "dialogue": return dialogue;
            case "quests":
                Map<String,Object> quests=new LinkedHashMap<>();
                quests.put("the_grand_tree",Map.of("state","finished"));
                quests.put("tree_gnome_village",Map.of("state","finished"));
                quests.put(quest.equals("waterfall") ? "waterfall_quest" : quest,Map.of("state",finished ? "finished" : "in_progress","progress",stage));
                return quests;
            case "skills": return Map.of("available",true,"magic",Map.of("level",50,"boosted_level",50,"xp",101333),
                "hitpoints",Map.of("level",40,"boosted_level",40,"xp",37224),"prayer",Map.of("level",43,"boosted_level",43,"xp",50339));
            case "vars": return variables(query);
            case "runtime": return Map.of("game_tick",tick,"game_state","LOGGED_IN");
            case "scene": return Map.of("available",sceneAvailable,"instance",instanced);
            default: throw new AssertionError("Unexpected quest read: " + subject);
        }
    }

    private Map<String,Object> bankSnapshot()
    {
        if (!bankKnown) return Map.of("available",false,"state","unknown","open",false,"items",List.of(),"occupied_slots",0);
        Map<String,Object> snapshot = new LinkedHashMap<>(container(bank));
        snapshot.put("state",bankOpen ? "open" : "cached");
        snapshot.put("open",bankOpen);
        return snapshot;
    }

    private Map<String,Object> variables(Map<String,Object> query)
    {
        Map<Long,Integer> bits = new LinkedHashMap<>();
        for (Object value : (List<?>)query.getOrDefault("varbits",List.of()))
        {
            long id = ((Number)value).longValue();
            bits.put(id,varbits.getOrDefault(id,0));
        }
        return Map.of("available",true,"varps",Map.of((long)varpId,stage | varpFlags),"varbits",bits);
    }

    private Map<String,Object> player()
    {
        Map<String,Object> value = new LinkedHashMap<>();
        value.put("identity",1L); value.put("logged_in",true); value.put("name","Player");
        value.put("world",world(position)); value.put("interacting",null); value.put("animation",-1);
        value.put("current_hitpoints",40); value.put("max_hitpoints",40);
        value.put("run_energy",10000); value.put("run_enabled",true);
        return value;
    }

    private Object entity(Map<String,Object> query)
    {
        long identity = ((Number)query.get("identity")).longValue();
        if (identity==1) return player();
        List<Map<String,Object>> rows = query.get("kind").equals("npc") ? npcs : objects;
        return rows.stream().filter(row -> ((Number)row.get("identity")).longValue()==identity).findFirst().orElse(null);
    }

    private static Map<String,Object> container(Map<Integer,Integer> items)
    {
        List<Map<String,Object>> rows = new ArrayList<>();
        items.forEach((id,count) -> rows.add(Map.of("id",id,"name","Item "+id,"quantity",count,"slot",rows.size(),
            "stackable",true,"actions",List.of("Wield","Use","Eat"))));
        return Map.of("available",true,"items",rows,"occupied_slots",rows.size());
    }

    private static Map<String,Integer> world(Tile tile) { return Map.of("x",tile.getX(),"y",tile.getY(),"plane",tile.getZ()); }

    void message(String type, String text) { messages.add(Map.of("type",type,"text",text,"game_tick",tick)); }

    @Override public Map<String,Object> execute(String type, Map<String,Object> arguments, long timeout)
    {
        actions.add(type);
        intents.observe(type);
        if (type.equals("safety.configure")) { safety=arguments; return Map.of("status","complete"); }
        if (type.equals("safety.clear")) { safety=Map.of(); return Map.of("status","complete"); }
        if (type.equals("client.behaviors.configure")) { behavior=arguments; return Map.of("status","complete"); }
        receipt=Map.of("status",type.equals("walk.to") ? "arrived" : "dispatched");
        input.accept(type,arguments);
        return receipt;
    }

    @Override public void sleep(long millis)
    {
        checkpoint();
        if (++tick > 300) throw new AssertionError("Quest made no observable progress");
        if (!transitions.isEmpty()) transitions.remove().run();
    }
    @Override public long activeTimeNanos() { return tick*600_000_000L; }
    @Override public void sleepTicks(int ticks, Map<String,Object> options) { for(int i=0;i<ticks;i++) sleep(600); }
    @Override public long tick() { return tick; }
    @Override public void checkpoint() { if (!running) throw new CancellationException(); }
    @Override public void stop() { running=false; }
    @Override public boolean isRunning() { return running; }
    @Override public boolean isPaused() { return false; }
    @Override public void log(Object value) {}
    @Override public Map<String,Object> inputs() { return Map.of("quest",quest,"scope",scope,"restock","bank_only"); }
    @Override public String nextAction() { return buttons.poll(); }
    @Override public Map<String,Object> phase(String name, Map<String,Object> options)
    {
        phaseActivities.add(activity); phaseOptions.add(options);
        return Map.of("status","ready");
    }
    @Override public void activity(String name, Map<String,Object> policy) { activity=name; this.policy=policy; }
    @Override public void result(Object value) { result=value; }
    @Override public void overlay(Map<String,String> rows) { overlayRows = rows; }
    @Override public void markers(List<Map<String,Object>> markers) {}
}
