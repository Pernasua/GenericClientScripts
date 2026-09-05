package com.genericclient.scripts.quests;

import com.genericclient.script.Automation;
import com.genericclient.script.SnapshotData;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.dialogues.Dialogues;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.widget.Widgets;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

final class MonkeyPrelude
{
	private final QuestWorkflow quest;
	private final MonkeyTravel travel;
	MonkeyPrelude(QuestWorkflow quest, MonkeyTravel travel) { this.quest = quest; this.travel = travel; }
	void execute(String phase)
	{
		switch (phase)
		{
			case "start":
				travel.king();
				Automation.intent("monkey_madness.start_quest", () ->
				{
					quest.talk(GnomeTravel.KING,null,() -> quest.varp() >= 1 && Inventory.contains(4004),false,"Yes.","Yes");
					closeChapter();
					return null;
				}); break;
			case "shipyard": shipyard(); break;
			case "report": travel.king(); quest.talk(GnomeTravel.KING,null,() -> quest.bit(121) >= 7 && Inventory.contains(4005),false); break;
			case "daero": travel.daero(); quest.talk(MonkeyTravel.DAERO,null,() -> quest.bit(123) >= 1,false,"Talk about the 10th squad...","Who is it?","Yes","Leave..."); break;
			case "hangar": hangar(); break;
			case "puzzle": puzzle(); break;
			case "confirm":
				Automation.intent("monkey_madness.confirm_reinitialization", () ->
				{
					quest.talk(MonkeyTravel.DAERO,null,() -> quest.bit(123) >= 7,false);
					closeChapter();
					return null;
				}); break;
			default: throw new IllegalArgumentException("Unknown Monkey Madness introduction phase: " + phase);
		}
	}
	private void shipyard()
	{
		travel.shipyardGate();
		Automation.intent("monkey_madness.enter_shipyard", () ->
		{
			GameObject gate = GameObjects.closest(2438);
			QuestWorkflow.require(gate != null && gate.interact("Open"),"Shipyard gate did not open");
			Sleep.sleepTicks(2);
			com.genericclient.scripts.shared.Conversations.finish();
			quest.walk(MonkeyMap.SHIPYARD_GATE_INSIDE,0,false);
			return null;
		});
		quest.talk(new int[]{1460},MonkeyMap.CARANOCK,() -> quest.bit(122) >= 3,false);
	}
	private void hangar()
	{
		travel.daero();
		Automation.intent("monkey_madness.enter_hangar", () ->
		{
			Set<String> chosen = new HashSet<>();
			int conversations = 0;
			int closed = 0;
			for (int tick = 0; tick < 240; tick++)
			{
				if (quest.bit(123) >= 5 && !Dialogues.inDialogue()) return null;
				if (Dialogues.canContinue()) { QuestWorkflow.require(Dialogues.continueDialogue(),"Daero dialogue failed"); closed = 0; }
				else if (Dialogues.inDialogue())
				{
					String selection = hangarChoice(chosen);
					QuestWorkflow.require(selection != null && Dialogues.chooseOption(selection),"Unexpected Daero travel choices");
					chosen.add(selection); closed = 0;
				}
				else if (++closed >= 3)
				{
					QuestWorkflow.require(++conversations <= 4,"Daero conversation limit reached");
					NPC daero = QuestWorkflow.npc(MonkeyTravel.DAERO);
					QuestWorkflow.require(daero != null && daero.interact("Talk-to"),"Daero could not resume travel dialogue");
					closed = 0;
				}
				Sleep.sleepTicks(1);
			}
			throw new IllegalStateException("Daero did not start reinitialization");		});

	}
	private String hangarChoice(Set<String> chosen)
	{
		List<String> priority = quest.bit(123) <= 2 ? List.of("Talk about the 10th squad...","Who is it?","Yes","Leave...") :
			quest.bit(123) == 3 ? List.of("How will I travel?","Are you coming with me?","Who is Garkor?","Who is it?",
				"Talk about the 10th squad...","Talk about Caranock...","Talk about the journey...","Yes","Leave...") :
			List.of("Yes","Who is it?","Leave...");
		List<String> options = Arrays.asList(Dialogues.getOptions());
		return priority.stream().filter(value -> !chosen.contains(value) && options.contains(value)).findFirst()
			.orElse(options.contains("Return to previous menu") ? "Return to previous menu" : options.contains("Leave...") ? "Leave..." : null);
	}

	private void puzzle()
	{
		Map<?,?> puzzle = SnapshotData.read("sliding_puzzle");
		if (!Boolean.TRUE.equals(puzzle.get("available")))
		{
			quest.walk(MonkeyMap.REINITIALIZATION_PANEL,3,false);
			GameObject panel = GameObjects.closest(4871);
			QuestWorkflow.require(panel != null && panel.interact("Operate"),"Reinitialization panel did not open");
			QuestWorkflow.await(() -> Boolean.TRUE.equals(SnapshotData.read("sliding_puzzle").get("available")),20,"Sliding puzzle was not observed");
			puzzle = SnapshotData.read("sliding_puzzle");
		}
		List<?> moves = (List<?>)puzzle.get("moves");
		QuestWorkflow.require(((List<?>)puzzle.get("board")).size() == 25 && moves.size() <= 400,"Sliding puzzle state is invalid");
		int widget = SnapshotData.integer(puzzle,"widget_id");
		for (Object move : moves)
		{
			int position = ((Number)move).intValue();
			QuestWorkflow.require(SnapshotData.action("ui.click",Map.of("widget_id",widget,"widget_index",position)),"Sliding puzzle click failed");
			QuestWorkflow.await(() -> quest.bit(123) >= 6 || blank() == position,10,"Sliding puzzle move was not observed");
			if (quest.bit(123) >= 6) return;
		}
		QuestWorkflow.await(() -> quest.bit(123) >= 6,40,"Reinitialization completion was not observed");
	}
	private int blank()
	{
		Set<Integer> positions = new HashSet<>();
		for (Map<?,?> widget : SnapshotData.rows("widgets",Map.of("group",306,"limit",100)))
			if ("Sliding piece".equals(widget.get("name"))) positions.add(SnapshotData.integer(widget,"index"));
		if (positions.size() != 24) return -1;
		for (int i = 0; i < 25; i++) if (!positions.contains(i)) return i;
		throw new IllegalStateException("Sliding puzzle has no blank");
	}
	private void closeChapter()
	{
		var chapter = Widgets.getWidget(225);
		if (chapter != null && chapter.isVisible()) Widgets.closeAll();
	}
}
