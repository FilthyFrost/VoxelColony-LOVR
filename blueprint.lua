-- blueprint.lua — Dynamic room construction with formula sizing, scaffold, and demolish-rebuild
-- Supports 3x3 to 11x11 rooms, 1-2 story, with scaffold steps for multi-story

local BP = {}

----------------------------------------------------------------------------
-- BLOCK COUNTING (for demolish-rebuild material calculation)
----------------------------------------------------------------------------
function BP.countWallBlocks(bp)
    local count = 0
    for _, s in ipairs(bp.steps) do
        if s.action == "place" and s.need == "wall" and not s.scaffold then
            count = count + 1
        end
    end
    return count
end

function BP.countRoofBlocks(bp)
    local count = 0
    for _, s in ipairs(bp.steps) do
        if s.action == "place" and s.need == "roof" then count = count + 1 end
    end
    return count
end

----------------------------------------------------------------------------
-- FORMULA-BASED SIZE CHOOSER (picks largest buildable size)
----------------------------------------------------------------------------
function BP.chooseBlueprintSize(resourceCache, config, oldBlueprint)
    local walls = (resourceCache["wall"] or 0) + (resourceCache["wood"] or 0)
    local roofs = resourceCache["roof"] or 0

    -- Add recyclable materials from old building
    if oldBlueprint and oldBlueprint.completed then
        walls = walls + BP.countWallBlocks(oldBlueprint)
        roofs = roofs + BP.countRoofBlocks(oldBlueprint)
    end

    -- Try sizes from largest to smallest, 2-story first (but 2-story needs >= 5x5)
    local sizes = {11, 9, 7, 5, 3}
    for _, sz in ipairs(sizes) do
        local maxStories = sz >= 5 and 2 or 1  -- 3x3 is too small for scaffold
        for _, stories in ipairs(maxStories >= 2 and {2, 1} or {1}) do
            local wallH = config.WALL_H * stories
            local perim = 2 * (sz + sz - 2)
            local wallNeed = perim * wallH
            local roofNeed = sz * sz
            -- Scaffold needs temporary wall blocks (recovered after)
            local scaffoldNeed = 0
            if stories >= 2 then
                scaffoldNeed = (sz - 2) * 2  -- interior scaffold row, 2 layers
            end
            if walls >= wallNeed + scaffoldNeed and roofs >= roofNeed then
                return {size = sz .. "x" .. sz, stories = stories, w = sz, d = sz}
            end
        end
    end
    -- Minimum: 3x3 single story
    return {size = "3x3", stories = 1, w = 3, d = 3}
end

