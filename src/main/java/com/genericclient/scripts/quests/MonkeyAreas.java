package com.genericclient.scripts.quests;

import org.dreambot.api.methods.map.Area;
import org.dreambot.api.methods.map.Tile;

final class MonkeyAreas
{
	private MonkeyAreas() {}
	static final Area APE_ATOLL_NORTH_EAST = new Area(2735,2730,2815,2765,0);
	static final Area TEMPLE_GUARD_BUILDING = new Area(2787,2773,2808,2793,0);
	static final Area SHIPYARD = new Area(2945,3016,3000,3060,0);
	static final Area JUNGLE_DEMON_ROOM_PLATFORM = new Area(2671,9151,2749,9214,1);
	static final Area JUNGLE_DEMON_ROOM_GROUND = new Area(2671,9151,2749,9214,0);
	static final Area CRASH_ISLAND = new Area(2883,2693,2941,2747,0);
	static final Area TEMPLE_MELEE_THRESHOLD = new Area(2787,2784,2787,2789,0);
	static final Area THRONE_ROOM = new Area(2800,2759,2805,2766,0);
	static final Area APE_ATOLL_SOUTH_CORRIDOR_NARROW = new Area(2718,2744,2726,2765,0);
	static final Area TEMPLE_DUNGEON = new Area(2777,9185,2818,9219,0);
	static final Area THRONE_ROOM_ENTRY = new Area(2798,2762,2799,2763,0);
	static final Area APE_ATOLL_OVER_BRIDGE = new Area(2726,2751,2733,2769,0);
	static final Area APE_ATOLL_NORTH_WEST = new Area(2687,2738,2716,2765,0);
	static final Area GANDIUS = new Area(2900,2940,3010,3070,0);
	static final Area APE_ATOLL_SOUTH = new Area(2687,2687,2820,2737,0);
	static final Area PRISON_NORTH_EXIT = new Area(2777,2798,2790,2810,0);
	static final Area APE_ATOLL_BRIDGE = new Area(2712,2765,2730,2767,2);
	static final Area APE_ATOLL_SOUTH_CORRIDOR_WIDE = new Area(2713,2738,2737,2743,0);
	static final Area DENTURE_BUILDING = new Area(2759,2764,2770,2772,0);
	static final java.util.List<java.util.Map<String,Integer>> PRISON_BOUNDS = java.util.List.of(
		java.util.Map.of("x1",2765,"y1",2793,"x2",2776,"y2",2802,"plane",0),
		java.util.Map.of("x1",2764,"y1",2793,"x2",2764,"y2",2796,"plane",0),
		java.util.Map.of("x1",2764,"y1",2800,"x2",2764,"y2",2802,"plane",0));
	static final Area PRISON_WEST_CLEAR = new Area(2762,2797,2764,2799,0);
	static final Area STRONGHOLD_TRANSPORT = new Area(2440,3435,2480,3460,0);
	static final Area MONKEY_PEN_EAST = new Area(2605,3277,2606,3281,0);
	static final Area MONKEY_PEN_WEST = new Area(2598,3274,2600,3278,0);
	static final Area ZOOKNOCK_DUNGEON = new Area(2690,9088,2813,9149,0);
	static final Area AMULET_MOULD_ROOM = new Area(2752,9156,2806,9183,0);
	static final Area MONKEY_PEN_MIDDLE = new Area(2600,3276,2604,3282,0);
	static final Area POST_PUZZLE_HANGAR = new Area(2620,4480,2680,4540,0);
	static final Area THRONE_ROOM_WEST = new Area(2796,2763,2798,2765,0);
	static final Area APE_ATOLL_NORTH = new Area(2682,2766,2816,2817,0);
	static final Area HANGAR = new Area(2360,9860,2420,9910,0);
	static boolean south() { return in(APE_ATOLL_SOUTH,APE_ATOLL_SOUTH_CORRIDOR_WIDE,APE_ATOLL_SOUTH_CORRIDOR_NARROW); }
	static boolean north() { return in(APE_ATOLL_NORTH,APE_ATOLL_NORTH_WEST,APE_ATOLL_NORTH_EAST); }
	static boolean prison()
	{
		Tile tile = QuestWorkflow.tile();
		return PRISON_BOUNDS.stream().anyMatch(b -> tile.getZ()==b.get("plane") && tile.getX()>=b.get("x1") &&
			tile.getX()<=b.get("x2") && tile.getY()>=b.get("y1") && tile.getY()<=b.get("y2"));
	}
	static boolean ape() { return south() || north() || prison() || TEMPLE_DUNGEON.contains(QuestWorkflow.tile()); }
	static boolean pen() { return in(MONKEY_PEN_WEST,MONKEY_PEN_EAST,MONKEY_PEN_MIDDLE); }
	static boolean throne() { return in(THRONE_ROOM_WEST,THRONE_ROOM_ENTRY,THRONE_ROOM); }
	static boolean demon() { return in(JUNGLE_DEMON_ROOM_GROUND,JUNGLE_DEMON_ROOM_PLATFORM); }
	static boolean tree() { Tile t=QuestWorkflow.tile(); return t.getX()>=2420 && t.getX()<=2505 && t.getY()>=3460 && t.getY()<=3525; }
	private static boolean in(Area... areas) { Tile tile=QuestWorkflow.tile(); for (Area area:areas) if (area.contains(tile)) return true; return false; }
}
