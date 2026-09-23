package com.genericclient.scripts.quests;

import com.genericclient.scripts.shared.Jewellery;
import com.genericclient.scripts.shared.Supply;
import java.util.List;

final class MonkeyLoadouts
{
	private static final Supply ANTIPOISON = new Supply(2448,"Superantipoison(4)",1,10000,181,183,185);
	private static final Supply STAMINA = new Supply(12625,"Stamina potion(4)",1,20000,12627,12629,12631);
	private static final Supply LOCKPICK = new Supply(1523,"Lockpick",1,5000);
	private static final Supply PRAYER_RESERVE = new Supply(2434,"Prayer potion(4)",3,20000,139,141);
	private static final Supply MSPEAK_AMULET = new Supply(4021,"M'speak amulet",1,0);

	private MonkeyLoadouts() {}
	static final List<Supply> APE_ATOLL_LOADOUT = List.of(
		new Supply(379,"Lobster",18,1000),
		ANTIPOISON,
		STAMINA,
		Jewellery.DUELING_RING,
		LOCKPICK,
		new Supply(2434,"Prayer potion(4)",3,20000));
	static final List<Supply> ZOO_LOADOUT = List.of(
		new Supply(379,"Lobster",10,1000),
		ANTIPOISON,
		STAMINA,
		Jewellery.DUELING_RING,
		new Supply(11980,"Ring of wealth (5)",2,20000,11982,11984,11986,11988),
		new Supply(2434,"Prayer potion(4)",2,20000,139,141,143),
		MSPEAK_AMULET,
		new Supply(4031,"Karamjan monkey greegree",1,0));
	static final List<Supply> AMULET_CRAFTING_LOADOUT = List.of(
		new Supply(379,"Lobster",14,1000),
		ANTIPOISON,
		STAMINA,
		Jewellery.DUELING_RING,
		LOCKPICK,
		PRAYER_RESERVE,
		new Supply(4007,"Enchanted bar",1,0),
		new Supply(4020,"M'amulet mould",1,0),
		new Supply(1759,"Ball of wool",1,5000));
	static final List<Supply> DEMON_LOADOUT = List.of(
		new Supply(379,"Lobster",16,1000),
		new Supply(2434,"Prayer potion(4)",4,20000),
		Jewellery.DUELING_RING,
		new Supply(11980,"Ring of wealth (5)",1,20000,11982,11984,11986,11988),
		new Supply(1387,"Staff of fire",1,5000),
		new Supply(556,"Air rune",900,100),
		new Supply(562,"Chaos rune",300,250),
		new Supply(4035,"10th squad sigil",1,0));
	static final List<Supply> GREEGREE_LOADOUT = List.of(
		new Supply(379,"Lobster",12,1000),
		ANTIPOISON,
		STAMINA,
		Jewellery.DUELING_RING,
		PRAYER_RESERVE,
		MSPEAK_AMULET,
		new Supply(4023,"Monkey talisman",1,0),
		new Supply(3183,"Monkey bones",1,5000,3166));
	static final List<Supply> AMULET_BAR_LOADOUT = List.of(
		new Supply(379,"Lobster",14,1000),
		ANTIPOISON,
		STAMINA,
		Jewellery.DUELING_RING,
		LOCKPICK,
		PRAYER_RESERVE,
		new Supply(2357,"Gold bar",1,5000),
		new Supply(4006,"Monkey dentures",1,0),
		new Supply(4020,"M'amulet mould",1,0));
}
