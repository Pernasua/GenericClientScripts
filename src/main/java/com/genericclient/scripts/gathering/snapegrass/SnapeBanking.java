package com.genericclient.scripts.gathering.snapegrass;

import java.awt.Polygon;
import java.util.LinkedHashSet;
import java.util.Set;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.bank.Bank;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.interactive.Players;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.Player;
import org.dreambot.api.wrappers.items.Item;

/** The source's sequential bank blocks, including its intentionally retained quirks. */
final class SnapeBanking
{
    static final String TABLET = "Waterbirth teleport";
    static final String GRASS = "Snape grass";
    static final int RING_SLOT = 12;
    static final Tile CASTLE_WARS = new Tile(2444,3083,0);
    private static final Polygon CHEST_AREA = new Polygon(
        new int[]{2448,2448,2441,2441}, new int[]{3086,3080,3080,3087}, 4);

    private SnapeBanking() {}

    static boolean isRing(Item item) { return item.getName().contains("Ring of dueling"); }
    static boolean ringEquipped() { return Equipment.get(SnapeBanking::isRing) != null; }
    static boolean ringCarried() { return Inventory.get(SnapeBanking::isRing) != null; }
    static int tablets() { return Inventory.count(TABLET); }
    static boolean stationary()
    {
        Player player = Players.getLocal();
        return player != null && player.exists() && !player.isMoving();
    }

    static boolean needsBank()
    {
        return Inventory.isFull() || tablets() < 2 || (!ringEquipped() && !ringCarried());
    }

    static void wearCarriedRing()
    {
        if (ringEquipped()) return;
        Item ring = Inventory.get(SnapeBanking::isRing);
        if (ring != null && ring.interact("Wear")) Sleep.sleepTicks(1);
    }

    static void closeWhenReady()
    {
        if (Bank.isOpen() && tablets() >= 2 && ringEquipped() && !Inventory.isFull()) Bank.close();
    }

    static void bank()
    {
        if (!Bank.isOpen()) approachBank();
        if (!Bank.isOpen()) return;
        depositEquipment();
        if (Inventory.isFull())
        {
            depositExceptTablets();
            Sleep.sleepTicks(1);
        }
        if (Inventory.count(GRASS) > 0)
        {
            depositExceptTablets();
            Sleep.sleepTicks(1);
        }
        if (tablets() < 2)
        {
            Item tablets = Bank.get(TABLET);
            if (tablets != null && Bank.withdrawAll(tablets.getId())) Sleep.sleepTicks(1);
        }
        if (!ringEquipped())
        {
            if (!ringCarried())
            {
                Item ring = Bank.get(SnapeBanking::isRing);
                if (ring != null) Bank.withdraw(ring.getId(),1);
            }
            wearCarriedRing();
        }
        closeWhenReady();
    }

    private static void approachBank()
    {
        wearCarriedRing();
        if (CASTLE_WARS.distance() < 21 && GameObjects.closest(4483) != null && stationary())
        {
            GameObject chest = GameObjects.closest(object -> object.getName().equals("Bank chest") &&
                object.getTile().getZ() == 0 && CHEST_AREA.contains(object.getTile().getX(),object.getTile().getY()));
            if (chest != null && chest.interact("Use")) Sleep.sleepTicks(1);
        }
        // These strict inequalities and separate post-teleport ring checks are deliberate.
        if (CASTLE_WARS.distance() > 21)
        {
            if (ringEquipped())
            {
                Item ring = Equipment.getItemInSlot(RING_SLOT);
                if (ring != null && ring.interact("Castle Wars")) Sleep.sleepTicks(6);
            }
            if (!ringEquipped() && !ringCarried()) NearestBank.open();
        }
    }

    private static void depositEquipment()
    {
        // Any occupied non-ring slot causes Deposit worn items, including the ring.
        for (int slot = 0; slot < 14; slot++)
            if (slot != RING_SLOT && Equipment.getItemInSlot(slot) != null) Bank.depositAllEquipment();
    }

    private static void depositExceptTablets()
    {
        Set<Integer> ids = new LinkedHashSet<>();
        for (Item item : Inventory.all()) if (!TABLET.equals(item.getName())) ids.add(item.getId());
        for (int id : ids) Bank.depositAll(id);
    }
}
