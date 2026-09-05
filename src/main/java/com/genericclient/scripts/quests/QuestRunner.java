package com.genericclient.scripts.quests;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.WorkflowScript;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;

@ScriptManifest(name="Quest Runner",author="GenericClient",category=Category.QUEST,version=1,
	description="Run the maintained quest workflows from observed progress and inventory.")
@ScriptSettings(id="quest-runner",inputs={
	@ScriptSettings.Input(id="quest",label="Quest",choices={"witchs_house","waterfall","tree_gnome_village","fight_arena","the_grand_tree","monkey_madness_i"},
		labels={"Witch's House","Waterfall Quest","Tree Gnome Village","Fight Arena","The Grand Tree","Monkey Madness I"},defaultValue="witchs_house"),
	@ScriptSettings.Input(id="restock",label="Restock",choices={"ge","bank_only"},labels={"Grand Exchange","Bank only"},defaultValue="ge"),
	@ScriptSettings.Input(id="scope",label="Scope",choices={"complete","checkpoint","prison_cell"},labels={"Quest completion","Next checkpoint","Monkey Madness prison cell"},defaultValue="complete")
},actions=@ScriptSettings.Button(id="stop_safely",label="Stop safely"))
public final class QuestRunner extends WorkflowScript
{
	@Override protected Object runWorkflow()
	{
		String selected = Automation.input("quest");
		require(!"prison_cell".equals(Automation.input("scope")) || selected.equals("monkey_madness_i"),"Prison-cell scope belongs to Monkey Madness I");
		Automation.activity("questing");
		return quest(selected).run();
	}
	private QuestWorkflow quest(String key)
	{
		switch (key)
		{
			case "witchs_house":return new WitchsHouse();
			case "waterfall":return new Waterfall();
			case "tree_gnome_village":return new TreeGnomeVillage();
			case "fight_arena":return new FightArena();
			case "the_grand_tree":return new GrandTree();
			case "monkey_madness_i":return new MonkeyMadness();
			default:throw new IllegalArgumentException("Unknown quest: " + key);
		}
	}
}
