package com.genericclient.scripts.shared;

import com.genericclient.script.Automation;
import java.util.Arrays;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.utilities.Sleep;

public final class Conversations
{
	private Conversations() {}
	public static void finish(String... permittedChoices)
	{
		Automation.intent("dialogue.finish", () ->
		{
			for (int step = 0; step < 80; step++)
			{
				if (!Dialogues.inDialogue()) return null;
				if (Dialogues.canContinue()) WorkflowScript.require(Dialogues.continueDialogue(), "Dialogue did not continue");
				else
				{
					String selected = Arrays.stream(Dialogues.getOptions())
						.filter(option -> Arrays.asList(permittedChoices).contains(option)).findFirst().orElse(null);
					WorkflowScript.require(selected != null, "Unexpected dialogue choices: " + Arrays.toString(Dialogues.getOptions()));
					WorkflowScript.require(Dialogues.chooseOption(selected), "Dialogue choice failed: " + selected);
				}
				Sleep.sleepTicks(1);
			}
			throw new IllegalStateException("Dialogue did not finish");		});

	}
}
