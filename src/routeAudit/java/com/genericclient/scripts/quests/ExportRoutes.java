package com.genericclient.scripts.quests;

import com.genericclient.script.Navigation.Journey;
import java.io.BufferedWriter;
import java.io.IOException;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.dreambot.api.methods.map.Tile;

/** Export real catalog geometry; starts describe the script's calling locations. */
public final class ExportRoutes
{
    private ExportRoutes() {}

    public static void main(String[] args) throws Exception
    {
        Path output=Path.of(args[0]);
        Files.createDirectories(output.toAbsolutePath().getParent());
        Map<String,Tile> starts=monkeyStarts();
        try (BufferedWriter writer=Files.newBufferedWriter(output))
        {
            writer.write("# name\tindex\tx\ty\tplane\twithin\tkind\taccount\n");
            Field[] routes=MonkeyRoutes.class.getDeclaredFields();
            Arrays.sort(routes,Comparator.comparing(Field::getName));
            for (Field field : routes)
            {
                if (field.getType()!=Journey.class) continue;
                Journey journey=(Journey)field.get(null);
                String name=field.getName().toLowerCase(Locale.ROOT);
                Tile start=starts.remove(name);
                if (start==null) throw new IllegalArgumentException("Missing caller start: " + name);
                route(writer,"monkey_madness_i."+name,start,journey,"ALL");
                if (name.startsWith("prison_to_") || name.equals("temple_to_monkey_child"))
                    rows(writer,"monkey_madness_i."+name,prisonTiles(),0,"forbidden","ALL");
            }
            if (!starts.isEmpty()) throw new IllegalArgumentException("Unused caller starts: " + starts.keySet());
            route(writer,"tree_gnome_village.maze_inside",new Tile(2505,3190),new Journey(new Tile(2515,3159),0),"ALL");
            route(writer,"tree_gnome_village.maze_exit",new Tile(2515,3159),new Journey(new Tile(2505,3190),0),"ALL");
            route(writer,"waterfall.gnome_dungeon",new Tile(2440,3089),new Journey(WaterfallNavigation.GNOME_BASEMENT,1),"QUEST_ROUTES");
            route(writer,"grand_tree.stronghold",new Tile(2440,3089),new Journey(GnomeTravel.KING_TILE,2),"ALL");
            route(writer,"grand_tree.hazelmere",new Tile(2440,3089),new Journey(GnomeTravel.HAZELMERE,1),"ALL");
            transports(writer);
        }
        System.out.println("Exported Java catalog journeys to " + output);
    }

