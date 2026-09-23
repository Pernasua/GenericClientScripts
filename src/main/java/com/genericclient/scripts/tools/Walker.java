package com.genericclient.scripts.tools;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;

@ScriptManifest(name="Walker",author="GenericClient",category=Category.UTILITY,version=1,
	description="Travel to a selected city destination.")
@ScriptSettings(id="walker",inputs=@ScriptSettings.Input(id="destination",label="Destination",
	choices={"grand_exchange","varrock_center","edgeville_bank","falador_center","draynor_village","lumbridge_castle"},
	labels={"Grand Exchange","Varrock Center","Edgeville Bank","Falador Center","Draynor Village","Lumbridge Castle"},defaultValue="grand_exchange"))
public final class Walker extends WorkflowScript
{
	private static final Map<String,Tile> PLACES = Map.of(
		"grand_exchange",new Tile(3164,3487),"varrock_center",new Tile(3210,3424),
		"edgeville_bank",new Tile(3094,3492),"falador_center",new Tile(2965,3379),
		"draynor_village",new Tile(3105,3251),"lumbridge_castle",new Tile(3222,3218));
	@Override protected Object runWorkflow()
	{
		String place = Automation.input("destination");
		Automation.overlay(Map.of("Destination",place,"State","Walking"));
		Travel.to(PLACES.get(place),3);
		Automation.phase("travel." + place + ".arrived");
		return Map.of("status","arrived","destination",place);
	}
}
