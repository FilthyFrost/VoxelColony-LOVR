# STEP 01: Create Demand System

## Task

Create a new file `demand.lua` that manages NPC demands. NPCs generate demands (building materials, food, companions). The player must fulfill these demands by clicking to drop blocks. This replaces the old player-driven template selection system.

## Create file: demand.lua

```lua
-- demand.lua — NPC Demand System
-- NPCs generate demands, player fulfills them by dropping blocks.
-- Demands have urgency levels that affect NPC dialogue and HUD display.

local Demand = {}
Demand.__index = Demand

local TemplateLib = require("templatelib")
local Items = require("items")

-- Active demands list (managed by DemandScheduler)
Demand.active = {}
Demand.nextId = 1
Demand.tutorialStep = 0  -- 0=not started, 1-3=scripted tutorial demands
Demand.totalFulfilled = 0  -- weighted count of fulfilled demands
Demand.gameTime = 0

-- Personality weights: how traits influence demand generation
local PERSONALITY_WEIGHTS = {
    diligent = {building = 1.3, food = 0.8, expansion = 1.2, companion = 1.0},
    lazy     = {building = 0.7, food = 1.4, expansion = 0.5, companion = 1.0},
    greedy   = {building = 1.0, food = 1.3, expansion = 1.5, companion = 1.0},
    explorer = {building = 1.0, food = 0.9, expansion = 1.3, companion = 0.6},
    shy      = {building = 1.3, food = 1.0, expansion = 1.0, companion = 0.4},
    social   = {building = 0.9, food = 0.9, expansion = 1.0, companion = 1.6},
}

-- Phase-based template pools (controls which buildings are available)
local PHASE_TEMPLATES = {
    [1] = {"small_house_1","small_house_2","small_house_3","small_house_4",
           "small_house_5","small_house_6","small_house_7","small_house_8",
           "small_cozy_house","start_house"},
    [2] = {"cozy_cabin","lamp_1","small_farm_1","meeting_point_1","meeting_point_2"},
    [3] = {"medium_house_1","medium_house_2","butcher_shop_1","fisher_cottage_1",
           "tannery_1","fletcher_house_1","shepherds_house"},
    [4] = {"big_house_1","library_1","library_2","temple_1","temple_2",
           "stable_1","armorer_house","weaponsmith_1","cartographer_1"},
}

-- Scheduler state
local scheduler = {
    timer = 0,
    interval = 3.0,        -- check every 3 seconds
    lastDemandTime = -10,   -- time of last demand creation
    minInterval = 5.0,      -- minimum seconds between new demands
    maxActive = 1,          -- max simultaneous active demands (increases with phase)
}

----------------------------------------------------------------------------
-- DEMAND CREATION
----------------------------------------------------------------------------
function Demand.create(dtype, npc, data)
    local d = setmetatable({}, Demand)
    d.id = "demand_" .. Demand.nextId
    Demand.nextId = Demand.nextId + 1
    d.type = dtype           -- "building" | "food" | "companion" | "expansion"
    d.npc = npc
    d.state = "active"       -- "active" | "fulfilled" | "building" | "completed"
    d.urgency = "normal"     -- "normal" | "urgent" | "critical"
    d.createdAt = Demand.gameTime

    if dtype == "building" or dtype == "expansion" then
        d.template = data.template
        d.materials = data.materials  -- {{itemType, needed, delivered}, ...}
        d.totalNeeded = 0
        d.totalDelivered = 0
        for _, m in ipairs(d.materials) do
            d.totalNeeded = d.totalNeeded + m.needed
        end
    elseif dtype == "food" then
        d.foodNeeded = data.foodNeeded or 3
        d.foodDelivered = 0
    elseif dtype == "companion" then
        d.companionDelivered = false
    end

    Demand.active[#Demand.active + 1] = d
    return d
end

----------------------------------------------------------------------------
-- MATERIAL CALCULATION
-- Calculate what materials a template needs (extract from template blocks)
----------------------------------------------------------------------------
function Demand.calcMaterials(tmpl)
    local TYPE_MAP = {
        oak_door="door", white_bed="bed", yellow_bed="bed", red_bed="bed",
        dirt="cobblestone", grass_block="cobblestone", farmland="cobblestone",
        white_terracotta="cobblestone", terracotta="cobblestone", clay="cobblestone",
        dirt_path="cobblestone", smooth_stone="cobblestone",
        wall_torch="torch", stripped_oak_wood="stripped_oak_log",
        white_wool="oak_planks", yellow_wool="oak_planks",
        iron_bars="glass_pane", furnace="cobblestone",
        yellow_stained_glass_pane="glass_pane", white_stained_glass_pane="glass_pane",
        water_cauldron="cauldron", oak_leaves="leaves",
        brewing_stand="crafting_table", smithing_table="crafting_table",
    }
    local SKIP = {
        white_carpet=true, yellow_carpet=true, green_carpet=true, red_carpet=true,
        poppy=true, dandelion=true, potted_dandelion=true, rose_bush=true,
        wheat=true, short_grass=true, tall_grass=true,
        oak_pressure_plate=true, stone_pressure_plate=true,
        water=true, lava=true, air=true,
    }
    local doorX = tmpl.doorPos and tmpl.doorPos.x or math.floor(tmpl.w / 2)
    local doorZ = tmpl.doorPos and tmpl.doorPos.z or 0

    -- Deduplicate same as templatelib.toBlueprint
    local sorted = {}
    for i, b in ipairs(tmpl.blocks) do
        b._origIdx = b._origIdx or i
        sorted[#sorted + 1] = b
    end
    table.sort(sorted, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        if a.z ~= b.z then return a.z < b.z end
        return (a._origIdx or 0) < (b._origIdx or 0)
    end)
    local byPos = {}
    for _, b in ipairs(sorted) do
        if not (b.x == doorX and b.z == doorZ and b.y < 2) then
            local mat = b.t or "wall"
            if not SKIP[mat] then
                mat = TYPE_MAP[mat] or mat
                byPos[b.x..","..b.y..","..b.z] = mat
            end
        end
    end

    -- Count by type
    local counts = {}
    local order = {}
    for _, mat in pairs(byPos) do
        if not counts[mat] then order[#order + 1] = mat end
        counts[mat] = (counts[mat] or 0) + 1
    end

    -- Build materials list with 5% buffer
    local materials = {}
    table.sort(order)
    for _, mat in ipairs(order) do
        materials[#materials + 1] = {
            itemType = mat,
            needed = counts[mat] + math.max(1, math.ceil(counts[mat] * 0.05)),
            delivered = 0,
        }
    end
    return materials
end

----------------------------------------------------------------------------
-- DEMAND FULFILLMENT
-- Called when player drops a block. Returns true if any demand was matched.
----------------------------------------------------------------------------
function Demand.onPlayerDrop(itemType, gx, gz, count)
    local matched = false
    local remaining = count

    -- Sort active demands by urgency (critical first)
    local urgencyRank = {critical = 3, urgent = 2, normal = 1}
    local sorted = {}
    for _, d in ipairs(Demand.active) do
        if d.state == "active" then sorted[#sorted + 1] = d end
    end
    table.sort(sorted, function(a, b)
        return (urgencyRank[a.urgency] or 0) > (urgencyRank[b.urgency] or 0)
    end)

    for _, d in ipairs(sorted) do
        if remaining <= 0 then break end

        if d.type == "food" and itemType == "apple" then
            local give = math.min(remaining, d.foodNeeded - d.foodDelivered)
            if give > 0 then
                d.foodDelivered = d.foodDelivered + give
                remaining = remaining - give
                matched = true
                if d.foodDelivered >= d.foodNeeded then
                    d.state = "fulfilled"
                end
            end
        elseif (d.type == "building" or d.type == "expansion") and d.materials then
            for _, mat in ipairs(d.materials) do
                if remaining <= 0 then break end
                if mat.itemType == itemType and mat.delivered < mat.needed then
                    local give = math.min(remaining, mat.needed - mat.delivered)
                    mat.delivered = mat.delivered + give
                    d.totalDelivered = (d.totalDelivered or 0) + give
                    remaining = remaining - give
                    matched = true
                end
            end
            -- Check if all materials fulfilled
            local allDone = true
            for _, mat in ipairs(d.materials) do
                if mat.delivered < mat.needed then allDone = false; break end
            end
            if allDone then d.state = "fulfilled" end
        end
    end
    return matched
end

-- Called when player presses N to spawn NPC
function Demand.onCompanionSpawned()
    for _, d in ipairs(Demand.active) do
        if d.type == "companion" and d.state == "active" then
            d.companionDelivered = true
            d.state = "fulfilled"
            return true
        end
    end
    return false
end

----------------------------------------------------------------------------
-- GET MOST NEEDED MATERIAL (for bubble display)
----------------------------------------------------------------------------
function Demand:getMostNeededMaterial()
    if not self.materials then return nil end
    local worst = nil
    local worstRatio = 2.0
    for _, mat in ipairs(self.materials) do
        if mat.delivered < mat.needed then
            local ratio = mat.delivered / mat.needed
            if ratio < worstRatio then
                worstRatio = ratio
                worst = mat
            end
        end
    end
    return worst
end

function Demand:getProgress()
    if self.type == "food" then
        return self.foodDelivered / self.foodNeeded
    elseif self.type == "companion" then
        return self.companionDelivered and 1.0 or 0.0
    elseif self.materials then
        if self.totalNeeded == 0 then return 0 end
        return (self.totalDelivered or 0) / self.totalNeeded
    end
    return 0
end

----------------------------------------------------------------------------
-- URGENCY UPDATE
----------------------------------------------------------------------------
function Demand.updateUrgencies(npcs, world)
    for _, d in ipairs(Demand.active) do
        if d.state ~= "active" then goto skip end
        if d.type == "food" then
            local hunger = d.npc.hunger / d.npc.cfg.HUNGER_MAX
            if hunger < 0.15 then d.urgency = "critical"
            elseif hunger < 0.30 then d.urgency = "urgent"
            else d.urgency = "normal" end
        elseif d.type == "building" then
            if world.isNight and not d.npc:_hasShelter() then
                d.urgency = "critical"
            elseif not d.npc:_hasShelter() then
                d.urgency = "urgent"
            else d.urgency = "normal" end
        else
            d.urgency = "normal"
        end
        ::skip::
    end
end

----------------------------------------------------------------------------
-- SCHEDULER: generates new demands based on NPC state
----------------------------------------------------------------------------
function Demand.getGamePhase(gameTime)
    if gameTime < 120 then return 1       -- 0-2min: tutorial
    elseif gameTime < 300 then return 2   -- 2-5min: expansion
    elseif gameTime < 600 then return 3   -- 5-10min: pressure
    else return 4 end                     -- 10min+: chaos
end

function Demand.getMaxActive(phase)
    if phase == 1 then return 1
    elseif phase == 2 then return 2
    elseif phase == 3 then return 4
    else return 5 end
end

-- Apply personality weights to demand base score
local function applyPersonality(npc, demandType, baseWeight)
    local mult = 1.0
    for trait, _ in pairs(npc.traits) do
        local w = PERSONALITY_WEIGHTS[trait]
        if w and w[demandType] then mult = mult * w[demandType] end
    end
    return baseWeight * mult
end

-- Choose a template from the phase-appropriate pool
local function chooseTemplate(npc, phase)
    local pool = {}
    for p = 1, phase do
        if PHASE_TEMPLATES[p] then
            for _, name in ipairs(PHASE_TEMPLATES[p]) do
                pool[#pool + 1] = name
            end
        end
    end
    -- Find matching template from TemplateLib.all
    local candidates = {}
    for _, tmpl in ipairs(TemplateLib.all) do
        for _, name in ipairs(pool) do
            if tmpl.name:lower():gsub(" ","_") == name or tmpl.name == name then
                candidates[#candidates + 1] = tmpl
                break
            end
        end
    end
    if #candidates == 0 then
        -- Fallback: use any template
        if #TemplateLib.all > 0 then return TemplateLib.all[math.random(#TemplateLib.all)] end
        return nil
    end
    return candidates[math.random(#candidates)]
end

function Demand.update(dt, npcs, world, config)
    Demand.gameTime = Demand.gameTime + dt
    scheduler.timer = scheduler.timer - dt
    if scheduler.timer > 0 then return end
    scheduler.timer = scheduler.interval

    -- Clean up completed demands
    for i = #Demand.active, 1, -1 do
        if Demand.active[i].state == "completed" then
            table.remove(Demand.active, i)
        end
    end

    -- Update urgencies
    Demand.updateUrgencies(npcs, world)

    -- Count active demands
    local activeCount = 0
    for _, d in ipairs(Demand.active) do
        if d.state == "active" then activeCount = activeCount + 1 end
    end

    local phase = Demand.getGamePhase(Demand.gameTime)
    local maxActive = Demand.getMaxActive(phase)

    -- No-vacuum rule: always have at least 1 active demand
    if activeCount >= maxActive and activeCount > 0 then return end

    -- Minimum interval between demands (skip for no-vacuum)
    if activeCount > 0 and (Demand.gameTime - scheduler.lastDemandTime) < scheduler.minInterval then
        return
    end

    -- TUTORIAL: first 3 demands are scripted
    if Demand.tutorialStep < 3 then
        Demand.tutorialStep = Demand.tutorialStep + 1
        if Demand.tutorialStep == 1 then
            -- First demand: build a small house
            local npc = npcs[1]
            if npc then
                local tmpl = chooseTemplate(npc, 1)
                if tmpl then
                    local mats = Demand.calcMaterials(tmpl)
                    Demand.create("building", npc, {template = tmpl, materials = mats})
                    scheduler.lastDemandTime = Demand.gameTime
                end
            end
        elseif Demand.tutorialStep == 2 then
            -- Second demand: companion
            local npc = npcs[1]
            if npc then
                Demand.create("companion", npc, {})
                scheduler.lastDemandTime = Demand.gameTime
            end
        elseif Demand.tutorialStep == 3 then
            -- Third demand: food for both NPCs
            for _, npc in ipairs(npcs) do
                if not npc.dead then
                    Demand.create("food", npc, {foodNeeded = 3})
                end
            end
            scheduler.lastDemandTime = Demand.gameTime
        end
        return
    end

    -- DYNAMIC DEMANDS: score each type for each NPC, pick highest
    local bestScore = -1
    local bestType = nil
    local bestNpc = nil

    for _, npc in ipairs(npcs) do
        if npc.dead then goto nextNpc end

        -- Food demand
        local hungerR = npc.hunger / config.HUNGER_MAX
        if hungerR < 0.5 then
            local score = applyPersonality(npc, "food", 90 + (0.5 - hungerR) * 100)
            -- Skip if this NPC already has a food demand
            local hasFoodDemand = false
            for _, d in ipairs(Demand.active) do
                if d.npc == npc and d.type == "food" and d.state == "active" then
                    hasFoodDemand = true; break
                end
            end
            if not hasFoodDemand and score > bestScore then
                bestScore = score; bestType = "food"; bestNpc = npc
            end
        end

        -- Building demand (no shelter)
        if not npc:_hasShelter() then
            local score = applyPersonality(npc, "building", 85)
            if world.isNight then score = score + 30 end
            local hasBuildDemand = false
            for _, d in ipairs(Demand.active) do
                if d.npc == npc and d.type == "building" and d.state ~= "completed" then
                    hasBuildDemand = true; break
                end
            end
            if not hasBuildDemand and score > bestScore then
                bestScore = score; bestType = "building"; bestNpc = npc
            end
        end

        -- Companion demand
        local completedBuildings = 0
        for _, d in ipairs(Demand.active) do
            if d.type == "building" and d.state == "completed" then completedBuildings = completedBuildings + 1 end
        end
        local aliveNpcs = 0
        for _, n in ipairs(npcs) do if not n.dead then aliveNpcs = aliveNpcs + 1 end end
        if completedBuildings > aliveNpcs / 2 and aliveNpcs < 10 then
            local score = applyPersonality(npc, "companion", 70)
            local hasCompDemand = false
            for _, d in ipairs(Demand.active) do
                if d.type == "companion" and d.state == "active" then
                    hasCompDemand = true; break
                end
            end
            if not hasCompDemand and score > bestScore then
                bestScore = score; bestType = "companion"; bestNpc = npc
            end
        end

        -- Expansion demand (has shelter, wants bigger)
        if npc:_hasShelter() and hungerR > 0.5 then
            local score = applyPersonality(npc, "expansion", 50 + aliveNpcs * 5)
            local hasExpDemand = false
            for _, d in ipairs(Demand.active) do
                if d.npc == npc and d.type == "expansion" and d.state ~= "completed" then
                    hasExpDemand = true; break
                end
            end
            if not hasExpDemand and score > bestScore then
                bestScore = score; bestType = "expansion"; bestNpc = npc
            end
        end

        ::nextNpc::
    end

    -- Create the winning demand
    if bestType and bestNpc then
        if bestType == "food" then
            Demand.create("food", bestNpc, {foodNeeded = 3})
        elseif bestType == "building" or bestType == "expansion" then
            local tmpl = chooseTemplate(bestNpc, phase)
            if tmpl then
                local mats = Demand.calcMaterials(tmpl)
                Demand.create(bestType, bestNpc, {template = tmpl, materials = mats})
            end
        elseif bestType == "companion" then
            Demand.create("companion", bestNpc, {})
        end
        scheduler.lastDemandTime = Demand.gameTime
    end
end

-- Mark a demand as completed (called when NPC finishes building)
function Demand.markCompleted(demand)
    demand.state = "completed"
    local weight = 1.0
    if demand.type == "food" then weight = 0.5
    elseif demand.type == "companion" then weight = 0.3 end
    Demand.totalFulfilled = Demand.totalFulfilled + weight
end

-- Get all active demands sorted by urgency
function Demand.getActiveSorted()
    local result = {}
    local urgencyRank = {critical = 3, urgent = 2, normal = 1}
    for _, d in ipairs(Demand.active) do
        if d.state == "active" then result[#result + 1] = d end
    end
    table.sort(result, function(a, b)
        return (urgencyRank[a.urgency] or 0) > (urgencyRank[b.urgency] or 0)
    end)
    return result
end

-- Reset for new game
function Demand.reset()
    Demand.active = {}
    Demand.nextId = 1
    Demand.tutorialStep = 0
    Demand.totalFulfilled = 0
    Demand.gameTime = 0
    scheduler.timer = 3.0
    scheduler.lastDemandTime = -10
end

return Demand
```

## Verification

After creating this file, test by adding to your main script:
1. `local Demand = require("demand")` at the top
2. Call `Demand.update(dt, npcs, world, Config)` in your update loop
3. Verify: after game starts, `#Demand.active` should be 1 (first building demand)
4. Verify: `Demand.active[1].materials` should contain a list of material requirements
5. Verify: calling `Demand.onPlayerDrop("cobblestone", 48, 48, 1)` should increment the delivered count
