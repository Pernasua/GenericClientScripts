package com.genericclient.scripts.gathering.snapegrass;

import com.genericclient.scripts.CatalogEnvironment;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Accepted inputs and subsequent server-tick effects, using the production SDK. */
final class GrassScenario extends CatalogEnvironment
{
    static final int TABLET = 90001; // Synthetic IDs ensure the port resolves the source's name filters.
    static final int BOOTS = 90002;
    static final int GRASS = 231;
    static final int RING = 2552;
    final List<Map<String,Object>> trace = new ArrayList<>();
    final List<Integer> waits = new ArrayList<>();
    final List<Map<String,Object>> ground = new ArrayList<>();
    final List<Map<String,Object>> objects = new ArrayList<>();
    final List<Map<String,Object>> widgets = new ArrayList<>();
    final Map<String,Object> quests = new LinkedHashMap<>();
    final Map<Long,Integer> varbits = new LinkedHashMap<>();
    final ArrayDeque<Runnable> effects = new ArrayDeque<>();
    Map<String,Integer> world = point(2546,3763);
    Map<String,String> overlay = Map.of();
    boolean bankOpen;
    boolean moving;
    boolean loggedIn = true;
    boolean geOpen;
    boolean runEnabled = true;
    boolean rejectTake;
    boolean rejectTeleport;
    boolean consumeLastRing;
    boolean delayPickup;
    int runEnergy = 10000;
    int nearestBankOpens;
    Map<String,Integer> nearestDestination;
    boolean routeFails;
    final SnapeGrassCollector collector;

    GrassScenario()
    {
        this(new SnapeGrassCollector());
    }
    private GrassScenario(SnapeGrassCollector collector)
    {
        super(collector,Map.of());
        this.collector = collector;
        inventory.put(TABLET,10);
        equipment.put(RING,1);
    }

    @Override public Object read(String subject, Map<String,Object> query)
    {
        switch (subject)
        {
            case "quests": return quests;
            case "vars": return Map.of("available",true,"varbits",varbits);
            case "runtime": return Map.of("game_tick",tick(),"game_state",loggedIn ? "LOGGED_IN" : "LOGIN_SCREEN");
            case "player": return player();
            case "entity":
                if (((Number)query.get("identity")).longValue() == 1L) return player();
                return objects.stream().filter(row -> query.get("identity").equals(row.get("identity"))).findFirst().orElse(null);
            case "inventory": return container(inventory,false,false);
            case "equipment": return container(equipment,true,false);
            case "bank": return container(bank,false,true);
            case "ground_items": return ground;
            case "objects": return objects;
            case "npcs": return List.of();
            case "widgets":
                List<Map<String,Object>> result = new ArrayList<>(widgets);
                if (geOpen) result.add(Map.of("id",465<<16,"index",-1,"visible",true,"actions",List.of()));
                List<?> ids = (List<?>)query.getOrDefault("ids",List.of());
                return result.stream().filter(row -> ids.isEmpty() || ids.contains(row.get("id")))
                    .collect(java.util.stream.Collectors.toList());
            default: return super.read(subject,query);
        }
    }

    private Map<String,Object> player()
    {
        Map<String,Object> row = new LinkedHashMap<>(Map.of("identity",1L,"world",world,"logged_in",loggedIn,
            "moving",moving,"animation",-1,"run_energy",runEnergy,"run_enabled",runEnabled));
        row.put("interacting",null);
        return row;
    }

    private Map<String,Object> container(Map<Integer,Integer> contents, boolean worn, boolean banking)
    {
        List<Map<String,Object>> rows = new ArrayList<>();
        for (Map.Entry<Integer,Integer> entry : contents.entrySet())
            addItems(rows,entry.getKey(),entry.getValue(),worn,banking);
        Map<String,Object> result = new LinkedHashMap<>(Map.of("available",true,"items",rows,"occupied_slots",rows.size()));
        if (banking) { result.put("open",bankOpen); result.put("state",bankOpen ? "open" : "cached"); }
        return result;
    }

    private static void addItems(List<Map<String,Object>> rows, int id, int count, boolean worn, boolean banking)
    {
        if (count <= 0) return;
        boolean stackable = id == TABLET;
        int slots = banking || stackable ? 1 : count;
        for (int i=0; i<slots; i++)
        {
            int slot = worn ? (id == BOOTS ? 10 : 12) : rows.size();
            rows.add(Map.of("id",id,"name",name(id),"quantity",banking || stackable ? count : 1,
                "slot",slot,"stackable",stackable,"actions",List.of(id==TABLET ? "Break" : "Wear","Castle Wars")));
        }
    }

    private static String name(int id)
    {
        if (id == TABLET) return "Waterbirth teleport";
        if (id == BOOTS) return "Boots";
        if (id == GRASS) return "Snape grass";
        if (id == 379) return "Lobster";
        if (id >= 2552 && id <= 2566) return "Ring of dueling(" + (8-(id-2552)/2) + ")";
        throw new AssertionError("Unconfigured item " + id);
    }

