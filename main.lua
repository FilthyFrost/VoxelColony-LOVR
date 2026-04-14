-- main.lua — Voxel Colony for LOVR 0.18
-- Free-fly + Follow + Ant-Eye camera modes
-- NPC personality colors, bounce animation, head rotation, enhanced HUD

local Config = require("config")
local Items = require("items")
local World = require("world")
local NPC = require("npc")
local Textures = require("textures")

local mouse = require("mouse")
local TemplateLib = require("templatelib")

local world, npcs, fallingItems, tex, hudFont
local selectedIdx = 1
local templateIdx = 1
local uiMode = "block"  -- "block", "template", or "preview"
local buildQueue = {}    -- global build queue: {template, blueprint, materialPos}
local previewBuildings = {}  -- preview mode placed buildings (for X to delete)
local gameTime = 0

-- Debug logging: use shared module so NPC/world logs get correct timestamps
local log = require("debuglog")

----------------------------------------------------------------------------
-- CAMERA: Free-fly + Follow + Ant-Eye modes
----------------------------------------------------------------------------
local cam = {
    x = 12, y = 15, z = -5,
    yaw = 0, pitch = -0.6,
    speed = 12,
    sensitivity = 0.003,
    -- Follow mode
    followNPC = nil,
    followIdx = 0,      -- 0 = free-fly
    firstPerson = false, -- ant-eye view
}

function cam:update(dt)
    if self.followNPC then
        local npc = self.followNPC
        if npc.dead then
            self.followNPC = nil
            self.followIdx = 0
            self.firstPerson = false
            return
        end

        if self.firstPerson then
            -- Ant-eye: camera at NPC head height
            local lerpSpd = 5 * dt
            self.x = self.x + (npc.x - self.x) * lerpSpd
            self.y = self.y + (npc.y + 1.3 - self.y) * lerpSpd
            self.z = self.z + (npc.z - self.z) * lerpSpd
            -- Auto look direction from path
            if npc.path and npc.pathIdx and npc.pathIdx <= #npc.path then
                local wp = npc.path[npc.pathIdx]
                local dx = wp.x - npc.gx
                local dz = wp.z - npc.gz
                if dx ~= 0 or dz ~= 0 then
                    local targetYaw = math.atan2(dx, dz)
                    self.yaw = self.yaw + (targetYaw - self.yaw) * 3 * dt
                end
            end
            self.pitch = -0.1
        else
            -- Third-person follow
            local targetX = npc.x
            local targetY = npc.y + 4
            local targetZ = npc.z - 5
            local lerpSpd = 3 * dt
            self.x = self.x + (targetX - self.x) * lerpSpd
            self.y = self.y + (targetY - self.y) * lerpSpd
            self.z = self.z + (targetZ - self.z) * lerpSpd
            -- Look at NPC
            local dx = npc.x - self.x
            local dy = (npc.y + 1) - self.y
            local dz = npc.z - self.z
            local dist = math.sqrt(dx * dx + dz * dz)
            self.yaw = math.atan2(dx, dz)
            if dist > 0.01 then self.pitch = math.atan2(dy, dist) end
        end
    else
        -- Free-fly (original)
        local fwdX = math.sin(self.yaw)
        local fwdZ = math.cos(self.yaw)
        local rightX = -fwdZ
        local rightZ = fwdX
        local moveX, moveY, moveZ = 0, 0, 0
        if lovr.system.isKeyDown("w") then moveX = moveX + fwdX; moveZ = moveZ + fwdZ end
        if lovr.system.isKeyDown("s") then moveX = moveX - fwdX; moveZ = moveZ - fwdZ end
        if lovr.system.isKeyDown("a") then moveX = moveX - rightX; moveZ = moveZ - rightZ end
        if lovr.system.isKeyDown("d") then moveX = moveX + rightX; moveZ = moveZ + rightZ end
        if lovr.system.isKeyDown("space") then moveY = moveY + 1 end
        if lovr.system.isKeyDown("lshift") or lovr.system.isKeyDown("rshift") then moveY = moveY - 1 end
        local len = math.sqrt(moveX * moveX + moveZ * moveZ)
        if len > 0 then moveX = moveX / len; moveZ = moveZ / len end
        self.x = self.x + moveX * self.speed * dt
        self.y = math.max(1, self.y + moveY * self.speed * dt)
        self.z = self.z + moveZ * self.speed * dt
    end
end

function cam:apply(pass)
    local dirX = math.sin(self.yaw) * math.cos(self.pitch)
    local dirY = math.sin(self.pitch)
    local dirZ = math.cos(self.yaw) * math.cos(self.pitch)
    local eye = lovr.math.vec3(self.x, self.y, self.z)
    local target = lovr.math.vec3(self.x + dirX, self.y + dirY, self.z + dirZ)
    local up = lovr.math.vec3(0, 1, 0)
    pass:setViewPose(1, lovr.math.newMat4():lookAt(eye, target, up), true)
    local w, h = lovr.system.getWindowDimensions()
    local vfov = math.rad(60)
    local aspect = w / h
    local hfov = 2 * math.atan(math.tan(vfov / 2) * aspect)
    pass:setProjection(1, hfov / 2, hfov / 2, vfov / 2, vfov / 2, 0.1, 0)
end

function cam:getLookTarget()
    local dirX = math.sin(self.yaw) * math.cos(self.pitch)
    local dirY = math.sin(self.pitch)
    local dirZ = math.cos(self.yaw) * math.cos(self.pitch)
    if dirY >= 0 then return nil, nil end
    local t = -self.y / dirY
    local hitX = self.x + dirX * t
    local hitZ = self.z + dirZ * t
    local gx = math.floor(hitX + 0.5)
    local gz = math.floor(hitZ + 0.5)
    if gx >= 0 and gx < Config.GRID and gz >= 0 and gz < Config.GRID then
        return gx, gz
    end
    return nil, nil
end