----------------------------------------------------------------------------
-- DYNAMIC ROOM GENERATION with scaffold for multi-story
----------------------------------------------------------------------------
function BP.generateDynamicRoom(homeX, homeZ, config, options)
    local w = options.w or config.ROOM_W
    local d = options.d or config.ROOM_D
    local stories = options.stories or 1
    local baseWallH = config.WALL_H
    local wallH = baseWallH * stories
    local ox = math.floor(homeX) - math.floor(w / 2)
    local oz = math.floor(homeZ) - math.floor(d / 2)
    local steps = {}

    -- Door position: center of south wall — NEVER place walls here
    -- This keeps the doorway open so the NPC can enter/exit during construction
    local doorX = ox + math.floor(w / 2)
    local doorZ = oz
    local doorH = 2  -- door is always 2 blocks high

    -- Helper: is this position the doorway?
    local function isDoor(x, y, z)
        return x == doorX and z == doorZ and y < doorH
    end

    -- Reach from ground: gy=0 can reach y=0,1,2
    local groundReach = 2

    -- Phase 1: Build walls reachable from ground (y=0 to groundReach), skip door
    local groundWallTop = math.min(wallH - 1, groundReach)
    for y = 0, groundWallTop do
        for x = ox, ox + w - 1 do
            if not isDoor(x, y, oz) then
                steps[#steps + 1] = {action = "place", x = x, y = y, z = oz, need = "wall"}
            end
            steps[#steps + 1] = {action = "place", x = x, y = y, z = oz + d - 1, need = "wall"}
        end
        for z = oz + 1, oz + d - 2 do
            steps[#steps + 1] = {action = "place", x = ox, y = y, z = z, need = "wall"}
            steps[#steps + 1] = {action = "place", x = ox + w - 1, y = y, z = z, need = "wall"}
        end
    end

    -- Phase 2: Scaffold + high walls (for multi-story only)
    if stories >= 2 and wallH > groundReach + 1 then
        local scaffZ = oz + math.floor(d / 2)
        local scaffXs = {}
        for x = ox + 1, ox + w - 2 do
            scaffXs[#scaffXs + 1] = x
        end

        -- Layer 1 scaffold (y=0)
        for _, sx in ipairs(scaffXs) do
            steps[#steps + 1] = {action = "place", x = sx, y = 0, z = scaffZ, need = "wall", scaffold = true}
        end

        -- Build y=3 walls (skip door)
        local layer1Top = math.min(wallH - 1, 3)
        if layer1Top > groundWallTop then
            for y = groundWallTop + 1, layer1Top do
                for x = ox, ox + w - 1 do
                    if not isDoor(x, y, oz) then
                        steps[#steps + 1] = {action = "place", x = x, y = y, z = oz, need = "wall"}
                    end
                    steps[#steps + 1] = {action = "place", x = x, y = y, z = oz + d - 1, need = "wall"}
                end
                for z = oz + 1, oz + d - 2 do
                    steps[#steps + 1] = {action = "place", x = ox, y = y, z = z, need = "wall"}
                    steps[#steps + 1] = {action = "place", x = ox + w - 1, y = y, z = z, need = "wall"}
                end
            end
        end

        -- Layer 2 scaffold (y=1)
        for _, sx in ipairs(scaffXs) do
            steps[#steps + 1] = {action = "place", x = sx, y = 1, z = scaffZ, need = "wall", scaffold = true}
        end

        -- Roof
        for x = ox, ox + w - 1 do
            for z = oz, oz + d - 1 do
                steps[#steps + 1] = {action = "place", x = x, y = wallH, z = z, need = "roof"}
            end
        end

        -- Remove scaffold (top to bottom)
        for _, sx in ipairs(scaffXs) do
            steps[#steps + 1] = {action = "break", x = sx, y = 1, z = scaffZ, scaffold = true}
        end
        for _, sx in ipairs(scaffXs) do
            steps[#steps + 1] = {action = "break", x = sx, y = 0, z = scaffZ, scaffold = true}
        end

        -- Inter-floor
        local floorY = baseWallH
        for x = ox + 1, ox + w - 2 do
            for z = oz + 1, oz + d - 2 do
                steps[#steps + 1] = {action = "place", x = x, y = floorY, z = z, need = "roof"}
            end
        end

        -- Ladder opening
        steps[#steps + 1] = {action = "break", x = ox + 1, y = floorY, z = oz + 1}
    else
        -- Single story: roof only, no door break needed (door was never placed)
        for x = ox, ox + w - 1 do
            for z = oz, oz + d - 1 do
                steps[#steps + 1] = {action = "place", x = x, y = wallH, z = z, need = "roof"}
            end
        end
    end

    return {
        originX = ox, originZ = oz, width = w, depth = d,
        homeX = homeX, homeZ = homeZ,
        doorX = doorX, doorZ = doorZ,
        stories = stories, wallH = wallH,
        steps = steps, currentStep = 1, completed = false,
        furnished = false,
        claims = {},  -- cooperative building: [stepIndex] = {npcId, claimTime}
    }
end

-- Legacy wrapper
function BP.generateRoom(homeX, homeZ, config)
    return BP.generateDynamicRoom(homeX, homeZ, config, {
        w = config.ROOM_W, d = config.ROOM_D, stories = 1,
    })
end

----------------------------------------------------------------------------
-- Phase 2: Furnishing steps
----------------------------------------------------------------------------
function BP.addFurnishingSteps(blueprint, world, items)
    if blueprint.furnished then return end
    blueprint.furnished = true

    local ox, oz = blueprint.originX, blueprint.originZ
    local w, d = blueprint.width, blueprint.depth
    local ix1, iz1 = ox + 1, oz + 1
    local ix2, iz2 = ox + w - 2, oz + d - 2

    local added = false

    -- Interior furniture FIRST (placed before door seals the entrance)
    if world:nearestLoose(0, 0, "bed") then
        -- Bed occupies 2 cells in Z: place at iz2-1 so extension lands at iz2 (still inside)
        local bedZ = math.max(iz1, iz2 - 1)
        blueprint.steps[#blueprint.steps + 1] = {
            action = "place_furniture", x = ix2, y = 0, z = bedZ,
            need = "bed", furniture_type = "bed",
        }
        added = true
    end
    if world:nearestLoose(0, 0, "torch") then
        blueprint.steps[#blueprint.steps + 1] = {
            action = "place_furniture", x = ix1, y = 1, z = oz + math.floor(d / 2),
            need = "torch", furniture_type = "torch",
        }
        added = true
    end
    if world:nearestLoose(0, 0, "chest") then
        blueprint.steps[#blueprint.steps + 1] = {
            action = "place_furniture", x = ix2, y = 0, z = iz1,
            need = "chest", furniture_type = "chest",
        }
        added = true
    end
    if (blueprint.stories or 1) >= 2 and world:nearestLoose(0, 0, "ladder") then
        blueprint.steps[#blueprint.steps + 1] = {
            action = "place_furniture", x = ix1, y = 0, z = iz1,
            need = "ladder", furniture_type = "ladder",
        }
        added = true
    end
    -- Door LAST (seals the entrance)
    if world:nearestLoose(0, 0, "door") then
        blueprint.steps[#blueprint.steps + 1] = {
            action = "place_furniture", x = blueprint.doorX, y = 0, z = blueprint.doorZ,
            need = "door", furniture_type = "door",
        }
        added = true
    end

    if added then
        blueprint.completed = false
    end
end

----------------------------------------------------------------------------
-- STEP MANAGEMENT
----------------------------------------------------------------------------
function BP.currentStep(bp)
    if bp.completed then return nil end
    if bp.currentStep > #bp.steps then bp.completed = true; return nil end
    return bp.steps[bp.currentStep]
end

function BP.advance(bp)
    bp.currentStep = bp.currentStep + 1
    if bp.currentStep > #bp.steps then bp.completed = true end
end

function BP.skipIfDone(bp, world)
    local s = BP.currentStep(bp)
    if not s then return false end
    if s.action == "place" or s.action == "place_furniture" then
        local k = world:_key(s.x, s.y, s.z)
        local block = world.occupied[k]
        if block and block.state == "placed" then
            -- Verify correct type
            local items = require("items")
            local typeMatch = false
            if s.action == "place_furniture" or s.exactType then
                typeMatch = (block.itemType == s.need)
            else
                local def = items.get(block.itemType)
                typeMatch = (def and def.building_type == s.need)
            end
            if typeMatch then BP.advance(bp); return true end
        end
        return false
    end
    if s.action == "break" and not world:isOccupied(s.x, s.y, s.z) then
        BP.advance(bp); return true
    end
    return false
end

----------------------------------------------------------------------------
-- DEMOLISH BLUEPRINT: generates break steps for tearing down a building
-- Steps go from roof (top) down to ground — like a human would demolish
----------------------------------------------------------------------------
function BP.generateDemolishSteps(oldBp, world)
    local steps = {}
    local ox, oz = oldBp.originX, oldBp.originZ
    local w, d = oldBp.width, oldBp.depth
    local maxY = (oldBp.wallH or 2) + 1  -- roof is at wallH

    -- Top to bottom: roof first, then walls layer by layer
    for y = maxY, 0, -1 do
        for x = ox, ox + w - 1 do
            for z = oz, oz + d - 1 do
                if world:isOccupied(x, y, z) then
                    steps[#steps + 1] = {action = "break", x = x, y = y, z = z}
                end
            end
        end
    end

    if #steps == 0 then return nil end

    return {
        originX = ox, originZ = oz, width = w, depth = d,
        homeX = oldBp.homeX, homeZ = oldBp.homeZ,
        doorX = oldBp.doorX, doorZ = oldBp.doorZ,
        stories = 1, wallH = oldBp.wallH or 2,
        steps = steps, currentStep = 1, completed = false,
        furnished = true,  -- prevent furnishing
        isDemolish = true,  -- flag for special handling
    }
end

function BP.interiorPoint(bp)
    return bp.originX + math.floor(bp.width / 2), bp.originZ + math.floor(bp.depth / 2)
end

----------------------------------------------------------------------------
-- COOPERATIVE BUILDING: claim system for multiple NPCs sharing a blueprint
----------------------------------------------------------------------------
function BP.claimNextStep(bp, npcId, worldTime, world)
    if not bp.claims then bp.claims = {} end
    local items = require("items")
    for i = 1, #bp.steps do
        local claim = bp.claims[i]

        -- Re-validate "done" claims (block may have been removed/changed)
        if claim and claim.npcId == "done" then
            local s = bp.steps[i]
            local stillDone = false
            if s.action == "place" or s.action == "place_furniture" then
                local k = world:_key(s.x, s.y, s.z)
                local block = world.occupied[k]
                if block and block.state == "placed" then
                    if s.action == "place_furniture" then
                        stillDone = (block.itemType == s.need)
                    else
                        local def = items.get(block.itemType)
                        stillDone = (def and def.building_type == s.need)
                    end
                end
            elseif s.action == "break" then
                stillDone = not world:isOccupied(s.x, s.y, s.z)
            end
            if not stillDone then
                bp.claims[i] = nil  -- invalidate stale "done" claim
                claim = nil
            end
        end

        -- Skip active claims by other NPCs
        if claim and claim.npcId ~= "done" and claim.npcId ~= npcId then
            -- another NPC is working on this, skip
        elseif not claim then
            local s = bp.steps[i]
            local done = false
            if s.action == "place" or s.action == "place_furniture" then
                local k = world:_key(s.x, s.y, s.z)
                local block = world.occupied[k]
                if block and block.state == "placed" then
                    if s.action == "place_furniture" then
                        done = (block.itemType == s.need)
                    else
                        local def = items.get(block.itemType)
                        done = (def and def.building_type == s.need)
                    end
                end
            elseif s.action == "break" then
                if not world:isOccupied(s.x, s.y, s.z) then done = true end
            end
            if done then
                bp.claims[i] = {npcId = "done", claimTime = 0}
            else
                bp.claims[i] = {npcId = npcId, claimTime = worldTime}
                return i, s
            end
        end
    end
    return nil, nil
end

function BP.releaseClaim(bp, stepIndex)
    if bp.claims then bp.claims[stepIndex] = nil end
end

function BP.releaseExpiredClaims(bp, worldTime, timeout)
    if not bp.claims then return end
    for i, claim in pairs(bp.claims) do
        if claim.npcId ~= "done" and worldTime - claim.claimTime > timeout then
            bp.claims[i] = nil
        end
    end
end

function BP.markClaimDone(bp, stepIndex)
    if bp.claims then bp.claims[stepIndex] = {npcId = "done", claimTime = 0} end
end

function BP.allStepsDone(bp, world)
    -- Verify every step against actual world state (don't trust claims alone)
    local items = require("items")
    for i = 1, #bp.steps do
        local s = bp.steps[i]
        if s.action == "place" or s.action == "place_furniture" then
            local k = world:_key(s.x, s.y, s.z)
            local block = world.occupied[k]
            if not block or block.state ~= "placed" then return false end
            if s.action == "place_furniture" then
                if block.itemType ~= s.need then return false end
            else
                local def = items.get(block.itemType)
                if not (def and def.building_type == s.need) then return false end
            end
        elseif s.action == "break" then
            if world:isOccupied(s.x, s.y, s.z) then return false end
        end
    end
    return true
end

----------------------------------------------------------------------------
-- MULTI-NPC ROOM PLACEMENT (dynamic w, d)
----------------------------------------------------------------------------
function BP.findAdjacentSlot(allNpcs, config, w, d)
    w = w or config.ROOM_W
    d = d or config.ROOM_D
    local sides = {"east", "west", "north", "south"}
    for _, npc in ipairs(allNpcs) do
        if npc.blueprint and npc.blueprint.completed and npc.shelterVerified then
            for _, side in ipairs(sides) do
                local ebp = npc.blueprint
                local ox, oz
                if side == "east" then      ox = ebp.originX + ebp.width - 1; oz = ebp.originZ
                elseif side == "west" then  ox = ebp.originX - w + 1;         oz = ebp.originZ
                elseif side == "north" then ox = ebp.originX;                 oz = ebp.originZ + ebp.depth - 1
                else                        ox = ebp.originX;                 oz = ebp.originZ - d + 1
                end
                if ox >= 1 and ox + w < config.GRID - 1 and oz >= 1 and oz + d < config.GRID - 1 then
                    local hx, hz = ox + math.floor(w / 2), oz + math.floor(d / 2)
                    local overlap = false
                    for _, o in ipairs(allNpcs) do
                        if o.blueprint and o ~= npc then
                            local ob = o.blueprint
                            if ox < ob.originX + ob.width and ox + w > ob.originX
                                and oz < ob.originZ + ob.depth and oz + d > ob.originZ then
                                overlap = true; break
                            end
                        end
                    end
                    if not overlap then
                        local bp = BP.generateDynamicRoom(hx, hz, config, {w = w, d = d, stories = 1})
                        return bp, hx, hz
                    end
                end
            end
        end
    end
    return nil
end

return BP
