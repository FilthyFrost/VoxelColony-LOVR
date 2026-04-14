# STEP 05: HUD — Demand List and Urgency Display

## Task

Add a demand list panel on the right side of the screen showing active NPC demands sorted by urgency. Add a death notification banner at the top. Add urgency-colored indicators. Use UrhoX UI system (Yoga Flexbox + NanoVG).

## Prerequisites

- `demand.lua` from STEP_01
- `dialogue.lua` from STEP_02

## Create: HUD Demand List (right side)

### 1. Create the demand list UI panel

```lua
-- Create a right-side panel showing top 5 demands
-- Update every frame with current demand states

function createDemandListUI(uiRoot)
    local panel = uiRoot:CreateChild("BorderImage")
    panel:SetAlignment(HA_RIGHT, VA_TOP)
    panel:SetPosition(IntVector2(-10, 10))
    panel:SetSize(IntVector2(250, 200))
    panel:SetColor(Color(0, 0, 0, 0.5))
    panel:SetVisible(true)
    return panel
end

-- Demand entry colors by urgency
local URGENCY_COLORS = {
    critical = Color(1.0, 0.2, 0.2, 1.0),  -- red, pulsing
    urgent   = Color(1.0, 0.8, 0.2, 1.0),  -- yellow
    normal   = Color(0.9, 0.9, 0.9, 0.8),  -- white
}

function updateDemandListUI(panel, demandSystem, gameTime)
    -- Clear previous children
    panel:RemoveAllChildren()

    local demands = demandSystem.getActiveSorted()
    local maxShow = 5

    for i = 1, math.min(#demands, maxShow) do
        local d = demands[i]
        local entry = panel:CreateChild("Text")
        entry:SetFont(chineseFont, 12)
        entry:SetPosition(IntVector2(5, (i - 1) * 35))

        -- Build display text
        local npcName = d.npc and d.npc.name or "NPC"
        local text = ""
        local color = URGENCY_COLORS[d.urgency] or URGENCY_COLORS.normal

        -- Urgency prefix
        if d.urgency == "critical" then
            text = "!! "
            -- Pulse alpha for critical
            local alpha = 0.7 + 0.3 * math.sin(gameTime * 5)
            color = Color(1.0, 0.2, 0.2, alpha)
        elseif d.urgency == "urgent" then
            text = "!  "
        else
            text = "   "
        end

        if d.type == "building" or d.type == "expansion" then
            local most = d:getMostNeededMaterial()
            if most then
                local Dialogue = require("dialogue")
                local matName = Dialogue.getMaterialName(most.itemType)
                text = text .. npcName .. ": " .. matName .. " " .. most.delivered .. "/" .. most.needed
            else
                text = text .. npcName .. ": " .. math.floor(d:getProgress() * 100) .. "%"
            end

            -- Show full material breakdown on second line
            if d.materials then
                local detailText = ""
                for _, mat in ipairs(d.materials) do
                    local Dialogue = require("dialogue")
                    local mn = Dialogue.getMaterialName(mat.itemType)
                    local prefix = mat.delivered >= mat.needed and "OK " or "   "
                    detailText = detailText .. prefix .. mn .. " " .. mat.delivered .. "/" .. mat.needed .. "\n"
                end
                local detail = panel:CreateChild("Text")
                detail:SetFont(chineseFont, 9)
                detail:SetPosition(IntVector2(20, (i - 1) * 35 + 15))
                detail:SetColor(Color(0.7, 0.7, 0.7, 0.6))
                detail:SetText(detailText)
            end

        elseif d.type == "food" then
            text = text .. npcName .. ": " .. "苹果 " .. d.foodDelivered .. "/" .. d.foodNeeded
        elseif d.type == "companion" then
            text = text .. npcName .. ": " .. "要伙伴 [N]"
        end

        entry:SetText(text)
        entry:SetColor(color)
    end
end
```

### 2. Update the top-left status bar

