# STEP 09: Demon Gambling System + Disasters

## Task

Create `gambling.lua` that spawns a demon NPC at timed intervals. The demon forces the player into a mini-game (rock-paper-scissors or dice). Winning grants a temporary buff. Losing triggers a weather disaster. The world does NOT pause during gambling — NPCs keep starving.

## Create file: gambling.lua

```lua
-- gambling.lua — Demon Gambling System
-- A demon appears periodically, forcing the player to gamble.
-- World continues running during gambling (NPCs still decay).

local Gambling = {}

-- State
Gambling.active = false         -- is a gambling session in progress?
Gambling.phase = "none"         -- "approaching" | "choosing" | "playing" | "result" | "none"
Gambling.currentGame = nil      -- "rps" | "dice"
Gambling.result = nil           -- "win" | "lose" | nil
Gambling.gameState = {}         -- game-specific state

-- Demon
Gambling.demonX = 0
Gambling.demonZ = 0
Gambling.demonTargetX = 48
Gambling.demonTargetZ = 48
Gambling.demonSpeed = 8

-- Timing
Gambling.gameTime = 0
Gambling.nextTrigger = 180      -- first demon at 3 minutes
Gambling.interval = 150         -- seconds between demons
Gambling.intervalDecay = 0.85   -- each interval shrinks by 15%
Gambling.minInterval = 90       -- minimum 90 seconds
Gambling.triggerCount = 0

-- Active buff
Gambling.activeBuff = nil       -- {name, effect, remaining, duration}

-- Active disaster
Gambling.activeDisaster = nil   -- {name, effect, remaining, duration, originalValues}

-- Result display
Gambling.resultTimer = 0
Gambling.resultText = ""

----------------------------------------------------------------------------
-- BUFF DEFINITIONS
----------------------------------------------------------------------------
local BUFFS = {
    {
        name = "双料模式",
        desc = "Drop two material types per click",
        duration = 60,
        effect = "dual_material",
    },
    {
        name = "缓时光环",
        desc = "NPC hunger and temperature decay at 50% speed",
        duration = 120,
        effect = "slow_decay",
    },
    {
        name = "建造加速",
        desc = "NPC build speed x3",
        duration = 90,
        effect = "build_speed",
    },
}

----------------------------------------------------------------------------
-- DISASTER DEFINITIONS
----------------------------------------------------------------------------
local DISASTERS = {
    {
        name = "寒潮",
        duration = 30,
        apply = function(config)
            local orig = config.TEMP_DECAY
            config.TEMP_DECAY = config.TEMP_DECAY * 3
            return {TEMP_DECAY = orig}
        end,
        cleanup = function(config, orig)
            config.TEMP_DECAY = orig.TEMP_DECAY
        end,
    },
    {
        name = "饥荒",
        duration = 45,
        apply = function(config)
            local orig = config.HUNGER_DECAY
            config.HUNGER_DECAY = config.HUNGER_DECAY * 2
            return {HUNGER_DECAY = orig}
        end,
        cleanup = function(config, orig)
            config.HUNGER_DECAY = orig.HUNGER_DECAY
        end,
    },
}

----------------------------------------------------------------------------
-- UPDATE (call every frame)
----------------------------------------------------------------------------
function Gambling.update(dt, config, npcs, world)
    Gambling.gameTime = Gambling.gameTime + dt

    -- Update active buff timer
    if Gambling.activeBuff then
        Gambling.activeBuff.remaining = Gambling.activeBuff.remaining - dt
        if Gambling.activeBuff.remaining <= 0 then
            Gambling.removeBuff(config)
        end
    end

    -- Update active disaster timer
    if Gambling.activeDisaster then
        Gambling.activeDisaster.remaining = Gambling.activeDisaster.remaining - dt
        if Gambling.activeDisaster.remaining <= 0 then
            Gambling.removeDisaster(config)
        end
    end

    -- Result display timer
    if Gambling.resultTimer > 0 then
        Gambling.resultTimer = Gambling.resultTimer - dt
        if Gambling.resultTimer <= 0 then
            Gambling.phase = "none"
            Gambling.active = false
        end
    end

    -- Check trigger
    if not Gambling.active and Gambling.gameTime >= Gambling.nextTrigger then
        Gambling.startDemon(world)
    end

    -- Demon approach animation
    if Gambling.phase == "approaching" then
        local dx = Gambling.demonTargetX - Gambling.demonX
        local dz = Gambling.demonTargetZ - Gambling.demonZ
        local dist = math.sqrt(dx * dx + dz * dz)
        if dist < 2 then
            Gambling.phase = "choosing"
        else
            local speed = Gambling.demonSpeed * dt
            Gambling.demonX = Gambling.demonX + (dx / dist) * speed
            Gambling.demonZ = Gambling.demonZ + (dz / dist) * speed
        end
    end
end

function Gambling.startDemon(world)
    Gambling.active = true
    Gambling.phase = "approaching"
    Gambling.result = nil
    Gambling.triggerCount = Gambling.triggerCount + 1

    -- Spawn demon from map edge
    local side = math.random(4)
    local grid = 96
    if side == 1 then Gambling.demonX = 0; Gambling.demonZ = grid / 2
    elseif side == 2 then Gambling.demonX = grid; Gambling.demonZ = grid / 2
    elseif side == 3 then Gambling.demonX = grid / 2; Gambling.demonZ = 0
    else Gambling.demonX = grid / 2; Gambling.demonZ = grid end

    -- Target: map center
    Gambling.demonTargetX = grid / 2
    Gambling.demonTargetZ = grid / 2

    -- Schedule next trigger
    Gambling.interval = math.max(Gambling.minInterval, Gambling.interval * Gambling.intervalDecay)
    Gambling.nextTrigger = Gambling.gameTime + Gambling.interval
end

----------------------------------------------------------------------------
-- GAME SELECTION (player presses 1 or 2)
----------------------------------------------------------------------------
function Gambling.selectGame(choice)
    if Gambling.phase ~= "choosing" then return end
    if choice == 1 then
        Gambling.currentGame = "rps"
        Gambling.startRPS()
    elseif choice == 2 then
        Gambling.currentGame = "dice"
        Gambling.startDice()
    end
end

----------------------------------------------------------------------------
-- ROCK-PAPER-SCISSORS
-- Timeline: player picks -> 1.5s countdown -> reveal -> result
----------------------------------------------------------------------------
function Gambling.startRPS()
    Gambling.phase = "playing"
    Gambling.gameState = {
        subphase = "pick",      -- "pick" | "countdown" | "reveal" | "done"
        playerChoice = nil,     -- 1=rock, 2=scissors, 3=paper
        demonChoice = nil,
        countdownTimer = 0,
        revealTimer = 0,
    }
end

function Gambling.rpsPlayerPick(choice)
    local gs = Gambling.gameState
    if gs.subphase ~= "pick" then return end
    gs.playerChoice = choice
    gs.demonChoice = math.random(3)
    gs.subphase = "countdown"
    gs.countdownTimer = 1.5
end

function Gambling.updateRPS(dt)
    local gs = Gambling.gameState
    if gs.subphase == "countdown" then
        gs.countdownTimer = gs.countdownTimer - dt
        if gs.countdownTimer <= 0 then
            gs.subphase = "reveal"
            gs.revealTimer = 1.5
        end
    elseif gs.subphase == "reveal" then
        gs.revealTimer = gs.revealTimer - dt
        if gs.revealTimer <= 0 then
            -- Determine winner
            local p, d = gs.playerChoice, gs.demonChoice
            if p == d then
                Gambling.result = "lose"  -- tie = demon wins
            elseif (p == 1 and d == 2) or (p == 2 and d == 3) or (p == 3 and d == 1) then
                Gambling.result = "win"
            else
                Gambling.result = "lose"
            end
            gs.subphase = "done"
            Gambling.applyResult()
        end
    end
end

-- RPS choice names for display
Gambling.RPS_NAMES = {"石头", "剪刀", "布"}

----------------------------------------------------------------------------
-- DICE GAME
-- Timeline: pick big/small -> 3s blow phase (click for bonus) -> roll -> result
-- 10% demon cheat: if player would win, demon re-rolls
----------------------------------------------------------------------------
function Gambling.startDice()
    Gambling.phase = "playing"
    Gambling.gameState = {
        subphase = "pick",       -- "pick" | "blow" | "rolling" | "result" | "cheat" | "done"
        playerGuess = nil,       -- "big" | "small"
        blowClicks = 0,
        blowTimer = 3.0,
        rollTimer = 0,
        dice1 = 0,
        dice2 = 0,
        diceSum = 0,
        isBig = false,
        cheated = false,
        cheatTimer = 0,
    }
end

function Gambling.dicePickGuess(guess)
    local gs = Gambling.gameState
    if gs.subphase ~= "pick" then return end
    gs.playerGuess = guess  -- "big" or "small"
    gs.subphase = "blow"
    gs.blowTimer = 3.0
    gs.blowClicks = 0
end

function Gambling.diceBlowClick()
    local gs = Gambling.gameState
    if gs.subphase ~= "blow" then return end
    gs.blowClicks = gs.blowClicks + 1
end

function Gambling.updateDice(dt)
    local gs = Gambling.gameState
    if gs.subphase == "blow" then
        gs.blowTimer = gs.blowTimer - dt
        if gs.blowTimer <= 0 then
            gs.subphase = "rolling"
            gs.rollTimer = 1.5
            -- Roll dice
            gs.dice1 = math.random(6)
            gs.dice2 = math.random(6)
            gs.diceSum = gs.dice1 + gs.dice2
            gs.isBig = gs.diceSum >= 7
        end
    elseif gs.subphase == "rolling" then
        gs.rollTimer = gs.rollTimer - dt
        if gs.rollTimer <= 0 then
            -- Apply blow bonus: each click = +1% win chance (max +10%)
            local bonus = math.min(10, gs.blowClicks)
            local playerCorrect = (gs.playerGuess == "big" and gs.isBig)
                or (gs.playerGuess == "small" and not gs.isBig)

            -- Demon cheat: 10% chance to re-roll if player would win
            if playerCorrect and not gs.cheated and math.random() < 0.10 then
                gs.cheated = true
                gs.subphase = "cheat"
                gs.cheatTimer = 1.5
                -- Re-roll
                gs.dice1 = math.random(6)
                gs.dice2 = math.random(6)
                gs.diceSum = gs.dice1 + gs.dice2
                gs.isBig = gs.diceSum >= 7
                return
            end

            -- Apply blow bonus (random chance to flip result in player's favor)
            if not playerCorrect and math.random(100) <= bonus then
                -- Lucky blow! Flip one die
                if gs.playerGuess == "big" then
                    gs.dice1 = math.max(gs.dice1, 4 + math.random(2))
                else
                    gs.dice1 = math.min(gs.dice1, 1 + math.random(2))
                end
                gs.diceSum = gs.dice1 + gs.dice2
                gs.isBig = gs.diceSum >= 7
                playerCorrect = (gs.playerGuess == "big" and gs.isBig)
                    or (gs.playerGuess == "small" and not gs.isBig)
            end

            Gambling.result = playerCorrect and "win" or "lose"
            gs.subphase = "done"
            Gambling.applyResult()
        end
    elseif gs.subphase == "cheat" then
        gs.cheatTimer = gs.cheatTimer - dt
        if gs.cheatTimer <= 0 then
            local playerCorrect = (gs.playerGuess == "big" and gs.isBig)
                or (gs.playerGuess == "small" and not gs.isBig)
            Gambling.result = playerCorrect and "win" or "lose"
            gs.subphase = "done"
            Gambling.applyResult()
        end
    end
end

----------------------------------------------------------------------------
-- APPLY RESULT
----------------------------------------------------------------------------
function Gambling.applyResult()
    Gambling.resultTimer = 2.5  -- show result for 2.5 seconds
    if Gambling.result == "win" then
        local buff = BUFFS[math.random(#BUFFS)]
        Gambling.activeBuff = {
            name = buff.name,
            effect = buff.effect,
            remaining = buff.duration,
            duration = buff.duration,
        }
        Gambling.resultText = "你赢了！获得: " .. buff.name .. " (" .. buff.duration .. "秒)"
        Gambling.applyBuff()
    else
        local disaster = DISASTERS[math.random(#DISASTERS)]
        Gambling.resultText = "你输了！灾害: " .. disaster.name .. " (" .. disaster.duration .. "秒)"
        Gambling.applyDisaster(disaster)
    end
end

function Gambling.applyBuff()
    -- Buff effects are checked in game logic:
    -- "dual_material": in dropItem(), drop a second random needed material type
    -- "slow_decay": multiply hunger/temp decay by 0.5
    -- "build_speed": multiply NPC step time by 0.33
end

function Gambling.removeBuff(config)
    if not Gambling.activeBuff then return end
    -- Undo buff effects if they modified config
    if Gambling.activeBuff.effect == "slow_decay" then
        -- Decay rates return to normal (handled by checking activeBuff existence)
    elseif Gambling.activeBuff.effect == "build_speed" then
        -- Step time returns to normal
    end
    Gambling.activeBuff = nil
end

function Gambling.applyDisaster(disaster)
    local config = require("config")
    local originalValues = disaster.apply(config)
    Gambling.activeDisaster = {
        name = disaster.name,
        remaining = disaster.duration,
        duration = disaster.duration,
        cleanup = disaster.cleanup,
        originalValues = originalValues,
    }
end

function Gambling.removeDisaster(config)
    if not Gambling.activeDisaster then return end
    if Gambling.activeDisaster.cleanup then
        Gambling.activeDisaster.cleanup(config, Gambling.activeDisaster.originalValues)
    end
    Gambling.activeDisaster = nil
end

-- Check if a buff effect is active
function Gambling.hasEffect(effectName)
    return Gambling.activeBuff and Gambling.activeBuff.effect == effectName
end

-- Handle key press during gambling
function Gambling.handleKey(key)
    if Gambling.phase == "choosing" then
        if key == "1" then Gambling.selectGame(1) end  -- RPS
        if key == "2" then Gambling.selectGame(2) end  -- Dice
    elseif Gambling.phase == "playing" then
        if Gambling.currentGame == "rps" then
            local gs = Gambling.gameState
            if gs.subphase == "pick" then
                if key == "1" then Gambling.rpsPlayerPick(1) end  -- rock
                if key == "2" then Gambling.rpsPlayerPick(2) end  -- scissors
                if key == "3" then Gambling.rpsPlayerPick(3) end  -- paper
            end
        elseif Gambling.currentGame == "dice" then
            local gs = Gambling.gameState
            if gs.subphase == "pick" then
                if key == "1" then Gambling.dicePickGuess("big") end
                if key == "2" then Gambling.dicePickGuess("small") end
            end
        end
    end
end

-- Handle mouse click during gambling (for dice blow phase)
function Gambling.handleClick()
    if Gambling.phase == "playing" and Gambling.currentGame == "dice" then
        Gambling.diceBlowClick()
    end
end

-- Update game logic (call from main update after Gambling.update)
function Gambling.updateGame(dt)
    if Gambling.phase ~= "playing" then return end
    if Gambling.currentGame == "rps" then
        Gambling.updateRPS(dt)
    elseif Gambling.currentGame == "dice" then
        Gambling.updateDice(dt)
    end
end

-- Reset for new game
function Gambling.reset()
    Gambling.active = false
    Gambling.phase = "none"
    Gambling.currentGame = nil
    Gambling.result = nil
    Gambling.gameState = {}
    Gambling.gameTime = 0
    Gambling.nextTrigger = 180
    Gambling.interval = 150
    Gambling.triggerCount = 0
    Gambling.activeBuff = nil
    Gambling.activeDisaster = nil
    Gambling.resultTimer = 0
end

return Gambling
```