----------------------------------------------------------------------------
-- INIT
----------------------------------------------------------------------------
function lovr.load()
    math.randomseed(os.time())
    world = World.new(Config, Items)
    npcs = {}
    fallingItems = {}
    tex = Textures.loadAll()

    log.init()
    TemplateLib.init()
    NPC.buildQueue = buildQueue

    -- GPU Instancing: create cube mesh + shader for batched rendering
    local cubeVerts = {
        {-0.5,-0.5,-0.5, 0,0,-1, 0,1}, { 0.5,-0.5,-0.5, 0,0,-1, 1,1}, { 0.5,0.5,-0.5, 0,0,-1, 1,0}, {-0.5,0.5,-0.5, 0,0,-1, 0,0},
        { 0.5,-0.5, 0.5, 0,0, 1, 0,1}, {-0.5,-0.5, 0.5, 0,0, 1, 1,1}, {-0.5,0.5, 0.5, 0,0, 1, 1,0}, { 0.5,0.5, 0.5, 0,0, 1, 0,0},
        {-0.5, 0.5,-0.5, 0,1, 0, 0,1}, { 0.5, 0.5,-0.5, 0,1, 0, 1,1}, { 0.5,0.5, 0.5, 0,1, 0, 1,0}, {-0.5,0.5, 0.5, 0,1, 0, 0,0},
        {-0.5,-0.5, 0.5, 0,-1,0, 0,1}, { 0.5,-0.5, 0.5, 0,-1,0, 1,1}, { 0.5,-0.5,-0.5, 0,-1,0, 1,0}, {-0.5,-0.5,-0.5, 0,-1,0, 0,0},
        { 0.5,-0.5,-0.5, 1,0, 0, 0,1}, { 0.5,-0.5, 0.5, 1,0, 0, 1,1}, { 0.5,0.5, 0.5, 1,0, 0, 1,0}, { 0.5,0.5,-0.5, 1,0, 0, 0,0},
        {-0.5,-0.5, 0.5,-1,0, 0, 0,1}, {-0.5,-0.5,-0.5,-1,0, 0, 1,1}, {-0.5,0.5,-0.5,-1,0, 0, 1,0}, {-0.5,0.5, 0.5,-1,0, 0, 0,0},
    }
    cubeMesh = lovr.graphics.newMesh(cubeVerts)
    cubeMesh:setIndices({
        1,2,3, 3,4,1,  5,6,7, 7,8,5,  9,10,11, 11,12,9,
        13,14,15, 15,16,13,  17,18,19, 19,20,17,  21,22,23, 23,24,21,
    })

    instanceShader = lovr.graphics.newShader([[
        buffer InstanceData { vec4 positions[]; };
        vec4 lovrmain() {
            vec4 p = positions[InstanceIndex];
            mat4 m = mat4(
                p.w, 0, 0, 0,
                0, p.w, 0, 0,
                0, 0, p.w, 0,
                p.x, p.y, p.z, 1
            );
            return Projection * View * m * VertexPosition;
        }
    ]], [[
        vec4 lovrmain() {
            return DefaultColor * Color * getPixel(ColorTexture, UV);
        }
    ]])

    instanceGroups = {}  -- rebuilt when world.renderDirty

    log.write("main", "Game loaded. GRID=%d templates:%d", Config.GRID, #TemplateLib.all)

    -- Camera: overview of map center
    local cx = math.floor(Config.GRID / 2)
    local cz = math.floor(Config.GRID / 2)
    cam.x = cx
    cam.y = 25
    cam.z = cz - 20
    cam.yaw = 0
    cam.pitch = -0.5
    npcs[#npcs + 1] = NPC.new(Config, world, Items, cx, cz, npcs)

    -- No auto-drop: player selects template and clicks to drop materials

    lovr.graphics.setBackgroundColor(0.45, 0.65, 0.92)
    mouse.setRelativeMode(true)
end

-- Re-lock mouse when window regains focus (fixes alt-tab issue)
function lovr.focus(focused)
    if focused then
        mouse.setRelativeMode(true)
    end
end

function lovr.update(dt)
    local ok, err = pcall(function()
    gameTime = gameTime + dt
    log.setTime(gameTime)
    log.perfFrame(dt)
    world:update(dt)

    -- Falling items
    for i = #fallingItems, 1, -1 do
        local fi = fallingItems[i]
        fi.y = fi.y - Config.FALL_SPEED * dt
        local landY = fi.targetY or 0
        if fi.y <= landY + 0.5 then
            world:addBlock(fi.gx, landY, fi.gz, fi.itemType, "loose")
            table.remove(fallingItems, i)
        end
    end

    for _, npc in ipairs(npcs) do npc:update(dt) end
    cam:update(dt)

    -- Periodic state summary (every 2s)
    log._tickTimer = (log._tickTimer or 0) - dt
    if log._tickTimer <= 0 then
        log._tickTimer = 2
        log.summary(npcs, #world.blocks, fallingItems, #world.markers)
    end
    end) -- pcall
    if not ok then
        log.write("main", "UPDATE ERROR: %s", tostring(err))
    end
end

----------------------------------------------------------------------------
-- DRAW
----------------------------------------------------------------------------
function lovr.draw(pass)
    cam:apply(pass)
    local dl = world:daylight()

    -- Ground
    pass:setColor(dl, dl, dl)
    pass:setMaterial(tex.grass)
    local g = Config.GRID
    pass:box(g / 2, -0.05, g / 2, g, 0.1, g)
    pass:setMaterial()

    -- Grid lines (every 4 cells for large worlds)
    local gridStep = g > 32 and 4 or 1
    pass:setColor(0.2 * dl, 0.35 * dl, 0.15 * dl, 0.15)
    for i = 0, g, gridStep do
        pass:line(i, 0.02, 0, i, 0.02, g)
        pass:line(0, 0.02, i, g, 0.02, i)
    end
    -- Crosshair highlight
    local lookX, lookZ = cam:getLookTarget()
    if lookX then
        pass:setColor(1, 1, 1, 0.3)
        pass:box(lookX, 0.03, lookZ, 1, 0.02, 1)
    end

    -- Facing direction to rotation angle (radians around Y axis)
    local FACING_ANGLE = {north=0, south=math.pi, east=math.pi*0.5, west=math.pi*1.5}

    -- GPU INSTANCED RENDERING: rebuild buffers when blocks change
    if world.renderDirty then
        world.renderDirty = false
        instanceDirty = false
        local SPECIAL_TYPES = {
            door=true, bed=true, torch=true, chest=true,
            spruce_stairs=true, oak_stairs=true, dark_oak_stairs=true,
            cobblestone_stairs=true, stone_stairs=true, stone_brick_stairs=true,
            oak_slab=true, spruce_slab=true, dark_oak_slab=true,
            smooth_stone_slab=true, cobblestone_slab=true, stone_slab=true,
            trapdoor=true, spruce_trapdoor=true, oak_trapdoor=true,
            fence=true, oak_fence=true, dark_oak_fence=true, oak_fence_gate=true,
            barrel=true, composter=true, lectern=true, bell=true, campfire=true,
            cauldron=true, anvil=true, grindstone=true,
            glass_pane=true, ladder=true, cobblestone_wall=true, leaves=true,
        }
        local groups = {}
        instanceSpecialBlocks = {}
        for _, b in ipairs(world.blocks) do
            if b.state ~= "carried" then
                if SPECIAL_TYPES[b.itemType] then
                    instanceSpecialBlocks[#instanceSpecialBlocks + 1] = b
                else
                    local typ = b.itemType
                    if not groups[typ] then groups[typ] = {} end
                    groups[typ][#groups[typ] + 1] = {b.gx, b.gy + 0.5, b.gz, 0.98}
                end
            end
        end
        instanceGroups = {}
        for typ, positions in pairs(groups) do
            instanceGroups[typ] = {
                buffer = lovr.graphics.newBuffer('vec4', positions),
                count = #positions,
            }
        end
    end

    -- Draw full cubes: ONE draw call per block type (GPU instancing)
    pass:setColor(dl, dl, dl)
    pass:setShader(instanceShader)
    for typ, group in pairs(instanceGroups) do
        local t = tex[typ] or tex.wood
        pass:setMaterial(t)
        pass:send('InstanceData', group.buffer)
        pass:draw(cubeMesh, mat4(), group.count)
    end
    pass:setShader()
    pass:setMaterial()

    -- Draw special shapes individually (minority of blocks)
    for _, b in ipairs(instanceSpecialBlocks or {}) do
        pass:setColor(dl, dl, dl)
        local t = tex[b.itemType] or tex.wood
        pass:setMaterial(t)
        local bx, by, bz = b.gx, b.gy, b.gz
        local typ = b.itemType
        local facing = b.facing
        local half = b.half
        local shape = b.shape

        if typ == "door" then
                pass:box(bx, by + 1, bz, 0.95, 1.95, 0.15)

            elseif typ == "bed" then
                pass:box(bx, by + 0.3, bz, 0.95, 0.55, 1.8)

            elseif typ == "torch" then
                pass:box(bx, by + 0.3, bz, 0.15, 0.6, 0.15)

            elseif typ == "chest" then
                pass:box(bx, by + 0.4, bz, 0.85, 0.75, 0.85)

            -- STAIRS: L-shaped block (bottom slab + back wall), rotated by facing
            elseif typ == "spruce_stairs" or typ == "oak_stairs" or typ == "dark_oak_stairs"
                   or typ == "cobblestone_stairs" or typ == "stone_stairs" or typ == "stone_brick_stairs" then
                local angle = FACING_ANGLE[facing or "north"] or 0
                local topHalf = (half == "top")
                pass:push()
                pass:translate(bx, by + 0.5, bz)
                pass:rotate(angle, 0, 1, 0)
                if topHalf then
                    -- Top half stairs: inverted
                    pass:box(0, 0.25, 0, 0.98, 0.48, 0.98)      -- full top slab
                    pass:box(0, -0.25, 0.25, 0.98, 0.48, 0.48)  -- front bottom step
                else
                    -- Bottom half stairs: normal
                    pass:box(0, -0.25, 0, 0.98, 0.48, 0.98)     -- full bottom slab
                    pass:box(0, 0.25, 0.25, 0.98, 0.48, 0.48)   -- back top step
                end
                pass:pop()

            -- SLABS: half-height block
            elseif typ == "oak_slab" or typ == "spruce_slab" or typ == "dark_oak_slab"
                   or typ == "smooth_stone_slab" or typ == "cobblestone_slab"
                   or typ == "stone_slab" then
                if half == "top" then
                    pass:box(bx, by + 0.75, bz, 0.98, 0.48, 0.98)
                elseif half == "double" then
                    pass:box(bx, by + 0.5, bz, 0.98, 0.98, 0.98)  -- full block
                else -- bottom (default)
                    pass:box(bx, by + 0.25, bz, 0.98, 0.48, 0.98)
                end

            -- TRAPDOORS: thin flat panel
            elseif typ == "trapdoor" or typ == "spruce_trapdoor" or typ == "oak_trapdoor" then
                local angle = FACING_ANGLE[facing or "north"] or 0
                if b.open then
                    -- Open: vertical panel on wall side
                    pass:push()
                    pass:translate(bx, by + 0.5, bz)
                    pass:rotate(angle, 0, 1, 0)
                    pass:box(0, 0, -0.45, 0.95, 0.95, 0.08)
                    pass:pop()
                else
                    -- Closed: horizontal panel
                    if half == "top" then
                        pass:box(bx, by + 0.95, bz, 0.95, 0.08, 0.95)
                    else
                        pass:box(bx, by + 0.05, bz, 0.95, 0.08, 0.95)
                    end
                end

            -- FENCES: thin post + crossbars
            elseif typ == "fence" or typ == "oak_fence" or typ == "dark_oak_fence" then
                pass:box(bx, by + 0.5, bz, 0.2, 0.98, 0.2)     -- center post
                pass:box(bx, by + 0.65, bz, 0.7, 0.08, 0.08)   -- top rail X
                pass:box(bx, by + 0.35, bz, 0.08, 0.08, 0.7)   -- bottom rail Z

            -- FENCE GATE: wider thin gate
            elseif typ == "oak_fence_gate" then
                local angle = FACING_ANGLE[facing or "north"] or 0
                pass:push()
                pass:translate(bx, by + 0.5, bz)
                pass:rotate(angle, 0, 1, 0)
                pass:box(0, 0.1, -0.4, 0.15, 0.78, 0.15)  -- left post
                pass:box(0, 0.1, 0.4, 0.15, 0.78, 0.15)   -- right post
                pass:box(0, 0.2, 0, 0.08, 0.08, 0.65)      -- bottom rail
                pass:box(0, 0.45, 0, 0.08, 0.08, 0.65)     -- top rail
                pass:pop()

            -- BARREL: slightly rounded chest
            elseif typ == "barrel" then
                pass:box(bx, by + 0.5, bz, 0.8, 0.95, 0.8)

            -- COMPOSTER: open-top box
            elseif typ == "composter" then
                pass:box(bx, by + 0.25, bz, 0.85, 0.48, 0.85)  -- bottom
                pass:box(bx, by + 0.5, bz - 0.38, 0.85, 0.98, 0.08)  -- wall
                pass:box(bx, by + 0.5, bz + 0.38, 0.85, 0.98, 0.08)
                pass:box(bx - 0.38, by + 0.5, bz, 0.08, 0.98, 0.85)
                pass:box(bx + 0.38, by + 0.5, bz, 0.08, 0.98, 0.85)

            -- LECTERN: angled bookstand
            elseif typ == "lectern" then
                local angle = FACING_ANGLE[facing or "north"] or 0
                pass:push()
                pass:translate(bx, by + 0.5, bz)
                pass:rotate(angle, 0, 1, 0)
                pass:box(0, -0.25, 0, 0.6, 0.48, 0.6)   -- base
                pass:box(0, 0.05, 0, 0.3, 0.12, 0.3)     -- post
                pass:box(0, 0.25, 0, 0.7, 0.12, 0.5)     -- top
                pass:pop()

            -- BELL: golden bell on frame
            elseif typ == "bell" then
                pass:box(bx, by + 0.7, bz, 0.9, 0.12, 0.2)   -- top bar
                pass:box(bx, by + 0.4, bz, 0.4, 0.5, 0.4)    -- bell body

            -- CAMPFIRE: flat fire on logs
            elseif typ == "campfire" then
                pass:box(bx, by + 0.15, bz, 0.9, 0.25, 0.2)  -- log 1
                pass:box(bx, by + 0.15, bz, 0.2, 0.25, 0.9)  -- log 2 (cross)

            -- CAULDRON: open-top bucket
            elseif typ == "cauldron" then
                pass:box(bx, by + 0.35, bz, 0.75, 0.68, 0.75)

            -- ANVIL: heavy metal block
            elseif typ == "anvil" then
                local angle = FACING_ANGLE[facing or "north"] or 0
                pass:push()
                pass:translate(bx, by + 0.5, bz)
                pass:rotate(angle, 0, 1, 0)
                pass:box(0, -0.3, 0, 0.7, 0.18, 0.5)   -- base
                pass:box(0, -0.05, 0, 0.3, 0.3, 0.3)    -- middle
                pass:box(0, 0.2, 0, 0.8, 0.2, 0.45)     -- top
                pass:pop()

            -- GRINDSTONE: hanging wheel
            elseif typ == "grindstone" then
                pass:box(bx, by + 0.5, bz, 0.6, 0.6, 0.6)

            -- GLASS PANES: thin vertical panel
            elseif typ == "glass_pane" then
                pass:box(bx, by + 0.5, bz, 0.08, 0.98, 0.98)

            -- LADDERS: thin panel on wall
            elseif typ == "ladder" then
                local angle = FACING_ANGLE[facing or "north"] or 0
                pass:push()
                pass:translate(bx, by + 0.5, bz)
                pass:rotate(angle, 0, 1, 0)
                pass:box(0, 0, -0.45, 0.95, 0.95, 0.08)
                pass:pop()

            -- COBBLESTONE WALL: thin column
            elseif typ == "cobblestone_wall" then
                pass:box(bx, by + 0.5, bz, 0.35, 0.98, 0.35)

            -- LEAVES: slightly smaller with transparency
            elseif typ == "leaves" then
                pass:setColor(dl, dl, dl, 0.85)
                pass:box(bx, by + 0.5, bz, 0.95, 0.95, 0.95)

            end  -- special block type switch
            pass:setMaterial()

    end  -- special blocks loop

    -- Floating labels for loose blocks (separate pass, all block types)
    for _, b in ipairs(world.blocks) do
        if b.state == "loose" then
            local toCamX = cam.x - b.gx
            local toCamZ = cam.z - b.gz
            local dist2 = toCamX * toCamX + toCamZ * toCamZ
            if dist2 < 64 then
                local angle = math.atan2(toCamX, toCamZ)
                pass:push()
                pass:translate(b.gx, b.gy + 1.1, b.gz)
                pass:rotate(angle, 0, 1, 0)
                pass:setColor(1, 1, 1, 0.7)
                pass:text(b.itemType, 0, 0, 0, 0.08)
                pass:pop()
            end
        end
    end

    -- Falling items
    for _, fi in ipairs(fallingItems) do
        pass:setColor(1, 1, 1, 0.85)
        local t = tex[fi.itemType] or tex.wood
        pass:setMaterial(t)
        pass:box(fi.gx, fi.y, fi.gz, 0.9, 0.9, 0.9)
        pass:setMaterial()
    end

    -- Communication markers (ground circles, only near camera)
    for _, m in ipairs(world.markers) do
        local dx = cam.x - m.x
        local dz = cam.z - m.z
        if dx * dx + dz * dz < 400 then  -- within 20 blocks
            local alpha = m.strength / 100 * 0.25
            if m.type == "food_here" then pass:setColor(0.2, 0.8, 0.2, alpha)
            elseif m.type == "help_needed" then pass:setColor(0.9, 0.7, 0.1, alpha)
            elseif m.type == "home_here" then pass:setColor(0.3, 0.5, 0.9, alpha) end
            pass:circle(m.x, 0.04, m.z, 1.5, math.pi / 2, 1, 0, 0)
        end
    end

    -- NPCs
    for _, npc in ipairs(npcs) do
        drawNPC(pass, npc, dl)
    end

    drawHUD(pass)
end

----------------------------------------------------------------------------
-- NPC RENDERER (with personality colors, bounce, head rotation)
----------------------------------------------------------------------------
local MOOD_COLORS = {
    happy     = {0.2, 0.9, 0.3},
    content   = {0.5, 0.8, 0.5},
    neutral   = {0.6, 0.6, 0.6},
    sad       = {0.3, 0.4, 0.8},
    miserable = {0.2, 0.2, 0.5},
    excited   = {1.0, 0.8, 0.1},
}

function drawNPC(pass, npc, dl)
    local x, z = npc.x, npc.z
    local baseY = npc.y

    -- Sleeping: NPC lies down (Minecraft-style)
    if npc.sleeping then
        local skinR, skinG, skinB = 0.85 * dl, 0.70 * dl, 0.55 * dl
        local shirtR, shirtG, shirtB
        local pantsR, pantsG, pantsB
        if npc.shirtColor then
            shirtR = npc.shirtColor[1] * dl
            shirtG = npc.shirtColor[2] * dl
            shirtB = npc.shirtColor[3] * dl
        else
            shirtR, shirtG, shirtB = 0.2 * dl, 0.5 * dl, 0.8 * dl
        end
        if npc.pantsColor then
            pantsR = npc.pantsColor[1] * dl
            pantsG = npc.pantsColor[2] * dl
            pantsB = npc.pantsColor[3] * dl
        else
            pantsR, pantsG, pantsB = 0.25 * dl, 0.25 * dl, 0.35 * dl
        end

        -- Height: on bed = raised, on floor = ground level
        local sleepY = baseY
        if npc.sleepQuality == 2 then sleepY = sleepY + 0.35 end

        -- Rotated body (lying on side along X axis)
        pass:push()
        pass:translate(x, sleepY + 0.2, z)
        pass:rotate(math.pi / 2, 0, 0, 1)  -- rotate 90° around Z = lie down

        -- Legs (bottom)
        pass:setColor(pantsR, pantsG, pantsB)
        pass:box(0, -0.35, 0, 0.12, 0.4, 0.12)
        -- Torso (center)
        pass:setColor(shirtR, shirtG, shirtB)
        pass:box(0, 0.05, 0, 0.3, 0.45, 0.18)
        -- Head (top)
        pass:setColor(skinR, skinG, skinB)
        pass:box(0, 0.4, 0, 0.24, 0.24, 0.24)

        pass:pop()

        -- Zzz bubble (stays upright, billboard)
        local toCamX = cam.x - x
        local toCamZ = cam.z - z
        local angle = math.atan2(toCamX, toCamZ)
        pass:push()
        pass:translate(x, sleepY + 0.7, z)
        pass:rotate(angle, 0, 1, 0)
        pass:setColor(1, 1, 1, 0.6 + 0.3 * math.sin(gameTime * 2))
        pass:text(string.rep("z", 1 + math.floor(gameTime % 3)), 0, 0, 0, 0.12)
        pass:pop()

        -- Sleep quality dot
        if npc.sleepQuality == 2 then pass:setColor(0.2, 0.9, 0.3, 0.5)
        elseif npc.sleepQuality == 1 then pass:setColor(0.8, 0.8, 0.2, 0.5)
        else pass:setColor(0.8, 0.3, 0.3, 0.5) end
        pass:sphere(x - 0.3, sleepY + 0.5, z, 0.05)

        return  -- Don't draw normal body
    end

    -- Push NPC render position away from adjacent solid blocks (prevent visual clipping)
    local gx = math.floor(x + 0.5)
    local gz = math.floor(z + 0.5)
    local npcY = math.floor(baseY + 0.5)
    local pushX, pushZ = 0, 0
    local pushDist = 0.2
    -- Check all 4 cardinal directions at feet and head height
    for _, dy in ipairs({npcY, npcY + 1}) do
        if world:isSolid(gx + 1, dy, gz) then pushX = pushX - pushDist end
        if world:isSolid(gx - 1, dy, gz) then pushX = pushX + pushDist end
        if world:isSolid(gx, dy, gz + 1) then pushZ = pushZ - pushDist end
        if world:isSolid(gx, dy, gz - 1) then pushZ = pushZ + pushDist end
    end
    x = x + pushX * 0.5  -- dampen to avoid jitter
    z = z + pushZ * 0.5

    local isMoving = npc.task ~= nil and not npc.dead
    local swing = isMoving and math.sin(gameTime * 8) * 0.4 or 0

    -- Bounce when excited
    if npc.excited then
        baseY = baseY + math.abs(math.sin(gameTime * Config.GIFT_BOUNCE_FREQUENCY)) * Config.GIFT_BOUNCE_AMPLITUDE
    end

    -- Per-NPC colors (personality)
    local skinR, skinG, skinB = 0.85 * dl, 0.70 * dl, 0.55 * dl
    local shirtR, shirtG, shirtB
    local pantsR, pantsG, pantsB

    if npc.shirtColor then
        shirtR = npc.shirtColor[1] * dl
        shirtG = npc.shirtColor[2] * dl
        shirtB = npc.shirtColor[3] * dl
    else
        shirtR, shirtG, shirtB = 0.2 * dl, 0.5 * dl, 0.8 * dl
    end
    if npc.pantsColor then
        pantsR = npc.pantsColor[1] * dl
        pantsG = npc.pantsColor[2] * dl
        pantsB = npc.pantsColor[3] * dl
    else
        pantsR, pantsG, pantsB = 0.25 * dl, 0.25 * dl, 0.35 * dl
    end

    if npc.dead then
        skinR, skinG, skinB = 0.4 * dl, 0.15 * dl, 0.15 * dl
        shirtR, shirtG, shirtB = 0.25 * dl, 0.15 * dl, 0.15 * dl
    elseif npc.injured then
        -- Darken injured NPC
        skinR = skinR * 0.5; skinG = skinG * 0.5; skinB = skinB * 0.5
        shirtR = shirtR * 0.5; shirtG = shirtG * 0.5; shirtB = shirtB * 0.5
        pantsR = pantsR * 0.5; pantsG = pantsG * 0.5; pantsB = pantsB * 0.5
    end

    -- Legs
    pass:setColor(pantsR, pantsG, pantsB)
    pass:box(x - 0.1, baseY + 0.25, z + swing * 0.1, 0.15, 0.5, 0.15)
    pass:box(x + 0.1, baseY + 0.25, z - swing * 0.1, 0.15, 0.5, 0.15)
    -- Torso
    pass:setColor(shirtR, shirtG, shirtB)
    pass:box(x, baseY + 0.75, z, 0.35, 0.45, 0.2)
    -- Arms
    pass:setColor(shirtR * 0.9, shirtG * 0.9, shirtB * 0.9)
    pass:box(x - 0.27, baseY + 0.7, z - swing * 0.12, 0.1, 0.4, 0.1)
    pass:box(x + 0.27, baseY + 0.7, z + swing * 0.12, 0.1, 0.4, 0.1)

    -- Head (with look-at rotation)
    pass:push()
    pass:translate(x, baseY + 1.15, z)
    if npc.lookAtX and npc.lookAtZ then
        local hdx = npc.lookAtX - npc.x
        local hdz = npc.lookAtZ - npc.z
        if hdx ~= 0 or hdz ~= 0 then
            pass:rotate(math.atan2(hdx, hdz), 0, 1, 0)
        end
    end
    pass:setColor(skinR, skinG, skinB)
    pass:box(0, 0, 0, 0.28, 0.28, 0.28)
    pass:setColor(0.1 * dl, 0.1 * dl, 0.1 * dl)
    pass:box(-0.07, 0.03, -0.14, 0.04, 0.04, 0.02)
    pass:box(0.07, 0.03, -0.14, 0.04, 0.04, 0.02)
    pass:pop()

    -- Mood dot
    local mood = npc:getMood()
    local mc = MOOD_COLORS[mood] or MOOD_COLORS.neutral
    pass:setColor(mc[1] * dl, mc[2] * dl, mc[3] * dl)
    pass:sphere(x + 0.2, baseY + 1.35, z - 0.15, 0.04)

    -- Carried block
    if npc.carriedBlock then
        pass:setColor(dl, dl, dl)
        local t = tex[npc.carriedBlock.itemType] or tex.wood
        pass:setMaterial(t)
        pass:box(x, baseY + 1.5, z, 0.35, 0.35, 0.35)
        pass:setMaterial()
    end

    -- HP bar (only show when damaged)
    if npc.hp < npc.cfg.HP_MAX and not npc.dead then
        local hpR = npc.hp / npc.cfg.HP_MAX
        pass:setColor(0.7, 0.15, 0.15, 0.7)
        pass:box(x, baseY + 1.5, z, 0.5, 0.04, 0.02)
        pass:setColor(0.15, 0.7, 0.15, 0.8)
        pass:box(x - 0.25 * (1 - hpR), baseY + 1.5, z, 0.5 * hpR, 0.04, 0.02)
    end

    -- Fight effect (red flash)
    if npc.fightTarget and not npc.dead then
        pass:setColor(1, 0.15, 0.1, 0.4 + 0.3 * math.sin(gameTime * 15))
        pass:sphere(x, baseY + 0.8, z, 0.35)
    end

    -- Chat bubble (when socializing)
    if npc.chatTarget and not npc.dead then
        if math.floor(gameTime * 2) % 2 == 0 then
            local toCamX2 = cam.x - x
            local toCamZ2 = cam.z - z
            local chatAngle = math.atan2(toCamX2, toCamZ2)
            pass:push()
            pass:translate(x, baseY + 1.9, z)
            pass:rotate(chatAngle, 0, 1, 0)
            pass:setColor(1, 1, 0.8, 0.85)
            pass:box(0, 0, 0, 0.4, 0.18, 0.02)
            pass:setColor(0.2, 0.2, 0.2)
            pass:text("...", 0, 0, -0.01, 0.1)
            pass:pop()
        end
    end

    -- Thought bubble (billboard)
    local thought = npc:getThought()
    if thought and not npc.dead then
        local toCamX = cam.x - x
        local toCamZ = cam.z - z
        local angle = math.atan2(toCamX, toCamZ)
        pass:push()
        pass:translate(x, baseY + 1.9, z)
        pass:rotate(angle, 0, 1, 0)
        pass:setColor(1, 1, 1, 0.85)
        pass:box(0, 0, 0, 0.8, 0.25, 0.02)
        pass:setColor(0.1, 0.1, 0.1)
        pass:text(thought.text, 0, 0, -0.015, 0.1)
        pass:setColor(1, 1, 1, 0.85)
        pass:box(0, -0.15, 0, 0.08, 0.08, 0.02)
        pass:pop()
    end
end

----------------------------------------------------------------------------
-- HUD (with NPC names, traits, follow mode indicator)
----------------------------------------------------------------------------
function drawHUD(pass)
    local w, h = lovr.system.getWindowDimensions()
    pass:setViewPose(1, lovr.math.mat4())
    pass:setProjection(1, lovr.math.mat4():orthographic(0, w, h, 0, -10, 10))
    -- px() converts target pixel height to font scale
    -- Cached: default font height is always 1.0 so px(N) = N
    local function px(n) return n end

    local selName = Items.panel_order[selectedIdx]
    local sel = Items.get(selName)
    local c = Items.getColor(selName)
    local timeStr = world.isNight and "NIGHT" or "DAY"

    -- Crosshair
    pass:setColor(1, 1, 1, 0.6)
    pass:line(w / 2 - 15, h / 2, 0, w / 2 + 15, h / 2, 0)
    pass:line(w / 2, h / 2 - 15, 0, w / 2, h / 2 + 15, 0)

    -- Bottom-center: item/template selector
    local bx, by = w / 2, h - 40
    if uiMode == "block" then
        pass:setColor(0, 0, 0, 0.55)
        pass:plane(bx, by, 0, 260, 50)
        pass:setColor(0.85, 0.85, 0.85)
        pass:text("<", bx - 110, by, 0, px(24))
        pass:setColor(c[1], c[2], c[3])
        pass:plane(bx - 50, by, 0, 30, 30)
        pass:setColor(1, 1, 1)
        pass:text(selName, bx + 10, by - 4, 0, px(18))
        pass:setColor(0.55, 0.55, 0.55)
        pass:text(selectedIdx .. "/" .. #Items.panel_order, bx + 10, by + 12, 0, px(11))
        pass:setColor(0.85, 0.85, 0.85)
        pass:text(">", bx + 110, by, 0, px(24))
    else
        -- Template mode
        local tmpl = TemplateLib.all[templateIdx]
        local tmplName = tmpl and tmpl.name or "???"
        pass:setColor(0.15, 0.1, 0.4, 0.7)
        pass:plane(bx, by, 0, 360, 50)
        pass:setColor(0.85, 0.85, 0.85)
        pass:text("<", bx - 160, by, 0, px(24))
        pass:setColor(1, 0.9, 0.3)
        pass:text(tmplName, bx, by - 4, 0, px(16))
        pass:setColor(0.65, 0.65, 0.65)
        if uiMode == "template" then
            pass:text(templateIdx .. "/" .. #TemplateLib.all .. "  [TAB] Template", bx, by + 12, 0, px(10))
        else
            pass:setColor(1, 0.4, 0.3)
            pass:text(templateIdx .. "/" .. #TemplateLib.all .. "  [TAB] PREVIEW  X=Delete", bx, by + 12, 0, px(10))
        end
        pass:setColor(0.85, 0.85, 0.85)
        pass:text(">", bx + 160, by, 0, px(24))
    end

    -- Bottom-left: [N] + NPC button
    local btnX, btnY = 80, h - 40
    pass:setColor(0.1, 0.55, 0.25, 0.85)
    pass:plane(btnX, btnY, 0, 120, 34)
    pass:setColor(1, 1, 1)
    pass:text("[N] + NPC", btnX, btnY, 0, px(15))

    -- Top-left: DAY/NIGHT + NPC count
    pass:setColor(0, 0, 0, 0.45)
    pass:plane(75, 16, 0, 150, 24)
    pass:setColor(1, 1, 1, 0.95)
    pass:text(timeStr .. "  NPC:" .. #npcs, 75, 16, 0, px(15))

    -- Controls hint
    pass:setColor(0.7, 0.7, 0.7, 0.6)
    pass:text("WASD=Fly  Tab=Mode  V=Follow  N=NPC  Click=Drop  Q=Quit", 230, 38, 0, px(10))

    -- Follow mode indicator
    if cam.followNPC then
        local npcName = cam.followNPC.name or ("NPC-" .. cam.followIdx)
        local viewMode = cam.firstPerson and "ANT-EYE" or "FOLLOW"
        pass:setColor(0, 0, 0, 0.55)
        pass:plane(w / 2, 70, 0, 350, 24)
        pass:setColor(1, 0.9, 0.2)
        pass:text(string.format("[%s] %s   Tab=Next  F=Toggle  Esc=Exit", viewMode, npcName),
            w / 2, 70, 0, px(13))
    end

    -- Right: NPC status
    for i, npc in ipairs(npcs) do
        if not npc.dead then
            local label = npc:getState()
            if label == "fetch_block" then label = "fetch"
            elseif label == "place_block" then label = "place"
            elseif label == "break_block" then label = "break"
            elseif label == "fetch_eat" then label = "eat"
            elseif label == "go_sleep" then label = "sleep"
            elseif label == "socialize" then label = "chat" end
            if npc.sleeping then label = "Zzz" end

            local displayName = npc.name or ("NPC" .. i)
            local moodStr = npc:getMood()
            local lineY = 16 + (i - 1) * 20

            pass:setColor(0, 0, 0, 0.4)
            pass:plane(w - 120, lineY, 0, 230, 18)

            if npc.shirtColor then
                pass:setColor(npc.shirtColor[1], npc.shirtColor[2], npc.shirtColor[3])
                pass:plane(w - 228, lineY, 0, 10, 10)
            end

            pass:setColor(1, 1, 1, 0.9)
            if label == "attack" then label = "ATK!"
            elseif label == "fighting" then label = "FIGHT!" end
            pass:text(string.format("%s HP:%d [%s] %s D:%d", displayName, npc.hp, label, moodStr, npc.desperation),
                w - 120, lineY, 0, px(11))
        end
    end
end

----------------------------------------------------------------------------
-- INPUT
----------------------------------------------------------------------------
function lovr.keypressed(key)
    log.write("main", "KEY:%s", key)
    if key == "escape" then
        if cam.followNPC then
            cam.followNPC = nil
            cam.followIdx = 0
            cam.firstPerson = false
        end
        -- Don't quit on Escape — only exit follow mode
        return
    end
    if key == "tab" then
        -- Cycle UI mode: block → template → preview → block
        if uiMode == "block" then uiMode = "template"
        elseif uiMode == "template" then uiMode = "preview"
        else uiMode = "block" end
    end
    if key == "v" then
        -- Follow NPC mode (moved from Tab)
        if #npcs == 0 then return end
        cam.followIdx = cam.followIdx + 1
        if cam.followIdx > #npcs then
            cam.followNPC = nil
            cam.followIdx = 0
            cam.firstPerson = false
        else
            cam.followNPC = npcs[cam.followIdx]
            cam.firstPerson = false
        end
    end
    if key == "f" and cam.followNPC then
        cam.firstPerson = not cam.firstPerson
    end
    if key == "left" then
        if uiMode == "block" then
            selectedIdx = selectedIdx - 1
            if selectedIdx < 1 then selectedIdx = #Items.panel_order end
        else
            templateIdx = templateIdx - 1
            if templateIdx < 1 then templateIdx = #TemplateLib.all end
        end
    end
    if key == "right" then
        if uiMode == "block" then
            selectedIdx = selectedIdx + 1
            if selectedIdx > #Items.panel_order then selectedIdx = 1 end
        else
            templateIdx = templateIdx + 1
            if templateIdx > #TemplateLib.all then templateIdx = 1 end
        end
    end
    if key == "return" then dropItem() end
    if key == "x" and uiMode == "preview" then
        -- Delete last preview building
        local last = previewBuildings[#previewBuildings]
        if last then
            for _, block in ipairs(last) do
                world:removeBlock(block)
            end
            table.remove(previewBuildings)
            log.write("main", "Removed preview building, %d remaining", #previewBuildings)
        end
    end
    if key == "n" then
        if #npcs >= 10 then return end  -- max 10 NPCs (prevent crash from too many)
        local gx, gz = cam:getLookTarget()
        if gx then
            npcs[#npcs + 1] = NPC.new(Config, world, Items, gx, gz, npcs)
            log.write("main", "Spawned %s at (%d,%d) total:%d", npcs[#npcs].name, gx, gz, #npcs)
        end
    end
    if key == "q" then lovr.event.quit() end
end

function lovr.mousemoved(x, y, dx, dy)
    if not cam.followNPC or cam.firstPerson then
        cam.yaw = cam.yaw - dx * cam.sensitivity
        cam.pitch = math.max(-1.5, math.min(1.5, cam.pitch - dy * cam.sensitivity))
    end
end

function lovr.wheelmoved(x, y)
    if y > 0 then cam.speed = math.min(50, cam.speed * 1.2) end
    if y < 0 then cam.speed = math.max(3, cam.speed / 1.2) end
end

function lovr.mousepressed(mx, my, button)
    log.write("main", "CLICK btn:%d at:%.0f,%.0f", button, mx, my)
    local w, h = lovr.system.getWindowDimensions()
    if button == 1 then
        local bx, by = w / 2, h - 40
        if my >= by - 28 and my <= by + 28 then
            if mx < bx - 60 then
                selectedIdx = selectedIdx - 1
                if selectedIdx < 1 then selectedIdx = #Items.panel_order end
                return
            elseif mx > bx + 60 then
                selectedIdx = selectedIdx + 1
                if selectedIdx > #Items.panel_order then selectedIdx = 1 end
                return
            else
                dropItem()
                return
            end
        end
        dropItem()
    end
end

function dropItem()
    if uiMode == "template" then
        dropTemplateMaterials()
        return
    elseif uiMode == "preview" then
        placePreviewBuilding()
        return
    end
    local gx, gz = cam:getLookTarget()
    if not gx then return end
    log.write("world", "DROP %s at:%d,%d falling:%d", Items.panel_order[selectedIdx], gx, gz, #fallingItems)
    local itemType = Items.panel_order[selectedIdx]
    local topY = -1
    for y = 20, 0, -1 do
        if world:isOccupied(gx, y, gz) then topY = y; break end
    end
    for _, fi in ipairs(fallingItems) do
        if fi.gx == gx and fi.gz == gz then
            if fi.targetY > topY then topY = fi.targetY end
        end
    end
    fallingItems[#fallingItems + 1] = {gx = gx, gz = gz, y = Config.FALL_START_Y, targetY = topY + 1, itemType = itemType}
end

-- Drop all materials for a template as organized stacked columns
function dropTemplateMaterials()
    local tmpl = TemplateLib.all[templateIdx]
    if not tmpl then return end

    local gx, gz = cam:getLookTarget()
    if not gx then return end

    -- Count materials with deduplication (same logic as toBlueprint)
    local doorX = tmpl.doorPos and tmpl.doorPos.x or math.floor(tmpl.w / 2)
    local doorZ = tmpl.doorPos and tmpl.doorPos.z or 0
    local byPos = {}
    for i, b in ipairs(tmpl.blocks) do
        b._origIdx = b._origIdx or i
    end
    local sorted = {}
    for _, b in ipairs(tmpl.blocks) do sorted[#sorted+1] = b end
    table.sort(sorted, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        if a.z ~= b.z then return a.z < b.z end
        return (a._origIdx or 0) < (b._origIdx or 0)
    end)
    -- Block type mapping (same as templatelib.lua toBlueprint)
    local TYPE_MAP = {
        oak_door="door", white_bed="bed", yellow_bed="bed", red_bed="bed",
        dirt="cobblestone", grass_block="cobblestone", farmland="cobblestone",
        white_terracotta="cobblestone", terracotta="cobblestone", clay="cobblestone",
        dirt_path="cobblestone", smooth_stone="cobblestone",
        wall_torch="torch", stripped_oak_wood="stripped_oak_log",
        white_wool="oak_planks", yellow_wool="oak_planks",
        iron_bars="glass_pane",
        yellow_stained_glass_pane="glass_pane", white_stained_glass_pane="glass_pane",
        water_cauldron="cauldron", oak_leaves="leaves",
        brewing_stand="crafting_table", smithing_table="crafting_table",
        furnace="cobblestone",
    }
    local SKIP = {
        white_carpet=true, yellow_carpet=true, green_carpet=true, red_carpet=true,
        poppy=true, dandelion=true, potted_dandelion=true, rose_bush=true,
        wheat=true, short_grass=true, tall_grass=true,
        oak_pressure_plate=true, stone_pressure_plate=true,
        water=true, lava=true, air=true,
    }
    for _, b in ipairs(sorted) do
        if not (b.x == doorX and b.z == doorZ and b.y < 2) then
            local mat = b.t or "wall"
            if not SKIP[mat] then
                mat = TYPE_MAP[mat] or mat
                byPos[b.x..","..b.y..","..b.z] = mat
            end
        end
    end
    local needed = {}
    local matOrder = {}
    for _, mat in pairs(byPos) do
        if not needed[mat] then matOrder[#matOrder+1] = mat end
        needed[mat] = (needed[mat] or 0) + 1
    end
    -- Add 5% buffer
    for mat, count in pairs(needed) do
        needed[mat] = count + math.max(1, math.ceil(count * 0.05))
    end
    table.sort(matOrder)  -- alphabetical for consistent layout

    -- Layout: flat grid on ground (y=0). Each block gets unique (x,z).
    -- Same material type grouped together in rows for visual organization.
    local delay = 0
    local placeX = gx
    local placeZ = gz
    local rowStart = gx
    local maxRowWidth = 20  -- blocks per row before wrapping to next row
    local colInRow = 0
    for _, mat in ipairs(matOrder) do
        local count = needed[mat]
        for _ = 1, count do
            -- Find a free ground position
            while world:isOccupied(placeX, 0, placeZ) do
                colInRow = colInRow + 1
                if colInRow >= maxRowWidth then
                    colInRow = 0
                    placeZ = placeZ + 1
                    placeX = rowStart
                else
                    placeX = placeX + 1
                end
            end
            fallingItems[#fallingItems + 1] = {
                gx = placeX, gz = placeZ,
                y = Config.FALL_START_Y + delay,
                targetY = 0,
                itemType = mat,
            }
            delay = delay + 0.005
            colInRow = colInRow + 1
            if colInRow >= maxRowWidth then
                colInRow = 0
                placeZ = placeZ + 1
                placeX = rowStart
            else
                placeX = placeX + 1
            end
        end
    end

    -- Add to build queue
    buildQueue[#buildQueue + 1] = {
        template = tmpl,
        blueprint = nil,  -- NPC will create blueprint with auto-siting
        materialPos = {x = gx, z = gz},
    }

    log.write("main", "Template '%s' materials dropped (%d items), queue #%d",
        tmpl.name, #fallingItems, #buildQueue)
end

-- Preview mode: instantly place a fully built building for template inspection
function placePreviewBuilding()
    local tmpl = TemplateLib.all[templateIdx]
    if not tmpl then return end

    local cx, cz = cam:getLookTarget()
    if not cx then return end

    local originX = math.floor(cx) - math.floor(tmpl.w / 2)
    local originZ = math.floor(cz) - math.floor(tmpl.d / 2)
    local doorX = tmpl.doorPos and tmpl.doorPos.x or math.floor(tmpl.w / 2)
    local doorZ = tmpl.doorPos and tmpl.doorPos.z or 0

    -- Sort + dedup (same as toBlueprint)
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
    local posOrder = {}
    for _, b in ipairs(sorted) do
        local wx = originX + b.x
        local wz = originZ + b.z
        if not (b.x == doorX and b.z == doorZ and b.y < 2) then
            local pk = wx..","..b.y..","..wz
            if not byPos[pk] then posOrder[#posOrder + 1] = pk end
            byPos[pk] = b
        end
    end

    -- Place all blocks instantly
    local placedBlocks = {}
    for _, pk in ipairs(posOrder) do
        local b = byPos[pk]
        local wx = originX + b.x
        local wz = originZ + b.z
        local mat = b.t or "wall"
        -- Apply same type normalization as toBlueprint
        local PTYPE_MAP = {
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
        local PSKIP = {
            white_carpet=true, yellow_carpet=true, green_carpet=true,
            poppy=true, dandelion=true, potted_dandelion=true,
            wheat=true, short_grass=true, tall_grass=true,
            oak_pressure_plate=true, water=true, lava=true, air=true,
        }
        if PSKIP[mat] then goto nextPreviewBlock end
        mat = PTYPE_MAP[mat] or mat
        local block = world:addBlock(wx, b.y, wz, mat, "placed")
        if block then
            block.noGravity = true
            block.facing = b.f
            block.half = b.h
            block.shape = b.s
            block.open = b.o
            placedBlocks[#placedBlocks + 1] = block
        end
        ::nextPreviewBlock::
    end

    previewBuildings[#previewBuildings + 1] = placedBlocks
    log.write("main", "Preview '%s' placed at (%d,%d): %d/%d blocks",
        tmpl.name, originX, originZ, #placedBlocks, #posOrder)
end
