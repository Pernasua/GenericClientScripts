package com.genericclient.scripts.events;

import com.genericclient.script.ScriptSettings;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;

@ScriptManifest(name="Drunken Dwarf",author="GenericClient",category=Category.UTILITY,version=1,description="Talk to the Drunken Dwarf and wait for his departure.")
@ScriptSettings(id="drunken-dwarf",randomEvents={322})
public final class DrunkenDwarf extends GiftEvent
{
	@Override protected Object runWorkflow() { return solve("drunken_dwarf.reward",322,tick -> true); }
}