    @Override public Map<String,Object> execute(String type, Map<String,Object> arguments, long timeout)
    {
        actions.add(type);
        Map<String,Object> recorded = new LinkedHashMap<>(arguments);
        recorded.put("type",type); recorded.put("tick",tick()); trace.add(recorded);
        switch (type)
        {
            case "walk.nearest": return nearestDestination == null ? Map.of("status","unreachable") :
                Map.of("status","complete","destination",nearestDestination);
            case "walk.to":
                if (routeFails) return Map.of("status","unreachable");
                world=nearestDestination;
                chest();
                return Map.of("status","arrived");
            case "bank.close": bankOpen = false; break;
            case "bank.deposit_equipment": equipment.forEach((id,count) -> bank.merge(id,count,Integer::sum)); equipment.clear(); break;
            case "bank.deposit": transfer(inventory,bank,arguments); break;
            case "bank.withdraw": transfer(bank,inventory,arguments); break;
            case "object.interact": bankOpen = true; nearestBankOpens++; break;
            case "equipment.interact":
                effects.add(() -> { world=point(2444,3083); if (consumeLastRing) equipment.clear(); });
                break;
            case "item.interact":
                return interactItem(arguments);
            case "ground_item.take":
                if (rejectTake) return Map.of("status","rejected");
                if (!delayPickup) effects.add(() ->
                {
                    Map<?,?> target=(Map<?,?>)arguments.get("world");
                    Map<String,Object> item=ground.stream().filter(row -> row.get("world").equals(target)).findFirst().orElseThrow();
                    ground.remove(item); inventory.merge(GRASS,1,Integer::sum);
                    world=point(((Number)target.get("x")).intValue(),((Number)target.get("y")).intValue());
                });
                break;
            case "walk.step":
                Map<?,?> destination=(Map<?,?>)arguments.get("destination");
                world=point(((Number)destination.get("x")).intValue(),((Number)destination.get("y")).intValue());
                break;
            case "ui.click": runEnabled=true; break;
            default: throw new AssertionError("Unexpected mutation: " + type + " " + arguments);
        }
        return Map.of("status",type.startsWith("bank.") ? "complete" : "dispatched");
    }

    private Map<String,Object> interactItem(Map<String,Object> arguments)
    {
        int id = ((Number)arguments.get("id")).intValue();
        if (arguments.get("action").equals("Wear"))
            effects.add(() -> { remove(id); equipment.put(id,1); });
        else if (arguments.get("action").equals("Break"))
        {
            if (rejectTeleport) return Map.of("status","rejected");
            effects.add(() -> { remove(id); world=point(2546,3763); });
        }
        else throw new AssertionError("Unexpected item action " + arguments);
        return Map.of("status","dispatched");
    }

    private static void transfer(Map<Integer,Integer> from, Map<Integer,Integer> to, Map<String,Object> arguments)
    {
        int id=((Number)arguments.get("id")).intValue();
        int quantity=Boolean.TRUE.equals(arguments.get("all")) ? from.getOrDefault(id,0) : ((Number)arguments.get("quantity")).intValue();
        quantity=Math.min(quantity,from.getOrDefault(id,0));
        if (quantity>0) { from.merge(id,-quantity,Integer::sum); to.merge(id,quantity,Integer::sum); }
    }

    private void remove(int id)
    {
        if (inventory.getOrDefault(id,0)<=0) throw new AssertionError("Consumed absent item " + id);
        inventory.merge(id,-1,Integer::sum);
    }
    @Override public void sleep(long millis)
    {
        super.sleep(millis);
        if (!effects.isEmpty()) effects.remove().run();
    }
    @Override public void sleepTicks(int ticks, Map<String,Object> options)
    {
        waits.add(ticks);
        super.sleepTicks(ticks,options);
    }
    @Override public long activeTimeNanos() { return tick()*600_000_000L; }
    @Override public void overlay(Map<String,String> rows) { overlay=rows; }

    void spawn(int x, int y) { ground.add(Map.of("id",GRASS,"name","Snape grass","quantity",1,"world",point(x,y))); }
    void chest()
    {
        objects.add(Map.of("identity",2L,"id",4483,"name","Bank chest","world",point(2443,3083),"actions",List.of("Use")));
    }
    void runButton() { widgets.add(Map.of("id",160<<16|27,"index",-1,"visible",true,"actions",List.of("Toggle Run"))); }
    List<Map<String,Object>> calls(String type)
    {
        return trace.stream().filter(row -> type.equals(row.get("type"))).collect(java.util.stream.Collectors.toList());
    }
    static Map<String,Integer> point(int x, int y) { return Map.of("x",x,"y",y,"plane",0); }
}
