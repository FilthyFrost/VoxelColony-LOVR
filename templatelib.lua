-- templatelib.lua — Building template library
-- Loads Minecraft-inspired building templates and converts to blueprints
-- NPC selects template based on personality + available materials

local TL = {}

-- All available templates (loaded on init)
TL.all = {}

function TL.init()
    local names = {
        -- Original templates
        "armorer_house",
        "small_15x13_survival_house", "cozy_cabin", "start_house", "small_cozy_house",
        -- Plains Village buildings (from Minecraft Wiki)
        "big_house_1",
        "butcher_shop_1", "butcher_shop_2",
        "cartographer_1",
        "fisher_cottage_1",
        "fletcher_house_1",
        "fountain_1",
        "lamp_1",
        "large_farm_1",
        "library_1", "library_2",
        "masons_house_1",
        "medium_house_1", "medium_house_2",
        "meeting_point_1", "meeting_point_2", "meeting_point_3",
        "meeting_point_4", "meeting_point_5",
        "shepherds_house",
        "small_farm_1",
        "small_house_1", "small_house_2", "small_house_3",
        "small_house_4", "small_house_5", "small_house_6",
        "small_house_7", "small_house_8",
        "stable_1",
        "tannery_1",
        "temple_1", "temple_2",
        "tool_smith_house_1",
        "weaponsmith_1",
    }
    TL.all = {}
    for _, name in ipairs(names) do
        local ok, tmpl = pcall(require, "templates." .. name)
        if ok and tmpl and tmpl.blocks then
            TL.all[#TL.all + 1] = tmpl
        end
    end
end

-- Choose best template for this NPC given available materials
function TL.chooseBest(npc, resourceCache)
    if #TL.all == 0 then return nil end

    -- Count total available building materials
    local totalMats = (resourceCache["wall"] or 0) + (resourceCache["wood"] or 0)
        + (resourceCache["roof"] or 0) + (resourceCache["glass"] or 0)

    local best, bestScore = nil, -1

    for _, tmpl in ipairs(TL.all) do
        -- Can we afford this template?
        local needed = #tmpl.blocks
        if totalMats < needed then goto skip end

        -- Personality matching
        local score = 0
        for _, tag in ipairs(tmpl.tags) do
            if tag == "cozy" and npc.traits.shy then score = score + 20 end
            if tag == "ambitious" and npc.traits.diligent then score = score + 25 end
            if tag == "sturdy" and npc.traits.diligent then score = score + 15 end
            if tag == "medieval" then score = score + 10 end
            if tag == "social" and npc.traits.social then score = score + 20 end
            if tag == "spacious" and npc.traits.social then score = score + 15 end
            if tag == "defensive" and npc.traits.shy then score = score + 15 end
            if tag == "starter" then score = score + 3 end  -- slight bonus for simple builds
            if tag == "large" and npc.traits.explorer then score = score + 10 end
        end

        -- Prefer buildings that use most of available materials (build big if you can)
        score = score + math.min(needed, 60)

        -- Small random variance for variety
        score = score + math.random() * 5

        if score > bestScore then bestScore = score; best = tmpl end
        ::skip::
    end

    return best
end

-- Convert template to blueprint (compatible with existing build system)
function TL.toBlueprint(tmpl, homeX, homeZ, npc)
    -- Determine material mapping from NPC's personality
    local slotMap = TL.getSlotMap(npc)

    -- Center template on home position
    local originX = math.floor(homeX) - math.floor(tmpl.w / 2)
    local originZ = math.floor(homeZ) - math.floor(tmpl.d / 2)

    -- Door position in world coords
    local doorX = originX + (tmpl.doorPos and tmpl.doorPos.x or math.floor(tmpl.w / 2))
    local doorZ = originZ + (tmpl.doorPos and tmpl.doorPos.z or 0)

    -- Sort blocks by Y (build from ground up), then Z, then original index
    -- CRITICAL: Lua's table.sort is unstable. Without the original index tiebreaker,
    -- entries at the same (y,z) get scrambled, breaking the "last entry wins" dedup.
    local sorted = {}
    for i, b in ipairs(tmpl.blocks) do
        b._origIdx = i
        sorted[#sorted + 1] = b
    end
    table.sort(sorted, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        if a.z ~= b.z then return a.z < b.z end
        return a._origIdx < b._origIdx  -- preserve original order for same (y,z)
    end)

    -- Generate steps (deduplicate: same position → last entry wins)
    local stepsByPos = {}  -- "x,y,z" → step data
    local stepOrder = {}   -- ordered list of position keys
    for _, b in ipairs(sorted) do
        local wx = originX + b.x
        local wz = originZ + b.z
        local wy = b.y

        -- Skip door opening (y < 2 at door position)
        if wx == doorX and wz == doorZ and wy < 2 then
            goto nextBlock
        end

        local blockType, isExact
        if b.t then
            blockType = b.t
            isExact = true
        else
            blockType = slotMap[b.slot] or slotMap.primary or "wall"
        end

        local posKey = wx .. "," .. wy .. "," .. wz
        if not stepsByPos[posKey] then
            stepOrder[#stepOrder + 1] = posKey
        end
        -- Last entry at this position wins (overrides earlier)
        stepsByPos[posKey] = {
            action = "place",
            x = wx, y = wy, z = wz,
            need = blockType,
            exactType = isExact,
            facing = b.f,
            half = b.h,
            shape = b.s,
            open = b.o,
        }

        ::nextBlock::
    end

    local steps = {}
    for _, posKey in ipairs(stepOrder) do
        steps[#steps + 1] = stepsByPos[posKey]
    end

    -- Assign dependency layers: layer N requires all steps in layer N-1 complete
    -- Each Y level = one layer. Simple and correct.
    for _, s in ipairs(steps) do
        s.layer = s.y
    end

    -- No scaffold needed — NPCs use ground-based placement (like RimWorld).
    -- NPC walks near the building and places blocks remotely at any height.
    local scaffoldCount = 0

    return {
        originX = originX,
        originZ = originZ,
        width = tmpl.w,
        depth = tmpl.d,
        homeX = homeX,
        homeZ = homeZ,
        doorX = doorX,
        doorZ = doorZ,
        wallH = tmpl.h,
        stories = 1,
        steps = steps,
        currentStep = 1,
        completed = false,
        furnished = false,
        templateName = tmpl.name,
        scaffoldCount = scaffoldCount,  -- for material drop calculation
        scaffoldPositions = scaffoldPositions,  -- for diagnostic
    }
end

-- Get material slot mapping based on NPC personality
function TL.getSlotMap(npc)
    -- Each NPC has a unique build style based on traits
    if npc.buildStyle then return npc.buildStyle end

    local primary, secondary
    if npc.traits.diligent then
        primary = "wall"; secondary = "wood"    -- stone + wood = sturdy medieval
    elseif npc.traits.explorer then
        primary = "wood"; secondary = "glass"   -- wood + glass = rustic cabin
    elseif npc.traits.social then
        primary = "wall"; secondary = "glass"   -- stone + glass = open & bright
    elseif npc.traits.shy then
        primary = "wall"; secondary = "wall"    -- all stone = fortress
    else
        -- Random for default
        local choices = {"wall", "wood"}
        primary = choices[math.random(#choices)]
        secondary = math.random() > 0.5 and "glass" or (primary == "wall" and "wood" or "wall")
    end

    npc.buildStyle = {primary = primary, secondary = secondary}
    return npc.buildStyle
end

return TL
