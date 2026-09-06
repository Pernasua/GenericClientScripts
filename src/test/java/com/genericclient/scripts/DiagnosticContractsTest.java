package com.genericclient.scripts;

import static org.junit.Assert.*;

import com.genericclient.scripts.tools.WalkStress;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.Test;

public class DiagnosticContractsTest
{
	@Test public void walkStressCollectsThreeAttemptsEvenWhenIndividualClicksAreRejected()
	{
		List<Object> reports = new ArrayList<>();
		List<String> phases = new ArrayList<>();
		SceneScenario scene = new SceneScenario(new WalkStress())
		{
			@Override public void log(Object message) { reports.add(message); }
			@Override public Map<String,Object> phase(String name, Map<String,Object> options)
			{
				phases.add(name);
				return super.phase(name,options);
			}
		};
		scene.input = (type,args) ->
		{
			assertEquals("walk.random", type);
			scene.receipt = Map.of("status", scene.gameInputs == 2 ? "dispatched" : "rejected",
				"result", scene.gameInputs == 2 ? "walk_dispatched" : "no_clickable_tile");
		};
		scene.run();
		assertEquals(Map.of("status","complete","attempts",3), scene.result);
		assertEquals(3, scene.gameInputs);
		assertEquals(List.of("diagnostics.walk-stress"), phases);
		assertEquals(3, reports.size());
		assertEquals("no_clickable_tile", ((Map<?,?>) reports.get(0)).get("result"));
		assertEquals("walk_dispatched", ((Map<?,?>) reports.get(1)).get("result"));
		assertEquals("no_clickable_tile", ((Map<?,?>) reports.get(2)).get("result"));
		assertEquals(Map.of("State","Complete","Attempts","3 / 3"), scene.overlayRows);
	}

	@Test public void manualCancellationStopsTheDiagnosticBeforeAnotherAttempt()
	{
		SceneScenario scene = new SceneScenario(new WalkStress());
		scene.input = (type,args) -> scene.stop();
		try { scene.run(); fail("Cancelled diagnostic continued"); }
		catch (java.util.concurrent.CancellationException expected) { assertFalse(scene.isRunning()); }
		assertEquals(1, scene.gameInputs);
		assertNull(scene.result);
	}
}
