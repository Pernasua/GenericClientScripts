package com.genericclient.scripts;

import com.genericclient.script.ScriptEnvironment;
import com.genericclient.script.ScriptScope;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CancellationException;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.script.AbstractScript;

/** Observable account frames and delayed server effects for catalog scenarios. */
public class CatalogEnvironment implements ScriptEnvironment
{
	final IntentTrace intents = new IntentTrace();
	@Override public <T> T intent(String name, java.util.function.Supplier<T> body) { return intents.run(name,body); }
	public final Map<Integer,Integer> bank = new LinkedHashMap<>();
	public final Map<Integer,Integer> inventory = new LinkedHashMap<>();
	public final Map<Integer,Integer> equipment = new LinkedHashMap<>();
	public final Map<Skill,Integer> experience = new LinkedHashMap<>();
	public final List<String> actions = new ArrayList<>();
	public final ArrayDeque<String> buttons = new ArrayDeque<>();
	public Object result;
	public String lastSpell;
	Map<String,String> overlayRows = Map.of();
	String activity;
	Map<String,Object> policy = Map.of();
	int maximumSleeps = 300;
	private final Map<String,Object> inputs;
	private final AbstractScript script;
	private final ArrayDeque<Runnable> pending = new ArrayDeque<>();
	private boolean open = true;
	private boolean running = true;
	private long tick;
	private int sleeps;

	public CatalogEnvironment(AbstractScript script, Map<String,Object> inputs)
	{
		this.script = script;
		this.inputs = inputs;
		for (Skill skill : Skill.values()) experience.put(skill, Skills.getExperienceForLevel(skill == Skill.HITPOINTS ? 31 : 1));
	}

	public int run()
	{
		ScriptScope scope = new ScriptScope(this);
		try (scope) { return script.onLoop(); }
	}

	@Override public Object read(String subject, Map<String,Object> query)
	{
		switch (subject)
		{
			case "runtime": return Map.of("game_tick",tick,"game_state","LOGGED_IN");
			case "local_player": return Map.of("identity",1L);
			case "entity":
				if (((Number)query.get("identity")).longValue()==1L) return read("player",Map.of());
				return ((List<?>)read("npcs",Map.of())).stream().map(Map.class::cast)
					.filter(row -> query.get("identity").equals(row.get("identity"))).findFirst().orElse(null);
			case "player":
				Map<String,Object> player = new LinkedHashMap<>();
				player.put("identity",1L); player.put("logged_in",true); player.put("name","Player");
				player.put("world",Map.of("x",3165,"y",3491,"plane",0));
				player.put("animation",-1); player.put("interacting",null);
				player.put("current_hitpoints",31); player.put("max_hitpoints",31);
				return player;
			case "inventory": return container(inventory);
			case "equipment": return container(equipment);
			case "bank":
				Map<String,Object> snapshot = container(bank);
				snapshot.put("open",open); snapshot.put("state",open ? "open" : "cached");
				return snapshot;
			case "skills": return skills();
			case "cash": return Map.of("complete",true,"known_total_value",(long) bank.getOrDefault(995,0)+inventory.getOrDefault(995,0));
			case "npcs": return List.of(Map.of("identity",2L,"id",1633,"index",1,"name","Banker","combat_level",0,
				"world",Map.of("x",3164,"y",3491,"plane",0),"actions",List.of("Bank")));
			case "objects": return List.of();
			default: throw new AssertionError("Unexpected read: " + subject);
		}
	}

	private Map<String,Object> container(Map<Integer,Integer> contents)
	{
		List<Map<String,Object>> rows = new ArrayList<>();
		for (Map.Entry<Integer,Integer> entry : contents.entrySet())
		{
			boolean stackable = List.of(561,558,555,556,557,562,890,995).contains(entry.getKey());
			int slots = stackable ? 1 : entry.getValue();
			for (int slot = 0; slot < slots; slot++) rows.add(Map.of("id",entry.getKey(),"name",name(entry.getKey()),
				"quantity",stackable ? entry.getValue() : 1,"slot",rows.size(),"stackable",stackable,"actions",itemActions(entry.getKey())));
		}
		Map<String,Object> value = new LinkedHashMap<>();
		value.put("available",true); value.put("items",rows); value.put("occupied_slots",rows.size());
		return value;
	}
	private Map<String,Object> skills()
	{
		Map<String,Object> skills = new LinkedHashMap<>();
		skills.put("available",true);
		for (Map.Entry<Skill,Integer> entry : experience.entrySet())
		{
			int level = 1;
			while (level < 99 && Skills.getExperienceForLevel(level+1) <= entry.getValue()) level++;
			skills.put(entry.getKey().name().toLowerCase(java.util.Locale.ROOT), Map.of("xp",entry.getValue(),"level",level,"boosted_level",level));
		}
		return skills;
	}

