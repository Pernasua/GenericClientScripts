package com.genericclient.scripts.training;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Progress;
import com.genericclient.scripts.shared.Safety;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Supply;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.interactive.NPCs;
import org.dreambot.api.methods.magic.Magic;
import org.dreambot.api.methods.magic.Normal;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.NPC;
import org.dreambot.api.wrappers.items.Item;

@ScriptManifest(name="AIO Magic Trainer", author="GenericClient", category=Category.MAGIC, version=1,
	description="Train Magic with supplied combat spells, Superheat, or Low Alchemy.")
@ScriptSettings(id="aio-magic", inputs={
	@ScriptSettings.Input(id="target_level",label="Target level",choices={"13","20","30","50"},defaultValue="20"),
	@ScriptSettings.Input(id="method",label="Method",choices={"auto","port_sarim_jail"},labels={"Auto","Port Sarim jail"},defaultValue="auto"),
	@ScriptSettings.Input(id="restock",label="Restock",choices={"ge","bank_only"},labels={"Grand Exchange","Bank only"},defaultValue="ge")
}, actions=@ScriptSettings.Button(id="stop_after_cast",label="Stop after cast"))
public final class MagicTrainer extends WorkflowScript
{
	private static final Tile JAIL = new Tile(3012, 3189);
	private static final Tile DISENGAGE = new Tile(3012, 3190);
	private static final List<String> TARGETS = List.of("Pirate", "Thief", "Mugger", "Black knight");
	private static final CombatSpell[] SPELLS = {
		new CombatSpell(Normal.WIND_STRIKE, 1381, Map.of(558, 1)),
		new CombatSpell(Normal.WATER_STRIKE, 1381, Map.of(558, 1, 555, 1)),
		new CombatSpell(Normal.EARTH_STRIKE, 1381, Map.of(558, 1, 557, 2)),
		new CombatSpell(Normal.FIRE_STRIKE, 1387, Map.of(558, 1, 556, 2)),
		new CombatSpell(Normal.FIRE_BOLT, 1387, Map.of(562, 1, 556, 3))
	};
	private int target;
	private int targetXp;
	private boolean purchase;
	private boolean stopRequested;
	private int initialXp;

	@Override protected Object runWorkflow()
	{
		target = Integer.parseInt(Automation.input("target_level"));
		targetXp = Skills.getExperienceForLevel(target);
		purchase = Automation.input("restock").equals("ge");
		initialXp = Skills.getExperience(Skill.MAGIC);
		if (initialXp >= targetXp) return result("already_complete");
		boolean automatic = Automation.input("method").equals("auto");
		int combatTarget = automatic ? Math.min(targetXp, Skills.getExperienceForLevel(43)) : targetXp;
		if (initialXp < combatTarget) trainCombat(combatTarget);
		if (!stopRequested && Skills.getExperience(Skill.MAGIC) < targetXp) trainAtBank();
		Progress.training(Skill.MAGIC, target, stopRequested ? "Stopped" : "Complete");
		return result(stopRequested ? "stopped" : "complete");
	}

