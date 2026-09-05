package com.genericclient.scripts.quests;

import com.genericclient.script.ScriptScope;
import com.genericclient.scripts.shared.Conversations;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.container.impl.equipment.Equipment;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.wrappers.interactive.GameObject;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

final class WaterfallRitual
{
	private final Waterfall quest;
	WaterfallRitual(Waterfall quest) { this.quest = quest; }
	void execute(String phase)
	{
		switch (phase)
		{
			case "falls_key": quest.interact(1999,"Search",new Tile(2589,9888),() -> Inventory.contains(298),true); break;
			case "inner_door":
				quest.walk(new Tile(2568,9898),0,true);
				GameObject door = GameObjects.closest(2002);
				if (door != null) QuestWorkflow.require(door.interact("Open"),"Inner waterfall door did not open");
				quest.walk(new Tile(2566,9903),0,true); break;
			case "remove_amulet":
				QuestWorkflow.require(Equipment.get(item -> item.getId() == 295).interact("Remove"),"Glarial's amulet was not removed");
				QuestWorkflow.await(() -> Inventory.contains(295),12,"Glarial's amulet was not returned to inventory"); break;
			case "pillars": chargePillars(); break;
			case "finish": finish(); break;
			default: throw new IllegalArgumentException("Unknown Waterfall ritual phase: " + phase);
		}
	}
	private void chargePillars()
	{
		List<Tile> pillars = GameObjects.all(object -> object.getId() == 2005).stream().map(GameObject::getTile).distinct()
			.sorted(Comparator.comparingInt(Tile::getX).thenComparingInt(Tile::getY)).collect(Collectors.toList());
		QuestWorkflow.require(pillars.size() == 6,"Waterfall requires six observed pillars");
		for (Tile point : pillars)
		{
			quest.walk(point,3,true);
			for (int rune : new int[]{556,555,557})
			{
				int before = Inventory.count(rune);
				QuestWorkflow.require(before > 0,"Ritual runes are missing");
				long tick = ScriptScope.current().tick();
				GameObject pillar = QuestWorkflow.object(2005,point);
				QuestWorkflow.require(pillar != null && Inventory.get(rune).useOn(pillar),"Ritual rune placement failed");
				QuestWorkflow.await(() -> Inventory.count(rune) < before || QuestWorkflow.message(tick,"already"),8,"Ritual rune placement was not verified");
			}
		}
		quest.use(295,2006,new Tile(2565,9916),() -> Waterfall.CHALICE.contains(QuestWorkflow.tile()),true);
	}
	private void finish()
	{
		QuestWorkflow.require(!Inventory.contains(297),"The urn is empty");
		Conversations.finish();
		GameObject chalice = GameObjects.closest(2014);
		QuestWorkflow.require(chalice != null,"Chalice was not observed");
		quest.walk(chalice.getTile(),3,true);
		QuestWorkflow.require(Inventory.get(296).useOn(chalice),"Urn could not be placed in the chalice");
		quest.dialogue(quest::finished,50);
	}
}
