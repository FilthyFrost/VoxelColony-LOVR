-- npc.lua — Utility AI NPC with personality, cooperative building, instant gift feedback
--
-- Cooperative building: multiple NPCs share one blueprint via simple currentStep pointer.
-- No complex claim system — NPCs advance the shared pointer sequentially.

local Blueprint = require("blueprint")
local Pathfind = require("pathfind")

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

    -- Stamina / Sleep
    self.stamina = config.STAMINA_MAX
    self.sleeping = false
    self.sleepPos = nil        -- {x, z} for rendering
    self.sleepQuality = 0      -- 0=ground, 1=indoor, 2=bed

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
    self.resourceCache = {}
    self.resourceCacheTimer = 0

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

    -- Task
    self.task = nil
    self.stepTimer = 0
    self.thinkTimer = 0

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

    if self.temperature <= 0 or self.hunger <= 0 then self.dead = true; return end

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

        -- Wake up conditions
        if self.stamina >= self.cfg.STAMINA_WAKEUP
           or self.hunger < self.cfg.STAMINA_HUNGRY_WAKEUP then
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
        end
        self:_setThought("sleep_exhausted")
        return
    end

    self.resourceCacheTimer = self.resourceCacheTimer - dt
    if self.resourceCacheTimer <= 0 then
        self.resourceCache = self.world:countLooseByType()
        self.resourceCacheTimer = 3
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

    -- Social relationships
    self:_updateRelationships(dt)

    if self.thoughtTimer > 0 then self.thoughtTimer = self.thoughtTimer - dt end
    self:_updateMood()

    local spd = 8 * dt
    self.x = self.x + (self.gx - self.x) * spd
    self.y = self.y + (self.gy - self.y) * spd
    self.z = self.z + (self.gz - self.z) * spd

    if self.pathRecalcTimer > 0 then self.pathRecalcTimer = self.pathRecalcTimer - dt end

    self.thinkTimer = self.thinkTimer - dt
    if self.thinkTimer <= 0 or self.task == nil then
        self:_think()
        self.thinkTimer = 2
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
    }
    for _, c in ipairs(candidates) do c.score = c.score + math.random() * 2 end
    local best = candidates[1]
    for i = 2, #candidates do
        if candidates[i].score > best.score then best = candidates[i] end
    end
    if best.score > 0 then
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
    local bp = self.helpingBlueprint or self.blueprint
    if bp and not bp.completed then
        local base = self.helpingBlueprint and 88 or 90
        if self.traits.diligent then base = base * 1.3 end
        if self.traits.lazy then base = base * 0.6 end
        return base
    end
    return 0
end

function NPC:_scoreHelpBuild()
    if self.blueprint and not self.blueprint.completed then return 0 end
    if self.helpingBlueprint and not self.helpingBlueprint.completed then return 0 end
    for _, other in ipairs(self.allNpcs) do
        if other ~= self and other.blueprint and not other.blueprint.completed then
            local dist = math.abs(self.gx - other.gx) + math.abs(self.gz - other.gz)
            if dist <= 12 then
                local base = 75
                if self.traits.social then base = base * 1.4 end
                if self.traits.shy then base = base * 0.5 end
                return base
            end
        end
    end
    return 0
end

function NPC:_scoreBuildShelter()
    if self:_hasShelter() then return 0 end
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
    return base
end

function NPC:_scoreGoHome()
    if not self.world.isNight then return 0 end
    if not self:_hasShelter() then return 0 end
    if self:_adjacentTo(self.homeX, self.homeZ) then return 0 end
    local base = 60
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
    if not self:_hasShelter() then return 0 end
    if not self.blueprint or self.blueprint.width < 5 or self.blueprint.depth < 5 then return 0 end
    local available = 0
    for _, ft in ipairs({"door", "bed", "torch", "chest"}) do
        if (self.resourceCache[ft] or 0) > 0 then available = available + 1 end
    end
    if available == 0 then return 0 end
    local comfortR = self.comfort / self.cfg.COMFORT_MAX
    return (35 + available * 3) * (1 - comfortR * 0.5) + self.gratitude * 0.15
end

function NPC:_scoreBuildBigger()
    if not self:_hasShelter() then return 0 end
    local options = Blueprint.chooseBlueprintSize(self.resourceCache, self.cfg, self.blueprint)
    if self.blueprint then
        local oldVol = self.blueprint.width * self.blueprint.depth * (self.blueprint.stories or 1)
        local newVol = options.w * options.d * options.stories
        if newVol <= oldVol then return 0 end
    end
    -- High priority: always beats stockpile(35) and go_home(60)
    return 80 + self.gratitude * 0.2