## Integrate into main script

### 1. Key handling during gambling

```lua
-- In your key handler, check gambling first:
function handleKeyPress(key)
    if Gambling.active then
        Gambling.handleKey(key)
        return  -- block normal input during gambling
    end
    -- ... normal key handling ...
end
```

### 2. Click handling during gambling

```lua
function handleClick()
    if Gambling.active then
        Gambling.handleClick()
        -- Still allow normal drops during gambling (world doesn't pause!)
    end
    dropItem()
end
```

### 3. Update loop

```lua
-- In Update(dt):
Gambling.update(dt, Config, npcs, world)
Gambling.updateGame(dt)

-- Apply slow_decay buff
if Gambling.hasEffect("slow_decay") then
    -- Modify decay multiplier (temporary, checked each frame)
    -- This is handled by NPC update checking Gambling.hasEffect()
end
```

### 4. NPC reaction to demon

```lua
-- When demon enters "approaching" phase, set NPC dialogue:
if Gambling.phase == "approaching" then
    for _, npc in ipairs(npcs) do
        if not npc.dead then
            local Dialogue = require("dialogue")
            npc.dialogueLine = Dialogue.getLine("DEMON_APPEAR", nil, npc, {})
            npc.dialogueTimer = 5
        end
    end
end
```

## Render Gambling UI

