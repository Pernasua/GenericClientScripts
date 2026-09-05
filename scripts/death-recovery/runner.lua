local config = gc.require("config")

local function show(state, recovered)
  gc.overlay {
    { label = "State", value = state },
    { label = "Recovered", value = tostring(recovered or 0) },
  }
end

local function office_present()
  local portal = gc.read("objects", {
    id = config.office.exit_portal_id,
    action = config.office.exit_action,
    within = 30,
    limit = 1,
  })[1]
  if portal then return true end
  return gc.read("npcs", {
    id = config.office.death_npc_id,
    within = 30,
    limit = 1,
  })[1] ~= nil
end

local function retrieval_open()
  return #gc.read("widgets", {
    ids = { config.office.take_all_widget_id },
    limit = 1,
  }) > 0
end

local function wait_until(predicate, game_ticks)
  for _ = 1, game_ticks do
    gc.await { event = "game.tick" }
    if predicate() then return true end
  end
  return false
end

local function dialogue_has_option(dialogue, wanted)
  if dialogue.type ~= "choice" then return false end
  for _, option in ipairs(dialogue.options or {}) do
    if option.text == wanted then return true end
  end
  return false
end

local function inventory_quantities()
  local quantities = {}
  for _, item in ipairs(gc.read("inventory").items or {}) do
    quantities[item.id] = (quantities[item.id] or 0) + item.quantity
  end
  return quantities
end

