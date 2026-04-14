# STEP 03: Integrate Demand System into Main Game

## Task

Modify the main game script to:
1. Remove old template/preview UI modes (NPCs now choose what to build, not the player)
2. Integrate the demand system from STEP_01
3. Add number key hotkeys (1-9) for quick material selection
4. Connect player click-to-drop with the demand system

## Prerequisites

- `demand.lua` from STEP_01 must exist
- `dialogue.lua` from STEP_02 must exist

## Changes to Main Script

### 1. Add requires at the top

```lua
local Demand = require("demand")
local Dialogue = require("dialogue")
```

### 2. Remove template/preview mode variables

Remove or ignore these variables:
```lua
-- REMOVE these:
-- local templateIdx = 1
-- local uiMode = "block"  -- no longer needed, always "block" mode
-- local previewBuildings = {}
```

Keep `selectedIdx` (material selector) and `buildQueue` (used by demand system).

### 3. Initialize demand system in your init/Start function

```lua
-- In your init/Start function, after creating world and first NPC:
Demand.reset()
-- The demand system will auto-generate the first demand in its first update cycle
```

### 4. Update demand system every frame

```lua
-- In your Update(dt) function, after updating world and NPCs:
Demand.update(dt, npcs, world, Config)

-- Check fulfilled demands and start NPC building
for _, d in ipairs(Demand.active) do
    if d.state == "fulfilled" then
        if d.type == "building" or d.type == "expansion" then
            -- Add to buildQueue so NPCs start building
            buildQueue[#buildQueue + 1] = {
                template = d.template,
                blueprint = nil,
                materialPos = {x = d.npc.gx, z = d.npc.gz},
            }
            d.state = "building"
        elseif d.type == "food" then
            -- Food demands are fulfilled when NPC eats (handled by NPC AI)
            Demand.markCompleted(d)
        elseif d.type == "companion" then
            Demand.markCompleted(d)
        end
    end
    -- Check if building demands are completed (NPC finished building)
    if d.state == "building" then
        for _, job in ipairs(buildQueue) do
            if job.template == d.template and job.blueprint and job.blueprint.completed then
                Demand.markCompleted(d)
                break
            end
        end
    end
end
```

### 5. Modify drop function

Replace the old `dropItem()` / template drop logic with:

```lua
function dropItem()
    local gx, gz = getLookTarget()  -- your raycast function
    if not gx then return end

    local itemType = Items.panel_order[selectedIdx]
    local count = 1  -- will be replaced by upgrade system in STEP_07

    -- Create falling items
    for i = 1, count do
        local offsetX = 0
        local offsetZ = 0
        if count > 1 then
            offsetX = math.random(-1, 1)
            offsetZ = math.random(-1, 1)
        end
        local dropX = math.max(0, math.min(Config.GRID - 1, gx + offsetX))
        local dropZ = math.max(0, math.min(Config.GRID - 1, gz + offsetZ))

        -- Find stack height
        local topY = -1
        for y = 20, 0, -1 do
            if world:isOccupied(dropX, y, dropZ) then topY = y; break end
        end

        -- Create falling item (adapt to your engine's falling item system)
        addFallingItem(dropX, dropZ, topY + 1, itemType)
    end

    -- Notify demand system
    local matched = Demand.onPlayerDrop(itemType, gx, gz, count)

    -- If no demand matched and there are active demands, NPC complains
    if not matched and #Demand.getActiveSorted() > 0 then
        local nearest = nil
        local nearestDist = math.huge
        for _, d in ipairs(Demand.active) do
            if d.state == "active" and d.npc and not d.npc.dead then
                local dist = math.abs(d.npc.gx - gx) + math.abs(d.npc.gz - gz)
                if dist < nearestDist then
                    nearest = d
                    nearestDist = dist
                end
            end
        end
        if nearest then
            local neededMat = "cobblestone"
            if nearest.materials then
                local m = nearest:getMostNeededMaterial()
                if m then neededMat = m.itemType end
            end
            -- Set NPC dialogue to WRONG_MATERIAL
            nearest.npc.dialogueLine = Dialogue.getLine("WRONG_MATERIAL", nil, nearest.npc,
                {material = neededMat})
            nearest.npc.dialogueTimer = 2.0
        end
    end
end
```

### 6. Add number key hotkeys for material selection