Render a semi-transparent overlay using NanoVG. The world is visible behind it.

```lua
function renderGamblingUI(nvg, screenW, screenH, gameTime)
    if not Gambling.active then return end

    -- Semi-transparent background
    nvg:BeginPath()
    nvg:Rect(0, 0, screenW, screenH)
    nvg:FillColor(NanoColor(0, 0, 0, 0.5))
    nvg:Fill()

    local cx, cy = screenW / 2, screenH / 2

    if Gambling.phase == "choosing" then
        -- Game selection
        nvg:FontSize(28)
        nvg:FillColor(NanoColor(1, 0.3, 0.2, 1))
        nvg:TextAlign(NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvg:Text(cx, cy - 80, "恶魔的游戏")

        nvg:FontSize(18)
        nvg:FillColor(NanoColor(1, 1, 1, 0.9))
        nvg:Text(cx, cy - 30, "[1] 猜拳  胜率50%")
        nvg:Text(cx, cy + 10, "[2] 骰子  胜率~50%")

        nvg:FontSize(12)
        nvg:FillColor(NanoColor(1, 0.4, 0.3, 0.8))
        nvg:Text(cx, cy + 60, "NPC仍在消耗资源！")

    elseif Gambling.phase == "playing" then
        if Gambling.currentGame == "rps" then
            renderRPSUI(nvg, cx, cy, gameTime)
        elseif Gambling.currentGame == "dice" then
            renderDiceUI(nvg, cx, cy, gameTime)
        end

    elseif Gambling.resultTimer > 0 then
        -- Result display
        nvg:FontSize(24)
        if Gambling.result == "win" then
            nvg:FillColor(NanoColor(0.3, 1, 0.3, 1))
        else
            nvg:FillColor(NanoColor(1, 0.3, 0.3, 1))
        end
        nvg:TextAlign(NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvg:Text(cx, cy, Gambling.resultText)
    end
end

function renderRPSUI(nvg, cx, cy, gameTime)
    local gs = Gambling.gameState
    nvg:FontSize(22)
    nvg:FillColor(NanoColor(1, 1, 1, 0.95))
    nvg:TextAlign(NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    if gs.subphase == "pick" then
        nvg:Text(cx, cy - 40, "出拳！")
        nvg:FontSize(18)
        nvg:Text(cx, cy + 10, "[1]石头  [2]剪刀  [3]布")
    elseif gs.subphase == "countdown" then
        local count = math.ceil(gs.countdownTimer / 0.5)
        local texts = {"一...", "二...", "三..."}
        nvg:FontSize(36)
        nvg:Text(cx, cy, texts[math.min(count, 3)] or "...")
    elseif gs.subphase == "reveal" then
        local pName = Gambling.RPS_NAMES[gs.playerChoice] or "?"
        local dName = Gambling.RPS_NAMES[gs.demonChoice] or "?"
        nvg:FontSize(28)
        nvg:Text(cx, cy - 20, pName .. "  vs  " .. dName)
    end
end

function renderDiceUI(nvg, cx, cy, gameTime)
    local gs = Gambling.gameState
    nvg:FontSize(22)
    nvg:FillColor(NanoColor(1, 1, 1, 0.95))
    nvg:TextAlign(NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    if gs.subphase == "pick" then
        nvg:Text(cx, cy - 40, "掷骰子！")
        nvg:FontSize(18)
        nvg:Text(cx, cy + 10, "[1] 猜大    [2] 猜小")
    elseif gs.subphase == "blow" then
        nvg:Text(cx, cy - 40, "吹骰子！快点击！")
        -- Wind bar
        local barW = 200
        local fillW = barW * math.min(1, gs.blowClicks / 10)
        local bonus = math.min(10, gs.blowClicks)
        nvg:BeginPath()
        nvg:Rect(cx - barW/2, cy, barW, 20)
        nvg:FillColor(NanoColor(0.3, 0.3, 0.3, 0.8))
        nvg:Fill()
        nvg:BeginPath()
        nvg:Rect(cx - barW/2, cy, fillW, 20)
        nvg:FillColor(NanoColor(0.3, 0.8, 1, 0.9))
        nvg:Fill()
        nvg:FontSize(14)
        nvg:FillColor(NanoColor(1, 1, 1, 0.9))
        nvg:Text(cx, cy + 40, "风力: +" .. bonus .. "%")
        -- Timer
        nvg:Text(cx, cy - 60, string.format("%.1f秒", gs.blowTimer))
    elseif gs.subphase == "rolling" then
        nvg:FontSize(36)
        -- Animated dice (random numbers while rolling)
        local d1 = math.random(6)
        local d2 = math.random(6)
        nvg:Text(cx, cy, "[" .. d1 .. "] [" .. d2 .. "]")
    elseif gs.subphase == "cheat" then
        nvg:FontSize(22)
        nvg:FillColor(NanoColor(1, 0.3, 0.2, 1))
        nvg:Text(cx, cy - 20, "等等...不对！重来！")
        nvg:FontSize(14)
        nvg:Text(cx, cy + 20, "恶魔作弊了！")
    elseif gs.subphase == "done" then
        nvg:FontSize(28)
        local bigSmall = gs.isBig and "大！" or "小！"
        nvg:Text(cx, cy - 30, "[" .. gs.dice1 .. "] [" .. gs.dice2 .. "] = " .. gs.diceSum)
        nvg:Text(cx, cy + 10, bigSmall)
    end
end
```

## Verification

1. Wait 3 minutes. A demon should appear from the map edge and walk toward center.
2. NPCs should show Chinese panic dialogue ("完了完了完了...").
3. When demon arrives, game selection overlay appears (semi-transparent, world visible behind).
4. Press 1 for RPS. Pick rock/scissors/paper. See countdown, then reveal, then result.
5. Press 2 for Dice. Pick big/small. Blow phase: click rapidly, wind bar fills. Dice roll. Result.
6. Win: buff text appears. Buff timer shows in game.
7. Lose: disaster text appears. Config parameters change (verify TEMP_DECAY or HUNGER_DECAY doubled).
8. During gambling, NPCs in background continue to lose hunger (world not paused).
9. After result, gambling overlay disappears after 2.5 seconds.
10. Next demon appears at reduced interval (~127 seconds after first).
