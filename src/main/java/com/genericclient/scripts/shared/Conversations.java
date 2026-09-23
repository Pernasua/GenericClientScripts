package com.genericclient.scripts.shared;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptScope;
import com.genericclient.script.SnapshotData;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import org.dreambot.api.utilities.Sleep;

public final class Conversations
{
	private Conversations() {}
	public static void continuePage()
	{
		Map<String,Object> receipt = ScriptScope.current().execute("dialogue.continue",Map.of(),120_000);
		if ("dialogue_continue_not_visible".equals(receipt.get("result")) || "dialogue_is_choice".equals(receipt.get("result"))) return;
		WorkflowScript.require("dispatched".equals(receipt.get("status")),"Dialogue did not continue: " + receipt);
	}
	public static boolean advance(String... permittedChoices)
	{
		Map<?,?> page = SnapshotData.read("dialogue");
		if (!Boolean.TRUE.equals(page.get("open"))) return false;
		if ("continue".equals(page.get("type"))) continuePage();
		else choose((List<?>)page.get("options"),permittedChoices);
		return true;
	}
	public static String choose(List<?> options, String... permittedChoices)
	{
		for (String permitted : permittedChoices)
		{
			for (Object value : options)
			{
				Map<?,?> option = (Map<?,?>)value;
				if (!permitted.equals(option.get("text"))) continue;
				Map<String,Object> receipt = ScriptScope.current().execute("dialogue.choose",
					Map.of("index",option.get("index"),"text",permitted),120_000);
				if ("exact_dialogue_choice_not_visible".equals(receipt.get("result"))) return null;
				WorkflowScript.require("dispatched".equals(receipt.get("status")),"Dialogue choice failed: " + permitted);
				return permitted;
			}
		}
		throw new IllegalStateException("Unexpected dialogue choices: " + Arrays.toString(options.stream()
			.map(value -> ((Map<?,?>)value).get("text")).toArray()));
	}
	public static void finish(String... permittedChoices)
	{
		Automation.intent("dialogue.finish", () ->
		{
			for (int step = 0; step < 80; step++)
			{
				if (!advance(permittedChoices)) return null;
				Sleep.sleepTicks(1);
			}
			throw new IllegalStateException("Dialogue did not finish");
		});
	}
}
