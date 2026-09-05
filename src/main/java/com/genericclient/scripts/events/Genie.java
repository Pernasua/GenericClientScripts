package com.genericclient.scripts.events;

import com.genericclient.script.ScriptSettings;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;

@ScriptManifest(name="Genie",author="GenericClient",category=Category.UTILITY,version=1,description="Accept and verify the Genie's lamp.")
@ScriptSettings(id="genie",randomEvents={326})
public final class Genie extends GiftEvent
{
	@Override protected Object runWorkflow()
	{
		int lamps = Inventory.count(2528);
		return solve("genie.reward",326,tick -> Inventory.count(2528) > lamps && EventSupport.message(tick,"your reward is:","lamp"));
	}
}
