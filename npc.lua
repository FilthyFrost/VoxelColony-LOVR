-- npc.lua — Utility AI NPC with personality, cooperative building, instant gift feedback
--
-- Cooperative building: multiple NPCs share one blueprint via simple currentStep pointer.
-- No complex claim system — NPCs advance the shared pointer sequentially.

local Blueprint = require("blueprint")
local Pathfind = require("pathfind")
local TemplateLib = require("templatelib")
-- Safe log: try to use debuglog, fallback to no-op
local log = {write = function() end}
pcall(function() log = require("debuglog") end)

local NPC = {}
NPC.__index = NPC

local TASK_TIMEOUT = 20

local TRAIT_POOL = {"diligent", "lazy", "greedy", "explorer", "shy", "social"}

local THOUGHT_MAP = {
    continue_build = {icon = "hammer", text = "Building..."},
    help_build     = {icon = "hands",  text = "Helping!"},
    build_shelter  = {icon = "house",  text = "Need shelter!"},
    eat            = {icon = "apple",  text = "Hungry!"},
    go_home        = {icon = "moon",   text = "Going home"},
    stockpile      = {icon = "chest",  text = "Stockpiling"},
    furnish_home   = {icon = "chair",  text = "Furnishing"},
    build_bigger   = {icon = "castle", text = "Expanding!"},
    demolishing    = {icon = "pick",   text = "Demolishing!"},
    gift_received  = {icon = "heart",  text = "Thank you!"},
    need_wall      = {icon = "brick",  text = "Need walls!"},
    need_roof      = {icon = "roof",   text = "Need roof!"},
    need_food      = {icon = "apple",  text = "Need food!"},
    socialize      = {icon = "chat",   text = "Let's chat!"},
    attacking      = {icon = "fist",   text = "Get out!"},
    fighting       = {icon = "fight",  text = "!!!"},
    lost_home      = {icon = "sad",    text = "No..."},
    helping        = {icon = "shield", text = "Stop!"},
    fleeing        = {icon = "run",    text = "!"},
    sleep          = {icon = "bed",    text = "Sleepy..."},
    sleeping       = {icon = "zzz",    text = "Zzz"},
    sleep_exhausted= {icon = "zzz",    text = "So tired!"},
    idle           = {icon = "dots",   text = "..."},
}