	private void trainCombat(int goal)
	{
		Map<Integer, Integer> inventory = combatSupplies(goal);
		List<Supply> requests = new ArrayList<>();
		for (Map.Entry<Integer, Integer> item : inventory.entrySet()) requests.add(supply(item.getKey(), item.getValue()));
		Travel.to(Travel.GRAND_EXCHANGE, 8);
		Supplies.ensure(requests, purchase);
		Supplies.loadout(inventory, 2);
		Safety.configure(Safety.wine(), new Tile(3020, 3210), 3, false);
		Supplies.equip(spell().staff);
		Travel.via(new Tile(3104,3420), new Tile(3070,3359), new Tile(3052,3294),
			new Tile(3038,3245), new Tile(3024,3205));
		Travel.to(JAIL, 0);
		Automation.activity("skilling");
		Automation.phase("magic.port_sarim_jail.arrived");
		Normal configured = null;
		int failures = 0;
		while (Skills.getExperience(Skill.MAGIC) < goal && !stopRequested)
		{
			if (Dialogues.canContinue()) require(Dialogues.continueDialogue(), "Combat dialogue did not continue");
			CombatSpell current = spell();
			Supplies.equip(current.staff);
			if (configured != current.spell)
			{
				require(Magic.setAutocastSpell(current.spell), "Autocast could not be configured");
				configured = current.spell;
			}
			for (Map.Entry<Integer, Integer> rune : current.runes.entrySet())
				require(Inventory.count(rune.getKey()) >= rune.getValue(), "Combat runes exhausted");
			NPC npc = availableTarget();
			if (npc == null)
			{
				require(Sleep.sleepUntil(() -> availableTarget() != null, 60_000), "No eligible combat target appeared");
				npc = availableTarget();
			}
			Progress.training(Skill.MAGIC, target, current.spell.name());
			int before = Skills.getExperience(Skill.MAGIC);
			if (!npc.interact("Attack"))
			{
				require(++failures < 5, "Repeated combat interaction failures");
				Sleep.sleepTicks(2);
				continue;
			}
			int observed = observeCombat(goal,before);
			failures = observed > before ? 0 : failures + 1;
			require(failures < 5, "Combat casts did not produce Magic XP");
		}
		Travel.to(DISENGAGE, 0);
	}

	private int observeCombat(int goal, int before)
	{
		int quiet = 0;
		int idle = 0;
		int observed = before;
		for (int tick = 0; tick < 80; tick++)
		{
			Sleep.sleepTicks(1);
			int xp = Skills.getExperience(Skill.MAGIC);
			quiet = xp > observed ? 0 : quiet + 1;
			observed = xp;
			idle = com.genericclient.scripts.shared.WorkflowScript.player().isInCombat() ? 0 : idle + 1;
			stopRequested |= "stop_after_cast".equals(Automation.nextAction());
			if (xp >= goal || stopRequested || idle >= 2 || quiet >= 12) break;
		}
		return observed;
	}

	private void trainAtBank()
	{
		require(SnapshotData.action("safety.clear", Map.of()), "Combat safety state did not clear");
		Travel.to(Travel.GRAND_EXCHANGE, 8);
		boolean superheat = Skills.getRealLevel(Skill.SMITHING) >= 15;
		Normal spell = superheat ? Normal.SUPERHEAT_ITEM : Normal.LOW_LEVEL_ALCHEMY;
		int material = superheat ? 440 : 890;
		int casts = (int) Math.ceil((targetXp - Skills.getExperience(Skill.MAGIC)) / spell.getExperience());
		Supplies.ensure(List.of(supply(1387, 1), supply(561, casts), supply(material, casts)), purchase);
		while (Skills.getExperience(Skill.MAGIC) < targetXp && !stopRequested)
		{
			int remaining = (int) Math.ceil((targetXp - Skills.getExperience(Skill.MAGIC)) / spell.getExperience());
			int batch = superheat ? Math.min(26, remaining) : remaining;
			Automation.intent(superheat ? "magic.load_superheat_batch" : "magic.load_alchemy_batch", () ->
			{
				Supplies.loadout(Map.of(1387, 1, 561, remaining, material, batch), 0);
				Supplies.equip(1387);
				return null;
			});
			Automation.activity("skilling");
			Automation.phase(superheat ? "magic.superheat.bank" : "magic.low_alchemy.bank");
			while (Inventory.contains(material) && Skills.getExperience(Skill.MAGIC) < targetXp && !stopRequested)
			{
				int beforeXp = Skills.getExperience(Skill.MAGIC);
				int beforeQuantity = Inventory.count(material);
				Item item = Inventory.get(material);
				Progress.training(Skill.MAGIC, target, superheat ? "Superheating" : "Low Alchemy");
				require(Magic.castSpellOn(spell, item), "Spell interaction failed");
				await(() -> Skills.getExperience(Skill.MAGIC) > beforeXp && Inventory.count(material) < beforeQuantity,
					6000, "Spell XP and material consumption were not observed");
				stopRequested |= "stop_after_cast".equals(Automation.nextAction());
			}
		}
	}

