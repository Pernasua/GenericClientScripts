package com.genericclient.scripts.gathering.snapegrass;

import com.genericclient.script.ScriptScope;
import com.genericclient.script.SnapshotData;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.bank.Bank;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.methods.walking.impl.Walking;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.items.Item;

/** Ordered spawn selection from the recovered workflow; not nearest-item looting. */
final class SnapeRoute
{
    static final List<Tile> SPAWNS = List.of(new Tile(2540,3765,0),new Tile(2542,3765,0),
        new Tile(2546,3763,0),new Tile(2552,3757,0),new Tile(2553,3754,0),new Tile(2553,3751,0));
    static final Tile ANCHOR = new Tile(2546,3763,0);
    private int passIndex;

    void reset() { passIndex = 0; }

    void teleportWhenReady()
    {
        if (Bank.isOpen() || Inventory.isFull() || SnapeBanking.tablets() <= 1 ||
            !SnapeBanking.ringEquipped() || ANCHOR.distance() <= 30) return;
        passIndex = 0;
        Item tablet = Inventory.get(SnapeBanking.TABLET);
        if (tablet != null && tablet.interact("Break")) Sleep.sleepTicks(7);
    }

    void collect()
    {
        if (Bank.isOpen() || Inventory.isFull() || ANCHOR.distance() >= 30) return;
        if (passIndex >= SPAWNS.size()) passIndex = 0;
        Tile target = SPAWNS.get(passIndex);
        List<Map<?,?>> items = SnapshotData.rows("ground_items", Map.of("limit",Integer.MAX_VALUE));
        Map<?,?> grass = items.stream().filter(row -> grassAt(row,target)).findFirst().orElse(null);
        if (grass != null)
        {
            if (SnapeBanking.stationary()) take(grass,target);
        }
        else if (items.stream().anyMatch(SnapeRoute::listedGrass)) passIndex++;
        else if (SnapeBanking.stationary() && Walking.walk(SPAWNS.get(0))) Sleep.sleepTicks(1);
    }

    private static boolean grassAt(Map<?,?> row, Tile tile)
    {
        if (!SnapeBanking.GRASS.equals(row.get("name"))) return false;
        Map<?,?> world = SnapshotData.map(row.get("world"));
        return SnapshotData.integer(world,"x") == tile.getX() && SnapshotData.integer(world,"y") == tile.getY() &&
            SnapshotData.integer(world,"plane") == tile.getZ();
    }

    private static boolean listedGrass(Map<?,?> row) { return SPAWNS.stream().anyMatch(tile -> grassAt(row,tile)); }

    private static void take(Map<?,?> grass, Tile tile)
    {
        Map<String,Object> receipt = ScriptScope.current().execute("ground_item.take", Map.of(
            "id",SnapshotData.integer(grass,"id"),"world",Map.of("x",tile.getX(),"y",tile.getY(),"plane",tile.getZ()),
            "within",32),120_000);
        if (SnapshotData.succeeded(receipt)) Sleep.sleepTicks(1);
    }
}