```lua
-- Replace existing top-left info with:
function updateStatusBar(statusText, world, npcs, gameTime)
    local timeStr = world.isNight and "夜" or "日"
    local alive = 0
    for _, npc in ipairs(npcs) do
        if not npc.dead then alive = alive + 1 end
    end
    local minutes = math.floor(gameTime / 60)
    local seconds = math.floor(gameTime % 60)
    statusText:SetText(string.format("%s  NPC:%d  %d:%02d", timeStr, alive, minutes, seconds))
end
```

### 3. Update the bottom material selector

```lua
-- Modify bottom selector to show material name in Chinese and hotkey hint
function updateMaterialSelector(selectorText, selectedIdx)
    local itemType = Items.panel_order[selectedIdx]
    local Dialogue = require("dialogue")
    local matName = Dialogue.getMaterialName(itemType)

    -- Find hotkey for this material
    local hotkey = ""
    local HOTKEYS = {
        cobblestone="1", oak_planks="2", spruce_planks="3", stone_bricks="4",
        glass_pane="5", door="6", bed="7", torch="8", apple="9",
    }
    if HOTKEYS[itemType] then hotkey = " [" .. HOTKEYS[itemType] .. "]" end

    -- Check if any demand needs this material (highlight yellow if so)
    local needed = false
    for _, d in ipairs(Demand.active) do
        if d.state == "active" then
            if d.type == "food" and itemType == "apple" then needed = true end
            if d.materials then
                for _, mat in ipairs(d.materials) do
                    if mat.itemType == itemType and mat.delivered < mat.needed then
                        needed = true; break
                    end
                end
            end
        end
        if needed then break end
    end

    selectorText:SetText(matName .. hotkey)
    if needed then
        selectorText:SetColor(Color(1.0, 0.9, 0.3, 1.0))  -- yellow = someone needs this
    else
        selectorText:SetColor(Color(1.0, 1.0, 1.0, 0.9))   -- white = normal
    end
end
```

## Create: Death Notification Banner

### 4. Top-center death banner (appears for 3 seconds when NPC dies)

```lua
local deathBanner = {active = false, text = "", timer = 0}

function showDeathBanner(npcName, deathCauseText, lastWords)
    deathBanner.active = true
    deathBanner.text = "X " .. npcName .. " " .. deathCauseText .. '... "' .. lastWords .. '"'
    deathBanner.timer = 3.0
end

function updateDeathBanner(dt, bannerElement)
    if not deathBanner.active then
        bannerElement:SetVisible(false)
        return
    end
    deathBanner.timer = deathBanner.timer - dt
    if deathBanner.timer <= 0 then
        deathBanner.active = false
        bannerElement:SetVisible(false)
        return
    end
    bannerElement:SetVisible(true)
    bannerElement:SetText(deathBanner.text)
    bannerElement:SetColor(Color(1.0, 0.3, 0.3, math.min(1.0, deathBanner.timer)))
end
```

Call `showDeathBanner()` from the NPC death logic in STEP_04 when `self.dead = true`.

## Create: Upgrade Level Display

### 5. Bottom-left upgrade status

```lua
-- Show current drop level
function updateUpgradeDisplay(upgradeText, upgradeSystem)
    local text = "Lv." .. upgradeSystem.level .. " x" .. upgradeSystem.dropMultiplier
    upgradeText:SetText(text)
end
```

## Verification

1. Start game. Right side should show 1 demand entry (the first building demand).
2. The entry should show NPC name + material name in Chinese + progress counter.
3. As you drop correct materials, the counter should update in real time.
4. When NPC hunger drops below 30%, the demand urgency should change to "urgent" (yellow).
5. When NPC hunger drops below 15%, urgency should be "critical" (red, pulsing).
6. When an NPC dies, a red banner should appear at the top for 3 seconds showing cause and last words in Chinese.
7. Top-left should show day/night, alive NPC count, and elapsed time.
8. Bottom material selector should show Chinese name and highlight yellow when a demand needs that material.
