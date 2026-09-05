package com.genericclient.scripts.events;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.Locale;
import java.util.Map;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.utilities.Sleep;

@ScriptManifest(name="Certer",author="GenericClient",category=Category.UTILITY,version=1,description="Identify the displayed item and select its live answer label.")
@ScriptSettings(id="certer",randomEvents={5436,5437,5438,5439,5440,5441})
public final class Certer extends WorkflowScript
{
	private static final int ITEM = 12058631;
	private static final Map<Integer,String> ANSWERS = Map.of(2807,"A bowl.",8834,"A ring.",8828,"An axe.",
		8832,"A shield.",8835,"A pair of shears.",8833,"A helmet.",8829,"A fish.",8837,"A spade.");
	@Override protected Object runWorkflow()
	{
		long started = EventSupport.begin(5436,5437,5438,5439,5440,5441);
		return Automation.intent("certer.answer_question", () ->
		{
			EventSupport.enter("certer.answer_question",() -> com.genericclient.scripts.shared.Interfaces.widget(ITEM) != null);
			int model = com.genericclient.scripts.shared.Interfaces.widget(ITEM).getModelId();
			String expected = ANSWERS.get(model);
			require(expected != null,"Unrecognized Certer model: " + model);
			EventSupport.await(() -> com.genericclient.scripts.shared.Interfaces.widget(12058625) != null && com.genericclient.scripts.shared.Interfaces.widget(12058626) != null &&
				com.genericclient.scripts.shared.Interfaces.widget(12058627) != null,10,"Certer labels did not appear");
			int answer = -1;
			for (int index = 0; index < 3; index++)
			{
				if (normalize(com.genericclient.scripts.shared.Interfaces.widget(12058625+index).getText()).equals(normalize(expected)))
				{
					require(answer == -1,"Certer has duplicate matching labels");
					answer = index;
				}
			}
			require(answer >= 0,"Certer answer label was not found");
			com.genericclient.scripts.shared.Interfaces.click(12058632+answer);
			for (int tick = 0; tick < 30; tick++)
			{
				if (!EventSupport.present() && EventSupport.message(started,"your reward is:"))
					return Map.of("status","solved","model_id",model,"answer",expected);
				EventSupport.dialogue();
				Sleep.sleepTicks(1);
			}
			throw new IllegalStateException("Certer reward was not observed");		});

	}
	static String normalize(String label) { return label.toLowerCase(Locale.ROOT).replaceAll("\\s+"," ").strip().replaceAll("[.!?]+$",""); }
}
