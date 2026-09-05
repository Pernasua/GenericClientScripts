package com.genericclient.scripts.quests;

import com.genericclient.script.Navigation.Journey;
import java.util.Arrays;
import org.dreambot.api.methods.map.Tile;

final class MonkeyRoutes
{
	private MonkeyRoutes() {}
	static final Journey APE_ATOLL_VALLEY = new Journey(new Tile(2721,2763,0),2).timeout(900);
	static final Journey DENTURE_SAFE_APPROACH = new Journey(new Tile(2768,2769,0),0).timeout(900)
		.avoiding(Arrays.asList(MonkeyMap.DENTURE_LIGHT_FLOOR));
	static final Journey GARKOR_TO_DENTURES = new Journey(new Tile(2764,2763,0),1).timeout(900);
	static final Journey GARKOR_TO_WEST_LADDER = new Journey(new Tile(2713,2766,0),2).timeout(900);
	static final Journey MARIM_GATE_TO_GARKOR = new Journey(new Tile(2807,2762,0),2).timeout(900);
	static final Journey PRISON_TO_DENTURES = new Journey(new Tile(2764,2763,0),1).timeout(900)
		.via(new Tile(2784,2806,0),new Tile(2784,2770,0),new Tile(2780,2763,0));
	static final Journey PRISON_TO_GARKOR = new Journey(new Tile(2807,2762,0),2).timeout(900)
		.via(new Tile(2784,2806,0),new Tile(2784,2770,0),new Tile(2807,2770,0));
	static final Journey PRISON_TO_TEMPLE_ENTRY = new Journey(new Tile(2787,2787,0),0).timeout(900);
	static final Journey TEMPLE_TO_MONKEY_CHILD = new Journey(new Tile(2746,2799,0),0).timeout(900)
		.via(new Tile(2806,2785,0),new Tile(2784,2787,0),new Tile(2784,2806,0),new Tile(2764,2806,0),new Tile(2749,2804,0),new Tile(2749,2802,0),new Tile(2746,2802,0));
	static final Journey TEMPLE_TRAPDOOR_APPROACH = new Journey(new Tile(2807,2785,0),2).timeout(70)
		.arrivingAt(new Tile(2806,2785,0),new Tile(2806,2784,0),new Tile(2805,2785,0),new Tile(2807,2784,0),new Tile(2805,2784,0));
	static final Journey ZOO_TO_GRAND_TREE = new Journey(new Tile(2466,3482,0),2).timeout(900);
	static final Journey ZOOKNOCK_DUNGEON = new Journey(new Tile(2799,9138,0),3).timeout(900);
}
