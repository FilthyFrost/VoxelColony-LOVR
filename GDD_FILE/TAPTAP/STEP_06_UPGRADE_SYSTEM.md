# STEP 06: Create Player Upgrade System

## Task

Create `upgrade.lua` that tracks the player's drop multiplier. Each click drops more blocks as the player fulfills demands: 1 → 3 → 6 → 12 → 24. Show upgrade effect on screen when leveling up.

## Create file: upgrade.lua

```lua
-- upgrade.lua — Player Drop Multiplier Upgrade
-- Fulfilling NPC demands levels up the drop count per click.

local Upgrade = {}

Upgrade.level = 1
Upgrade.dropMultiplier = 1
Upgrade.totalFulfilled = 0    -- weighted demand completion count

-- Level thresholds and multipliers
local THRESHOLDS = {1, 3, 6, 10}         -- total fulfilled needed for Lv2, Lv3, Lv4, Lv5
local MULTIPLIERS = {1, 3, 6, 12, 24}    -- drop count at each level

-- Upgrade effect display state
Upgrade.showEffect = false
Upgrade.effectTimer = 0
Upgrade.effectText = ""
Upgrade.effectOldMult = 1
Upgrade.effectNewMult = 1

-- Called when a demand is fulfilled
-- demandType: "building", "food", "companion", "expansion"
function Upgrade.onDemandFulfilled(demandType)
    local weight = 1.0
    if demandType == "food" then weight = 0.5
    elseif demandType == "companion" then weight = 0.3 end

    Upgrade.totalFulfilled = Upgrade.totalFulfilled + weight

    -- Check for level up
    if Upgrade.level < #MULTIPLIERS then
        if Upgrade.totalFulfilled >= THRESHOLDS[Upgrade.level] then
            Upgrade.effectOldMult = Upgrade.dropMultiplier
            Upgrade.level = Upgrade.level + 1
            Upgrade.dropMultiplier = MULTIPLIERS[Upgrade.level]
            Upgrade.effectNewMult = Upgrade.dropMultiplier

            -- Trigger visual effect
            Upgrade.showEffect = true
            Upgrade.effectTimer = 2.0
            Upgrade.effectText = "x" .. Upgrade.effectOldMult .. " -> x" .. Upgrade.effectNewMult
        end
    end
end

-- Update effect timer
function Upgrade.update(dt)
    if Upgrade.showEffect then
        Upgrade.effectTimer = Upgrade.effectTimer - dt
        if Upgrade.effectTimer <= 0 then
            Upgrade.showEffect = false
        end
    end
end

-- Reset for new game
function Upgrade.reset()
    Upgrade.level = 1
    Upgrade.dropMultiplier = 1
    Upgrade.totalFulfilled = 0
    Upgrade.showEffect = false
    Upgrade.effectTimer = 0
end

return Upgrade
```

## Integrate into main script

### 1. Connect upgrade to demand completion

```lua
local Upgrade = require("upgrade")

-- Where you call Demand.markCompleted(d), also call:
Upgrade.onDemandFulfilled(d.type)
```

### 2. Use dropMultiplier in dropItem()

```lua
function dropItem()
    local gx, gz = getLookTarget()
    if not gx then return end

    local itemType = Items.panel_order[selectedIdx]
    local count = Upgrade.dropMultiplier  -- WAS: 1

    for i = 1, count do
        local offsetX = count > 1 and math.random(-1, 1) or 0
        local offsetZ = count > 1 and math.random(-1, 1) or 0
        local dropX = math.max(0, math.min(Config.GRID - 1, gx + offsetX))
        local dropZ = math.max(0, math.min(Config.GRID - 1, gz + offsetZ))
        local topY = -1
        for y = 20, 0, -1 do
            if world:isOccupied(dropX, y, dropZ) then topY = y; break end
        end
        addFallingItem(dropX, dropZ, topY + 1, itemType)
    end

    Demand.onPlayerDrop(itemType, gx, gz, count)
end
```

### 3. Update and render upgrade effect

```lua
-- In Update(dt):
Upgrade.update(dt)

-- Render upgrade effect (center screen, large text, 2 second duration):
if Upgrade.showEffect then
    -- Draw centered text using your UI system:
    -- Line 1 (large): "投放升级！"
    -- Line 2 (large): "x3 -> x6"
    -- Scale animation: start at 1.5x size, shrink to 1.0x over 0.3 seconds
    -- Color: gold (1.0, 0.9, 0.3)
    local scale = 1.0
    if Upgrade.effectTimer > 1.7 then
        scale = 1.0 + (Upgrade.effectTimer - 1.7) / 0.3 * 0.5  -- 1.5 -> 1.0
    end
    -- Use your UI/NanoVG to draw:
    -- "投放升级！" at screen center, font size 32 * scale
    -- Upgrade.effectText at screen center + 40px down, font size 24 * scale
end
```

### 4. Update HUD upgrade display

```lua
-- Bottom-left corner, always visible:
-- "Lv.3 x6"
-- Progress bar to next level (optional):
local progressToNext = 0
if Upgrade.level < #MULTIPLIERS then
    local current = Upgrade.totalFulfilled
    local prev = Upgrade.level > 1 and THRESHOLDS[Upgrade.level - 1] or 0
    local next = THRESHOLDS[Upgrade.level]
    progressToNext = (current - prev) / (next - prev)
end
```

## Verification

1. Start game. Drop multiplier should be 1 (one block per click).
2. Fulfill first building demand (all materials delivered + NPC finishes building).
3. `Upgrade.level` should become 2, `Upgrade.dropMultiplier` should become 3.
4. `Upgrade.showEffect` should be true for 2 seconds.
5. Next click should drop 3 blocks (with random XZ offset).
6. Fulfill 2 more demands (total 3). Level should become 3, multiplier 6.
7. Food demands count as 0.5 toward total. Companion demands count as 0.3.
