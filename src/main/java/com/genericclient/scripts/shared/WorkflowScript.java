package com.genericclient.scripts.shared;

import com.genericclient.script.Automation;
import org.dreambot.api.Client;
import org.dreambot.api.script.AbstractScript;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.utilities.impl.Condition;

/** A bounded catalog workflow runs on the host's cancellable script worker. */
public abstract class WorkflowScript extends AbstractScript
{
	public static final java.util.Map<String,Object> NO_DISCRETIONARY = java.util.Map.of(
		"breaks",false,"cursor_release","none","fidget","none");

	@Override public final int onLoop()
	{
		if (!Client.isLoggedIn()) return 600;
		Automation.finish(runWorkflow());
		return -1;
	}

	protected abstract Object runWorkflow();

	public static org.dreambot.api.wrappers.interactive.Player player()
	{
		org.dreambot.api.wrappers.interactive.Player player = org.dreambot.api.methods.interactive.Players.getLocal();
		while (player == null || !player.exists())
		{
			Sleep.sleep(50);
			player = org.dreambot.api.methods.interactive.Players.getLocal();
		}
		return player;
	}

	public static void require(boolean condition, String message)
	{
		if (!condition) throw new IllegalStateException(message);
	}

	protected static void await(Condition condition, long timeout, String message)
	{
		require(Sleep.sleepUntil(condition, timeout), message);
	}

	public static void awaitTicks(Condition condition, int ticks, String message)
	{
		require(Sleep.sleepUntil(condition, ticks * 600L), message);
	}
}
