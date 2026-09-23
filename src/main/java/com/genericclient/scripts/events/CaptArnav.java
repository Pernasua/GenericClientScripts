package com.genericclient.scripts.events;

import com.genericclient.scripts.shared.Conversations;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.methods.settings.PlayerSettings;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;

@ScriptManifest(name="Capt' Arnav",author="GenericClient",category=Category.UTILITY,version=1,description="Align the chest dials with their live labels and verify the reward.")
@ScriptSettings(id="capt-arnav",randomEvents={5426})
public final class CaptArnav extends WorkflowScript
{
	private static final int[] VARBITS = {9585,9593,9594};
	private static final int[] UP = {1703941,1703944,1703947};
	private static final int[] DOWN = {1703942,1703945,1703948};
	private static final Map<String,Integer> ITEMS = Map.of("COINS",0,"BOWL",1,"BAR",2,"RING",3);
	@Override protected Object runWorkflow()
	{
		long started = EventSupport.begin(5426);
		EventSupport.enter("capt_arnav.open_puzzle",() -> com.genericclient.scripts.shared.Interfaces.widget(1703961) != null,"Yes, I'll help you unlock your chest.");
		for (int dial = 0; dial < 3; dial++)
		{
			String label = com.genericclient.scripts.shared.Interfaces.widget(1703958+dial).getText().toUpperCase(java.util.Locale.ROOT);
			Integer required = ITEMS.get(label);
			require(required != null,"Unknown chest label: " + label);
			align(dial,required);
		}
		com.genericclient.scripts.shared.Interfaces.click(1703961);
		for (int tick = 0; tick < 30; tick++)
		{
			if (EventSupport.message(started,"your reward") || EventSupport.message(started,"successfully")) return Map.of("status","solved");
			Conversations.advance();
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Chest reward was not observed");
	}
	private void align(int dial, int required)
	{
		for (int attempt = 0; attempt < 4; attempt++)
		{
			int current = PlayerSettings.getBitValue(VARBITS[dial]);
			if (current == required) return;
			int up = Math.floorMod(required-current,4);
			int down = Math.floorMod(current-required,4);
			com.genericclient.scripts.shared.Interfaces.click(up <= down ? UP[dial] : DOWN[dial]);
			Sleep.sleepTicks(1);
		}
		require(PlayerSettings.getBitValue(VARBITS[dial]) == required,"Chest dial did not align");
	}
}
