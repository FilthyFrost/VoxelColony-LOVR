# STEP 07: Click Juice Effects

## Task

Add satisfying visual feedback for every block drop: camera shake, dust ring at landing point, "+N" floating text, NPC head-turn reaction, and progress bar bounce. The juice style changes based on upgrade level.

## Add: Camera Shake

```lua
-- Camera shake state
local camShake = {timer = 0, intensity = 0}

function triggerCamShake(blockCount)
    -- Lv.1-2: noticeable shake. Lv.3+: reduced (mass drop is its own spectacle)
    local intensity = math.max(0.005, 0.02 / math.sqrt(blockCount))
    camShake.timer = 0.08
    camShake.intensity = intensity
end

-- In your camera update each frame:
function applyCamShake(dt, cameraNode)
    if camShake.timer > 0 then
        camShake.timer = camShake.timer - dt
        local ox = (math.random() - 0.5) * 2 * camShake.intensity
        local oy = (math.random() - 0.5) * 2 * camShake.intensity
        -- Apply offset to camera position temporarily
        local pos = cameraNode:GetPosition()
        cameraNode:SetPosition(Vector3(pos.x + ox, pos.y + oy, pos.z))
    end
end
```

## Add: Dust Ring at Landing Point

```lua
-- Dust ring effect: expanding circle at block landing position
local dustRings = {}

function addDustRing(gx, gz)
    dustRings[#dustRings + 1] = {
        x = gx, z = gz,
        radius = 0.3,
        maxRadius = 1.5,
        timer = 0.3,
        maxTimer = 0.3,
    }
end

-- Update and render dust rings each frame
function updateDustRings(dt)
    for i = #dustRings, 1, -1 do
        local ring = dustRings[i]
        ring.timer = ring.timer - dt
        if ring.timer <= 0 then
            table.remove(dustRings, i)
        else
            local t = 1 - (ring.timer / ring.maxTimer)
            ring.radius = ring.maxRadius * t
        end
    end
end

-- Render dust rings using NanoVG or 3D circles
function renderDustRings(scene)
    for _, ring in ipairs(dustRings) do
        local alpha = ring.timer / ring.maxTimer * 0.4
        -- Draw a circle at (ring.x, 0.02, ring.z) with ring.radius
        -- Color: gray (0.6, 0.6, 0.6, alpha)
        -- Use a flat disc/plane node scaled to ring.radius * 2
    end
end
```

## Add: Floating "+N" Text

```lua
-- Floating text that rises and fades
local floatingTexts = {}

function addFloatingText(gx, gz, count)
    floatingTexts[#floatingTexts + 1] = {
        x = gx, y = 0.5, z = gz,
        text = "+" .. count,
        timer = 0.8,
        maxTimer = 0.8,
    }
end

function updateFloatingTexts(dt)
    for i = #floatingTexts, 1, -1 do
        local ft = floatingTexts[i]
        ft.timer = ft.timer - dt
        ft.y = ft.y + 1.5 * dt  -- rise upward
        if ft.timer <= 0 then
            table.remove(floatingTexts, i)
        end
    end
end

-- Render floating texts as 3D billboarded text or UrhoX 3D UI
function renderFloatingTexts(scene)
    for _, ft in ipairs(floatingTexts) do
        local alpha = ft.timer / ft.maxTimer
        -- Draw text ft.text at position (ft.x, ft.y, ft.z)
        -- Color: white with alpha
        -- Font size: 0.15 (world units)
        -- Billboard: always face camera
    end
end
```

## Add: NPC Head-Turn Reaction

```lua
-- When blocks drop near an NPC, make the NPC look at the landing point
function onBlockLanded(gx, gz, npcs)
    -- Find nearest NPC within 10 units
    local nearest = nil
    local nearestDist = 100
    for _, npc in ipairs(npcs) do
        if not npc.dead then
            local dist = math.abs(npc.gx - gx) + math.abs(npc.gz - gz)
            if dist < nearestDist and dist < 10 then
                nearest = npc
                nearestDist = dist
            end
        end
    end
    if nearest then
        nearest.lookAtX = gx
        nearest.lookAtZ = gz
        -- Clear lookAt after 0.5 seconds (use a timer in NPC update)
        nearest.lookAtClearTimer = 0.5
    end
end
```

In `NPC:update(dt)`, add:
```lua
if self.lookAtClearTimer then
    self.lookAtClearTimer = self.lookAtClearTimer - dt
    if self.lookAtClearTimer <= 0 then
        self.lookAtX = nil
        self.lookAtZ = nil
        self.lookAtClearTimer = nil
    end
end
```

## Integrate into Drop Function

```lua
function dropItem()
    local gx, gz = getLookTarget()
    if not gx then return end

    local itemType = Items.panel_order[selectedIdx]
    local count = Upgrade.dropMultiplier

    -- Camera shake
    triggerCamShake(count)

    -- Floating text (single "+N" for all blocks)
    addFloatingText(gx, gz, count)

    for i = 1, count do
        local offsetX = count > 1 and math.random(-1, 1) or 0
        local offsetZ = count > 1 and math.random(-1, 1) or 0
        local dropX = math.max(0, math.min(Config.GRID - 1, gx + offsetX))
        local dropZ = math.max(0, math.min(Config.GRID - 1, gz + offsetZ))
        local topY = -1
        for y = 20, 0, -1 do
            if world:isOccupied(dropX, y, dropZ) then topY = y; break end
        end

        -- Stagger fall start for cascade effect at high counts
        local fallDelay = (i - 1) * 0.05  -- 0.05s between each block
        addFallingItem(dropX, dropZ, topY + 1, itemType, fallDelay)
    end

    -- Dust rings (one per landing position, deduplicated)
    addDustRing(gx, gz)

    -- NPC head turn
    onBlockLanded(gx, gz, npcs)

    -- Demand system notification
    Demand.onPlayerDrop(itemType, gx, gz, count)
end
```

## Lv.3+ Special: Ground Flash

```lua
-- At upgrade Lv.3+, instead of camera shake, flash the ground white at drop point
function triggerGroundFlash(gx, gz)
    -- Create a white plane at (gx, 0.03, gz) that fades from alpha 0.6 to 0 over 0.15 seconds
    -- Size: 3x3 (covers the scatter area)
end
```

In dropItem(), add:
```lua
if Upgrade.level >= 3 then
    triggerGroundFlash(gx, gz)
    -- Don't do camera shake for high levels (replace, don't stack)
else
    triggerCamShake(count)
end
```

## Verification

1. Lv.1: Click to drop. Camera should shake slightly. One dust ring at landing point. "+1" text floats up. Nearest NPC turns head toward drop point.
2. Lv.3 (x6): Click to drop. 6 blocks cascade down with 0.05s stagger. Ground flashes white. "+6" floating text. Multiple dust rings. No camera shake.
3. Lv.5 (x24): Click to drop. 24 blocks cascade = visual waterfall. "+24" floating text. Ground flash. Very satisfying.
4. Floating text fades out after 0.8 seconds.
5. Dust rings expand from 0.3 to 1.5 radius over 0.3 seconds, then disappear.
