package com.genericclient.scripts.gathering.snapegrass;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptSettings;
import com.genericclient.script.SnapshotData;
import java.util.List;
import java.util.Map;
import org.dreambot.api.Client;
import org.dreambot.api.methods.container.impl.bank.Bank;
import org.dreambot.api.methods.grandexchange.GrandExchange;
import org.dreambot.api.methods.walking.impl.Walking;
import org.dreambot.api.script.AbstractScript;
import org.dreambot.api.script.Category;
import org.dreambot.api.script.ScriptManifest;
import org.dreambot.api.wrappers.widgets.WidgetChild;

@ScriptManifest(name="Snape Grass Collector", author="GenericClient", category=Category.MONEYMAKING, version=1,
    description="Mirrors grass.jar: six Waterbirth spawns, Castle Wars banking, all tablets and equipment deposits.")
@ScriptSettings(id="snape-grass-collector")
public final class SnapeGrassCollector extends AbstractScript
{
    private final SnapeRoute route = new SnapeRoute();
    private final SnapeProgress progress = new SnapeProgress();

    @Override public void onStart()
    {
        route.reset();
        progress.start();
        Automation.activity("skilling");
    }

    @Override public int onLoop()
    {
        if (!Client.isLoggedIn()) return 300;
        progress.observe();
        if (!Bank.isOpen()) SnapeBanking.wearCarriedRing();

        // NEED_BANK is captured before the independent early-close block in the source.
        boolean needBank = SnapeBanking.needsBank();
        SnapeBanking.closeWhenReady();
        if (needBank) SnapeBanking.bank();

        route.teleportWhenReady();
        route.collect();
        enableRunAtFullEnergy();
        progress.observe();
        progress.publish();
        return 30;
    }

    private static void enableRunAtFullEnergy()
    {
        if (Walking.getRunEnergy() != 100 || Walking.isRunEnabled() || Bank.isOpen() || GrandExchange.isOpen()) return;
        for (Map<?,?> row : SnapshotData.rows("widgets", Map.of("limit", Integer.MAX_VALUE)))
        {
            if (Boolean.TRUE.equals(row.get("visible")) && List.of(SnapshotData.strings(row.get("actions"))).contains("Toggle Run"))
            {
                new WidgetChild(SnapshotData.integer(row,"id"), SnapshotData.integer(row,"index")).interact("Toggle Run");
                return;
            }
        }
    }

    // Paint samples inventory during long actions, matching the original inventory-gain observer.
    @Override public void onPaint(java.awt.Graphics2D graphics) { progress.observe(); }

    @Override public void onExit() { progress.close(); }
}
