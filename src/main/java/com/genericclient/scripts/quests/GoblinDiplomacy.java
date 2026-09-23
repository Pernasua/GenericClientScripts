package com.genericclient.scripts.quests;

import static com.genericclient.scripts.shared.WorkflowScript.awaitTicks;
import static com.genericclient.scripts.shared.WorkflowScript.require;

import com.genericclient.script.Automation;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Supplies;
import com.genericclient.scripts.shared.Supply;
import java.util.ArrayList;
import java.util.List;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.wrappers.items.Item;

final class GoblinDiplomacy extends QuestWorkflow
{
	GoblinDiplomacy() { super("goblin_diplomacy"); }
	@Override int stage()
	{
		return ((Number)SnapshotData.map(SnapshotData.read("quests").get(key)).get("progress")).intValue();
	}
	@Override void validate() { /* This quest has no skill or combat requirements. */ }
	@Override void escape() { /* The generals' hut is safe to stop in. */ }
	@Override String phase()
	{
		if (stage() <= 3 && !Inventory.contains(286))
			return Inventory.contains(288) && Inventory.contains(1769) ? "dye_orange" : "prepare";
		if (stage() <= 4 && !Inventory.contains(287))
			return Inventory.contains(288) && Inventory.contains(1767) ? "dye_blue" : "prepare";
		if (!Inventory.contains(288)) return "prepare";
		switch (stage())
		{
			case 0: return "begin";
			case 3: return "orange_mail";
			case 4: return "blue_mail";
			case 5: return "brown_mail";
			default: throw new IllegalStateException("Unsupported Goblin Diplomacy stage: " + stage());
		}
	}
	@Override void execute(String phase)
	{
		if (phase.equals("prepare")) { prepareMail(); return; }
		if (phase.equals("dye_orange")) { dye(1769,286); return; }
		if (phase.equals("dye_blue")) { dye(1767,287); return; }
		int before = stage();
		talk(new int[]{669,670},new Tile(2958,3512),() -> before == 5 ? finished() : stage() > before,false,
			"Do you want me to pick an armour colour for you?","What about a different colour?","Yes.",
			"So how is life for the goblins?","Yes, he looks fat.",
			"I have some orange armour here.","I have some blue armour here.","I have some brown armour here.");
	}
	private void prepareMail()
	{
		toExchange();
		Supplies.openBank();
		List<Supply> supplies = new ArrayList<>();
		int plain = 1;
		if (stage() <= 3) plain += colourSupplies(supplies,286,"Orange",1769);
		if (stage() <= 4) plain += colourSupplies(supplies,287,"Blue",1767);
		supplies.add(new Supply(288,"Goblin mail",plain,2000));
		Supplies.prepare(supplies,purchase);
	}
	private int colourSupplies(List<Supply> supplies, int mail, String colour, int dye)
	{
		if (Supplies.owned(mail) > 0)
		{
			supplies.add(questItem(mail,colour + " goblin mail"));
			return 0;
		}
		supplies.add(new Supply(dye,colour + " dye",1,2000));
		return 1;
	}
	private void dye(int dye, int colouredMail)
	{
		Automation.intent("goblin_diplomacy.dye",() ->
		{
			Item heldDye = Inventory.get(dye);
			Item mail = Inventory.get(288);
			require(heldDye != null && mail != null && heldDye.useOn(mail),"Goblin mail dyeing failed");
			awaitTicks(() -> Inventory.contains(colouredMail),20,"Dyed goblin mail was not observed");
			return null;
		});
	}
}
