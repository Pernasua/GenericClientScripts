package com.genericclient.scripts;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

final class IntentTrace
{
	final List<String> entries = new ArrayList<>();
	final Map<String,List<String>> actions = new LinkedHashMap<>();
	String current;

	<T> T run(String name, Supplier<T> body)
	{
		String previous = current;
		if (previous == null) { current = name; entries.add(name); }
		try { return body.get(); }
		finally { current = previous; }
	}

	void observe(String action)
	{
		actions.computeIfAbsent(action, ignored -> new ArrayList<>()).add(current);
	}
}
