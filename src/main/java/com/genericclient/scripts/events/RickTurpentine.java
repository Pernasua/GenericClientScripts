package com.genericclient.scripts.events;

import com.genericclient.script.ScriptSettings;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;

@ScriptManifest(name="Rick Turpentine",author="GenericClient",category=Category.UTILITY,version=1,description="Accept and verify Rick Turpentine's reward.")
@ScriptSettings(id="rick-turpentine",randomEvents={375})
public final class RickTurpentine extends GiftEvent
{
	@Override protected Object runWorkflow() { return solve("rick_turpentine.reward",375,tick -> EventSupport.message(tick,"your reward is:")); }
}
