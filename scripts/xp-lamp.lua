-- genericclient-interface: 2

local LAMP_ID = 2528
local WIDGETS = {
  attack = 15728642,
  strength = 15728643,
  ranged = 15728644,
  magic = 15728645,
  defence = 15728646,
  hitpoints = 15728648,
  prayer = 15728649,
  agility = 15728650,
  herblore = 15728651,
  thieving = 15728652,
  crafting = 15728653,
  runecraft = 15728654,
  slayer = 15728655,
  farming = 15728656,
  mining = 15728657,
  smithing = 15728658,
  fishing = 15728659,
  cooking = 15728660,
  firemaking = 15728661,
  woodcutting = 15728662,
  fletching = 15728663,
  construction = 15728664,
  hunter = 15728665,
  confirm = 15728667,
}
local HARD_CAPS = {
  attack = 80,
  strength = 99,
  ranged = 99,
  magic = 99,
  defence = 75,
  hitpoints = 99,
  prayer = 77,
}

local function item_quantity(id)
  local total = 0
  for _, item in ipairs(gc.read("inventory").items or {}) do
    if item.id == id then total = total + item.quantity end
  end
  return total
end

local function widget(id)
  return gc.read("widgets", { ids = { id }, limit = 1 })[1]
end

local function wait_for_widgets(first, second, ticks)
  for _ = 1, ticks do
    if widget(first) and widget(second) then return true end
    gc.await { event = "game.tick" }
  end
  return false
end

return {
  inputs = {
    {
      id = "skill",
      label = "Skill",
      type = "choice",
      default = "prayer",
      choices = {
        { value = "prayer", label = "Prayer" },
        { value = "thieving", label = "Thieving" },
        { value = "slayer", label = "Slayer" },
        { value = "firemaking", label = "Firemaking" },
        { value = "agility", label = "Agility" },
        { value = "herblore", label = "Herblore" },
        { value = "ranged", label = "Ranged" },
        { value = "magic", label = "Magic" },
        { value = "hitpoints", label = "Hitpoints" },
        { value = "attack", label = "Attack" },
        { value = "strength", label = "Strength" },
        { value = "defence", label = "Defence" },
      },
    },
  },

  run = function(input)
    local skill_name = input.skill
    local skill_widget = assert(WIDGETS[skill_name], "Unsupported lamp skill")
    gc.await { event = "game.tick" }

    local skill = assert(gc.read("skills")[skill_name], "Skill snapshot unavailable")
    local cap = HARD_CAPS[skill_name] or 99
    if skill.level >= cap then
      return {
        status = "hard_cap_reached",
        skill = skill_name,
        level = skill.level,
        xp = skill.xp,
        cap = cap,
      }
    end

    local lamps_before = item_quantity(LAMP_ID)
    if lamps_before < 1 then
      return { status = "lamp_not_carried", lamp_id = LAMP_ID }
    end

    gc.overlay {
      { label = "XP Lamp", value = skill_name },
      { label = "State", value = "Opening" },
    }
    return gc.intent("xp_lamp.use", function()
      local opened = gc.await {
        action = { type = "item.interact", id = LAMP_ID, action = "Rub" },
        timeout = { game_ticks = 20 },
      }
      if opened.status ~= "dispatched" then
        return { status = "lamp_open_failed", receipt = opened }
      end
      if not wait_for_widgets(skill_widget, WIDGETS.confirm, 20) then
        return {
          status = "lamp_interface_unavailable",
          skill_widget = skill_widget,
          confirm_widget = WIDGETS.confirm,
        }
      end

      gc.overlay {
        { label = "XP Lamp", value = skill_name },
        { label = "State", value = "Selecting" },
      }
      local selected = gc.await {
        action = { type = "ui.click", widget_id = skill_widget },
        timeout = { game_ticks = 20 },
      }
      if selected.status ~= "dispatched" then
        return { status = "lamp_skill_selection_failed", receipt = selected }
      end
      gc.await { event = "game.tick" }

      local confirmed = gc.await {
        action = { type = "ui.click", widget_id = WIDGETS.confirm },
        timeout = { game_ticks = 20 },
      }
      if confirmed.status ~= "dispatched" then
        return { status = "lamp_confirmation_failed", receipt = confirmed }
      end

      for _ = 1, 20 do
        gc.await { event = "game.tick" }
        local current = gc.read("skills")[skill_name]
        local lamps = item_quantity(LAMP_ID)
        if current.xp > skill.xp and lamps < lamps_before then
          local result = {
            status = "complete",
            skill = skill_name,
            start_level = skill.level,
            final_level = current.level,
            start_xp = skill.xp,
            final_xp = current.xp,
            gained_xp = current.xp - skill.xp,
            lamps_before = lamps_before,
            lamps_after = lamps,
            selection = selected,
            confirmation = confirmed,
          }
          gc.overlay {
            { label = "XP Lamp", value = skill_name },
            { label = "State", value = "Complete" },
          }
          gc.log("info", "xp-lamp-complete", result)
          gc.await { action = { type = "mouse.offscreen" } }
          return result
        end
      end

      return {
        status = "lamp_reward_unverified",
        skill = skill_name,
        start_xp = skill.xp,
        current = gc.read("skills")[skill_name],
        lamps_before = lamps_before,
        lamps_after = item_quantity(LAMP_ID),
        selection = selected,
        confirmation = confirmed,
      }
    end)
  end,
}
