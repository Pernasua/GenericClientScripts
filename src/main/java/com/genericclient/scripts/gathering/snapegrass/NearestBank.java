package com.genericclient.scripts.gathering.snapegrass;

import com.genericclient.script.Navigation;
import com.genericclient.script.ScriptScope;
import com.genericclient.script.SnapshotData;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;
import org.dreambot.api.methods.container.impl.bank.Bank;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.utilities.Sleep;

/** Approaches a reachable bank, then makes up to ten observed open attempts. */
final class NearestBank
{
    private NearestBank() {}

    static boolean open()
    {
        if (Bank.open()) return true;
        List<Map<String,Integer>> candidates = BankLocations.available();
        if (candidates.isEmpty()) return false;
        Map<String,Object> choice = ScriptScope.current().execute("walk.nearest",
            Map.of("destinations",candidates,"within",3),120_000);
        if (!SnapshotData.succeeded(choice)) return false;
        Map<?,?> point = SnapshotData.map(choice.get("destination"));
        Tile destination = new Tile(SnapshotData.integer(point,"x"),SnapshotData.integer(point,"y"),
            SnapshotData.integer(point,"plane"));
        if (destination.distance() > 10 && !Navigation.walkTo(destination,3,600,List.of())) return false;
        for (int attempt=0; attempt<10; attempt++)
        {
            if (Bank.open()) return true;
            Sleep.sleepUntil(Bank::isOpen,ThreadLocalRandom.current().nextInt(2500,4501));
        }
        return Bank.isOpen();
    }
}
