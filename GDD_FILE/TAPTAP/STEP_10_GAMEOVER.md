# STEP 10: Game Over Screen + Scoring + Restart

## Task

Create `gameover.lua` that shows a statistics screen with Chinese NPC rating when all NPCs die. Display score, stats, and a restart button. Restart must be instant (<1 second).

## Create file: gameover.lua

```lua
-- gameover.lua — Game Over screen with stats, Chinese NPC rating, restart

local Dialogue = require("dialogue")

local GameOver = {}

GameOver.active = false
GameOver.stats = {}
GameOver.score = 0
GameOver.ratingText = ""
GameOver.fadeTimer = 0
GameOver.fadeIn = 2.0  -- 2 second fade-in

-- Game statistics (updated during gameplay)
GameOver.tracker = {
    survivalTime = 0,
    demandsFulfilled = 0,
    buildingsBuilt = 0,
    maxNpcCount = 0,
    gamblingWins = 0,
    gamblingLosses = 0,
    blocksDropped = 0,
    maxUpgradeLevel = 1,
    npcDeaths = 0,
}

-- Update tracker during gameplay (call relevant methods from game logic)
function GameOver.onBlockDropped(count)
    GameOver.tracker.blocksDropped = GameOver.tracker.blocksDropped + count
end

function GameOver.onDemandFulfilled()
    GameOver.tracker.demandsFulfilled = GameOver.tracker.demandsFulfilled + 1
end

function GameOver.onBuildingCompleted()
    GameOver.tracker.buildingsBuilt = GameOver.tracker.buildingsBuilt + 1
end

function GameOver.onNpcDeath()
    GameOver.tracker.npcDeaths = GameOver.tracker.npcDeaths + 1
end

function GameOver.onGamblingResult(won)
    if won then
        GameOver.tracker.gamblingWins = GameOver.tracker.gamblingWins + 1
    else
        GameOver.tracker.gamblingLosses = GameOver.tracker.gamblingLosses + 1
    end
end

function GameOver.updateNpcCount(aliveCount)
    if aliveCount > GameOver.tracker.maxNpcCount then
        GameOver.tracker.maxNpcCount = aliveCount
    end
end

function GameOver.updateUpgradeLevel(level)
    if level > GameOver.tracker.maxUpgradeLevel then
        GameOver.tracker.maxUpgradeLevel = level
    end
end

-- Calculate score
function GameOver.calculateScore()
    local s = GameOver.tracker
    local score = 0
    score = score + math.floor(s.survivalTime)           -- 1 point per second
    score = score + s.demandsFulfilled * 50               -- 50 per demand
    score = score + s.buildingsBuilt * 100                -- 100 per building
    score = score + s.maxNpcCount * 30                    -- 30 per max NPC
    score = score + s.gamblingWins * 80                   -- 80 per gambling win
    -- Efficiency bonus
    if s.blocksDropped > 0 then
        local efficiency = s.demandsFulfilled / s.blocksDropped * 1000
        score = score + math.floor(efficiency)
    end
    return score
end

-- Trigger game over
function GameOver.trigger(survivalTime)
    GameOver.active = true
    GameOver.fadeTimer = GameOver.fadeIn
    GameOver.tracker.survivalTime = survivalTime
    GameOver.score = GameOver.calculateScore()
    GameOver.ratingText = Dialogue.getRating(GameOver.score)
end

-- Update (call every frame)
function GameOver.update(dt)
    if not GameOver.active then return end
    if GameOver.fadeTimer > 0 then
        GameOver.fadeTimer = GameOver.fadeTimer - dt
    end
end

-- Render game over screen using NanoVG
function GameOver.render(nvg, screenW, screenH)
    if not GameOver.active then return end

    local fadeAlpha = math.min(1.0, 1.0 - GameOver.fadeTimer / GameOver.fadeIn)

    -- Dark overlay
    nvg:BeginPath()
    nvg:Rect(0, 0, screenW, screenH)
    nvg:FillColor(NanoColor(0, 0, 0, 0.75 * fadeAlpha))
    nvg:Fill()

    local cx = screenW / 2
    local baseY = screenH * 0.15

    -- Title
    nvg:FontSize(36)
    nvg:FillColor(NanoColor(1, 0.3, 0.2, fadeAlpha))
    nvg:TextAlign(NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvg:Text(cx, baseY, "殖民地覆灭")

    -- Stats panel background
    local panelW = 350
    local panelH = 260
    local panelY = baseY + 40
    nvg:BeginPath()
    nvg:RoundedRect(cx - panelW/2, panelY, panelW, panelH, 8)
    nvg:FillColor(NanoColor(0.1, 0.1, 0.1, 0.9 * fadeAlpha))
    nvg:Fill()

    -- Stats text
    nvg:FontSize(14)
    nvg:FillColor(NanoColor(0.9, 0.9, 0.9, fadeAlpha))
    nvg:TextAlign(NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local s = GameOver.tracker
    local minutes = math.floor(s.survivalTime / 60)
    local seconds = math.floor(s.survivalTime % 60)
    local stats = {
        "存活时间:     " .. minutes .. "分" .. seconds .. "秒",
        "满足需求:     " .. s.demandsFulfilled .. "个",
        "建造建筑:     " .. s.buildingsBuilt .. "座",
        "服务NPC:      " .. s.maxNpcCount .. "人",
        "赌博胜率:     " .. s.gamblingWins .. "胜" .. s.gamblingLosses .. "负",
        "投放方块:     " .. s.blocksDropped .. "个",
        "最高等级:     Lv." .. s.maxUpgradeLevel,
    }
    for i, line in ipairs(stats) do
        nvg:Text(cx - panelW/2 + 30, panelY + 15 + (i - 1) * 28, line)
    end

    -- NPC Rating
    local ratingY = panelY + panelH + 30
    nvg:FontSize(14)
    nvg:FillColor(NanoColor(0.7, 0.7, 0.7, fadeAlpha))
    nvg:TextAlign(NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvg:Text(cx, ratingY, "NPC评价:")
    nvg:FontSize(18)
    nvg:FillColor(NanoColor(1, 0.9, 0.3, fadeAlpha))
    nvg:Text(cx, ratingY + 25, GameOver.ratingText)

    -- Score
    nvg:FontSize(24)
    nvg:FillColor(NanoColor(1, 1, 1, fadeAlpha))
    nvg:Text(cx, ratingY + 65, "总分: " .. GameOver.score)

    -- Restart button
    local btnY = ratingY + 110
    local btnW = 150
    local btnH = 40
    nvg:BeginPath()
    nvg:RoundedRect(cx - btnW/2, btnY - btnH/2, btnW, btnH, 6)
    nvg:FillColor(NanoColor(0.2, 0.6, 0.3, fadeAlpha))
    nvg:Fill()
    nvg:FontSize(18)
    nvg:FillColor(NanoColor(1, 1, 1, fadeAlpha))
    nvg:Text(cx, btnY, "再来一局")

    -- Quit button
    local quitY = btnY + 50
    nvg:BeginPath()
    nvg:RoundedRect(cx - btnW/2, quitY - btnH/2, btnW, btnH, 6)
    nvg:FillColor(NanoColor(0.5, 0.2, 0.2, fadeAlpha))
    nvg:Fill()
    nvg:FillColor(NanoColor(1, 1, 1, fadeAlpha))
    nvg:Text(cx, quitY, "退出")
end

-- Handle click on game over screen
function GameOver.handleClick(mx, my, screenW, screenH)
    if not GameOver.active then return nil end
    if GameOver.fadeTimer > 0 then return nil end

    local cx = screenW / 2
    local baseY = screenH * 0.15
    local panelH = 260
    local ratingY = baseY + 40 + panelH + 30
    local btnY = ratingY + 110
    local btnW = 150
    local btnH = 40

    -- Restart button
    if mx >= cx - btnW/2 and mx <= cx + btnW/2
       and my >= btnY - btnH/2 and my <= btnY + btnH/2 then
        return "restart"
    end

    -- Quit button
    local quitY = btnY + 50
    if mx >= cx - btnW/2 and mx <= cx + btnW/2
       and my >= quitY - btnH/2 and my <= quitY + btnH/2 then
        return "quit"
    end

    return nil
end

-- Reset for new game
function GameOver.reset()
    GameOver.active = false
    GameOver.score = 0
    GameOver.ratingText = ""
    GameOver.fadeTimer = 0
    GameOver.tracker = {
        survivalTime = 0,
        demandsFulfilled = 0,
        buildingsBuilt = 0,
        maxNpcCount = 0,
        gamblingWins = 0,
        gamblingLosses = 0,
        blocksDropped = 0,
        maxUpgradeLevel = 1,
        npcDeaths = 0,
    }
end

return GameOver
```