local function recovered_items(before, after)
  local items = {}
  local quantity = 0
  for id, current in pairs(after) do
    local gained = current - (before[id] or 0)
    if gained > 0 then
      items[#items + 1] = { id = id, quantity = gained }
      quantity = quantity + gained
    end
  end
  table.sort(items, function(left, right) return left.id < right.id end)
  return items, quantity
end

local function enter_office()
  if office_present() then return { status = "already_inside" } end

  show("Traveling", 0)
  gc.activity("travel")
  local walked = gc.await {
    action = {
      type = "walk.to",
      destination = config.entrance.destination,
      within = 6,
    },
    timeout = { game_ticks = 900 },
  }
  if walked.status ~= "arrived" then
    return nil, { status = "death_office_travel_failed", receipt = walked }
  end

  local entrance = gc.read("objects", {
    id = config.entrance.object_id,
    action = config.entrance.action,
    within = 14,
    limit = 1,
  })[1]
  if not entrance then
    return nil, { status = "death_office_entrance_not_observed", player = gc.read("player") }
  end

  gc.activity("banking")
  local entered = gc.await {
    action = {
      type = "object.interact",
      id = entrance.id,
      action = config.entrance.action,
      world = entrance.world,
      within = 14,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if entered.status ~= "dispatched" then
    return nil, { status = "death_office_entry_failed", receipt = entered }
  end
  if not wait_until(office_present, 30) then
    return nil, { status = "death_office_entry_unverified", receipt = entered }
  end
  return entered
end

local function open_from_dialogue()
  for _ = 1, 40 do
    if retrieval_open() then return { status = "retrieval_open" } end
    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      local continued = gc.await {
        action = { type = "dialogue.continue", reading = false },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 30 },
      }
      if continued.status ~= "dispatched" and continued.result ~= "dialogue_is_choice" then
        return nil, { status = "death_dialogue_continue_failed", receipt = continued }
      end
    elseif dialogue.type == "choice" then
      local choice
      for _, option in ipairs(dialogue.options) do
        if option.text == config.office.collect_gravestone_option or
          option.text == config.office.accept_fee_option then
          choice = option.text
          break
        end
      end
      if not choice then
        return nil, { status = "death_dialogue_choice_unhandled", dialogue = dialogue }
      end
      local chosen = gc.await {
        action = { type = "dialogue.choose", text = choice },
        policy = { breaks = false, cursor_release = "none", fidget = "none" },
        timeout = { game_ticks = 30 },
      }
      if chosen.status ~= "dispatched" then
        gc.await { event = "game.tick" }
      end
      if chosen.status ~= "dispatched" and
        dialogue_has_option(gc.read("dialogue"), choice) then
        return nil, { status = "death_dialogue_choice_failed", receipt = chosen }
      end
    elseif dialogue.type == "closed" then
      return nil, { status = "death_retrieval_not_open" }
    else
      return nil, { status = "death_dialogue_unhandled", dialogue = dialogue }
    end
    gc.await { event = "game.tick" }
  end
  return nil, { status = "death_dialogue_timeout", dialogue = gc.read("dialogue") }
end

local function take_all_once(before)
  show("Taking all", 0)
  local taken = gc.await {
    action = {
      type = "ui.click",
      widget_id = config.office.take_all_widget_id,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if taken.status ~= "dispatched" then
    return nil, { status = "death_take_all_failed", receipt = taken }
  end
  gc.await { ticks = 4 }

  local dialogue = gc.read("dialogue")
  if dialogue.type ~= "closed" then
    return nil, {
      status = "death_recovery_confirmation_required",
      dialogue = dialogue,
      receipt = taken,
    }
  end

  local items, quantity = recovered_items(before, inventory_quantities())
  return { items = items, quantity = quantity, receipt = taken }
end

local function transfer_active_gravestone()
  gc.await {
    action = { type = "ui.close" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  local death = gc.read("npcs", {
    id = config.office.death_npc_id,
    within = 30,
    limit = 1,
  })[1]
  if not death then
    return nil, { status = "death_not_observed_for_gravestone_transfer" }
  end
  local talked = gc.await {
    action = {
      type = "npc.interact",
      id = death.id,
      action = "Talk-to",
      within = 30,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if talked.status ~= "dispatched" then
    return nil, { status = "death_gravestone_talk_failed", receipt = talked }
  end
  if not wait_until(function() return gc.read("dialogue").type ~= "closed" end, 10) then
    return nil, { status = "death_gravestone_dialogue_not_open", receipt = talked }
  end
  return open_from_dialogue()
end

local function collect_items()
  show("Opening retrieval", 0)
  gc.activity("banking")
  local opened = { status = "already_open" }
  if not retrieval_open() then
    local death = gc.read("npcs", {
      id = config.office.death_npc_id,
      within = 30,
      limit = 1,
    })[1]
    if not death then
      return nil, { status = "death_not_observed", player = gc.read("player") }
    end

    opened = gc.await {
      action = {
        type = "npc.interact",
        id = death.id,
        action = config.office.collect_action,
        within = 30,
      },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 40 },
    }
    if opened.status ~= "dispatched" then
      return nil, { status = "death_retrieval_open_failed", receipt = opened }
    end
    if not wait_until(retrieval_open, 10) then
      local dialogue_receipt, dialogue_error = open_from_dialogue()
      if not dialogue_receipt then return nil, dialogue_error end
      opened.dialogue = dialogue_receipt
    end
  end

  local before = inventory_quantities()
  local taken, take_error = take_all_once(before)
  if not taken then return nil, take_error end
  if taken.quantity == 0 then
    local transferred, transfer_error = transfer_active_gravestone()
    if not transferred then return nil, transfer_error end
    opened.gravestone_transfer = transferred
    taken, take_error = take_all_once(before)
    if not taken then return nil, take_error end
  end
  local items, quantity = taken.items, taken.quantity
  show("Recovered", quantity)
  return {
    status = quantity > 0 and "recovered" or "nothing_to_recover",
    quantity = quantity,
    items = items,
    open_receipt = opened,
    take_all_receipt = taken.receipt,
  }
end

local function leave_office()
  local closed = gc.await {
    action = { type = "ui.close" },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  gc.await { event = "game.tick" }

  local portal = gc.read("objects", {
    id = config.office.exit_portal_id,
    action = config.office.exit_action,
    within = 14,
    limit = 1,
  })[1]
  if not portal then
    return nil, { status = "death_office_exit_not_observed", close_receipt = closed }
  end
  local used = gc.await {
    action = {
      type = "object.interact",
      id = portal.id,
      action = config.office.exit_action,
      world = portal.world,
      within = 14,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 40 },
  }
  if used.status ~= "dispatched" then
    return nil, { status = "death_office_exit_failed", receipt = used }
  end
  if not wait_until(function() return not office_present() end, 30) then
    return nil, { status = "death_office_exit_unverified", receipt = used }
  end
  return used
end

local function fail(receipt)
  show("Faulted", 0)
  gc.log("error", "death-recovery-failed", receipt)
  error(receipt.status)
end

local function run()
  local entered, entry_error = enter_office()
  if not entered then fail(entry_error) end

  local recovered, recovery_error = collect_items()
  if not recovered then fail(recovery_error) end

  local exited, exit_error = leave_office()
  if not exited then fail(exit_error) end

  local result = {
    status = "complete",
    recovery = recovered,
    entry = entered,
    exit = exited,
    player = gc.read("player"),
    inventory = gc.read("inventory"),
  }
  show("Complete", recovered.quantity)
  gc.log("info", "death-recovery-complete", result)
  return result
end

return { run = run }
