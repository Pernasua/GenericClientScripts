package com.genericclient.scripts.quests;

import com.genericclient.script.Automation;
import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Supply;
import java.util.ArrayList;
import java.util.List;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Area;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.methods.widget.Widgets;

final class WitchsHouse extends QuestWorkflow
{
	static final Tile BASEMENT_ENTRY = new Tile(2906,9876);
	static final Tile SURFACE_ENTRY = new Tile(2906,3476);
	static final Area HOUSE = new Area(2901,3466,2907,3476);
	static final Area BASEMENT_EAST = new Area(2903,9870,2909,9878);
	static final Area BASEMENT_WEST = new Area(2897,9870,2902,9878);
	static final Area SHED = new Area(2934,3459,2937,3467);
	private boolean introPrepared;
	private boolean combatPrepared;
	WitchsHouse() { super("witchs_house",226); }
	@Override boolean finished() { return varp() == 7 || super.finished(); }
	@Override void validate()
	{
		require(Skills.getRealLevel(Skill.MAGIC) >= 13 && Skills.getRealLevel(Skill.HITPOINTS) >= 12,
			"Witch's House requires Magic 13 and at least 12 Hitpoints for this route");
	}
	@Override boolean checkpointReached(int initial)
	{
		return varp() == 6 || varp() == 5 && carried(2411);
	}

	@Override String phase()
	{
		int progress = varp();
		if (progress <= 2 && !introPrepared && (!carried(1059) || !Inventory.contains(1985))) return "prepare";
		if (progress == 0) return "accept";
		if (progress <= 2) return earlyPhase();
		if (progress == 3) return Inventory.contains(2408) ? "read_diary" : "take_diary";
		if (progress == 5)
		{
			if (!combatPrepared && !SHED.contains(tile())) return "prepare_combat";
			return Inventory.contains(2411) ? "experiment" : "garden";
		}
		if (progress == 6) return "return_ball";
		throw new IllegalStateException("Unexpected Witch's House stage: " + progress);
	}
	private String earlyPhase()
	{
		if (!Inventory.contains(2410))
		{
			if (BASEMENT_EAST.contains(tile())) return Equipment.contains(1059) ? "open_gate" : "equip_gloves";
			if (BASEMENT_WEST.contains(tile())) return GameObjects.closest(2869) == null ? "open_cupboard" : "take_magnet";
			if (HOUSE.contains(tile())) return "basement";
			return Inventory.contains(2409) ? "enter_house" : "house_key";
		}
		return BASEMENT_EAST.contains(tile()) || BASEMENT_WEST.contains(tile()) ? "upstairs" : "mouse";
	}
	@Override void execute(String phase)
	{
		switch (phase)
		{
			case "prepare": prepareIntro(); break;
			case "accept": talk(new int[]{3994},new Tile(2928,3456),() -> varp() > 0,false,"What's the matter?","Ok, I'll see what I can do.","Yes."); break;
			case "house_key": interact(2867,"Look-under",new Tile(2900,3474),() -> Inventory.contains(2409),false); break;
			case "enter_house": openAndCross(2861,new Tile(2900,3473),new Tile(2902,3473)); break;
			case "basement": walk(BASEMENT_ENTRY,0,false); break;
			case "equip_gloves": Supplies.equip(1059); break;
			case "open_gate": openAndCross(2866,new Tile(2902,9873),new Tile(2901,9874)); break;
			case "open_cupboard": interact(2868,"Open",new Tile(2898,9873),() -> GameObjects.closest(2869) != null,false); break;
			case "take_magnet": interact(2869,"Search",new Tile(2898,9873),() -> Inventory.contains(2410),false); break;
			case "upstairs": walk(SURFACE_ENTRY,0,false); break;
			case "mouse": lureMouse(); break;
			case "take_diary": take(2408,new Tile(2903,3471)); break;
			case "read_diary":
				Automation.intent("witchs_house.read_diary", () ->
				{
					require(Inventory.interact(2408,"Read"),"Witch's diary could not be read");
					await(() -> varp() >= 5,20,"Witch's diary stage did not update");
					require(Widgets.closeAll(),"Witch's diary did not close");
					return null;
				}); break;
			case "prepare_combat": prepareCombat(); break;
			case "garden": new WitchGarden(this).fountain(); break;
			case "experiment": new WitchExperiment(this).fight(); break;
			case "return_ball": returnBall(); break;
			default: throw new IllegalArgumentException("Unknown Witch's House phase: " + phase);
		}
	}
	private void prepareIntro()
	{
		List<Supply> supplies = new ArrayList<>(List.of(new Supply(1985,"Cheese",2,100),new Supply(1059,"Leather gloves",1,50),necklace()));
		for (int id : new int[]{2409,2410,2408,2411}) if (carried(id) || Supplies.owned(id) > 0) supplies.add(questItem(id,"Quest item"));
		prepare(supplies);
		introPrepared = true;
	}
	private void prepareCombat()
	{
		List<Supply> supplies = new ArrayList<>(List.of(new Supply(1387,"Staff of fire",1,1200),
			new Supply(556,"Air rune",300,10),new Supply(558,"Mind rune",150,10),new Supply(2550,"Ring of recoil",4,1000),
			necklace(),wine(6),questItem(2409,"Door key")));
		if (carried(2411) || Supplies.owned(2411) > 0) supplies.add(questItem(2411,"Shed key"));
		prepare(supplies);
		Jewellery.teleport(Jewellery.Destination.BURTHORPE);
		combatPrepared = true;
	}
	private void openAndCross(int id, Tile door, Tile inside)
	{
		walk(door,3,false);
		require(object(id,door).interact("Open"),"Witch's House door did not open");
		walk(inside,0,false);
	}
	private void lureMouse()
	{
		walk(new Tile(2903,3467),3,false);
		Automation.intent("witchs_house.lure_mouse", () ->
		{
			require(Inventory.get(1985).useOn(object(2870,new Tile(2903,3466))),"Cheese could not be placed at the mouse hole");
			await(() -> npc(4000) != null,50,"Mouse did not appear");
			require(Inventory.get(2410).useOn(npc(4000)),"Magnet could not be attached to the mouse");
			await(() -> varp() >= 3,20,"Mouse stage did not update");
			return null;
		});
	}
	private void returnBall()
	{
		take(2407,new Tile(2935,3460));
		if (tile().getX() >= 2900 && tile().getX() <= 2937 && tile().getY() >= 3459 && tile().getY() <= 3475)
			Jewellery.teleport(Jewellery.Destination.BURTHORPE);
		require(Inventory.contains(2407),"Ball was lost before returning to the boy");
		talk(new int[]{3994},new Tile(2927,3455),this::finished,false);
	}
	@Override void escape() { Jewellery.teleport(Jewellery.Destination.BURTHORPE); }
}
