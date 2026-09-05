package com.genericclient.scripts.shared;

import org.dreambot.api.methods.widget.Widgets;
import org.dreambot.api.wrappers.widgets.WidgetChild;

public final class Interfaces
{
	private Interfaces() {}
	public static WidgetChild widget(int packed)
	{
		WidgetChild widget = Widgets.get(packed >>> 16,packed & 0xffff);
		return widget != null && widget.isVisible() ? widget : null;
	}
	public static void click(int packed)
	{
		WidgetChild widget = widget(packed);
		if (widget == null || !widget.interact()) throw new IllegalStateException("Widget interaction failed: " + packed);
	}
}