    private static void transports(BufferedWriter writer) throws IOException
    {
        route(writer,"witchs_house.basement",new Tile(2902,3473),new Journey(WitchsHouse.BASEMENT_ENTRY,0),"ALL");
        route(writer,"witchs_house.surface",new Tile(2901,9874),new Journey(WitchsHouse.SURFACE_ENTRY,0),"ALL");
        route(writer,"waterfall.raft",new Tile(2510,3493),new Journey(WaterfallNavigation.HUDON_LANDING,1),"QUEST_ROUTES");
        route(writer,"waterfall.tourist_upstairs",new Tile(2519,3430),new Journey(WaterfallNavigation.TOURIST_UPSTAIRS,0),"ALL");
        route(writer,"waterfall.tourist_ground",new Tile(2518,3431,1),new Journey(WaterfallNavigation.TOURIST_GROUND,0),"ALL");
        route(writer,"waterfall.gnome_basement",new Tile(2448,3090),new Journey(WaterfallNavigation.GNOME_BASEMENT,1),"QUEST_ROUTES");
        route(writer,"waterfall.gnome_surface",new Tile(2548,9566),new Journey(WaterfallNavigation.GNOME_SURFACE,1),"QUEST_ROUTES");
        route(writer,"waterfall.tomb_exit",new Tile(2542,9813),new Journey(WaterfallNavigation.TOMB_SURFACE,1),"ALL");
        route(writer,"the_grand_tree.hazelmere",new Tile(2677,3088),new Journey(GnomeTravel.HAZELMERE,1),"ALL");
        route(writer,"the_grand_tree.glough",new Tile(2466,3494),new Journey(GnomeTravel.GLOUGH_ROOM,2),"ALL");
        route(writer,"the_grand_tree.return_from_glough",new Tile(2477,3463,1),new Journey(GnomeTravel.KING_TILE,2),"ALL");
        route(writer,"the_grand_tree.charlie",new Tile(2466,3494),new Journey(GnomeTravel.TOP,1),"ALL");
        route(writer,"the_grand_tree.anita",new Tile(2466,3494,3),new Journey(GnomeTravel.ANITA,1),"ALL");
        route(writer,"the_grand_tree.invasion_plans",new Tile(2388,3513,1),new Journey(GnomeTravel.GLOUGH_ROOM,2),"ALL");
        route(writer,"monkey_madness_i.spirit_tree",new Tile(3184,3508),new Journey(MonkeyMap.STRONGHOLD_ARRIVAL,1),"QUEST_ROUTES");
        route(writer,"monkey_madness_i.shipyard",new Tile(2466,3494),new Journey(MonkeyMap.SHIPYARD_GATE,3),"QUEST_ROUTES");
        route(writer,"monkey_madness_i.return_from_gandius",new Tile(2970,2972),new Journey(MonkeyMap.KING_NARNODE,3),"QUEST_ROUTES");
        route(writer,"monkey_madness_i.daero",new Tile(2466,3494,3),new Journey(MonkeyMap.DAERO,5),"ALL");
        route(writer,"monkey_madness_i.repeat_hangar",new Tile(2461,3444),new Journey(MonkeyMap.POST_PUZZLE_LANDING,1),"QUEST_ROUTES");
        route(writer,"monkey_madness_i.waydar",new Tile(2649,4516),new Journey(MonkeyMap.CRASH_ISLAND_LANDING,1),"QUEST_ROUTES");
        route(writer,"monkey_madness_i.lumdo",new Tile(2894,2726),new Journey(MonkeyMap.APE_ATOLL_LANDING,1),"QUEST_ROUTES");
    }

    private static Map<String,Tile> monkeyStarts()
    {
        Map<String,Tile> starts=new LinkedHashMap<>();
        starts.put("ape_atoll_valley",new Tile(2770,2707));
        starts.put("denture_safe_approach",new Tile(2764,2764));
        starts.put("garkor_to_dentures",new Tile(2807,2762));
        starts.put("garkor_to_west_ladder",new Tile(2775,2767));
        starts.put("marim_gate_to_garkor",new Tile(2738,2767));
        starts.put("prison_to_dentures",new Tile(2762,2804));
        starts.put("prison_to_garkor",new Tile(2762,2804));
        starts.put("prison_to_temple_entry",new Tile(2762,2804));
        starts.put("temple_to_monkey_child",new Tile(2806,2785));
        starts.put("temple_trapdoor_approach",new Tile(2787,2787));
        starts.put("zoo_to_grand_tree",new Tile(2608,3278));
        starts.put("zooknock_dungeon",new Tile(2768,9101));
        return starts;
    }

    private static List<Tile> prisonTiles()
    {
        List<Tile> tiles=new ArrayList<>();
        for (Map<String,Integer> bounds : MonkeyAreas.PRISON_BOUNDS)
            for (int x=bounds.get("x1");x<=bounds.get("x2");x++)
                for (int y=bounds.get("y1");y<=bounds.get("y2");y++)
                    tiles.add(new Tile(x,y,bounds.get("plane")));
        return tiles;
    }

    private static void route(BufferedWriter writer, String name, Tile start, Journey journey, String account) throws IOException
    {
        List<Tile> route=new ArrayList<>();
        route.add(start); route.addAll(journey.via); route.add(journey.destination);
        rows(writer,name,route,journey.within,"route",account);
        rows(writer,name,journey.arrival,journey.within,"arrival",account);
        rows(writer,name,journey.avoid,journey.within,"avoid",account);
    }

    private static void rows(BufferedWriter writer, String name, List<Tile> tiles, int within, String kind, String account) throws IOException
    {
        for (int index=0; index<tiles.size(); index++)
        {
            Tile tile=tiles.get(index);
            writer.write(String.format(Locale.ROOT,"%s\t%d\t%d\t%d\t%d\t%d\t%s\t%s%n",name,index+1,tile.getX(),tile.getY(),tile.getZ(),within,kind,account));
        }
    }
}
