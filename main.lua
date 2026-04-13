-- main.lua — Voxel Colony for LOVR 0.18
-- Free-fly + Follow + Ant-Eye camera modes
-- NPC personality colors, bounce animation, head rotation, enhanced HUD

local Config = require("config")
local Items = require("items")
local World = require("world")
local NPC = require("npc")
local Textures = require("textures")

local mouse = require("mouse")

local world, npcs, fallingItems, tex, hudFont
local selectedIdx = 1
local gameTime = 0

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

    -- No custom font needed — we compute scale dynamically in drawHUD

    cam.x = Config.GRID / 2
    cam.y = 40
    cam.z = Config.GRID / 2 - 20
    cam.yaw = 0
    cam.pitch = -0.6

    -- Spawn 1 NPC
    local cx = math.floor(Config.GRID / 2)
    local cz = math.floor(Config.GRID / 2)
    npcs[#npcs + 1] = NPC.new(Config, world, Items, cx, cz, npcs)

    lovr.graphics.setBackgroundColor(0.45, 0.65, 0.92)
    mouse.setRelativeMode(true)
end

-- Crash log: write state to file every second so we can see what happened before crash
local crashLog = io.open("/tmp/lovr_crash.log", "w")
if crashLog then crashLog:write("=== Game started ===\n"); crashLog:close() end
local lastCrashLog = 0

local function writeCrashState(msg)
    local f = io.open("/tmp/lovr_crash.log", "a")
    if f then
        f:write(string.format("[%.1fs] %s | npcs:%d blocks:%d falling:%d markers:%d\n",
            gameTime, msg, #npcs, #world.blocks, #fallingItems, #world.markers))
        f:close()
    end
end

-- Auto-test
local autoTestDone = false
local autoTestTimer = 2

function lovr.update(dt)
    local ok, err = pcall(function()
    gameTime = gameTime + dt
    world:update(dt)

    -- Auto-test material drop
    if not autoTestDone then
        autoTestTimer = autoTestTimer - dt
        if autoTestTimer <= 0 then
            autoTestDone = true
            local cx = math.floor(Config.GRID / 2)
            local cz = math.floor(Config.GRID / 2)
            local used = {}
            local function drop(itemType, delay)
                for _ = 0, 50 do
                    local gx = cx + math.random(-7, 7)
                    local gz = cz + math.random(-7, 7)
                    local k = gx .. "," .. gz
                    if not used[k] then
                        used[k] = true
                        fallingItems[#fallingItems + 1] = {gx = gx, gz = gz, y = Config.FALL_START_Y + delay, targetY = 0, itemType = itemType}
                        return
                    end
                end
            end
            for i = 0, 35 do drop("wall", i * 0.12) end
            for i = 0, 24 do drop("roof", 5 + i * 0.12) end
            drop("door", 9); drop("bed", 9.1); drop("torch", 9.2); drop("chest", 9.3)
            for i = 0, 7 do drop("apple", 10 + i * 0.2) end
        end
    end

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

    -- Crash log: periodic state dump
    if gameTime - lastCrashLog >= 2 then
        lastCrashLog = gameTime
        local aliveNpcs = 0
        for _, n in ipairs(npcs) do if not n.dead then aliveNpcs = aliveNpcs + 1 end end
        writeCrashState(string.format("TICK alive:%d", aliveNpcs))
    end
    end) -- pcall
    if not ok then
        writeCrashState("UPDATE ERROR: " .. tostring(err))
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

    -- Blocks
    for _, b in ipairs(world.blocks) do
        if b.state ~= "carried" then
            pass:setColor(dl, dl, dl)
            local t = tex[b.itemType] or tex.wood
            pass:setMaterial(t)
            if b.itemType == "door" then
                pass:box(b.gx, b.gy + 1, b.gz, 0.95, 1.95, 0.15)
            elseif b.itemType == "bed" then
                pass:box(b.gx, b.gy + 0.3, b.gz, 0.95, 0.55, 1.8)
            elseif b.itemType == "torch" then
                pass:box(b.gx, b.gy + 0.3, b.gz, 0.15, 0.6, 0.15)
            elseif b.itemType == "chest" then
                pass:box(b.gx, b.gy + 0.4, b.gz, 0.85, 0.75, 0.85)
            elseif b.itemType == "ladder" then
                pass:box(b.gx, b.gy + 0.5, b.gz, 0.95, 0.95, 0.1)
            else
                pass:box(b.gx, b.gy + 0.5, b.gz, 0.98, 0.98, 0.98)
            end
            pass:setMaterial()

            -- Floating label for loose blocks (only nearest ones to camera)
            if b.state == "loose" then
                local toCamX = cam.x - b.gx
                local toCamZ = cam.z - b.gz
                local dist2 = toCamX * toCamX + toCamZ * toCamZ
                if dist2 < 64 then  -- within 8 blocks only
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

    -- Sleeping: render lying down with Zzz
    if npc.sleeping then
        local skinR = 0.85 * dl
        local shirtR, shirtG, shirtB
        if npc.shirtColor then
            shirtR = npc.shirtColor[1] * dl
            shirtG = npc.shirtColor[2] * dl
            shirtB = npc.shirtColor[3] * dl
        else
            shirtR, shirtG, shirtB = 0.2 * dl, 0.5 * dl, 0.8 * dl
        end
        -- Body lying on ground
        pass:setColor(shirtR, shirtG, shirtB)
        pass:box(x, baseY + 0.15, z, 0.8, 0.2, 0.3)
        -- Head
        pass:setColor(skinR, 0.70 * dl, 0.55 * dl)
        pass:box(x + 0.35, baseY + 0.15, z, 0.22, 0.22, 0.22)
        -- Zzz bubble
        local toCamX = cam.x - x
        local toCamZ = cam.z - z
        local angle = math.atan2(toCamX, toCamZ)
        pass:push()
        pass:translate(x, baseY + 0.6, z)
        pass:rotate(angle, 0, 1, 0)
        pass:setColor(1, 1, 1, 0.6 + 0.3 * math.sin(gameTime * 2))
        local zzz = string.rep("z", 1 + math.floor(gameTime % 3))
        pass:text(zzz, 0, 0, 0, 0.12)
        pass:pop()
        -- Sleep quality indicator
        if npc.sleepQuality == 2 then
            pass:setColor(0.2, 0.9, 0.3, 0.5)  -- green = bed
        elseif npc.sleepQuality == 1 then
            pass:setColor(0.8, 0.8, 0.2, 0.5)  -- yellow = indoor
        else
            pass:setColor(0.8, 0.3, 0.3, 0.5)  -- red = ground
        end
        pass:sphere(x - 0.3, baseY + 0.35, z, 0.06)
        return  -- Don't draw normal body
    end

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

    -- Bottom-center: item selector
    local bx, by = w / 2, h - 40
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
    pass:text("WASD=Fly  Tab=Follow  F=AntEye  Click=Drop  Q=Quit", 220, 38, 0, px(10))

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
    writeCrashState("KEY:" .. key)
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
        selectedIdx = selectedIdx - 1
        if selectedIdx < 1 then selectedIdx = #Items.panel_order end
    end
    if key == "right" then
        selectedIdx = selectedIdx + 1
        if selectedIdx > #Items.panel_order then selectedIdx = 1 end
    end
    if key == "return" then dropItem() end
    if key == "n" then
        local gx, gz = cam:getLookTarget()
        if gx then
            npcs[#npcs + 1] = NPC.new(Config, world, Items, gx, gz, npcs)
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
    writeCrashState(string.format("CLICK btn:%d at:%.0f,%.0f", button, mx, my))
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
    local gx, gz = cam:getLookTarget()
    if not gx then return end
    writeCrashState(string.format("DROP %s at:%d,%d falling:%d", Items.panel_order[selectedIdx], gx, gz, #fallingItems))
    local itemType = Items.panel_order[selectedIdx]
    -- Find highest occupied Y including blocks already in the world
    local topY = -1
    for y = 20, 0, -1 do
        if world:isOccupied(gx, y, gz) then topY = y; break end
    end
    -- Also account for items still falling to this position
    for _, fi in ipairs(fallingItems) do
        if fi.gx == gx and fi.gz == gz then
            if fi.targetY > topY then topY = fi.targetY end
        end
    end
    fallingItems[#fallingItems + 1] = {gx = gx, gz = gz, y = Config.FALL_START_Y, targetY = topY + 1, itemType = itemType}
end
