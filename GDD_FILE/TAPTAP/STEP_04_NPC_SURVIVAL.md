# STEP 04: Enable NPC Survival Pressure

## Task

Remove the MVP vitals lock in `npc.lua` so NPCs can actually die from hunger and cold. Adjust survival parameters to create gameplay tension. Add death flow with Chinese last words.

## Prerequisites

- `dialogue.lua` from STEP_02 must exist

## Modify: npc.lua

### 1. Remove MVP vitals lock

Find and DELETE these 4 lines in `NPC:update(dt)` (around line 166-170):

```lua
-- DELETE THESE LINES:
self.hp = self.cfg.HP_MAX
self.hunger = self.cfg.HUNGER_MAX
self.stamina = self.cfg.STAMINA_MAX
self.temperature = self.cfg.TEMP_MAX
```

### 2. Set new NPC initial values

In `NPC.new()`, change initial values so new NPCs have a survival buffer:

```lua
-- Change these initial values in NPC.new():
self.hunger = config.HUNGER_MAX * 0.8      -- 80% full (was 100%)
self.temperature = config.TEMP_MAX         -- full warmth
self.stamina = config.STAMINA_MAX * 0.9    -- 90% stamina
self.hp = config.HP_MAX                    -- full HP
```

## Modify: config.lua

### 3. Adjust survival parameters

Change these values in `config.lua`:

```lua
-- HUNGER: ~90 seconds from full to death
C.HUNGER_DECAY = 1.1           -- was 0.2. Now: 100/1.1 = 91 seconds to starve
C.HUNGER_EAT_RESTORE = 40     -- keep same. Each apple buys ~36 seconds

-- TEMPERATURE: ~45 seconds to freeze at night without shelter
C.TEMP_DECAY = 2.2             -- was 1.0. Now: 100/2.2 = 45 seconds to freeze
C.TEMP_REGEN = 1.5             -- keep same (daytime recovery)
C.TEMP_SHELTER = 4.0           -- keep same (shelter recovery)

-- All other values remain unchanged
```

## Modify: npc.lua — Death Flow

### 4. Enhance death logic

Find the death check in `NPC:update(dt)` (the `if self.temperature <= 0 or self.hunger <= 0 or self.hp <= 0 then` block). Replace it with:

```lua
if self.temperature <= 0 or self.hunger <= 0 or self.hp <= 0 then
    -- Determine death cause
    local deathCause = "hp"
    if self.hunger <= 0 then deathCause = "hunger"
    elseif self.temperature <= 0 then deathCause = "cold" end

    -- Chinese death cause text
    local DEATH_CAUSE_TEXT = {
        hunger = "饿死了",
        cold = "冻死了",
        hp = "伤重不治",
    }
    self.deathCauseText = DEATH_CAUSE_TEXT[deathCause] or "死了"

    -- Last words from dialogue system
    local Dialogue = require("dialogue")
    self.deathLine = Dialogue.getLine("DEATH", nil, self, {})

    -- Notify other NPCs (sadness)
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead then
            local rel = other:_getRelation(self)
            if rel.affinity >= self.cfg.AFFINITY_FRIEND then
                other.moodValue = math.max(-100, other.moodValue - 30)
            end
        end
    end

    -- Release building ownership
    if self.blueprint then
        self.blueprint = nil
    end
    if self.helpingBlueprint then
        self.helpingBlueprint = nil
    end

    self.dead = true
    self.deathTime = self.world.time
    return
end
```

## Add: Tutorial Protection Period

### 5. Slow survival decay in first 60 seconds

Add a protection multiplier that reduces hunger/temp decay during the tutorial:

```lua
-- Add this helper function to npc.lua or a shared utility:
function NPC:getSurvivalMultiplier()
    local gameTime = self.world.time or 0
    local protectionDuration = 60   -- first 60 seconds
    local transitionDuration = 10   -- 10 second smooth transition

    if gameTime < protectionDuration then
        return 0.3  -- only 30% decay during tutorial
    elseif gameTime < protectionDuration + transitionDuration then
        local t = (gameTime - protectionDuration) / transitionDuration
        return 0.3 + 0.7 * t  -- smooth transition from 30% to 100%
    else
        return 1.0
    end
end
```

Then modify the hunger decay line in `NPC:update(dt)`:
```lua
-- Change this line:
self.hunger = math.max(self.hunger - self.cfg.HUNGER_DECAY * dt, 0)
-- To this:
self.hunger = math.max(self.hunger - self.cfg.HUNGER_DECAY * self:getSurvivalMultiplier() * dt, 0)
```

And modify the temperature decay similarly:
```lua
-- In the night temperature section, multiply TEMP_DECAY by the same multiplier:
if self.world.isNight then
    local decay = indoors and -self.cfg.TEMP_SHELTER or self.cfg.TEMP_DECAY * self:getSurvivalMultiplier()
    self.temperature = self.temperature + (indoors and self.cfg.TEMP_SHELTER or -decay) * dt
end
```

## Add: Game Over Check

### 6. Check if all NPCs are dead

Add this function and call it whenever an NPC dies:

```lua
-- Add to main script or a shared module:
local gameOver = false

function checkGameOver(npcs)
    if gameOver then return end
    local alive = 0
    for _, npc in ipairs(npcs) do
        if not npc.dead then alive = alive + 1 end
    end
    if alive == 0 and #npcs > 0 then
        gameOver = true
        -- Trigger game over screen (implemented in STEP_11)
        onGameOver()
    end
end
```

Call `checkGameOver(npcs)` at the end of each update frame, after all NPC updates.

## Verification

1. Start the game. Do NOT drop any food.
2. After ~90 seconds, the NPC should die from hunger.
3. The NPC's `deathCauseText` should be "饿死了" and `deathLine` should be a Chinese last-words string.
4. Start a new game. Build a shelter for the NPC. Wait for night.
5. Spawn a second NPC (N key) who has no shelter. The unsheltered NPC should die from cold within ~45 seconds of nightfall.
6. When all NPCs are dead, `gameOver` should be `true`.
7. During the first 60 seconds, hunger decay should be ~30% of normal (tutorial protection).