	private Map<Integer, Integer> combatSupplies(int goal)
	{
		Map<Integer, Integer> stock = new LinkedHashMap<>();
		stock.put(1993, 6);
		int start = Skills.getExperience(Skill.MAGIC);
		for (int i = 0; i < SPELLS.length; i++)
		{
			CombatSpell tier = SPELLS[i];
			int lower = Math.max(start, Skills.getExperienceForLevel(tier.spell.getLevel()));
			int upper = i + 1 < SPELLS.length ? Math.min(goal, Skills.getExperienceForLevel(SPELLS[i + 1].spell.getLevel())) : goal;
			if (lower >= upper) continue;
			int casts = (int) Math.ceil((upper - lower) / tier.spell.getExperience());
			stock.put(tier.staff, 1);
			for (Map.Entry<Integer, Integer> rune : tier.runes.entrySet()) stock.merge(rune.getKey(), casts * rune.getValue(), Integer::sum);
		}
		return stock;
	}

	private CombatSpell spell()
	{
		int level = Skills.getRealLevel(Skill.MAGIC);
		CombatSpell selected = SPELLS[0];
		for (CombatSpell spell : SPELLS) if (level >= spell.spell.getLevel()) selected = spell;
		return selected;
	}

	private NPC availableTarget()
	{
		String player = com.genericclient.scripts.shared.WorkflowScript.player().getName();
		List<Integer> eligible = new ArrayList<>();
		for (Map<?, ?> npc : SnapshotData.rows("npcs", Map.of("within", 15)))
		{
			if (TARGETS.contains(npc.get("name")) && !Boolean.TRUE.equals(npc.get("dead")) &&
				Boolean.TRUE.equals(npc.get("line_of_sight")) &&
				(npc.get("interacting") == null || player.equals(npc.get("interacting"))))
				eligible.add(((Number) npc.get("index")).intValue());
		}
		return NPCs.closest(npc -> eligible.contains(npc.getIndex()));
	}

	private Supply supply(int id, int quantity)
	{
		switch (id)
		{
			case 1381: return new Supply(id, "Staff of air", quantity, 2000);
			case 1387: return new Supply(id, "Staff of fire", quantity, 2000);
			case 1993: return new Supply(id, "Jug of wine", quantity, 10);
			case 558: return new Supply(id, "Mind rune", quantity, 10);
			case 555: return new Supply(id, "Water rune", quantity, 10);
			case 556: return new Supply(id, "Air rune", quantity, 10);
			case 557: return new Supply(id, "Earth rune", quantity, 10);
			case 562: return new Supply(id, "Chaos rune", quantity, 250);
			case 561: return new Supply(id, "Nature rune", quantity, 250);
			case 440: return new Supply(id, "Iron ore", quantity, 150);
			case 890: return new Supply(id, "Adamant arrow", quantity, 50);
			default: throw new IllegalArgumentException("Unsupported Magic supply " + id);
		}
	}

	private Map<String, Object> result(String status)
	{
		int xp = Skills.getExperience(Skill.MAGIC);
		return Map.of("status", status, "final_level", Skills.getRealLevel(Skill.MAGIC), "final_xp", xp,
			"gained_xp", xp - initialXp, "target_level", target);
	}

	private static final class CombatSpell
	{
		final Normal spell;
		final int staff;
		final Map<Integer, Integer> runes;
		CombatSpell(Normal spell, int staff, Map<Integer, Integer> runes) { this.spell = spell; this.staff = staff; this.runes = runes; }
	}
}