function NPC.new(config, world, items, startX, startZ, allNpcs)
    local self = setmetatable({}, NPC)
    self.cfg = config
    self.world = world
    self.items = items
    self.allNpcs = allNpcs

    self.gx = math.floor(startX)
    self.gz = math.floor(startZ)
    self.gy = 0
    self.x, self.y, self.z = self.gx, 0, self.gz
    self.homeX, self.homeZ = self.gx, self.gz

    -- Identity
    self.npcId = tostring(os.clock()) .. "_" .. tostring(math.random(10000))
    self.name = "Ant-" .. (#allNpcs + 1)
    self.shirtColor = {math.random() * 0.5 + 0.2, math.random() * 0.5 + 0.2, math.random() * 0.5 + 0.2}
    self.pantsColor = {math.random() * 0.3 + 0.15, math.random() * 0.3 + 0.15, math.random() * 0.3 + 0.15}

    -- Personality
    self.traits = {}
    local pool = {}
    for _, t in ipairs(TRAIT_POOL) do pool[#pool + 1] = t end
    for _ = 1, math.random(1, 2) do
        if #pool == 0 then break end
        local idx = math.random(#pool)
        self.traits[pool[idx]] = true
        table.remove(pool, idx)
    end

    -- Survival
    self.temperature = config.TEMP_MAX * 0.5
    self.hunger = config.HUNGER_MAX
    self.dead = false

    -- HP
    self.hp = config.HP_MAX
    self.injured = false

    -- Stamina / Sleep
    self.stamina = config.STAMINA_MAX
    self.sleeping = false
    self.sleepPos = nil        -- {x, z} for rendering
    self.sleepQuality = 0      -- 0=ground, 1=indoor, 2=bed
    self.outdoorSleepCount = 0 -- times slept outdoors (feeds desperation)

    -- Combat
    self.desperation = 0       -- 0-100
    self.fightTarget = nil     -- NPC ref during combat
    self.fightTimer = 0        -- combat animation countdown

    -- Social
    self.socialNeed = 80
    self.relationships = {}    -- {[otherNpcId] = {affinity, interactions, lastTime, proximityTimer}}
    self.chatTarget = nil
    self.chatTimer = 0

    -- Desires
    self.comfort = 0
    self.ambition = 20
    self.gratitude = 0

    -- Mood & thought
    self.mood = "neutral"
    self.moodValue = 0          -- -100 to +100
    self.moodFactors = {}       -- list of current mood factors
    self.thought = nil
    self.thoughtTimer = 0

    -- Gift feedback
    self.giftCooldown = 0
    self.recentGifts = {}
    self.excited = false
    self.excitedTimer = 0
    self.lookAtX = nil
    self.lookAtZ = nil

    -- Resources
    self.resourceCache = world:countLooseByType()  -- initialize immediately
    self.resourceCacheTimer = 3

    -- Pathfinding
    self.path = nil
    self.pathIdx = 1
    self.pathTarget = nil
    self.pathRecalcTimer = 0

    -- Building
    self.carriedBlock = nil
    self.blueprint = nil
    self.shelterVerified = false
    self.buildingsOwned = {}
    self.helpingBlueprint = nil  -- cooperative: reference to another NPC's blueprint
    self.buildStep = nil         -- persistent step index (survives re-think)
    self.buildStepBp = nil       -- which blueprint the step belongs to
    self.buildStalled = false    -- true when no executable build step (missing materials)

    -- Task
    self.task = nil
    self.stepTimer = 0
    self.thinkTimer = 3 + math.random() * 2  -- wait for materials to land before first think

    return self
end

----------------------------------------------------------------------------
-- UPDATE
----------------------------------------------------------------------------
function NPC:update(dt)
    if self.dead then return end

    self.hunger = math.max(self.hunger - self.cfg.HUNGER_DECAY * dt, 0)
    local indoors = self.world:hasRoof(self.gx, self.gz)
        and self.shelterVerified and self.blueprint
        and self.gx >= self.blueprint.originX
        and self.gx < self.blueprint.originX + self.blueprint.width
        and self.gz >= self.blueprint.originZ
        and self.gz < self.blueprint.originZ + self.blueprint.depth
    if self.world.isNight then
        self.temperature = self.temperature + (indoors and self.cfg.TEMP_SHELTER or -self.cfg.TEMP_DECAY) * dt
    else
        self.temperature = self.temperature + self.cfg.TEMP_REGEN * dt
    end
    self.temperature = math.min(self.temperature, self.cfg.TEMP_MAX)

    self.comfort = math.max(0, self.comfort - self.cfg.COMFORT_DECAY * dt)
    self.ambition = math.min(self.cfg.AMBITION_MAX, self.ambition + self.cfg.AMBITION_GROWTH * dt)
    self.gratitude = math.max(0, self.gratitude - self.cfg.GRATITUDE_DECAY * dt)

    -- HP regen
    if self.hp < self.cfg.HP_MAX then
        local hpRegen = indoors and self.cfg.HP_REGEN_SHELTERED or self.cfg.HP_REGEN
        self.hp = math.min(self.cfg.HP_MAX, self.hp + hpRegen * dt)
    end
    self.injured = self.hp < self.cfg.HP_INJURED_THRESHOLD

    -- Death (extended with HP)
    if self.temperature <= 0 or self.hunger <= 0 or self.hp <= 0 then
        -- Notify friends of death
        for _, other in ipairs(self.allNpcs) do
            if other ~= self and not other.dead then
                local rel = other:_getRelation(self)
                if rel.affinity >= self.cfg.AFFINITY_FRIEND then
                    other.moodValue = math.max(-100, other.moodValue - 30)
                end
            end
        end
        log.write("npc", "%s DIED hp:%.0f hunger:%.0f temp:%.0f", self.name, self.hp, self.hunger, self.temperature)
        self.dead = true; return
    end

    -- Stamina / Sleep system
    if self.sleeping then
        -- Recover stamina based on sleep quality
        local regenRate
        if self.sleepQuality == 2 then
            regenRate = self.cfg.STAMINA_REGEN_SLEEP_BED
        elseif self.sleepQuality == 1 then
            regenRate = self.cfg.STAMINA_REGEN_SLEEP_INDOOR
        else
            regenRate = self.cfg.STAMINA_REGEN_SLEEP_GROUND
        end
        self.stamina = math.min(self.cfg.STAMINA_MAX, self.stamina + regenRate * dt)

        -- Smooth render position (keep interpolating even while sleeping)
        local spd = 8 * dt
        self.x = self.x + (self.gx - self.x) * spd
        self.y = self.y + (self.gy - self.y) * spd
        self.z = self.z + (self.gz - self.z) * spd

        -- Wake up conditions:
        -- 1. Stamina full  2. Hungry  3. Daytime (don't sleep through the day)
        local shouldWake = self.stamina >= self.cfg.STAMINA_WAKEUP
            or self.hunger < self.cfg.STAMINA_HUNGRY_WAKEUP
            or (not self.world.isNight and self.stamina > self.cfg.STAMINA_TIRED)
        if shouldWake then
            self.sleeping = false
            self.sleepPos = nil
            self.task = nil
            self.thinkTimer = 0
        end
        return  -- Skip all other logic while sleeping
    end

    -- Stamina decay (when awake)
    local staminaDecay
    if self.task then
        local t = self.task.type
        if t == "place_block" or t == "break_block" or t == "fetch_block" then
            staminaDecay = self.cfg.STAMINA_DECAY_WORK
        elseif t == "go_sleep" then
            staminaDecay = self.cfg.STAMINA_DECAY_WALK
        else
            staminaDecay = self.cfg.STAMINA_DECAY_WALK
        end
    else
        staminaDecay = self.cfg.STAMINA_DECAY_IDLE
    end
    self.stamina = math.max(0, self.stamina - staminaDecay * dt)

    -- RimWorld threshold interrupt: forced collapse when exhausted
    if self.stamina < self.cfg.STAMINA_EXHAUSTED then
        self.sleeping = true
        self.sleepPos = {x = self.gx, z = self.gz}
        self:_dropBlock()
        self.task = nil
        -- Determine sleep quality at current position
        if indoors then
            self.sleepQuality = self:_findNearbyBed() and 2 or 1
        else
            self.sleepQuality = 0
            self.outdoorSleepCount = self.outdoorSleepCount + 1
        end
        log.write("npc", "%s COLLAPSED sta:%.0f at:(%d,%d) quality:%d", self.name, self.stamina, self.gx, self.gz, self.sleepQuality)
        self:_setThought("sleep_exhausted")
        return
    end

    self.resourceCacheTimer = self.resourceCacheTimer - dt
    if self.resourceCacheTimer <= 0 then
        local oldCache = self.resourceCache
        self.resourceCache = self.world:countLooseByType()
        self.resourceCacheTimer = 3
        -- Reset buildStalled if new materials appeared (player dropped blocks)
        if self.buildStalled then
            for k, v in pairs(self.resourceCache) do
                if v > 0 and (not oldCache[k] or oldCache[k] == 0) then
                    self.buildStalled = false
                    self.thinkTimer = 0  -- re-think immediately
                    break
                end
            end
        end
    end

    self.giftCooldown = self.giftCooldown - dt
    if self.giftCooldown <= 0 then
        self:_detectGifts()
        self.giftCooldown = self.cfg.GIFT_DETECT_COOLDOWN
    end

    if self.excited then
        self.excitedTimer = self.excitedTimer - dt
        if self.excitedTimer <= 0 then
            self.excited = false
            self.lookAtX = nil
            self.lookAtZ = nil
        end
    end

    -- Social relationships (throttled: every 1 second, not every frame)
    self.socialTimer = (self.socialTimer or 0) - dt
    if self.socialTimer <= 0 then
        self:_updateRelationships(1.0)  -- pass accumulated dt
        self:_updateDesperation()
        self.socialTimer = 1.0
    else
        -- Still decay social need every frame (cheap)
        self.socialNeed = math.max(0, self.socialNeed - self.cfg.SOCIAL_DECAY * dt)
    end

    if self.thoughtTimer > 0 then self.thoughtTimer = self.thoughtTimer - dt end
    self:_updateMood()

    -- === PHASE 1: Eject from solid (MTV algorithm) ===
    -- If NPC's grid position is inside a solid block, teleport to nearest free cell
    if self.world:isSolid(self.gx, self.gy, self.gz) then
        local found = false
        for r = 1, 5 do
            for dx = -r, r do
                for dz = -r, r do
                    if math.abs(dx) == r or math.abs(dz) == r then
                        local nx, nz = self.gx + dx, self.gz + dz
                        if self.world:canStandAt(nx, self.gy, nz) then
                            self.gx, self.gz = nx, nz
                            self.x, self.z = nx, nz  -- snap visual too
                            self.path = nil
                            found = true
                            break
                        end
                    end
                end
                if found then break end
            end
            if found then break end
        end
    end

    -- === PHASE 2: NPC-NPC separation force (Reynolds 1/r) ===
    -- Prevents multiple NPCs from stacking on the same position
    local sepX, sepZ = 0, 0
    local sepRadius = 1.2
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead then
            local dx = self.x - other.x
            local dz = self.z - other.z
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist < sepRadius and dist > 0.01 then
                local strength = (sepRadius - dist) / sepRadius  -- 0..1, stronger when closer
                sepX = sepX + (dx / dist) * strength * 2.0
                sepZ = sepZ + (dz / dist) * strength * 2.0
            end
        end
    end

    -- === PHASE 3: Interpolation + separation ===
    local spd = 8 * dt
    self.x = self.x + (self.gx - self.x) * spd + sepX * dt
    self.y = self.y + (self.gy - self.y) * spd
    self.z = self.z + (self.gz - self.z) * spd + sepZ * dt

    -- === PHASE 4: Block collision (axis-ordered: Y, X, Z) ===
    -- NPC body is 0.6 wide cylinder, check edges against solid blocks
    local halfW = 0.3
    for dy = 0, 1 do
        local cy = self.gy + dy
        -- X axis first
        local cellZ = math.floor(self.z + 0.5)
        local rightCell = math.floor(self.x + halfW + 0.5)
        if rightCell ~= self.gx and self.world:isSolid(rightCell, cy, cellZ) then
            self.x = math.min(self.x, rightCell - 0.5 - halfW)
        end
        local leftCell = math.floor(self.x - halfW + 0.5)
        if leftCell ~= self.gx and self.world:isSolid(leftCell, cy, cellZ) then
            self.x = math.max(self.x, leftCell + 0.5 + halfW)
        end
        -- Z axis (after X resolved)
        local cellX = math.floor(self.x + 0.5)
        local frontCell = math.floor(self.z + halfW + 0.5)
        if frontCell ~= self.gz and self.world:isSolid(cellX, cy, frontCell) then
            self.z = math.min(self.z, frontCell - 0.5 - halfW)
        end
        local backCell = math.floor(self.z - halfW + 0.5)
        if backCell ~= self.gz and self.world:isSolid(cellX, cy, backCell) then
            self.z = math.max(self.z, backCell + 0.5 + halfW)
        end
    end

    if self.pathRecalcTimer > 0 then self.pathRecalcTimer = self.pathRecalcTimer - dt end

    self.thinkTimer = self.thinkTimer - dt
    if self.thinkTimer <= 0 then
        self:_think()
        self.thinkTimer = self.task and 2 or 3  -- longer cooldown when idle
    end

    if self.task then
        self.task.timer = self.task.timer + dt
        if self.task.timer > TASK_TIMEOUT then
            self:_failTask()
        else
            self:_executeTask(dt)
        end
    else
        self:_wander(dt)
    end
end

----------------------------------------------------------------------------
-- UTILITY AI
----------------------------------------------------------------------------
function NPC:_think()
    local candidates = {
        {name = "continue_build", score = self:_scoreContinueBuild()},
        {name = "help_build",     score = self:_scoreHelpBuild()},
        {name = "build_shelter",  score = self:_scoreBuildShelter()},
        {name = "eat",            score = self:_scoreEat()},
        {name = "go_home",        score = self:_scoreGoHome()},
        {name = "stockpile",      score = self:_scoreStockpile()},
        {name = "furnish_home",   score = self:_scoreFurnishHome()},
        {name = "build_bigger",   score = self:_scoreBuildBigger()},
        {name = "sleep",          score = self:_scoreSleep()},
        {name = "socialize",      score = self:_scoreSocialize()},
        {name = "attack",         score = self:_scoreAttack()},
    }
    for _, c in ipairs(candidates) do
        c.score = c.score + math.random() * 2
        -- Mood efficiency: happy=+10%, sad=-20%, miserable=-50%
        if self.moodValue > 30 then c.score = c.score * 1.1
        elseif self.moodValue < -50 then c.score = c.score * 0.5
        elseif self.moodValue < -30 then c.score = c.score * 0.8 end
    end
    local best = candidates[1]
    for i = 2, #candidates do
        if candidates[i].score > best.score then best = candidates[i] end
    end
    if best.score > 0 then
        log.write("npc", "%s think→%s(%.0f) pos:(%d,%d,%d) sta:%.0f hp:%.0f des:%.0f",
            self.name, best.name, best.score, self.gx, self.gy, self.gz,
            self.stamina, self.hp, self.desperation)
        self:_executeDecision(best.name)
        -- Show "demolishing" thought when tearing down
        local bp = self.helpingBlueprint or self.blueprint
        if best.name == "continue_build" and bp and bp.isDemolish then
            self:_setThought("demolishing")
        else
            self:_setThought(best.name)
        end
    else
        self.task = nil
        self:_setThought("idle")
    end
end

function NPC:_scoreContinueBuild()
    if self.injured then return 0 end
    local bp = self.helpingBlueprint or self.blueprint
    if bp and not bp.completed then
        -- If build is stalled (no materials), drop to very low priority
        -- so NPC does other things (idle, socialize, wander) instead of
        -- burning CPU scanning 169 steps every 5 seconds
        if self.buildStalled then return 8 end
        local base = self.helpingBlueprint and 88 or 90
        if self.traits.diligent then base = base * 1.3 end
        if self.traits.lazy then base = base * 0.6 end
        return base
    end
    return 0
end

function NPC:_scoreHelpBuild()
    if self.helpingBlueprint and not self.helpingBlueprint.completed then return 0 end
    -- Look for ANY NPC with unfinished blueprint (collective consciousness)
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and other.blueprint and not other.blueprint.completed then
            if self.blueprint and not self.blueprint.completed then return 0 end
            -- DF-inspired: reduce score per additional helper already on this blueprint
            local helperCount = 0
            for _, h in ipairs(self.allNpcs) do
                if h ~= self and not h.dead and h.helpingBlueprint == other.blueprint then
                    helperCount = helperCount + 1
                end
            end
            local base = 95 - helperCount * 12  -- each helper reduces appeal
            if base < 30 then base = 30 end
            if self.traits.social then base = base * 1.2 end
            if self.traits.shy then base = base * 0.7 end
            return base
        end
    end
    return 0
end

function NPC:_scoreBuildShelter()
    if self:_hasShelter() then return 0 end
    -- Collective consciousness: don't start own build if someone else needs help
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and other.blueprint and not other.blueprint.completed then
            return 0  -- defer own build, help them first
        end
    end
    local tempR = self.temperature / self.cfg.TEMP_MAX
    if tempR >= 0.8 then return 0 end
    return (1 - tempR) * 100
end

function NPC:_scoreEat()
    local hungerR = self.hunger / self.cfg.HUNGER_MAX
    if hungerR >= 0.7 then return 0 end
    if (self.resourceCache["apple"] or 0) <= 0 then return 0 end
    local base = (1 - hungerR) * 80
    if self.traits.greedy then base = base * 1.4 end
    -- food_here markers boost eating urgency
    local foodMarkers = self.world:getMarkersNear(self.gx, self.gz, 15, "food_here")
    if #foodMarkers > 0 then base = base + 10 end
    return base
end

function NPC:_scoreGoHome()
    -- Night = go home AND sleep (merged behavior)
    if not self.world.isNight then return 0 end
    if not self:_hasShelter() then return 0 end
    if self.sleeping then return 0 end
    local base = 75  -- high priority: nighttime = go home to sleep
    if self.traits.shy then base = base * 1.3 end
    return base
end

function NPC:_scoreStockpile()
    if not self:_hasShelter() then return 0 end
    if self.hunger / self.cfg.HUNGER_MAX <= 0.6 then return 0 end
    local apples = self.resourceCache["apple"] or 0
    if apples <= 0 then return 0 end
    return 25 + math.min(apples * 2, 10)
end

function NPC:_scoreFurnishHome()
    -- Disabled for template builds: template defines the complete building
    if self.blueprint and self.blueprint.templateName then return 0 end
    return 0
end

function NPC:_scoreBuildBigger()
    -- Disabled for template-based building: Armorer House is the final design.
    -- build_bigger generates a dynamic room that conflicts with the template.
    if self.blueprint and self.blueprint.templateName then return 0 end
    return 0
end

function NPC:_scoreSleep()
    if self.sleeping then return 0 end
    local staminaR = self.stamina / self.cfg.STAMINA_MAX
    -- Sigmoid response curve: urgency spikes sharply below 30% stamina
    local urgency = 1 / (1 + math.exp(-12 * (1 - staminaR - 0.7)))
    local base = urgency * 95
    -- Night: strong drive to sleep (even homeless NPC should sleep at night)
    if self.world.isNight then
        base = base + 40
        -- Homeless NPC: sleep score must compete with other options
        if not self:_hasShelter() then base = base + 10 end
    end
    if self:_hasShelter() then base = base + 5 end
    return base
end

function NPC:_findNearbyBed()
    if self.blueprint then
        local bp = self.blueprint
        for _, b in ipairs(self.world.blocks) do
            if b.itemType == "bed" and b.state == "placed" then
                if b.gx >= bp.originX and b.gx < bp.originX + bp.width
                   and b.gz >= bp.originZ and b.gz < bp.originZ + bp.depth then
                    return b
                end
            end
        end
    end
    return nil
end

function NPC:_findBed()
    -- Priority 1: bed inside own home
    local ownBed = self:_findNearbyBed()
    if ownBed then return ownBed end

    -- Priority 2: bed inside close friend's home
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead and other.blueprint then
            local rel = self:_getRelation(other)
            if rel.affinity >= self.cfg.AFFINITY_CLOSE_FRIEND then
                local bp = other.blueprint
                for _, b in ipairs(self.world.blocks) do
                    if b.itemType == "bed" and b.state == "placed"
                       and b.gx >= bp.originX and b.gx < bp.originX + bp.width
                       and b.gz >= bp.originZ and b.gz < bp.originZ + bp.depth then
                        return b
                    end
                end
            end
        end
    end

    -- No accessible bed
    return nil
end

----------------------------------------------------------------------------
-- SOCIAL RELATIONSHIPS
----------------------------------------------------------------------------
function NPC:_getRelation(otherNpc)
    local id = otherNpc.npcId
    if not self.relationships[id] then
        self.relationships[id] = {
            affinity = 20, interactions = 0,
            lastTime = self.world.time, proximityTimer = 0,
        }
    end
    return self.relationships[id]
end

function NPC:_getRelationType(otherNpc)
    local rel = self:_getRelation(otherNpc)
    if rel.affinity >= self.cfg.AFFINITY_PARTNER then return "partner"
    elseif rel.affinity >= self.cfg.AFFINITY_CLOSE_FRIEND then return "close_friend"
    elseif rel.affinity >= self.cfg.AFFINITY_FRIEND then return "friend"
    elseif rel.affinity >= self.cfg.AFFINITY_ACQUAINTANCE then return "acquaintance"
    else return "stranger" end
end

function NPC:_updateRelationships(dt)
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead then
            local rel = self:_getRelation(other)
            local dist = math.abs(self.gx - other.gx) + math.abs(self.gz - other.gz)
            if dist <= self.cfg.AFFINITY_PROXIMITY_RANGE then
                rel.proximityTimer = (rel.proximityTimer or 0) + dt
                if rel.proximityTimer >= self.cfg.AFFINITY_PROXIMITY_TIME then
                    rel.proximityTimer = 0
                    rel.affinity = math.min(100, rel.affinity + self.cfg.AFFINITY_PROXIMITY_BONUS)
                end
                rel.lastTime = self.world.time
            end
            if self.world.time - rel.lastTime > self.cfg.AFFINITY_DECAY_TIME then
                rel.affinity = math.max(0, rel.affinity - self.cfg.AFFINITY_DECAY_RATE * dt)
            end
            -- Grudge decay (very slow: -1 per 300s)
            if rel.grudge and rel.grudge > 0 then
                rel.grudgeTimer = (rel.grudgeTimer or 0) + dt
                if rel.grudgeTimer > 300 then
                    rel.grudge = rel.grudge - 1
                    rel.grudgeTimer = 0
                end
            end
        end
    end
end

function NPC:_scoreSocialize()
    if self.sleeping then return 0 end
    if self.chatTarget then return 0 end
    local socialR = self.socialNeed / self.cfg.SOCIAL_MAX
    local urgency = 1 / (1 + math.exp(-10 * (1 - socialR - 0.6)))
    local base = urgency * 60
    local hasTarget = false
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead and not other.sleeping then
            local dist = math.abs(self.gx - other.gx) + math.abs(self.gz - other.gz)
            if dist <= 15 then hasTarget = true; break end
        end
    end
    if not hasTarget then return 0 end
    if self.traits.social then base = base * 1.5 end
    if self.traits.shy then base = base * 0.4 end
    return base
end

----------------------------------------------------------------------------
-- DECISIONS
----------------------------------------------------------------------------
function NPC:_executeDecision(name)
    if name == "attack" then
        self:_execAttack()
    elseif name == "continue_build" then
        -- Don't interrupt active build tasks (fetch/place in progress)
        if not self.task or (self.task.type ~= "fetch_block" and self.task.type ~= "place_block" and self.task.type ~= "break_block") then
            self:_pushBuildTask()
        end
    elseif name == "help_build" then
        self:_execHelpBuild()
    elseif name == "build_shelter" then
        self:_execBuildShelter()
    elseif name == "eat" then
        local food = self:_findFood()
        if food then self.task = {type = "fetch_eat", target = food, timer = 0} end
    elseif name == "go_home" then
        self.task = {type = "go_home", timer = 0}
    elseif name == "stockpile" then
        local food = self.world:nearestLoose(self.gx, self.gz, "apple")
        if food then self.task = {type = "stockpile", target = food, timer = 0} end
    elseif name == "furnish_home" then
        self:_execFurnishHome()
    elseif name == "build_bigger" then
        self:_execBuildBigger()
    elseif name == "sleep" then
        self:_execSleep()
    elseif name == "socialize" then
        self:_execSocialize()
    end
end

function NPC:_execSocialize()
    local bestDist = math.huge
    local bestNpc = nil
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead and not other.sleeping and not other.chatTarget then
            local dist = math.abs(self.gx - other.gx) + math.abs(self.gz - other.gz)
            local rel = self:_getRelation(other)
            local bonus = rel.affinity >= 50 and -5 or 0
            if dist + bonus < bestDist then bestDist = dist + bonus; bestNpc = other end
        end
    end
    if bestNpc then
        self.task = {type = "socialize", target = bestNpc, timer = 0}
    end
end

function NPC:_execSleep()
    local bed = self:_findBed()
    if bed then
        self.task = {type = "go_sleep", target = {x = bed.gx, z = bed.gz, y = bed.gy},
                     timer = 0, bedRef = bed}
    elseif self:_hasShelter() then
        self.task = {type = "go_sleep", target = {x = self.homeX, z = self.homeZ, y = 0},
                     timer = 0, bedRef = nil}
    else
        -- No bed, no shelter: sleep right here
        self.sleeping = true
        self.sleepPos = {x = self.gx, z = self.gz}
        self.sleepQuality = 0
        self.task = nil
    end
end

function NPC:_execHelpBuild()
    local bestDist = math.huge
    local bestBp = nil
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and other.blueprint and not other.blueprint.completed then
            local dist = math.abs(self.gx - other.gx) + math.abs(self.gz - other.gz)
            if dist < bestDist then bestDist = dist; bestBp = other.blueprint end
        end
    end
    if bestBp then
        self.helpingBlueprint = bestBp
        self:_pushBuildTask()
    end
end

function NPC:_execBuildShelter()
    if not self.blueprint then
        -- GUARD: don't start a new build if ANY NPC has an unfinished one
        for _, other in ipairs(self.allNpcs) do
            if other ~= self and other.blueprint and not other.blueprint.completed then
                return  -- help them instead
            end
        end

        -- Count ALL building materials available
        local totalMats = 0
        for itemType, count in pairs(self.resourceCache) do
            local def = self.items.get(itemType)
            if def and def.category == "building" then
                totalMats = totalMats + count
            end
        end
        if totalMats < 5 then return end

        -- Always build Armorer House
        for _, tmpl in ipairs(TemplateLib.all) do
            if tmpl.name:find("Armorer") then
                self.blueprint = TemplateLib.toBlueprint(tmpl, self.homeX, self.homeZ, self)
                log.write("build", "%s starting %s at (%d,%d) steps:%d",
                    self.name, tmpl.name, self.homeX, self.homeZ, #self.blueprint.steps)
                break
            end
        end
    end
    self:_pushBuildTask()
end

function NPC:_execFurnishHome()
    if not self.blueprint then return end
    if self.blueprint.width < 5 or self.blueprint.depth < 5 then return end
    if self.blueprint.completed then
        Blueprint.addFurnishingSteps(self.blueprint, self.world, self.items)
        if not self.blueprint.completed then self:_pushBuildTask() end
    end
end

function NPC:_execBuildBigger()
    local oldBp = self.blueprint
    local options = Blueprint.chooseBlueprintSize(self.resourceCache, self.cfg, oldBp)
    if oldBp then
        local oldVol = oldBp.width * oldBp.depth * (oldBp.stories or 1)
        local newVol = options.w * options.d * options.stories
        if newVol <= oldVol then return end
    end
    if oldBp and oldBp.completed then
        -- Phase 1: Generate demolish blueprint (break blocks one by one)
        local demoBp = Blueprint.generateDemolishSteps(oldBp, self.world)
        if demoBp then
            -- Store the planned new size for after demolition
            self.pendingBuildOptions = options
            self.blueprint = demoBp
            self.shelterVerified = false
            self:_setThought("build_bigger")
            self.thoughtTimer = 5
            self:_pushBuildTask()
            return
        end
    end
    -- No old building or no blocks to demolish — build directly
    self.resourceCache = self.world:countLooseByType()
    self.blueprint = Blueprint.generateDynamicRoom(self.homeX, self.homeZ, self.cfg, options)
    self.shelterVerified = false
    self.ambition = self.ambition * 0.3
    self:_setThought("build_bigger")
    self.thoughtTimer = 5
    self:_pushBuildTask()
end

----------------------------------------------------------------------------
-- COOPERATIVE BUILD SYSTEM
-- Design: persistent step assignment + material check + block reservation
-- Each NPC "owns" a step (buildStep) until it completes or explicitly gives up.
-- Steps are skipped if: already done, claimed by another NPC, unreachable,
-- or no materials available. This prevents 10 NPCs from all getting stuck
-- on the same missing-material step.
----------------------------------------------------------------------------

function NPC:_isStepDone(s)
    if s.action == "place" or s.action == "place_furniture" then
        local k = self.world:_key(s.x, s.y, s.z)
        local block = self.world.occupied[k]
        if block and block.state == "placed" then
            if s.exactType or s.action == "place_furniture" then
                return block.itemType == s.need
            else
                local def = self.items.get(block.itemType)
                return def and def.building_type == s.need
            end
        end
        return false
    elseif s.action == "break" then
        return not self.world:isOccupied(s.x, s.y, s.z)
    end
    return false
end

-- Can the NPC physically reach this step? (cheap check, no A*)
-- Checks if at least one adjacent position is standable AND reachable from ground
function NPC:_isStepReachable(s)
    -- For ground-level placement (y=0), always reachable if within grid
    if s.y == 0 then return true end
    -- For all other heights: check if any adjacent position has a floor to stand on
    for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1},{0,0}}) do
        local ax, az = s.x + d[1], s.z + d[2]
        for standY = s.y, math.max(0, s.y - 2), -1 do
            if self.world:canStandAt(ax, standY, az) and s.y <= standY + 2 then
                -- Also verify NPC can get to this height from ground
                -- Check there's a chain of blocks from ground up to standY
                if standY == 0 then return true end  -- ground level, always accessible
                -- For standY > 0, the floor must exist (canStandAt already checked)
                -- and the NPC can jump up (A* handles the pathing)
                return true
            end
        end
    end
    return false
end

-- Does the required material exist as a loose block in the world?
function NPC:_hasMaterialFor(s)
    if s.action == "break" then return true end
    if s.exactType or s.action == "place_furniture" then
        -- Need exact item type
        for _, b in ipairs(self.world.blocks) do
            if b.state == "loose" and b.itemType == s.need then return true end
        end
    else
        -- Need any block with matching building_type
        for _, b in ipairs(self.world.blocks) do
            if b.state == "loose" then
                local def = self.items.get(b.itemType)
                if def and def.building_type == s.need then return true end
            end
        end
    end
    return false
end

-- Find nearest loose block not already targeted by another NPC's fetch task
function NPC:_findUnreservedBlock(step)
    -- Gather blocks reserved by other NPCs
    local reserved = {}
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead
           and other.task and other.task.type == "fetch_block" and other.task.target then
            reserved[other.task.target] = true
        end
    end
    -- Search for nearest unreserved loose block
    local best, bestD2 = nil, math.huge
    for _, b in ipairs(self.world.blocks) do
        if b.state == "loose" and not reserved[b] then
            local match = false
            if step.exactType or step.action == "place_furniture" then
                match = (b.itemType == step.need)
            else
                local def = self.items.get(b.itemType)
                match = def and def.building_type == step.need
            end
            if match then
                local d2 = (b.gx - self.gx)^2 + (b.gz - self.gz)^2
                if d2 < bestD2 then best, bestD2 = b, d2 end
            end
        end
    end
    return best
end

-- Get steps claimed by other NPCs (via persistent buildStep, not ephemeral task)
function NPC:_getClaimedSteps(bp)
    local claimed = {}
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead
           and other.buildStep and other.buildStepBp == bp then
            claimed[other.buildStep] = true
        end
    end
    return claimed
end

function NPC:_pushBuildTask()
    local bp = self.helpingBlueprint or self.blueprint
    if not bp then return end

    -- NOTE: removed skipIfDone loop here — it can prematurely set bp.completed
    -- when NPCs build out-of-order (distance-weighted selection). The full scan
    -- below correctly handles completion detection.

    -- If NPC has a persistent step assignment, check if it's still valid
    if self.buildStep and self.buildStepBp == bp then
        local s = bp.steps[self.buildStep]
        if s and not self:_isStepDone(s) then
            -- Step still valid — execute it
            self:_assignStepTask(bp, s)
            return
        end
        -- Step completed or invalid — clear and find new
        self.buildStep = nil
        self.buildStepBp = nil
    end

    -- SOFT LAYER PRIORITY: prefer lower layers but don't block on missing materials.
    -- If a step's material is unavailable, skip it and try higher layers.
    -- This prevents the entire build from stalling when one material runs out.
    local claimed = self:_getClaimedSteps(bp)
    local step = nil
    local stepIdx = nil
    local noMaterialStep = nil
    local bestScore = -1
    for i = 1, #bp.steps do
        local s = bp.steps[i]
        local skip = false
        if self:_isStepDone(s) then skip = true end
        if not skip and claimed[i] then skip = true end
        if not skip and (s.action == "place" or s.action == "place_furniture") then
            if not self:_hasMaterialFor(s) then
                if not noMaterialStep then noMaterialStep = s end
                skip = true
            end
        end
        if not skip then
            -- ACO-inspired: prefer steps closer to NPC (1 / (1 + distance))
            -- Soft layer priority: lower Y gets massive bonus (build bottom-up)
            -- + distance bonus (prefer nearby steps)
            local dist = math.abs(self.gx - s.x) + math.abs(self.gz - s.z)
            local layerPenalty = (s.layer or s.y) * 100  -- strongly prefer lower layers
            local score = 1000 - layerPenalty - dist
            if score > bestScore then
                bestScore = score
                step = s
                stepIdx = i
            end
        end
    end

    if not step then
        -- No executable step found. Check if blueprint is fully complete.
        local allDone = true
        for i = 1, #bp.steps do
            if not self:_isStepDone(bp.steps[i]) then allDone = false; break end
        end
        if allDone then bp.completed = true end

        if bp.completed then
            self.buildStep = nil
            self.buildStepBp = nil
            if self.helpingBlueprint then self.helpingBlueprint = nil end
            if bp == self.blueprint then
                if bp.isDemolish and self.pendingBuildOptions then
                    self.resourceCache = self.world:countLooseByType()
                    local options = self.pendingBuildOptions
                    self.pendingBuildOptions = nil
                    self.blueprint = Blueprint.generateDynamicRoom(self.homeX, self.homeZ, self.cfg, options)
                    self.shelterVerified = false
                    self.ambition = self.ambition * 0.3
                    self.buildingsOwned[#self.buildingsOwned + 1] = {
                        width = bp.width, depth = bp.depth,
                    }
                    self:_pushBuildTask()
                    return
                end
                self.shelterVerified = self.world:hasRoof(
                    math.floor(self.homeX + 0.5), math.floor(self.homeZ + 0.5))
                self.comfort = math.min(self.cfg.COMFORT_MAX,
                    self.comfort + bp.width * bp.depth * 0.5)
                if not bp.furnished and not bp.templateName and bp.width >= 5 and bp.depth >= 5 then
                    Blueprint.addFurnishingSteps(bp, self.world, self.items)
                end
                self.world:addMarker("home_here", self.homeX, self.homeZ, self.npcId)
            end
        else
            -- Not complete but no executable step — stalled (missing materials)
            self.buildStalled = true
            if noMaterialStep then
                log.write("build", "%s stalled: need %s", self.name, noMaterialStep.need)
                self:_setThought("need_wall"); self.thoughtTimer = 5
                self.world:addMarker("help_needed", self.gx, self.gz, self.npcId)
            end
        end
        self.task = nil
        self.thinkTimer = 20  -- long cooldown when stalled (don't waste CPU scanning)
        return
    end

    -- Claim the step persistently — building is active again
    self.buildStep = stepIdx
    self.buildStepBp = bp
    self.buildStalled = false
    self:_assignStepTask(bp, step)
end

-- Assign the actual fetch/place/break task for a step
function NPC:_assignStepTask(bp, step)
    if step.action == "place" or step.action == "place_furniture" then
        -- Check if carried block matches
        if self.carriedBlock then
            local def = self.items.get(self.carriedBlock.itemType)
            local matches = false
            if step.action == "place_furniture" or step.exactType then
                matches = (self.carriedBlock.itemType == step.need)
            else
                matches = (def and def.building_type == step.need)
            end
            if not matches then self:_dropBlock() end
        end

        if self.carriedBlock then
            self.task = {type = "place_block", target = {x = step.x, z = step.z, y = step.y}, timer = 0, step = step}
        else
            local block = self:_findUnreservedBlock(step)
            if block then
                self.task = {type = "fetch_block", target = block, timer = 0, step = step}
            else
                -- Material existed during scan but now all reserved/gone
                self.buildStep = nil
                self.buildStepBp = nil
                self.task = nil
                self.thinkTimer = 3
            end
        end
    elseif step.action == "break" then
        self.task = {type = "break_block", target = {x = step.x, z = step.z, y = step.y}, timer = 0, step = step}
    end
end

----------------------------------------------------------------------------
-- TASKS
----------------------------------------------------------------------------
function NPC:_executeTask(dt)
    local t = self.task.type
    if t == "fetch_block" then     self:_doFetchBlock(dt)
    elseif t == "place_block" then self:_doPlaceBlock(dt)
    elseif t == "break_block" then self:_doBreakBlock(dt)
    elseif t == "fetch_eat" then   self:_doFetchEat(dt)
    elseif t == "go_home" then     self:_doGoHome(dt)
    elseif t == "stockpile" then   self:_doStockpile(dt)
    elseif t == "go_sleep" then    self:_doGoSleep(dt)
    elseif t == "socialize" then   self:_doSocialize(dt)
    elseif t == "attack" then      self:_doAttack(dt)
    elseif t == "fighting" then    self:_doFighting(dt)
    end
end

function NPC:_doFetchBlock(dt)
    local block = self.task.target
    if not block or block.state ~= "loose" then self:_completeTask(); return end
    if self:_canReach(block.gx, block.gy, block.gz) then
        block.state = "carried"
        local k = self.world:_key(block.gx, block.gy, block.gz)
        if self.world.occupied[k] == block then self.world.occupied[k] = nil end
        self.carriedBlock = block
        self:_completeTask()
    else
        self:_moveToReach(block.gx, block.gy, block.gz, dt)
    end
end

function NPC:_doPlaceBlock(dt)
    local tgt = self.task.target
    if not self.carriedBlock then self:_completeTask(); return end

    -- Ground-based building: NPC walks near the blueprint perimeter,
    -- then places the block remotely at any height. Like RimWorld's construction.
    local bp = self.helpingBlueprint or self.blueprint
    local nearBuild
    if bp then
        -- Within 3 blocks of building perimeter
        local ox, oz = bp.originX, bp.originZ
        local inX = self.gx >= ox - 3 and self.gx <= ox + bp.width + 2
        local inZ = self.gz >= oz - 3 and self.gz <= oz + bp.depth + 2
        nearBuild = inX and inZ
    else
        nearBuild = self:_canReach(tgt.x, tgt.y, tgt.z)
    end

    if nearBuild then
        -- Double-check: is this step already done? (another NPC may have completed it)
        if self:_isStepDone(self.task.step) then
            -- Step already completed correctly — just drop our block and move on
            self:_dropBlockNearBuilding()
            self.buildStep = nil
            self.buildStepBp = nil
            self:_completeTask()
            return
        end

        -- Close enough to the building — place the block remotely
        local k = self.world:_key(tgt.x, tgt.y, tgt.z)
        local existing = self.world.occupied[k]
        if existing then
            local needClear = false
            if existing.state == "loose" then
                needClear = true
            elseif existing.state == "placed" then
                if self.task.step.exactType or self.task.step.action == "place_furniture" then
                    needClear = (existing.itemType ~= self.task.step.need)
                else
                    local def = self.items.get(existing.itemType)
                    needClear = not (def and def.building_type == self.task.step.need)
                end
            end
            if needClear then
                log.write("build", "%s REPLACING %s with %s at (%d,%d,%d)",
                    self.name, existing.itemType, self.task.step.need, tgt.x, tgt.y, tgt.z)
                local etype = existing.itemType
                self.world:removeBlock(existing)
                -- Drop cleared block OUTSIDE building to prevent interior contamination
                local fx, fz = bp and self:_findGroundOutsideBuilding(bp)
                    or self.world:_findFreeGround(tgt.x, tgt.z)
                if fx then self.world:addBlock(fx, 0, fz, etype, "loose") end
            end
        end
        local carryType = self.carriedBlock.itemType
        self.world:removeBlock(self.carriedBlock)
        self.carriedBlock = nil
        local placed = self.world:addBlock(tgt.x, tgt.y, tgt.z, self.task.step.need, "placed")
        if placed then
            placed.noGravity = true
            if self.task.step then
                placed.facing = self.task.step.facing
                placed.half = self.task.step.half
                placed.shape = self.task.step.shape
                placed.open = self.task.step.open
            end
        end
        if not placed then
            self:_dropBlockNearBuilding()
            self:_failTask()
            return
        end
        if self.task.step.action == "place_furniture" then
            self.comfort = math.min(self.cfg.COMFORT_MAX, self.comfort + self.cfg.COMFORT_FURNITURE_BONUS)
        end
        self.path = nil
        self.buildStep = nil
        self.buildStepBp = nil
        self:_completeTask()
    else
        -- Walk toward the building perimeter (door position, always walkable)
        local walkX = bp and bp.doorX or tgt.x
        local walkZ = bp and (bp.doorZ - 1) or tgt.z  -- one step outside door
        -- Clamp to grid
        if walkX < 0 then walkX = 0 end
        if walkZ < 0 then walkZ = 0 end
        self:_moveTo(walkX, 0, walkZ, dt)
        if self.task.timer > 15 then
            self:_failTask()
        end
    end
end

function NPC:_doBreakBlock(dt)
    local tgt = self.task.target
    if not self.world:isOccupied(tgt.x, tgt.y, tgt.z) then
        self:_completeTask()
        return
    end
    if self:_canReach(tgt.x, tgt.y, tgt.z) then
        -- Save block info before breaking (so we can drop it as loose)
        local k = self.world:_key(tgt.x, tgt.y, tgt.z)
        local block = self.world.occupied[k]
        local blockType = block and block.itemType or nil
        self.world:breakBlockAt(tgt.x, tgt.y, tgt.z)
        -- Drop the broken block OUTSIDE building
        if blockType then
            local bp2 = self.helpingBlueprint or self.blueprint
            local fx, fz = bp2 and self:_findGroundOutsideBuilding(bp2)
                or self.world:_findFreeGround(tgt.x, tgt.z)
            if fx then self.world:addBlock(fx, 0, fz, blockType, "loose") end
        end
        self.path = nil
        self:_completeTask()
    else
        self:_moveToReach(tgt.x, tgt.y, tgt.z, dt)
    end
end

function NPC:_doFetchEat(dt)
    local block = self.task.target
    if not block or (block.state ~= "loose" and block.state ~= "placed") then
        self:_completeTask(); return
    end
    if self:_canReach(block.gx, block.gy, block.gz) then
        local def = self.items.get(block.itemType)
        self.hunger = math.min(self.hunger + (def and def.nutrition or 40), self.cfg.HUNGER_MAX)
        self.world:removeBlock(block)
        self:_completeTask()
    else
        self:_moveToReach(block.gx, block.gy, block.gz, dt)
    end
end

function NPC:_doGoHome(dt)
    -- Try to get INTO the house (not just adjacent to door)
    if self.gx == self.homeX and self.gz == self.homeZ then
        -- Inside home: sleep if night
        if self.world.isNight then
            self.sleeping = true
            self.sleepPos = {x = self.gx, z = self.gz}
            local bed = self:_findNearbyBed()
            if bed then
                self.sleepQuality = 2
            elseif self.world:hasRoof(self.gx, self.gz) then
                self.sleepQuality = 1
            else
                self.sleepQuality = 0
                self.outdoorSleepCount = self.outdoorSleepCount + 1
            end
            self:_setThought("sleeping")
            self.task = nil
        else
            self:_completeTask()
        end
    else
        -- Walk toward home interior
        self:_moveTo(self.homeX, 0, self.homeZ, dt)
    end
end

function NPC:_doStockpile(dt)
    local block = self.task.target
    if self.carriedBlock then
        if self:_adjacentTo(self.homeX, self.homeZ) then
            self.world:removeBlock(self.carriedBlock)
            self.carriedBlock = nil
            self.world:addBlock(self.homeX, 0, self.homeZ, "apple", "placed")
            self:_completeTask()
        else
            self:_moveTo(self.homeX, 0, self.homeZ, dt)
        end
    else
        if not block or block.state ~= "loose" then self:_completeTask(); return end
        if self:_canReach(block.gx, block.gy, block.gz) then
            block.state = "carried"
            local k = self.world:_key(block.gx, block.gy, block.gz)
            if self.world.occupied[k] == block then self.world.occupied[k] = nil end
            self.carriedBlock = block
        else
            self:_moveToReach(block.gx, block.gy, block.gz, dt)
        end
    end
end

function NPC:_doGoSleep(dt)
    local tgt = self.task.target
    if self:_adjacentTo(tgt.x, tgt.z) or (self.gx == tgt.x and self.gz == tgt.z) then
        self.sleeping = true
        self.sleepPos = {x = self.gx, z = self.gz}
        if self.task.bedRef and self.task.bedRef.state == "placed" then
            self.sleepQuality = 2
        elseif self.world:hasRoof(self.gx, self.gz) then
            self.sleepQuality = 1
        else
            self.sleepQuality = 0
        end
        self:_setThought("sleeping")
        self.task = nil
    else
        self:_moveTo(tgt.x, 0, tgt.z, dt)
    end
end

function NPC:_doSocialize(dt)
    local other = self.task.target
    if other.dead or other.sleeping then self:_completeTask(); return end
    local dist = math.abs(self.gx - other.gx) + math.abs(self.gz - other.gz)
    if dist <= 2 then
        if not self.chatTarget then
            self.chatTarget = other
            self.chatTimer = self.cfg.SOCIAL_CHAT_DURATION
            other.lookAtX = self.gx
            other.lookAtZ = self.gz
            self.lookAtX = other.gx
            self.lookAtZ = other.gz
        end
        self.chatTimer = self.chatTimer - dt
        if self.chatTimer <= 0 then
            self.socialNeed = math.min(self.cfg.SOCIAL_MAX, self.socialNeed + self.cfg.SOCIAL_CHAT_RESTORE)
            if other.socialNeed then
                other.socialNeed = math.min(self.cfg.SOCIAL_MAX, other.socialNeed + self.cfg.SOCIAL_CHAT_RESTORE)
            end
            local rel = self:_getRelation(other)
            rel.affinity = math.min(100, rel.affinity + self.cfg.SOCIAL_CHAT_AFFINITY)
            rel.interactions = rel.interactions + 1
            local otherRel = other:_getRelation(self)
            otherRel.affinity = math.min(100, otherRel.affinity + self.cfg.SOCIAL_CHAT_AFFINITY)
            otherRel.interactions = otherRel.interactions + 1
            self.chatTarget = nil
            other.lookAtX = nil; other.lookAtZ = nil
            self.lookAtX = nil; self.lookAtZ = nil
            self:_completeTask()
        end
    else
        self:_moveTo(other.gx, 0, other.gz, dt)
    end
end

----------------------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------------------
-- COMBAT SYSTEM
----------------------------------------------------------------------------
function NPC:_updateDesperation()
    local d = 0
    if not self:_hasShelter() then
        d = d + self.cfg.DESPERATION_NO_SHELTER
        d = d + self.outdoorSleepCount * self.cfg.DESPERATION_PER_OUTDOOR_SLEEP
    end
    d = d + math.max(0, 20 - self.stamina) * 0.5
    d = d + math.max(0, 20 - self.hunger) * 0.8
    d = d + math.max(0, 20 - self.temperature) * 0.6
    d = d + math.max(0, -self.moodValue) * 0.3
    -- Relative deprivation: others have shelter but I don't
    if not self:_hasShelter() then
        for _, other in ipairs(self.allNpcs) do
            if other ~= self and not other.dead and other.shelterVerified then
                d = d + self.cfg.DESPERATION_RELATIVE_DEPRIVATION
            end
        end
    end
    self.desperation = math.min(100, d)
end

function NPC:_scoreAttack()
    if self.sleeping or self.injured then return 0 end
    if self:_hasShelter() then return 0 end
    if self.desperation < self.cfg.DESPERATION_ATTACK_THRESHOLD then return 0 end
    local target = self:_findAttackTarget()
    if not target then return 0 end
    -- Hawk-Dove: V = desperation, C = fight cost
    local V = self.desperation
    local C = self:_calcFightCost(target)
    local prob
    if V >= C then prob = 1.0 else prob = V / C end
    if self.traits.shy then prob = prob * 0.3 end
    return prob * 85
end

function NPC:_findAttackTarget()
    local best, bestScore = nil, -math.huge
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead and not other.sleeping
           and other.shelterVerified and other.blueprint then
            local score = (100 - other.stamina) * 0.5
            local rel = self:_getRelation(other)
            if (rel.grudge or 0) > 0 then score = score + 30 end
            score = score - rel.affinity * 0.5
            if score > bestScore then bestScore = score; best = other end
        end
    end
    return best
end

function NPC:_calcFightCost(target)
    local cost = 30
    cost = cost + math.max(0, target.stamina - self.stamina) * 0.4
    local rel = self:_getRelation(target)
    cost = cost + rel.affinity * 0.6
    return math.max(10, cost)
end

function NPC:_execAttack()
    local target = self:_findAttackTarget()
    if target then
        self.task = {type = "attack", target = target, timer = 0}
        self:_setThought("attacking")
    end
end

function NPC:_doAttack(dt)
    local target = self.task.target
    if target.dead then self:_completeTask(); return end
    local dist = math.abs(self.gx - target.gx) + math.abs(self.gz - target.gz)
    if dist <= 1 then
        -- Arrived: start fight
        self.task = {type = "fighting", target = target, timer = self.cfg.COMBAT_DURATION}
        self.fightTarget = target
        target.fightTarget = self
        -- Lock both NPCs
        target.task = {type = "fighting", target = self, timer = self.cfg.COMBAT_DURATION}
        target.path = nil
        self.path = nil
        -- Face each other
        self.lookAtX = target.gx; self.lookAtZ = target.gz
        target.lookAtX = self.gx; target.lookAtZ = self.gz
        -- Notify bystanders
        self:_notifyBystanders(target)
    else
        self:_moveTo(target.gx, 0, target.gz, dt)
    end
end

function NPC:_doFighting(dt)
    self.task.timer = self.task.timer - dt
    if self.task.timer <= 0 then
        local target = self.task.target
        self:_resolveCombat(self, target)
        self.fightTarget = nil
        if target then target.fightTarget = nil end
        self.lookAtX = nil; self.lookAtZ = nil
        if target and not target.dead then
            target.lookAtX = nil; target.lookAtZ = nil
            target.task = nil
            target.thinkTimer = 0
        end
        self:_completeTask()
    end
end

function NPC:_resolveCombat(attacker, defender)
    log.write("combat", "%s vs %s | atk_hp:%.0f atk_sta:%.0f def_hp:%.0f def_sta:%.0f",
        attacker.name, defender.name, attacker.hp, attacker.stamina, defender.hp, defender.stamina)
    local atkPower = attacker.stamina * 0.6 + math.random() * 30
    local defPower = defender.stamina * 0.6 + math.random() * 30

    -- Both take damage
    attacker.hp = math.max(0, attacker.hp - self.cfg.COMBAT_DEF_DAMAGE)
    defender.hp = math.max(0, defender.hp - self.cfg.COMBAT_ATK_DAMAGE)
    attacker.stamina = math.max(0, attacker.stamina - self.cfg.COMBAT_STAMINA_COST_ATK)
    defender.stamina = math.max(0, defender.stamina - self.cfg.COMBAT_STAMINA_COST_DEF)
    attacker.hunger = math.max(0, attacker.hunger - self.cfg.COMBAT_HUNGER_COST)
    defender.hunger = math.max(0, defender.hunger - self.cfg.COMBAT_HUNGER_COST)

    -- Relationship destruction + grudge
    local relA = attacker:_getRelation(defender)
    local relD = defender:_getRelation(attacker)
    relA.affinity = math.max(0, relA.affinity - self.cfg.COMBAT_AFFINITY_LOSS_ATK)
    relD.affinity = math.max(0, relD.affinity - self.cfg.COMBAT_AFFINITY_LOSS_DEF)
    relD.grudge = (relD.grudge or 0) + self.cfg.COMBAT_GRUDGE_GAIN

    -- Determine winner
    local winner, loser
    if atkPower > defPower then
        winner, loser = attacker, defender
        -- Extra damage to loser
        loser.hp = math.max(0, loser.hp - 10)
    else
        winner, loser = defender, attacker
        loser.hp = math.max(0, loser.hp - 10)
    end

    -- Check death
    if loser.hp <= 0 then loser.dead = true end

    -- House seizure: if attacker wins
    if winner == attacker and defender.blueprint and not defender.dead then
        attacker.blueprint = defender.blueprint
        attacker.homeX = defender.homeX
        attacker.homeZ = defender.homeZ
        attacker.shelterVerified = defender.shelterVerified
        defender.blueprint = nil
        defender.shelterVerified = false
        defender.homeX = defender.gx
        defender.homeZ = defender.gz
        defender.outdoorSleepCount = 0
        attacker:_setThought("attacking")
        defender:_setThought("lost_home")
    elseif winner == defender then
        attacker:_setThought("lost_home")
        defender:_setThought("fighting")
    end
end

function NPC:_notifyBystanders(defender)
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and other ~= defender and not other.dead and not other.sleeping then
            local dist = math.abs(self.gx - other.gx) + math.abs(self.gz - other.gz)
            if dist <= self.cfg.COMBAT_NOTIFY_RADIUS then
                local decision = other:_bystanderDecision(self, defender)
                if decision == "help_defender" then
                    -- Join fight against attacker: damage attacker
                    self.hp = math.max(0, self.hp - 10)
                    local rel = other:_getRelation(self)
                    rel.affinity = math.max(0, rel.affinity - 20)
                    other:_setThought("helping")
                elseif decision == "help_attacker" then
                    defender.hp = math.max(0, defender.hp - 10)
                    local rel = other:_getRelation(defender)
                    rel.affinity = math.max(0, rel.affinity - 20)
                elseif decision == "flee" then
                    -- Run away from fight
                    local fleeX = other.gx + (other.gx - self.gx)
                    local fleeZ = other.gz + (other.gz - self.gz)
                    fleeX = math.max(1, math.min(self.cfg.GRID - 2, fleeX))
                    fleeZ = math.max(1, math.min(self.cfg.GRID - 2, fleeZ))
                    other.task = {type = "go_home", timer = 0}
                    other:_setThought("fleeing")
                end
                -- "ignore" = do nothing
            end
        end
    end
end

function NPC:_bystanderDecision(attacker, defender)
    local relDef = self:_getRelation(defender)
    local relAtk = self:_getRelation(attacker)

    -- Hamilton: closeFriend always helps
    if relDef.affinity >= self.cfg.AFFINITY_CLOSE_FRIEND then
        return "help_defender"
    end
    if relAtk.affinity >= self.cfg.AFFINITY_CLOSE_FRIEND and relAtk.affinity > relDef.affinity then
        return "help_attacker"
    end

    -- Bystander effect: more people nearby = less likely to help
    local nearbyCount = 0
    for _, o in ipairs(self.allNpcs) do
        if o ~= self and o ~= attacker and o ~= defender and not o.dead then
            if math.abs(self.gx - o.gx) + math.abs(self.gz - o.gz) <= 10 then
                nearbyCount = nearbyCount + 1
            end
        end
    end
    local helpProb = 0.4 - nearbyCount * 0.15
    if helpProb > 0 and relDef.affinity > 30 and math.random() < helpProb then
        return "help_defender"
    end

    if self.traits.shy then return "flee" end
    return "ignore"
end

function NPC:_hasGrudge(otherNpc)
    local rel = self:_getRelation(otherNpc)
    return (rel.grudge or 0) > 0
end

----------------------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------------------
function NPC:_moveTo(tx, ty, tz, dt)
    if self.gx == tx and self.gy == ty and self.gz == tz then return true end
    local sameTarget = self.pathTarget
        and self.pathTarget.x == tx and self.pathTarget.y == ty and self.pathTarget.z == tz
    local needRecalc = not sameTarget or self.pathRecalcTimer <= 0
    if needRecalc then
        self.path = Pathfind.findPath(self.world, self.gx, self.gy, self.gz, tx, ty, tz, self.cfg.PATH_MAX_NODES)
        self.pathIdx = 1
        self.pathTarget = {x = tx, y = ty, z = tz}
        self.pathRecalcTimer = self.cfg.PATH_RECALC_TIME
        if not self.path then return false end
    end
    if not self.path then return false end
    return self:_followPath(dt)
end

function NPC:_moveToReach(tx, ty, tz, dt)
    if self:_canReach(tx, ty, tz) then return true end

    -- Direct pathfinding to reach target (no scaffold routing needed —
    -- building uses ground-based placement now)
    local sameTarget = self.pathTarget
        and self.pathTarget.x == tx and self.pathTarget.y == ty and self.pathTarget.z == tz
    local needRecalc = not sameTarget or self.pathRecalcTimer <= 0
    if needRecalc then
        self.path = Pathfind.findPathToReach(self.world, self.gx, self.gy, self.gz, tx, ty, tz, self.cfg.PATH_MAX_NODES)
        self.pathIdx = 1
        self.pathTarget = {x = tx, y = ty, z = tz}
        self.pathRecalcTimer = self.cfg.PATH_RECALC_TIME
        if not self.path then return false end
    end
    if not self.path then return false end
    return self:_followPath(dt)
end

function NPC:_followPath(dt)
    if not self.path then return true end
    if self.pathIdx > #self.path then self.path = nil; return true end
    self.stepTimer = self.stepTimer - dt
    if self.stepTimer > 0 then return false end
    local stepTime = self.cfg.NPC_STEP_TIME
    if self.traits.diligent then stepTime = stepTime * 0.8 end
    if self.traits.lazy then stepTime = stepTime * 1.3 end
    if self.excited then stepTime = stepTime / self.cfg.GIFT_EXCITED_SPEED_MULT end
    if self.stamina < self.cfg.STAMINA_TIRED then stepTime = stepTime * 1.4 end
    if self.injured then stepTime = stepTime * self.cfg.HP_INJURED_SPEED_MULT end
    self.stepTimer = stepTime
    local wp = self.path[self.pathIdx]
    -- Auto-open doors in the way (check feet and head height)
    for dy = 0, 1 do
        local door = self.world:getDoorAt(wp.x, wp.y + dy, wp.z)
        if door and not door.doorOpen then
            self.world:openDoor(door)
        end
    end
    -- Validate waypoint: if blocked by new block, invalidate path and recalc
    if not self.world:canStandAt(wp.x, wp.y, wp.z) then
        self.path = nil
        self.pathRecalcTimer = 0  -- force recalc next frame
        return false
    end
    self.gx, self.gy, self.gz = wp.x, wp.y, wp.z
    self.pathIdx = self.pathIdx + 1
    return false
end

function NPC:_canReach(tx, ty, tz)
    local xzDist = math.abs(self.gx - tx) + math.abs(self.gz - tz)
    return xzDist <= 1 and ty >= self.gy and ty <= self.gy + self.cfg.NPC_REACH_HEIGHT
end

function NPC:_adjacentTo(tx, tz)
    return math.abs(self.gx - tx) + math.abs(self.gz - tz) <= 1
end

function NPC:_completeTask()
    self.task = nil
    self.thinkTimer = 0
    self.path = nil
end

function NPC:_failTask()
    self:_dropBlock()
    self.task = nil
    self.buildStep = nil      -- release step claim so others can take it
    self.buildStepBp = nil
    self.thinkTimer = 0
    self.path = nil
end

function NPC:_dropBlock()
    if not self.carriedBlock then return end
    local itemType = self.carriedBlock.itemType
    self.world:removeBlock(self.carriedBlock)
    self.carriedBlock = nil
    -- Drop OUTSIDE building footprint to prevent interior contamination
    local bp = self.helpingBlueprint or self.blueprint
    if bp then
        local fx, fz = self:_findGroundOutsideBuilding(bp)
        if fx then
            self.world:addBlock(fx, 0, fz, itemType, "loose")
            return
        end
    end
    local fx, fz = self.world:_findFreeGround(self.gx, self.gz)
    if fx then self.world:addBlock(fx, 0, fz, itemType, "loose") end
end

-- Alias for compatibility
function NPC:_dropBlockNearBuilding()
    self:_dropBlock()
end

-- Find free ground position guaranteed OUTSIDE the building footprint
function NPC:_findGroundOutsideBuilding(bp)
    local ox, oz = bp.originX, bp.originZ
    local bw, bd = bp.width, bp.depth
    -- Search in expanding ring OUTSIDE the building
    local cx, cz = bp.doorX, bp.doorZ - 2  -- 2 blocks outside the door
    for r = 0, 15 do
        for dx = -r, r do
            for dz = -r, r do
                if math.abs(dx) == r or math.abs(dz) == r or r == 0 then
                    local fx, fz = cx + dx, cz + dz
                    -- Must be OUTSIDE building footprint (with 1-block margin)
                    local inside = fx >= ox - 1 and fx <= ox + bw
                                and fz >= oz - 1 and fz <= oz + bd
                    if not inside
                       and fx >= 0 and fx < self.world.config.GRID
                       and fz >= 0 and fz < self.world.config.GRID
                       and not self.world.occupied[self.world:_key(fx, 0, fz)] then
                        return fx, fz
                    end
                end
            end
        end
    end
    return nil, nil
end

----------------------------------------------------------------------------
-- WANDER
----------------------------------------------------------------------------
function NPC:_wander(dt)
    self.stepTimer = self.stepTimer - dt
    if self.stepTimer > 0 then return end
    local pauseBase = 0.5
    if self.traits.lazy then pauseBase = 1.0 end
    self.stepTimer = pauseBase + math.random() * 0.5

    local dx = math.random(-1, 1)
    local dz = math.random(-1, 1)
    local nx = self.gx + dx
    local nz = self.gz + dz

    -- All NPCs stay within wanderRange of home (prevents running off-map)
    local maxDist = self.traits.shy and 4 or (self.traits.explorer and 15 or 10)
    if math.abs(nx - self.homeX) > maxDist or math.abs(nz - self.homeZ) > maxDist then return end

    if nx >= 1 and nx < self.cfg.GRID - 2 and nz >= 1 and nz < self.cfg.GRID - 2 then
        if self.world:canStandAt(nx, self.gy, nz) then
            self.gx, self.gz = nx, nz
        elseif self.world:canStandAt(nx, self.gy + 1, nz) then
            self.gx, self.gy, self.gz = nx, self.gy + 1, nz
        elseif self.gy > 0 and self.world:canStandAt(nx, self.gy - 1, nz) then
            self.gx, self.gy, self.gz = nx, self.gy - 1, nz
        end
    end
end

----------------------------------------------------------------------------
-- GIFT DETECTION
----------------------------------------------------------------------------
function NPC:_detectGifts()
    local radius = self.cfg.GIFT_DETECT_RADIUS
    local since = self.world.time - self.cfg.GIFT_DETECT_COOLDOWN
    local nearby = self.world:getRecentDropsNear(self.gx, self.gz, radius, since)
    if #nearby > 0 then
        local bonus = 0
        local nearestDist = math.huge
        local nearestBlock = nil
        for _, b in ipairs(nearby) do
            local def = self.items.get(b.itemType)
            if def then
                if def.category == "food" then       bonus = bonus + self.cfg.GRATITUDE_GIFT_BONUS
                elseif def.category == "furniture" then bonus = bonus + self.cfg.GRATITUDE_GIFT_BONUS * 1.5
                elseif def.category == "building" then  bonus = bonus + self.cfg.GRATITUDE_GIFT_BONUS * 0.8
                end
                self.recentGifts[#self.recentGifts + 1] = {itemType = b.itemType, time = self.world.time}
                b.dropTime = nil
            end
            local dist = math.abs(b.gx - self.gx) + math.abs(b.gz - self.gz)
            if dist < nearestDist then nearestDist = dist; nearestBlock = b end
        end
        self.gratitude = math.min(self.cfg.GRATITUDE_MAX, self.gratitude + bonus)
        if bonus > 0 then
            self.mood = "excited"
            self:_setThought("gift_received")
            self.thoughtTimer = 4
            if nearestBlock then self.lookAtX = nearestBlock.gx; self.lookAtZ = nearestBlock.gz end
            self.excited = true
            self.excitedTimer = self.cfg.GIFT_EXCITED_DURATION
            if #nearby >= 3 then self.excitedTimer = self.excitedTimer * 1.5 end
        end
    end
    local cutoff = self.world.time - 60
    for i = #self.recentGifts, 1, -1 do
        if self.recentGifts[i].time < cutoff then table.remove(self.recentGifts, i) end
    end
end

----------------------------------------------------------------------------
-- MOOD & THOUGHTS
----------------------------------------------------------------------------
function NPC:_updateMood()
    if self.excited and self.thoughtTimer > 0 then self.mood = "excited"; return end

    local m = 0
    local factors = {}

    -- Hunger
    if self.hunger > 60 then m = m + 5
    elseif self.hunger < 20 then m = m - 20; factors[#factors+1] = "starving" end

    -- Stamina
    if self.stamina > 50 then m = m + 3
    elseif self.stamina < 15 then m = m - 15; factors[#factors+1] = "exhausted" end

    -- Temperature
    if self.temperature > 70 then m = m + 3
    elseif self.temperature < 30 then m = m - 15; factors[#factors+1] = "freezing" end

    -- Social
    if self.socialNeed > 60 then m = m + 10
    elseif self.socialNeed < 20 then m = m - 15; factors[#factors+1] = "lonely" end

    -- Environment
    if self:_hasShelter() then m = m + 10 end
    if self.comfort > 50 then m = m + 5 end

    -- Friends
    local friendCount = 0
    for _, rel in pairs(self.relationships) do
        if rel.affinity >= self.cfg.AFFINITY_FRIEND then friendCount = friendCount + 1 end
    end
    if friendCount > 0 then m = m + 5 + math.min(friendCount * 3, 15) end

    -- Gratitude
    if self.gratitude > 30 then m = m + 10 end

    -- Desperation
    if self.desperation > 50 then m = m - 20; factors[#factors+1] = "desperate" end

    -- Wounded
    if self.hp < 50 then m = m - 20; factors[#factors+1] = "wounded" end

    self.moodValue = math.max(-100, math.min(100, m))
    self.moodFactors = factors

    if m > 40 then self.mood = "happy"
    elseif m > 10 then self.mood = "content"
    elseif m > -20 then self.mood = "neutral"
    elseif m > -50 then self.mood = "sad"
    else self.mood = "miserable" end
end

function NPC:_setThought(key)
    local t = THOUGHT_MAP[key]
    if t then self.thought = t; self.thoughtTimer = 3 end
end

function NPC:getThought()
    if self.thoughtTimer > 0 and self.thought then return self.thought end
    return nil
end

function NPC:getMood() return self.mood end

function NPC:_hasShelter()
    -- Own shelter
    if self.blueprint and self.blueprint.completed and self.shelterVerified
       and self.world:hasRoof(math.floor(self.homeX + 0.5), math.floor(self.homeZ + 0.5)) then
        return true
    end
    -- Close friend's shelter (affinity >= CLOSE_FRIEND)
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and not other.dead then
            local rel = self:_getRelation(other)
            if rel.affinity >= self.cfg.AFFINITY_CLOSE_FRIEND then
                if other.blueprint and other.blueprint.completed and other.shelterVerified then
                    return true
                end
            end
        end
    end
    return false
end

function NPC:_findFood()
    if self.blueprint then
        local bp = self.blueprint
        for _, b in ipairs(self.world.blocks) do
            if b.itemType == "apple" and (b.state == "placed" or b.state == "loose") then
                if b.gx >= bp.originX and b.gx < bp.originX + bp.width
                    and b.gz >= bp.originZ and b.gz < bp.originZ + bp.depth then
                    self.world:addMarker("food_here", b.gx, b.gz, self.npcId)
                    return b
                end
            end
        end
    end
    local food = self.world:nearestLoose(self.gx, self.gz, "apple")
    if food then self.world:addMarker("food_here", food.gx, food.gz, self.npcId) end
    return food
end

function NPC:getState()
    if self.dead then return "dead" end
    if not self.task then return "idle" end
    return self.task.type
end

return NPC