end

function NPC:_scoreSleep()
    if self.sleeping then return 0 end
    local staminaR = self.stamina / self.cfg.STAMINA_MAX
    -- Sigmoid response curve: urgency spikes sharply below 30% stamina
    local urgency = 1 / (1 + math.exp(-12 * (1 - staminaR - 0.7)))
    local base = urgency * 95
    if self.world.isNight then base = base + 15 end
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
    local best, bestD2 = nil, math.huge
    for _, b in ipairs(self.world.blocks) do
        if b.itemType == "bed" and b.state == "placed" then
            local d2 = (b.gx - self.gx)^2 + (b.gz - self.gz)^2
            if d2 < bestD2 then best, bestD2 = b, d2 end
        end
    end
    return best
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
    self.socialNeed = math.max(0, self.socialNeed - self.cfg.SOCIAL_DECAY * dt)
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
    if name == "continue_build" then
        self:_pushBuildTask()
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
        local options = Blueprint.chooseBlueprintSize(self.resourceCache, self.cfg)
        if self.allNpcs then
            local bp, hx, hz = Blueprint.findAdjacentSlot(self.allNpcs, self.cfg, options.w, options.d)
            if bp then self.blueprint = bp; self.homeX, self.homeZ = hx, hz end
        end
        if not self.blueprint then
            self.blueprint = Blueprint.generateDynamicRoom(self.homeX, self.homeZ, self.cfg, options)
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
-- PUSH BUILD TASK (simple: uses shared currentStep pointer)
----------------------------------------------------------------------------
function NPC:_pushBuildTask()
    local bp = self.helpingBlueprint or self.blueprint
    if not bp then return end

    -- Skip already-done steps
    while Blueprint.skipIfDone(bp, self.world) do end
    local step = Blueprint.currentStep(bp)

    if not step then
        bp.completed = true
        if self.helpingBlueprint then
            self.helpingBlueprint = nil
        end
        if bp == self.blueprint then
            -- Check if this was a demolish phase — transition to building
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
            if bp.completed then
                self.shelterVerified = self.world:hasRoof(
                    math.floor(self.homeX + 0.5), math.floor(self.homeZ + 0.5))
                self.comfort = math.min(self.cfg.COMFORT_MAX,
                    self.comfort + bp.width * bp.depth * 0.5)
                if not bp.furnished and bp.width >= 5 and bp.depth >= 5 then
                    Blueprint.addFurnishingSteps(bp, self.world, self.items)
                end
            end
        end
        self.task = nil
        return
    end

    if step.action == "place" or step.action == "place_furniture" then
        if self.carriedBlock then
            local def = self.items.get(self.carriedBlock.itemType)
            local matches = false
            if step.action == "place_furniture" then
                matches = (self.carriedBlock.itemType == step.need)
            else
                matches = (def and def.building_type == step.need)
            end
            if not matches then self:_dropBlock() end
        end

        if self.carriedBlock then
            self.task = {type = "place_block", target = {x = step.x, z = step.z, y = step.y}, timer = 0, step = step}
        else
            local block
            if step.action == "place_furniture" then
                block = self.world:nearestLoose(self.gx, self.gz, step.need)
            else
                block = self.world:nearestLooseBuilding(self.gx, self.gz, step.need)
            end
            if block then
                self.task = {type = "fetch_block", target = block, timer = 0, step = step}
            else
                self.task = nil
                self.thinkTimer = 3
                if step.need == "wall" then self:_setThought("need_wall"); self.thoughtTimer = 5
                elseif step.need == "roof" then self:_setThought("need_roof"); self.thoughtTimer = 5
                end
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
    if self:_canReach(tgt.x, tgt.y, tgt.z) then
        -- Clear wrong-type block at target
        local k = self.world:_key(tgt.x, tgt.y, tgt.z)
        local existing = self.world.occupied[k]
        if existing then
            local needClear = false
            if existing.state == "loose" then
                needClear = true
            elseif existing.state == "placed" then
                local def = self.items.get(existing.itemType)
                if self.task.step.action == "place_furniture" then
                    needClear = (existing.itemType ~= self.task.step.need)
                else
                    needClear = not (def and def.building_type == self.task.step.need)
                end
            end
            if needClear then
                local etype = existing.itemType
                self.world:removeBlock(existing)
                local fx, fz = self.world:_findFreeGround(tgt.x, tgt.z)
                if fx then self.world:addBlock(fx, 0, fz, etype, "loose") end
            end
        end
        local carryType = self.carriedBlock.itemType
        self.world:removeBlock(self.carriedBlock)
        self.carriedBlock = nil
        local placed = self.world:addBlock(tgt.x, tgt.y, tgt.z, self.task.step.need, "placed")
        if not placed then
            -- Target still occupied — recover the block as loose nearby
            local fx, fz = self.world:_findFreeGround(self.gx, self.gz)
            if fx then self.world:addBlock(fx, 0, fz, carryType, "loose") end
            self:_failTask()
            self.thinkTimer = 2  -- wait before retrying
            return
        end
        if self.task.step.action == "place_furniture" then
            self.comfort = math.min(self.cfg.COMFORT_MAX, self.comfort + self.cfg.COMFORT_FURNITURE_BONUS)
        end
        -- Cooperative building affinity bonus
        local cbp = self.helpingBlueprint or self.blueprint
        if cbp then
            for _, other in ipairs(self.allNpcs) do
                if other ~= self and not other.dead then
                    local obp = other.helpingBlueprint or other.blueprint
                    if obp == cbp then
                        local rel = self:_getRelation(other)
                        rel.affinity = math.min(100, rel.affinity + self.cfg.AFFINITY_COOP_BONUS)
                        rel.interactions = rel.interactions + 1
                    end
                end
            end
        end
        self.path = nil
        self:_completeTask()
    else
        self:_moveToReach(tgt.x, tgt.y, tgt.z, dt)
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
        -- Drop the broken block as loose at ground level (material recovery)
        if blockType then
            local fx, fz = self.world:_findFreeGround(tgt.x, tgt.z)
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
    if self:_adjacentTo(self.homeX, self.homeZ) then
        self:_completeTask()
    else
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
function NPC:_moveTo(tx, ty, tz, dt)
    if self.gx == tx and self.gy == ty and self.gz == tz then return true end
    local needRecalc = (not self.path)
        or (not self.pathTarget)
        or (self.pathTarget.x ~= tx or self.pathTarget.y ~= ty or self.pathTarget.z ~= tz)
        or self.pathRecalcTimer <= 0
    if needRecalc then
        self.path = Pathfind.findPath(self.world, self.gx, self.gy, self.gz, tx, ty, tz, self.cfg.PATH_MAX_NODES)
        self.pathIdx = 1
        self.pathTarget = {x = tx, y = ty, z = tz}
        self.pathRecalcTimer = self.cfg.PATH_RECALC_TIME
        if not self.path then return false end
    end
    return self:_followPath(dt)
