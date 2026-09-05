local item_queries = gc.require("shared_items")

local prayer_potion_ids = { 2434, 139, 141, 143 }
local supported_styles = {
  magic = true,
  missiles = true,
  melee = true,
}

local function current_prayer_potion()
  return item_queries.first(gc.read("inventory"), prayer_potion_ids)
end

local function restore(minimum_points)
  minimum_points = minimum_points or 1
  local receipts = {}
  for _ = 1, 4 do
    local prayer = gc.read("skills").prayer
    if prayer.boosted_level >= minimum_points then
      return true, {
        status = #receipts == 0 and "unchanged" or "complete",
        result = #receipts == 0 and "prayer_points_sufficient" or "prayer_points_restored",
        receipts = receipts,
      }
    end

    local potion = current_prayer_potion()
    if not potion then
      return nil, {
        status = "prayer_restore_unavailable",
        prayer = prayer,
        receipts = receipts,
      }
    end
    local before = prayer.boosted_level
    local drank = gc.await {
      action = { type = "item.interact", id = potion, action = "Drink" },
      policy = { breaks = false, cursor_release = "none", fidget = "none" },
      timeout = { game_ticks = 20 },
    }
    receipts[#receipts + 1] = drank
    if drank.status ~= "dispatched" then
      return nil, {
        status = "prayer_restore_failed",
        receipt = drank,
        receipts = receipts,
      }
    end
    local increased = false
    for _ = 1, 6 do
      gc.await { event = "game.tick" }
      if gc.read("skills").prayer.boosted_level > before then
        increased = true
        break
      end
    end
    if increased and gc.read("skills").prayer.boosted_level < minimum_points then
      gc.await { event = "game.tick" }
      gc.await { event = "game.tick" }
    elseif not increased then
      gc.await { event = "game.tick" }
    end
  end
  return nil, {
    status = "prayer_restore_target_not_reached",
    prayer = gc.read("skills").prayer,
    minimum_points = minimum_points,
    receipts = receipts,
  }
end

local function prayer_name(style)
  if not supported_styles[style] then
    return nil, {
      status = "unsupported_protection_style",
      style = style,
    }
  end
  return "protect_from_" .. style
end

local function set(style, enabled, minimum_points)
  local prayer, invalid = prayer_name(style)
  if not prayer then return nil, invalid end
  local restore_receipt
  if enabled then
    local ready, failure
    ready, failure = restore(minimum_points)
    if not ready then return nil, failure end
    restore_receipt = failure
  end
  local receipt = gc.await {
    action = {
      type = "prayer.set",
      prayer = prayer,
      enabled = enabled,
    },
    policy = { breaks = false, cursor_release = "none", fidget = "none" },
    timeout = { game_ticks = 20 },
  }
  if receipt.status ~= "set" and receipt.status ~= "unchanged" then
    return nil, {
      status = "protection_prayer_failed",
      style = style,
      enabled = enabled,
      receipt = receipt,
    }
  end
  return true, {
    status = "complete",
    result = enabled and "protection_enabled" or "protection_disabled",
    style = style,
    restored = restore_receipt,
    receipt = receipt,
  }
end

return {
  enable = function(style, minimum_points) return set(style, true, minimum_points) end,
  disable = function(style) return set(style, false) end,
  restore = restore,
}
