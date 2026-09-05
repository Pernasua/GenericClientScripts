package com.genericclient.scripts.quests;

import com.genericclient.script.Automation;
import com.genericclient.script.ScriptScope;
import com.genericclient.script.SnapshotData;
import com.genericclient.scripts.shared.Conversations;
import com.genericclient.scripts.shared.Travel;
import com.genericclient.scripts.shared.WorkflowScript;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.dreambot.api.methods.container.impl.Inventory;
import org.dreambot.api.methods.interactive.GameObjects;
import org.dreambot.api.methods.map.Tile;
import org.dreambot.api.utilities.Sleep;
import org.dreambot.api.wrappers.interactive.GameObject;
import org.dreambot.api.wrappers.interactive.NPC;

final class MonkeyPrison
{
	void enter()
	{
		if (MonkeyAreas.prison()) return;
		QuestWorkflow.require(MonkeyAreas.south(),"Prison capture route must start on southern Ape Atoll");
		Automation.activity("hazardous_travel",WorkflowScript.NO_DISCRETIONARY);
		MonkeySurvival.behavior(false); MonkeySurvival.protection("missiles",true,12);
		Map<String,Object> moved = MonkeySurvival.traverse(() -> MonkeyRoutes.APE_ATOLL_VALLEY,"missiles",false);
		QuestWorkflow.require("arrived".equals(moved.get("status")) || MonkeyAreas.prison(),"Ape Atoll capture route failed: " + moved);
		QuestWorkflow.await(MonkeyAreas::prison,50,"Ape Atoll capture was not observed");
		Conversations.finish(); MonkeySurvival.protection("missiles",false,0); MonkeySurvival.maintain();
	}
	void escape(boolean stopAtSafeSpot)
	{
		if (!MonkeyAreas.prison()) return;
		Automation.activity("questing",WorkflowScript.NO_DISCRETIONARY);
		MonkeySurvival.behavior(true);
		Conversations.finish();
		settle(QuestWorkflow.tile());
		if (QuestWorkflow.tile().getX() >= 2770 && QuestWorkflow.tile().getY() <= 2795 && door() != null)
		{
			QuestWorkflow.require(Inventory.contains(1523),"Prison lockpick is missing");
			Travel.to(MonkeyMap.PRISON_START,0,"questing",WorkflowScript.NO_DISCRETIONARY);
			boolean unlocked = false;
			for (int cycle = 0; cycle < 10 && !unlocked; cycle++)
			{
				settle(MonkeyMap.PRISON_START); MonkeySurvival.maintain();
				int guard = lockWindow();
				unlocked = pick(guard);
			}
			QuestWorkflow.require(unlocked,"Prison lock window was exhausted");
			QuestWorkflow.await(() -> crossedDoor() || QuestWorkflow.tile().equals(MonkeyMap.PRISON_SAFE_SPOT),12,"Prison threshold crossing was not observed");
		}
		Travel.to(MonkeyMap.PRISON_SAFE_SPOT,0,"questing",WorkflowScript.NO_DISCRETIONARY);
		settle(MonkeyMap.PRISON_SAFE_SPOT);
		if (stopAtSafeSpot) return;
		for (int cycle = 0; cycle < 6; cycle++)
		{
			settle(MonkeyMap.PRISON_SAFE_SPOT); MonkeySurvival.maintain();
			int guard = guardAt(MonkeyMap.PRISON_GUARD_STAGE,320);
			MonkeySurvival.behavior(false);
			boolean retreat = false;
			for (int tick = 0; tick < 20; tick++)
			{
				NPC actor = QuestWorkflow.npc(guard);
				QuestWorkflow.require(actor != null,"Prison guard disappeared during exit timing");
				if (actor.getTile().equals(MonkeyMap.PRISON_GUARD_FOLLOW))
				{
					MonkeySurvival.protection("missiles",true,12);
					QuestWorkflow.require(SnapshotData.action("walk.click",Map.of("x",2762,"y",2804,"plane",0)),"Prison exit click failed");
					QuestWorkflow.await(() -> QuestWorkflow.tile().equals(MonkeyMap.PRISON_CLEAR),60,"Prison exit arrival was not observed");
					return;
				}
				if (actor.getTile().equals(MonkeyMap.PRISON_GUARD_RETURN)) { retreat = true; break; }
				Sleep.sleepTicks(1);
			}
			QuestWorkflow.require(retreat,"Prison exit decision was not observed");
		}
		throw new IllegalStateException("Prison exit opportunities were exhausted");
	}
	private int lockWindow()
	{
		Set<Integer> primed = new HashSet<>();
		for (int tick = 0; tick < 320; tick++)
		{
			for (int id : new int[]{5247,5248})
			{
				NPC guard = QuestWorkflow.npc(id);
				if (guard == null) { primed.remove(id); continue; }
				Tile point = guard.getTile();
				if (primed.contains(id) && point.equals(MonkeyMap.PRISON_GUARD_LOCK)) return id;
				if (point.equals(MonkeyMap.PRISON_GUARD_PRIME)) primed.add(id);
				else if (point.getX() != 2772 || point.getY() < 2796 || point.getY() > 2798) primed.remove(id);
			}
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Prison guard lock window was not observed");
	}
	private boolean pick(int guardId)
	{
		boolean north = false;
		for (int attempt = 0; attempt < 12; attempt++)
		{
			NPC guard = QuestWorkflow.npc(guardId);
			QuestWorkflow.require(guard != null,"Prison guard disappeared");
			north |= guard.getTile().getY() > 2800;
			if (north && guard.getTile().equals(MonkeyMap.PRISON_GUARD_RETURN)) return false;
			GameObject door = door(); if (door == null) return true;
			long tick = ScriptScope.current().tick();
			QuestWorkflow.require(door.interact("Pick-lock"),"Prison lockpick interaction failed");
			for (int wait = 0; wait < 12; wait++)
			{
				if (crossedDoor() || QuestWorkflow.message(tick,"manage to pick the lock")) return true;
				if (QuestWorkflow.message(tick,"fail to pick the lock")) break;
				guard = QuestWorkflow.npc(guardId);
				QuestWorkflow.require(guard != null,"Prison guard disappeared while lockpicking");
				north |= guard.getTile().getY() > 2800;
				if (north && guard.getTile().equals(MonkeyMap.PRISON_GUARD_RETURN)) return false;
				Sleep.sleepTicks(1);
			}
		}
		return false;
	}
	private int guardAt(Tile point, int ticks)
	{
		for (int tick = 0; tick < ticks; tick++)
		{
			for (int id : new int[]{5247,5248}) { NPC guard = QuestWorkflow.npc(id); if (guard != null && guard.getTile().equals(point)) return id; }
			Sleep.sleepTicks(1);
		}
		throw new IllegalStateException("Prison guard did not reach exit staging");
	}
	private void settle(Tile anchor)
	{
		MonkeySurvival.behavior(true);
		int quiet = 0;
		for (int tick = 0; tick < 60 && quiet < 3; tick++)
		{
			String name = WorkflowScript.player().getName();
			boolean attacked = SnapshotData.rows("npcs",Map.of("within",12,"limit",40)).stream()
				.anyMatch(npc -> name.equals(npc.get("interacting")) && !Boolean.TRUE.equals(npc.get("dead")));
			quiet = !attacked && !WorkflowScript.player().isInCombat() ? quiet+1 : 0;
			Sleep.sleepTicks(1);
		}
		QuestWorkflow.require(quiet >= 3,"Prison combat did not settle");
		Travel.to(anchor,0,"questing",WorkflowScript.NO_DISCRETIONARY);
	}
	private GameObject door() { return GameObjects.closest(object -> object.getId() == 4799 && object.hasAction("Pick-lock")); }
	private boolean crossedDoor() { Tile point = QuestWorkflow.tile(); return point.getX() >= 2769 && point.getX() <= 2772 && point.getY() >= 2796 && point.getY() <= 2797; }
}