end

function NPC:_moveToReach(tx, ty, tz, dt)
    if self:_canReach(tx, ty, tz) then return true end
    local needRecalc = (not self.path)
        or (not self.pathTarget)
        or (self.pathTarget.x ~= tx or self.pathTarget.y ~= ty or self.pathTarget.z ~= tz)
        or self.pathRecalcTimer <= 0
    if needRecalc then
        self.path = Pathfind.findPathToReach(self.world, self.gx, self.gy, self.gz, tx, ty, tz, self.cfg.PATH_MAX_NODES)
        self.pathIdx = 1
        self.pathTarget = {x = tx, y = ty, z = tz}
        self.pathRecalcTimer = self.cfg.PATH_RECALC_TIME
        if not self.path then return false end
    end
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
    self.stepTimer = stepTime
    local wp = self.path[self.pathIdx]
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
    self.thinkTimer = 0
    self.path = nil
end

function NPC:_dropBlock()
    if not self.carriedBlock then return end
    local itemType = self.carriedBlock.itemType
    self.world:removeBlock(self.carriedBlock)
    self.carriedBlock = nil
    self.world:addBlock(self.gx, self.gy, self.gz, itemType, "loose")
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
    if self.traits.shy then
        local maxDist = 4
        if math.abs(nx - self.homeX) > maxDist or math.abs(nz - self.homeZ) > maxDist then return end
    end
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
    if self.mood == "excited" and self.thoughtTimer > 0 then return end
    local tempR = self.temperature / self.cfg.TEMP_MAX
    local hungerR = self.hunger / self.cfg.HUNGER_MAX
    if self.gratitude > 50 then       self.mood = "happy"
    elseif tempR < 0.3 then          self.mood = "cold"
    elseif hungerR < 0.3 then        self.mood = "hungry"
    elseif self.comfort > 60 then    self.mood = "content"
    else                              self.mood = "neutral"
    end
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
                    return b
                end
            end
        end
    end
    return self.world:nearestLoose(self.gx, self.gz, "apple")
end

function NPC:getState()
    if self.dead then return "dead" end
    if not self.task then return "idle" end
    return self.task.type
end

return NPC
