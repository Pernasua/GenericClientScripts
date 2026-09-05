package com.genericclient.scripts.events;

import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.settings.PlayerSettings;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;

@ScriptManifest(name="Pinball",author="GenericClient",category=Category.MINIGAME,version=1,description="Tag the indicated posts, reach ten points, and claim the reward.")
@ScriptSettings(id="pinball",randomEvents={6744})
public final class Pinball extends WorkflowScript
{
	private static final int[] POSTS = {8982,8984,9079,9081,9258};
	@Override protected Object runWorkflow()
	{
		long started = EventSupport.begin(6744);
		EventSupport.enter("pinball.accept_game",() -> GameObjects.closest(9293) != null,"Yes, pinball is fun.");
		for (int round = 0; round < 10 && PlayerSettings.getBitValue(2122) != 1; round++) tag();
		int score = PlayerSettings.getBitValue(2121);
		require(score >= 10 && PlayerSettings.getBitValue(2122) == 1,"Pinball did not reach its completion state");
		GameObject exit = GameObjects.closest(9293);
		require(exit != null && exit.interact("Exit"),"Pinball exit failed");
		EventSupport.await(() -> EventSupport.message(started,"your reward is:") || EventSupport.message(started,"you were awarded"),
			40,"Pinball reward was not observed");
		return Map.of("status","solved","score",score);
	}
	private void tag()
	{
		int current = PlayerSettings.getBitValue(2119);
		int score = PlayerSettings.getBitValue(2121);
		require(current >= 0 && current < POSTS.length,"Unknown pinball post");
		GameObject post = GameObjects.closest(POSTS[current]);
		require(post != null && post.interact("Tag"),"Pinball tag failed");
		for (int tick = 0; tick < 24; tick++)
		{
			Sleep.sleepTicks(1);
			int after = PlayerSettings.getBitValue(2121);
			if (after == score+1 || PlayerSettings.getBitValue(2122) == 1) return;
			require(after >= score,"Pinball score reset");
		}
		throw new IllegalStateException("Pinball score did not change");
	}
}
