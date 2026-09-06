package com.genericclient.scripts.training;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.Progress;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.skills.Skill;
import org.dreambot.api.methods.skills.Skills;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;

@ScriptManifest(name="AIO Agility Trainer",author="GenericClient",category=Category.AGILITY,version=1,
	description="Train Agility on the Gnome Stronghold course through level 25.")
@ScriptSettings(id="aio-agility",inputs={
	@ScriptSettings.Input(id="target_level",label="Target level",choices={"10","20","25"},defaultValue="25"),
	@ScriptSettings.Input(id="method",label="Method",choices={"auto","gnome_stronghold"},labels={"Auto","Gnome Stronghold"},defaultValue="auto")
},actions=@ScriptSettings.Button(id="stop_after_obstacle",label="Stop after obstacle"))
public final class AgilityTrainer extends WorkflowScript
{
	private static final Obstacle[] OBSTACLES = {
		new Obstacle(23145,"Walk-across"), new Obstacle(23134,"Climb-over"), new Obstacle(23559,"Climb"),
		new Obstacle(23557,"Walk-on"), new Obstacle(23560,"Climb-down"), new Obstacle(23135,"Climb-over"),
		new Obstacle(23139,"Squeeze-through")
	};

	@Override protected Object runWorkflow()
	{
		int target = Integer.parseInt(Automation.input("target_level"));
		int goal = Skills.getExperienceForLevel(target);
		if (Skills.getExperience(Skill.AGILITY) >= goal) return Map.of("status","already_complete");
		enterCourse();
		int obstacles = 0;
		int laps = 0;
		String outcome = "complete";
		while (Skills.getExperience(Skill.AGILITY) < goal)
		{
			if ("stop_after_obstacle".equals(Automation.nextAction())) { outcome = "stopped"; break; }
			int stage = stage(com.genericclient.scripts.shared.WorkflowScript.player().getTile());
			if (stage == 0) Travel.to(new Tile(2475,3437), 0);
			Automation.activity("skilling");
			Progress.training(Skill.AGILITY, target, OBSTACLES[stage].action);
			perform(OBSTACLES[stage]);
			obstacles++;
			if (stage == 6) laps++;
		}
		return Map.of("status",outcome,"final_level",Skills.getRealLevel(Skill.AGILITY),
			"final_xp",Skills.getExperience(Skill.AGILITY),"obstacles",obstacles,"laps",laps);
	}

	private void enterCourse()
	{
		Tile player = com.genericclient.scripts.shared.WorkflowScript.player().getTile();
		if (player.getX() >= 2455 && player.getX() <= 2500 && player.getY() >= 3400 && player.getY() <= 3450) return;
		Travel.westernTraining(new Tile(2545,3260),4);
		Travel.via(new Tile(2580,3260), new Tile(2580,3310),
			new Tile(2580,3355), new Tile(2530,3370), new Tile(2480,3375), new Tile(2461,3379));
		for (int attempt = 0; attempt < 2 && com.genericclient.scripts.shared.WorkflowScript.player().getTile().getY() < 3384; attempt++)
		{
			GameObject gate = GameObjects.closest(190);
			require(gate != null && gate.interact("Open"), "Stronghold gate did not open");
			Sleep.sleepTicks(2);
			Conversations.finish("Okay then.");
		}
		Travel.via(new Tile(2461,3400), new Tile(2470,3420));
	}

	static int stage(Tile tile)
	{
		if (tile.getZ() == 1) return 2;
		if (tile.getZ() == 2) return tile.getX() < 2483 ? 3 : 4;
		if (tile.getZ() != 0) throw new IllegalStateException("Unexpected course plane");
		if (tile.getY() >= 3434 || tile.getX() <= 2470 && tile.getY() <= 3424) return 0;
		if (tile.getX() <= 2479 && tile.getY() <= 3432) return 1;
		if (tile.getX() >= 2482 && tile.getY() <= 3423) return 5;
		if (tile.getX() >= 2482 && tile.getY() >= 3427) return 6;
		return 0;
	}

	private void perform(Obstacle obstacle)
	{
		GameObject object = GameObjects.closest(obstacle.id);
		require(object != null, "Agility obstacle is not visible: " + obstacle.id);
		int before = Skills.getExperience(Skill.AGILITY);
		require(object.interact(obstacle.action), "Agility obstacle interaction failed");
		await(() -> Skills.getExperience(Skill.AGILITY) > before, 24_000, "Agility XP did not change");
		Conversations.finish();
		await(() -> !com.genericclient.scripts.shared.WorkflowScript.player().isAnimating(), 12_000, "Agility animation did not finish");
		Sleep.sleepTicks(1);
	}

	private static final class Obstacle
	{
		final int id;
		final String action;
		Obstacle(int id, String action) { this.id = id; this.action = action; }
	}
}
