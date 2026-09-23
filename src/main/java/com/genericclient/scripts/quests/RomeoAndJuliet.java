package com.genericclient.scripts.quests;

import org.dreambot.api.methods.settings.PlayerSettings;
import com.genericclient.scripts.shared.Supply;
import com.genericclient.script.SnapshotData;
import java.util.List;
import java.util.Map;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.map.Tile;

final class RomeoAndJuliet extends QuestWorkflow
{
	// Talk-to cannot reach Juliet through her closed door, and an adjacent tile outside it already counts as near her.
	private static final Tile JULIET_ROOM = new Tile(3158,3426,1);
	RomeoAndJuliet() { super("romeo__juliet"); }
	@Override int stage() { return PlayerSettings.getConfig(144); }

	@Override void validate() { /* This quest has no skill or combat requirements. */ }
	@Override void escape() { /* Surface conversations can stop in place. */ }
	@Override boolean finished() { return super.finished() && inMainWorld(); }
	private static boolean inMainWorld()
	{
		Map<?,?> scene = SnapshotData.read("scene");
		return Boolean.TRUE.equals(scene.get("available")) && !Boolean.TRUE.equals(scene.get("instance"));
	}
	@Override String phase()
	{
		if (stage() >= 50 && !inMainWorld()) return "cutscene";
		switch (stage())
		{
			case 0: return "meet_romeo";
			case 10: return "letter";
			case 20: return Inventory.contains(755) ? "deliver_letter" : "letter";
			case 30: return "father_lawrence";
			case 40: return "apothecary";
			case 50: return Inventory.contains(756) ? "deliver_potion" : "apothecary";
			case 60: return "finish";
			default: throw new IllegalStateException("Unsupported Romeo & Juliet stage: " + stage());
		}
	}
	@Override void execute(String phase)
	{
		if (phase.equals("cutscene"))
		{
			dialogue(RomeoAndJuliet::inMainWorld,160);
			return;
		}
		boolean juliet = phase.equals("letter") || phase.equals("deliver_potion");
		if (juliet && tile().getZ() == 0)
			interact(11797,"Climb-up",new Tile(3157,3435),() -> tile().getZ() == 1,false);
		else if (!juliet && tile().getZ() == 1)
			interact(11799,"Climb-down",new Tile(3156,3435,1),() -> tile().getZ() == 0,false);
		switch (phase)
		{
			case "meet_romeo":
				talk(new int[]{5037},new Tile(3211,3422),() -> stage() >= 10,false,
					"Yes, I have seen her actually!","Yes, ok, I'll let her know.","Yes.");
				break;
			case "letter":
				walk(JULIET_ROOM,0,false);
				talk(new int[]{5035},null,() -> Inventory.contains(755),false);
				break;
			case "deliver_letter":
				talk(new int[]{5037},new Tile(3211,3422),() -> stage() >= 30,false);
				break;
			case "father_lawrence":
				talk(new int[]{5038},new Tile(3254,3483),() -> stage() >= 40,false,"Ok, thanks.");
				break;
			case "apothecary":
				if (!Inventory.contains(753)) prepare(List.of(new Supply(753,"Cadava berries",1,1000)));
				int before = stage();
				talk(new int[]{5036},new Tile(3195,3405),() -> stage() > before || Inventory.contains(756),false,
					"Talk about something else.","Talk about Romeo & Juliet.");
				break;
			case "deliver_potion":
				walk(JULIET_ROOM,0,false);
				talk(new int[]{5035},null,() -> stage() >= 60,false);
				break;
			default:
				talk(new int[]{5037},new Tile(3211,3422),this::finished,false);
		}
	}
}