```lua
-- In your key handler:
local HOTKEYS = {
    ["1"] = "cobblestone",
    ["2"] = "oak_planks",
    ["3"] = "spruce_planks",
    ["4"] = "stone_bricks",
    ["5"] = "glass_pane",
    ["6"] = "door",
    ["7"] = "bed",
    ["8"] = "torch",
    ["9"] = "apple",
}

function handleKeyPress(key)
    -- Number hotkeys
    if HOTKEYS[key] then
        local target = HOTKEYS[key]
        for i, name in ipairs(Items.panel_order) do
            if name == target then
                selectedIdx = i
                break
            end
        end
        return
    end

    -- Left/Right arrow: cycle materials
    if key == "left" then
        selectedIdx = selectedIdx - 1
        if selectedIdx < 1 then selectedIdx = #Items.panel_order end
    elseif key == "right" then
        selectedIdx = selectedIdx + 1
        if selectedIdx > #Items.panel_order then selectedIdx = 1 end
    end

    -- N: spawn NPC (only if companion demand exists)
    if key == "n" then
        if #npcs >= 10 then return end
        local gx, gz = getLookTarget()
        if gx then
            -- Check if there's a companion demand
            local hasCompDemand = Demand.onCompanionSpawned()
            -- Spawn NPC regardless (player can always add NPCs)
            local newNpc = NPC.new(Config, world, Items, gx, gz, npcs)
            npcs[#npcs + 1] = newNpc
        end
    end

    -- Tab: removed (no more template/preview modes)
    -- V: follow NPC (keep existing)
    -- F: first person (keep existing)
    -- Q: quit (keep existing)
end
```

### 7. Remove old template/preview functions

Remove these functions entirely:
- `dropTemplateMaterials()` — replaced by demand system
- `placePreviewBuilding()` — no longer needed

### 8. Add NPC dialogue state

Each NPC needs these new fields (add to NPC.new or equivalent):

```lua
-- Add to each NPC object:
npc.dialogueLine = nil      -- current Chinese text to display
npc.dialogueTimer = 0       -- seconds remaining to show this line
npc.dialogueCategory = nil  -- "DEMAND_BUILDING", "DEMAND_FOOD", etc.
npc.dialogueCycleTimer = 0  -- timer for cycling waiting lines
npc.currentDemand = nil     -- reference to this NPC's active demand
```

### 9. Update NPC dialogue each frame

```lua
-- In Update(dt), after demand system update:
for _, npc in ipairs(npcs) do
    if npc.dead then goto nextNpc end

    npc.dialogueTimer = npc.dialogueTimer - dt
    npc.dialogueCycleTimer = npc.dialogueCycleTimer - dt

    -- Find this NPC's active demand
    npc.currentDemand = nil
    for _, d in ipairs(Demand.active) do
        if d.npc == npc and d.state == "active" then
            npc.currentDemand = d
            break
        end
    end

    -- Cycle dialogue for active demands
    if npc.currentDemand and npc.dialogueCycleTimer <= 0 then
        local d = npc.currentDemand
        local category = "DEMAND_BUILDING"
        if d.type == "food" then category = "DEMAND_FOOD"
        elseif d.type == "companion" then category = "DEMAND_COMPANION"
        elseif d.type == "expansion" then category = "DEMAND_EXPANSION" end

        local vars = {}
        if d.materials then
            local most = d:getMostNeededMaterial()
            if most then
                vars.count = most.needed
                vars.material = most.itemType
                vars.delivered = most.delivered
                vars.remaining = most.needed - most.delivered
            end
        elseif d.type == "food" then
            vars.count = d.foodNeeded
            vars.material = "apple"
            vars.delivered = d.foodDelivered
            vars.remaining = d.foodNeeded - d.foodDelivered
        end

        npc.dialogueLine = Dialogue.getLine(category, "waiting", npc, vars)
        -- Cycle speed based on urgency
        local interval = 6 + math.random() * 2  -- 6-8 seconds
        if d.urgency == "critical" then interval = 3 end
        if d.urgency == "urgent" then interval = 4 end
        npc.dialogueCycleTimer = interval
        npc.dialogueTimer = interval
    end

    ::nextNpc::
end
```

## Verification

1. Start the game. One NPC should appear and display a Chinese demand bubble (e.g. "喂！你！给我搬XX个圆石来！快点！")
2. Press 1 to select cobblestone. Click to drop blocks near the NPC.
3. The demand progress should update (check `Demand.active[1]:getProgress()`)
4. After all materials are delivered, NPC should start building.
5. After building completes, NPC should generate a companion demand.
6. Press N to spawn a new NPC. The companion demand should be fulfilled.
7. Both NPCs should generate food demands.
8. Press 9 to select apple, click to drop. Food demand progress should update.
