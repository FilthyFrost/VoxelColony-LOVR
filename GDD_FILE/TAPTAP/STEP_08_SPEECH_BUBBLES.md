# STEP 08: NPC Speech Bubbles with Progress Bars

## Task

Replace the existing simple thought bubbles with larger Chinese dialogue bubbles that show demand text + material progress bars. Bubbles are billboarded 3D UI elements above each NPC's head. Bubble size scales with urgency.

## Prerequisites

- `dialogue.lua` from STEP_02
- `demand.lua` from STEP_01
- NPC objects must have `dialogueLine`, `dialogueTimer`, `currentDemand` fields (from STEP_03)

## Bubble Design

Each NPC with an active demand shows a bubble containing:
- Line 1: Chinese dialogue text (e.g. "喂！给我10个圆石！快点！")
- Line 2: Progress bar + material counter (e.g. "圆石 6/10")
- Line 3: Overall building progress percentage (e.g. "建筑进度: 65%")

NPCs without active demands show either:
- Building status ("建造中..." with hammer icon text)
- Idle text (random idle line from dialogue)
- Nothing (if sleeping)

## Implementation

### 1. Render NPC Bubble (3D Billboard)

```lua
-- Call this for each alive NPC during rendering
function renderNpcBubble(npc, cameraNode, gameTime)
    if npc.dead or npc.sleeping then return end

    local d = npc.currentDemand
    local line = npc.dialogueLine or ""
    local hasProgress = false
    local progressRatio = 0
    local progressText = ""
    local totalProgressText = ""

    if d and d.state == "active" then
        -- Get most needed material for progress display
        if d.type == "building" or d.type == "expansion" then
            local most = d:getMostNeededMaterial()
            if most then
                local Dialogue = require("dialogue")
                local matName = Dialogue.getMaterialName(most.itemType)
                progressText = matName .. " " .. most.delivered .. "/" .. most.needed
                progressRatio = most.delivered / most.needed
                hasProgress = true
            end
            totalProgressText = "建筑进度: " .. math.floor(d:getProgress() * 100) .. "%"
        elseif d.type == "food" then
            progressText = "苹果 " .. d.foodDelivered .. "/" .. d.foodNeeded
            progressRatio = d.foodDelivered / d.foodNeeded
            hasProgress = true
        elseif d.type == "companion" then
            progressText = "按 [N] 生成"
            hasProgress = false
        end
    elseif not d then
        -- No demand: show idle or building text
        if npc.task and (npc.task.type == "fetch_block" or npc.task.type == "place_block") then
            line = "建造中..."
        elseif npc.dialogueTimer and npc.dialogueTimer > 0 then
            -- Keep showing current dialogue
        else
            line = ""  -- no bubble
            return
        end
    end

    if line == "" and not hasProgress then return end

    -- Determine bubble size based on urgency
    local urgency = d and d.urgency or "normal"
    local scale = 1.0
    if urgency == "critical" then scale = 1.3
    elseif urgency == "urgent" then scale = 1.1 end

    -- Bubble position: above NPC head
    local bubbleX = npc.x
    local bubbleY = npc.y + 1.9
    local bubbleZ = npc.z

    -- Billboard: calculate rotation to face camera
    local camPos = cameraNode:GetPosition()
    local dx = camPos.x - bubbleX
    local dz = camPos.z - bubbleZ
    local angle = math.atan2(dx, dz)

    -- Bubble dimensions
    local bubbleW = 1.0 * scale
    local bubbleH = 0.4 * scale
    if hasProgress then bubbleH = 0.55 * scale end
    if totalProgressText ~= "" then bubbleH = 0.65 * scale end

    -- Bubble colors by urgency
    local bgColor, borderColor
    if urgency == "critical" then
        local pulse = 0.7 + 0.3 * math.sin(gameTime * 5)
        bgColor = {0.3, 0.05, 0.05, 0.9 * pulse}
        borderColor = {1.0, 0.2, 0.2, pulse}
    elseif urgency == "urgent" then
        bgColor = {0.3, 0.25, 0.05, 0.9}
        borderColor = {1.0, 0.8, 0.2, 0.9}
    else
        bgColor = {0.1, 0.1, 0.1, 0.85}
        borderColor = {0.5, 0.5, 0.5, 0.5}
    end

    -- RENDER BUBBLE (adapt to your engine's 3D text/billboard system)
    -- Option A: Use 3D nodes with billboard constraint
    -- Option B: Use NanoVG to project to screen space and draw 2D

    -- Pseudo-code for 3D billboard approach:
    -- 1. Create or reuse a bubble node at (bubbleX, bubbleY, bubbleZ)
    -- 2. Set rotation to face camera (angle around Y axis)
    -- 3. Draw background box (bgColor)
    -- 4. Draw border (borderColor)
    -- 5. Draw text line 1: dialogue text (white, font size ~0.07 * scale)
    -- 6. Draw progress bar if hasProgress:
    --    - Background bar (gray, 0.6 wide)
    --    - Filled portion (green-to-yellow based on ratio)
    --    - Text: progressText (white, font size 0.05 * scale)
    -- 7. Draw total progress text if present

    -- For NanoVG screen-space approach:
    -- 1. Project (bubbleX, bubbleY, bubbleZ) to screen coordinates
    -- 2. If on screen, draw rectangle + text at screen position
    -- This is simpler and avoids 3D text rendering complexity

    renderBubbleAtScreenPos(npc, bubbleX, bubbleY, bubbleZ, line, progressText,
        progressRatio, totalProgressText, hasProgress, bgColor, borderColor, scale,
        cameraNode, gameTime)
end

-- Screen-space bubble rendering using NanoVG
function renderBubbleAtScreenPos(npc, wx, wy, wz, line, progressText,
        progressRatio, totalProgressText, hasProgress, bgColor, borderColor, scale,
        cameraNode, gameTime)
    -- Project world position to screen
    local camera = cameraNode:GetComponent("Camera")
    local screenPos = camera:WorldToScreenPoint(Vector3(wx, wy, wz))
    if screenPos.z < 0 then return end  -- behind camera

    local sx = screenPos.x * screenWidth
    local sy = screenPos.y * screenHeight

    -- Clamp to screen bounds with margin
    if sx < 50 or sx > screenWidth - 50 or sy < 20 or sy > screenHeight - 50 then
        return
    end

    -- Draw using NanoVG:
    local nvg = GetNanoVG()  -- your NanoVG context

    local bw = 200 * scale
    local bh = 50 * scale
    if hasProgress then bh = 70 * scale end
    if totalProgressText ~= "" then bh = 85 * scale end

    -- Background
    nvg:BeginPath()
    nvg:RoundedRect(sx - bw/2, sy - bh, bw, bh, 6)
    nvg:FillColor(NanoColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
    nvg:Fill()

    -- Border
    nvg:StrokeColor(NanoColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4]))
    nvg:StrokeWidth(1.5)
    nvg:Stroke()

    -- Pointer triangle
    nvg:BeginPath()
    nvg:MoveTo(sx - 5, sy)
    nvg:LineTo(sx + 5, sy)
    nvg:LineTo(sx, sy + 8)
    nvg:ClosePath()
    nvg:FillColor(NanoColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
    nvg:Fill()

    -- Text line 1: dialogue
    nvg:FontSize(13 * scale)
    nvg:FillColor(NanoColor(1, 1, 1, 0.95))
    nvg:TextAlign(NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvg:Text(sx, sy - bh + 6, line)

    -- Progress bar
    if hasProgress then
        local barY = sy - bh + 28 * scale
        local barW = bw * 0.8
        local barH = 8 * scale

        -- Background bar
        nvg:BeginPath()
        nvg:RoundedRect(sx - barW/2, barY, barW, barH, 3)
        nvg:FillColor(NanoColor(0.3, 0.3, 0.3, 0.8))
        nvg:Fill()

        -- Filled bar (green to yellow gradient based on progress)
        local fillW = barW * math.min(1, progressRatio)
        if fillW > 0 then
            nvg:BeginPath()
            nvg:RoundedRect(sx - barW/2, barY, fillW, barH, 3)
            local r = 1 - progressRatio
            local g = progressRatio
            nvg:FillColor(NanoColor(r, g, 0.2, 0.9))
            nvg:Fill()
        end

        -- Progress text
        nvg:FontSize(10 * scale)
        nvg:FillColor(NanoColor(1, 1, 1, 0.85))
        nvg:Text(sx, barY + barH + 2, progressText)
    end

    -- Total progress text
    if totalProgressText ~= "" then
        nvg:FontSize(9 * scale)
        nvg:FillColor(NanoColor(0.7, 0.7, 0.7, 0.7))
        nvg:Text(sx, sy - 14, totalProgressText)
    end
end
```

## Verification

1. Start game. NPC should have a dark bubble above its head with Chinese demand text.
2. Bubble should show progress bar and material counter (e.g. "圆石 0/10").
3. Drop correct material. Progress bar should update immediately (e.g. "圆石 1/10").
4. When material type is fully delivered, bubble should auto-switch to next needed material.
5. Bubble text should cycle every 5-8 seconds (different waiting lines).
6. When urgency is "critical": bubble gets larger (1.3x), red pulsing background.
7. When urgency is "urgent": bubble gets slightly larger (1.1x), yellow border.
8. When NPC is building (no active demand): bubble shows "建造中..." or disappears.
9. When NPC is idle: no bubble shown.
