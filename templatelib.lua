-- templatelib.lua — Building template library
-- Loads Minecraft-inspired building templates and converts to blueprints
-- NPC selects template based on personality + available materials

local TL = {}

-- All available templates (loaded on init)
TL.all = {}

function TL.init()
    local names = {
        "small_15x13_survival_house", "cozy_cabin", "start_house", "small_cozy_house",
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

    -- Sort blocks by Y (build from ground up), then by distance from door (build outward)
    local sorted = {}
    for _, b in ipairs(tmpl.blocks) do sorted[#sorted + 1] = b end
    table.sort(sorted, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.z < b.z  -- front to back within same layer
    end)

    -- Generate steps
    local steps = {}
    for _, b in ipairs(sorted) do
        local wx = originX + b.x
        local wz = originZ + b.z
        local wy = b.y

        -- Skip door opening (y < 2 at door position)
        if wx == doorX and wz == doorZ and wy < 2 then
            goto nextBlock
        end

        local blockType
        if b.t then
            blockType = b.t
        else
            blockType = slotMap[b.slot] or slotMap.primary or "wall"
        end
        steps[#steps + 1] = {
            action = "place",
            x = wx, y = wy, z = wz,
            need = blockType,
            -- Preserve Minecraft block metadata for rendering
            facing = b.f,
            half = b.h,
            shape = b.s,
            open = b.o,
        }

        ::nextBlock::
    end

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
