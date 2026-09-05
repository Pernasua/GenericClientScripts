package com.genericclient.scripts.quests;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptScope;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Supply;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.magic.Magic;
import org.dreambot.api.methods.magic.Normal;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.settings.PlayerSettings;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.utilities.impl.Condition;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;
import org.dreambot.api.wrappers.items.Item;

abstract class QuestWorkflow
{
	final String key;
	final int varpId;
	final boolean purchase;
	final String scope;
	private int initialCheckpoint;

	QuestWorkflow(String key, int varpId)
	{
		this.key = key; this.varpId = varpId;
		purchase = "ge".equals(Automation.input("restock"));
		scope = Automation.input("scope");
	}

	Object run()
	{
		if (finished()) return Map.of("status","complete","quest",key);
		validate();
		initialCheckpoint = checkpoint();
		for (int step = 0; step < 200; step++)
		{
			if (finished())
			{
				SnapshotData.action("safety.clear",Map.of());
				return Map.of("status","complete","quest",key,"varp",varp());
			}
			if ("stop_safely".equals(Automation.nextAction())) { escape(); return Map.of("status","stopped","quest",key); }
			if (scope.equals("checkpoint") && checkpointReached(initialCheckpoint))
				return Map.of("status","checkpoint","quest",key,"varp",varp());
			String phase = phase();
			Automation.overlay(Map.of("Quest",key,"Phase",phase));
			Automation.phase("quest." + key + "." + phase,Map.of("policy",WorkflowScript.NO_DISCRETIONARY));
			execute(phase);
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Quest stage limit reached: " + key);
	}
	abstract String phase();
	abstract void execute(String phase);
	abstract void validate();
	abstract void escape();
	int checkpoint() { return varp(); }
	boolean checkpointReached(int initial) { return checkpoint() > initial; }
	int varp() { return PlayerSettings.getConfig(varpId); }
	int bit(int id) { return PlayerSettings.getBitValue(id); }
	boolean finished() { return "finished".equals(SnapshotData.map(SnapshotData.read("quests").get(key)).get("state")); }
	static Tile tile() { return WorkflowScript.player().getTile(); }
	static void require(boolean value, String message) { if (!value) throw new IllegalStateException(message); }
	static void await(Condition condition, int ticks, String message)
	{
		require(Sleep.sleepUntil(condition,ticks*600L),message);
	}
	static boolean carried(int id) { return Inventory.contains(id) || Equipment.contains(id); }
	static NPC npc(int... ids) { return NPCs.closest(Arrays.stream(ids).boxed().toArray(Integer[]::new)); }
	static GameObject object(int id, Tile point)
	{
		return GameObjects.closest(candidate -> candidate.getId() == id && (point == null || candidate.getTile().equals(point)));
	}
	void walk(Tile point, int within, boolean hazardous)
	{
		Travel.to(point,within,hazardous ? "hazardous_travel" : "questing",
			hazardous ? WorkflowScript.NO_DISCRETIONARY : Map.of());
	}
	void interact(int id, String action, Tile point, Condition complete, boolean hazardous)
	{
		if (point != null && point.getZ() == tile().getZ()) walk(point,3,hazardous);
		GameObject target = object(id,point);
		require(target != null && target.interact(action),"Quest object interaction failed: " + id + " " + action);
		await(complete,50,"Quest object result was not observed: " + id);
	}
	void use(int item, int object, Tile point, Condition complete, boolean hazardous)
	{
		if (point != null && point.getZ() == tile().getZ()) walk(point,3,hazardous);
		GameObject target = object(object,point);
		Item held = Inventory.get(item);
		require(held != null && target != null && held.useOn(target),"Quest item use failed: " + item + " on " + object);
		await(complete,50,"Quest item-use result was not observed");
	}
	void take(int id, Tile point)
	{
		if (Inventory.contains(id)) return;
		walk(point,5,false);
		require(SnapshotData.action("ground_item.take",Map.of("id",id,"world",Map.of("x",point.getX(),"y",point.getY(),"plane",point.getZ()),"within",12)),
			"Quest item could not be taken: " + id);
		await(() -> Inventory.contains(id),30,"Quest item was not observed: " + id);
	}
	void talk(int[] ids, Tile point, Condition complete, boolean hazardous, String... choices)
	{
		if (complete.verify()) return;
		if (point != null) walk(point,5,hazardous);
		Automation.intent(key + ".talk", () ->
		{
			NPC target = NPCs.closest(candidate -> Arrays.stream(ids).anyMatch(id -> candidate.getId() == id) && candidate.hasAction("Talk-to"));
			require(target != null && target.interact("Talk-to"),"Quest NPC interaction failed: " + Arrays.toString(ids));
			dialogue(complete,160,choices);
			return null;
		});
	}
	void dialogue(Condition complete, int ticks, String... choices)
	{
		Automation.intent(key + ".finish_dialogue", () ->
		{
			long since = ScriptScope.current().tick();
			long lastMessageBox = since-1;
			for (int tick = 0; tick < ticks; tick++)
			{
				if (complete.verify()) return null;
				boolean advancedMessage = false;
				for (Map<?,?> message : SnapshotData.rows("messages",Map.of("since_tick",since,"limit",20)))
				{
					long observed = ((Number)message.get("game_tick")).longValue();
					if ("mesbox".equals(message.get("type")) && observed > lastMessageBox)
					{
						require(SnapshotData.action("ui.key",Map.of("key","SPACE")),"Quest message box did not advance");
						lastMessageBox = observed;
						advancedMessage = true;
					}
				}
				if (advancedMessage) { Sleep.sleepTicks(1); continue; }
				if (Dialogues.canContinue()) require(Dialogues.continueDialogue(),"Quest dialogue did not continue");
				else if (Dialogues.inDialogue())
				{
					String selected = Arrays.stream(choices).filter(choice -> Arrays.asList(Dialogues.getOptions()).contains(choice)).findFirst().orElse(null);
					require(selected != null && Dialogues.chooseOption(selected),"Unexpected quest dialogue: " + Arrays.toString(Dialogues.getOptions()));
				}
				Sleep.sleepTicks(1);
			}
			throw new IllegalStateException("Quest dialogue result was not observed");		});

	}
	void prepare(List<Supply> supplies)
	{
		toExchange();
		Supplies.prepare(supplies,purchase);
	}
	void toExchange()
	{
		if (Travel.GRAND_EXCHANGE.distance() <= 8) return;
		if (Jewellery.carried(Jewellery.Destination.GRAND_EXCHANGE)) Jewellery.teleport(Jewellery.Destination.GRAND_EXCHANGE);
		else if (Jewellery.carried(Jewellery.Destination.BURTHORPE)) Jewellery.teleport(Jewellery.Destination.BURTHORPE);
		else if (Jewellery.carried(Jewellery.Destination.EMIRS_ARENA)) Jewellery.teleport(Jewellery.Destination.EMIRS_ARENA);
		else if (Travel.GRAND_EXCHANGE.distance() > 120) require(Magic.castSpell(Normal.HOME_TELEPORT),"Quest preparation needs a safe transport to a bank");
		Travel.to(Travel.GRAND_EXCHANGE,8);
	}
	static Supply necklace() { return new Supply(3853,"Games necklace",1,1000,3855,3857,3859,3861,3863,3865,3867); }
	static Supply duelingRing() { return new Supply(2552,"Ring of dueling",1,1000,2554,2556,2558,2560,2562,2564,2566); }
	static Supply wine(int count) { return new Supply(1993,"Jug of wine",count,100); }
	static Supply questItem(int id, String name) { return new Supply(id,name,1,0); }
	void foodGuard(boolean allowOverheal)
	{
		require(SnapshotData.action("safety.configure",Map.of("minimum_hitpoints",Math.max(4,Skills.getRealLevel(Skill.HITPOINTS)/4),
			"consumables",List.of(Map.of("id",1993,"action","Drink","heal_amount",11)),
			"continue_after_consumable",true,"allow_overheal",allowOverheal)),"Quest food guard could not be configured");
	}
	static boolean message(long since, String fragment)
	{
		return SnapshotData.rows("messages",Map.of("since_tick",since,"limit",60)).stream()
			.anyMatch(row -> ((String)row.get("text")).toLowerCase(java.util.Locale.ROOT).contains(fragment));
	}
	static Tile mapped(Tile template)
	{
		if (tile().getX() < 10000) return template;
		Map<?,?> mapping = SnapshotData.map(ScriptScope.current().read("instance",Map.of("template",
			Map.of("x",template.getX(),"y",template.getY(),"plane",template.getZ()))));
		return ((List<?>)mapping.get("matches")).stream().map(value ->
		{
			Map<?,?> point = (Map<?,?>)value;
			return new Tile(((Number)point.get("x")).intValue(),((Number)point.get("y")).intValue(),((Number)point.get("plane")).intValue());
		}).min(java.util.Comparator.comparingDouble(Tile::distance)).orElseThrow(() -> new IllegalStateException("Instance destination was not mapped: " + template));
	}
}