	@Override public Map<String,Object> execute(String action, Map<String,Object> arguments, long timeout)
	{
		actions.add(action);
		intents.observe(action);
		switch (action)
		{
			case "safety.clear": return Map.of("status","complete");
			case "npc.interact": open = true; return Map.of("status","dispatched");
			case "bank.loadout": loadout((List<?>) arguments.get("items")); open = false; return Map.of("status","complete");
			case "item.interact":
				int id = ((Number) arguments.get("id")).intValue();
				String option = (String) arguments.get("action");
				if (option.equals("Bury")) pending.add(() -> { remove(id); experience.merge(Skill.PRAYER,72,Integer::sum); });
				else if (option.equals("Wield")) pending.add(() -> { remove(id); equipment.put(id,1); });
				else throw new AssertionError("Unexpected item action: " + option);
				return Map.of("status","dispatched");
			case "spell.cast_on_item":
				lastSpell = (String) arguments.get("spell");
				int material = ((Number) arguments.get("item_id")).intValue();
				String cast = lastSpell;
				pending.add(() ->
				{
					remove(material); remove(561);
					experience.merge(Skill.MAGIC,cast.equals("superheat_item") ? 53 : 31,Integer::sum);
					if (cast.equals("superheat_item")) inventory.merge(2351,1,Integer::sum);
				});
				return Map.of("status","dispatched");
			default: throw new AssertionError("Unexpected account mutation: " + action);
		}
	}

	private void loadout(List<?> requested)
	{
		if (!open) throw new AssertionError("Loadout requires an open bank");
		inventory.forEach((id,count) -> bank.merge(id,count,Integer::sum)); inventory.clear();
		equipment.forEach((id,count) -> bank.merge(id,count,Integer::sum)); equipment.clear();
		for (Object value : requested)
		{
			Map<?,?> item = (Map<?,?>) value;
			int id = ((Number) item.get("id")).intValue();
			int quantity = ((Number) item.get("quantity")).intValue();
			if (bank.getOrDefault(id,0) < quantity) throw new AssertionError("Insufficient bank stock: " + id);
			bank.put(id,bank.get(id)-quantity); inventory.put(id,quantity);
		}
	}
	private void remove(int id)
	{
		int quantity = inventory.getOrDefault(id,0);
		if (quantity <= 0) throw new AssertionError("Consumed absent item " + id);
		if (quantity == 1) inventory.remove(id); else inventory.put(id,quantity-1);
	}
	private String name(int id)
	{
		switch (id)
		{
			case 536:return "Dragon bones";
			case 1387:return "Staff of fire";
			case 561:return "Nature rune";
			case 890:return "Adamant arrow";
			case 440:return "Iron ore";
			case 2351:return "Iron bar";
			case 995:return "Coins";
			default:throw new AssertionError("Unconfigured item " + id);
		}
	}
	private List<String> itemActions(int id) { return List.of(id == 536 ? "Bury" : id == 1387 ? "Wield" : "Use"); }

	@Override public void sleep(long millis)
	{
		checkpoint();
		if (++sleeps > maximumSleeps) throw new AssertionError("Workflow made no observable progress");
		tick++;
		if (!pending.isEmpty()) pending.remove().run();
	}
	@Override public void checkpoint() { if (!running) throw new CancellationException(); }
	@Override public void stop() { running = false; }
	@Override public boolean isRunning() { return running; }
	@Override public boolean isPaused() { return false; }
	@Override public void sleepTicks(int ticks, Map<String,Object> options) { for(int i=0;i<ticks;i++) sleep(600); }
    @Override public long tick() { return tick; }
	@Override public void log(Object message) {}
	@Override public Map<String,Object> inputs() { return inputs; }
	@Override public String nextAction() { return buttons.poll(); }
	@Override public Map<String,Object> phase(String name, Map<String,Object> options) { return Map.of("status","ready"); }
	@Override public void activity(String name, Map<String,Object> policy) { activity=name; this.policy=policy; }
	@Override public void result(Object value) { result = value; }
	@Override public void overlay(Map<String,String> rows) { overlayRows=rows; }
	@Override public void markers(List<Map<String,Object>> markers) {}
	@Override public long activeTimeNanos() { return System.nanoTime(); }
}