## Integrate into main script

### 1. Game state machine

```lua
local gameState = "playing"  -- "playing" | "gameover"

function Update(dt)
    if gameState == "playing" then
        -- Normal game update (world, NPCs, demands, gambling, etc.)
        updateGame(dt)

        -- Track stats
        GameOver.updateNpcCount(countAliveNpcs())
        GameOver.updateUpgradeLevel(Upgrade.level)

        -- Check game over
        if countAliveNpcs() == 0 and #npcs > 0 then
            GameOver.trigger(gameTime)
            gameState = "gameover"
        end
    elseif gameState == "gameover" then
        GameOver.update(dt)
    end
end
```

### 2. Restart function

```lua
function restartGame()
    -- Reset all systems
    Demand.reset()
    Upgrade.reset()
    Gambling.reset()
    GameOver.reset()

    -- Reset world
    world = World.new(Config, Items)

    -- Reset NPCs
    npcs = {}
    local cx = math.floor(Config.GRID / 2)
    local cz = math.floor(Config.GRID / 2)
    npcs[1] = NPC.new(Config, world, Items, cx, cz, npcs)
    NPC.buildQueue = buildQueue
    buildQueue = {}

    -- Reset game state
    gameTime = 0
    gameState = "playing"

    -- Reset camera
    -- (set camera to initial position)
end
```

### 3. Handle clicks on game over screen

```lua
function handleClick(mx, my)
    if gameState == "gameover" then
        local action = GameOver.handleClick(mx, my, screenW, screenH)
        if action == "restart" then restartGame()
        elseif action == "quit" then
            -- Exit game (platform-specific)
        end
        return
    end
    -- Normal click handling...
end
```

## Verification

1. Let all NPCs die. Game over screen should fade in over 2 seconds.
2. Stats should show survival time, demands fulfilled, buildings built, etc.
3. Chinese NPC rating should appear based on score (low score = insulting, high = reluctant praise).
4. Click "再来一局" button. Game should restart instantly (<1 second) with fresh state.
5. After restart, 1 NPC should appear, demand system should start fresh at tutorial step 1.
6. Click "退出" to exit.
7. Score should be higher for longer survival, more demands, more buildings.
