local function maximum_spend(requests)
  local total = 0
  for _, item in ipairs(requests) do
    if item.purchase == false then
      return nil, { status = "untradeable_supply_missing", item = item }
    end
    total = total + item.quantity * item.maximum_unit_price
  end
  return total
end

local function buy(requests, options)
  local spend, spend_failure = maximum_spend(requests)
  if not spend then return nil, spend_failure end

  local coins = gc.await {
    action = {
      type = "bank.loadout",
      items = { { id = 995, quantity = spend } },
      minimum_free_slots = 27,
      close = true,
    },
    timeout = { game_ticks = options.bank_timeout_ticks or 240 },
  }
  if coins.status ~= "complete" then
    return nil, { status = "coin_loadout_failed", receipt = coins }
  end
  gc.await { ticks = 2 }

  local opened = gc.await {
    action = {
      type = "npc.interact",
      name = "Grand Exchange Clerk",
      action = "Exchange",
      within = 10,
    },
    activity = "trading",
    timeout = { game_ticks = 30 },
  }
  if opened.status ~= "dispatched" then
    return nil, { status = "exchange_open_failed", receipt = opened }
  end
  gc.await { ticks = 3 }

  local purchases = {}
  for _, item in ipairs(requests) do
    if options.before_purchase then options.before_purchase(item) end
    local purchase = gc.await {
      action = {
        type = "ge.buy",
        item_id = item.id,
        item_name = item.name,
        quantity = item.quantity,
        maximum_unit_price = item.maximum_unit_price,
        minimum_cash_reserve = options.minimum_cash_reserve,
        collect_mode = options.collect_mode,
      },
      timeout = { game_ticks = options.purchase_timeout_ticks or 300 },
    }
    purchases[#purchases + 1] = purchase
    if purchase.status ~= "complete" then
      return nil, { status = "purchase_incomplete", item = item, receipt = purchase }
    end
  end

  gc.await {
    action = { type = "ui.close" },
    activity = "trading",
  }
  gc.await { ticks = 2 }
  return true, {
    status = "complete",
    result = "purchases_complete",
    purchases = purchases,
  }
end

return {
  buy = buy,
  maximum_spend = maximum_spend,
}
