local failure = gc.require("shared_failure")

local NPC_IDS = {
  [5436] = true, -- Niles
  [5437] = true, -- Miles
  [5438] = true, -- Giles
  [5439] = true, -- Niles (underwater)
  [5440] = true, -- Miles (underwater)
  [5441] = true, -- Giles (underwater)
}

local WIDGET = {
  item = 12058631, -- 184:7, macro_certer_item
  labels = { 12058625, 12058626, 12058627 }, -- 184:1-3
  answers = { 12058632, 12058633, 12058634 }, -- 184:8-10
}

-- Certer uses one of these eight purpose-built models. The answer order is
-- randomized, so the model identifies the item while the live labels identify
-- which button to click.
-- Item semantics: Infinitay/Random-Event-Helper@43e578fd30f60ac765a32b7b99c82b6ca3791776.
-- Component ownership: Joshua-F/osrs-dumps@5bc2ff1e74086422cff362c60761f9b27424e9ce.
local ANSWER_BY_MODEL = {
  [2807] = "A bowl.",
  [8834] = "A ring.",
  [8828] = "An axe.",
  [8832] = "A shield.",
  [8835] = "A pair of shears.",
  [8833] = "A helmet.",
  [8829] = "A fish.",
  [8837] = "A spade.",
}

local function normalize(value)
  return string.lower(value or "")
    :gsub("%s+", " ")
    :gsub("^%s+", "")
    :gsub("%s+$", "")
    :gsub("[%.!?]+$", "")
end

local function visible_widgets()
  local ids = { WIDGET.item }
  for _, id in ipairs(WIDGET.labels) do ids[#ids + 1] = id end
  return gc.read("widgets", { ids = ids, limit = #ids })
end

local function read_question()
  local by_id = {}
  for _, widget in ipairs(visible_widgets()) do
    by_id[widget.id] = widget
  end

  local item = by_id[WIDGET.item]
  if not item then return nil end

  local expected = ANSWER_BY_MODEL[item.model_id]
  if not expected then
    return nil, {
      status = "unknown_item_model",
      model_id = item.model_id,
      item_widget = item,
    }
  end

  local matched_index = nil
  local labels = {}
  local label_count = 0
  for index, id in ipairs(WIDGET.labels) do
    local label = by_id[id]
    labels[index] = label and label.text or nil
    if label then label_count = label_count + 1 end
    if label and normalize(label.text) == normalize(expected) then
      if matched_index then
        return nil, {
          status = "duplicate_answer_label",
          model_id = item.model_id,
          expected = expected,
          labels = labels,
        }
      end
      matched_index = index
    end
  end

  if label_count < #WIDGET.labels then return nil end

  if not matched_index then
    return nil, {
      status = "answer_label_not_found",
      model_id = item.model_id,
      expected = expected,
      labels = labels,
    }
  end

  return {
    model_id = item.model_id,
    expected = expected,
    answer_index = matched_index,
    answer_widget = WIDGET.answers[matched_index],
    labels = labels,
  }
end

local function open_question(event)
  local talked = false
  for _ = 1, 40 do
    local question, question_error = read_question()
    if question then return question end
    if question_error then failure.raise("certer-failed", question_error.status, question_error) end

    local dialogue = gc.read("dialogue")
    if dialogue.type == "continue" then
      local receipt = gc.await {
        action = { type = "dialogue.continue" },
        timeout = { game_ticks = 20 },
      }
      if receipt.status ~= "dispatched" then
        failure.raise("certer-failed", "dialogue_continue_failed", { receipt = receipt, dialogue = dialogue })
      end
    elseif not talked then
      local receipt = gc.await {
        action = {
          type = "npc.interact",
          id = event.npc_id,
          action = "Talk-to",
          within = 12,
        },
        timeout = { game_ticks = 30 },
      }
      if receipt.status ~= "dispatched" then
        failure.raise("certer-failed", "talk_failed", { receipt = receipt, event = event })
      end
      talked = true
    else
      gc.await { event = "game.tick" }
    end
  end

  failure.raise("certer-failed", "question_not_observed", {
    event = gc.read("random_event"),
    widgets = gc.read("widgets", { group = 184, limit = 20 }),
  })
end

local function reward_message(since_tick)
  for _, message in ipairs(gc.read("messages", { since_tick = since_tick, limit = 30 })) do
    if string.find(string.lower(message.text or ""), "your reward is:", 1, true) then
      return message
    end
  end
  return nil
end

return {
  run = function()
    local event = gc.read("random_event")
    if not event.active or not NPC_IDS[event.npc_id] then
      error("Certer solver started without its owned event")
    end

    return gc.intent("certer.answer_question", function()
      local question = open_question(event)
      local started_tick = gc.read("runtime").game_tick
      local selected = gc.await {
        action = { type = "ui.click", widget_id = question.answer_widget },
        timeout = { game_ticks = 20 },
      }
      if selected.status ~= "dispatched" then
        failure.raise("certer-failed", "answer_click_failed", { question = question, receipt = selected })
      end

      for _ = 1, 30 do
        gc.await { event = "game.tick" }
        local reward = reward_message(started_tick)
        local current_event = gc.read("random_event")
        if reward and not current_event.present then
          return {
            status = "solved",
            model_id = question.model_id,
            answer = question.expected,
            answer_index = question.answer_index,
            reward = reward,
          }
        end

        local dialogue = gc.read("dialogue")
        if dialogue.type == "continue" then
          local receipt = gc.await {
            action = { type = "dialogue.continue" },
          }
          if receipt.status ~= "dispatched" then
            failure.raise("certer-failed", "reward_dialogue_failed", { receipt = receipt, dialogue = dialogue })
          end
        end
      end

      failure.raise("certer-failed", "reward_not_observed", {
        question = question,
        event = gc.read("random_event"),
        messages = gc.read("messages", { since_tick = started_tick, limit = 30 }),
      })
    end)
  end,
}
