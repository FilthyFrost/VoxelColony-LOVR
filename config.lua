-- config.lua — Voxel Colony LOVR version

local C = {}

C.GRID = 96
C.DAY_LEN = 300.0              -- 5 minutes per cycle
C.NIGHT_START = 0.55
C.NIGHT_END = 0.95

C.NPC_COUNT = 1                -- start with 1 NPC
C.NPC_SPEED = 2.5
C.NPC_SPEED_URGENT = 4.5
C.TEMP_MAX = 100
C.TEMP_DECAY = 3.0
C.TEMP_REGEN = 1.5
C.TEMP_SHELTER = 4.0
C.TEMP_COLD_RATIO = 0.7
C.HUNGER_MAX = 100
C.HUNGER_DECAY = 0.2
C.HUNGER_EAT_RESTORE = 40
C.WANDER_RANGE = 6
C.WANDER_PAUSE = 2.0

C.SHELTER_URGENCY_WEIGHT = 100
C.FOOD_URGENCY_WEIGHT = 80
C.EXPANSION_URGENCY_WEIGHT = 60

C.ROOM_W = 5
C.ROOM_D = 5
C.WALL_H = 2
C.DOOR_SIDE = "south"
C.ROOM_CAPACITY = 2
C.CROWD_CHECK_RADIUS = 3

-- Pathfinding
C.PATH_MAX_NODES = 5000        -- A* search budget (larger world needs more)
C.PATH_RECALC_TIME = 2.0      -- seconds between path recalculations
C.NPC_STEP_TIME = 0.2          -- seconds per grid step (movement speed)

C.BLOCK_DUR = 900.0
C.FALL_SPEED = 12.0
C.FALL_START_Y = 10

-- Desire / need system
C.COMFORT_MAX = 100
C.COMFORT_DECAY = 0.1              -- slow erosion without furniture
C.COMFORT_FURNITURE_BONUS = 5      -- per furniture item in home
C.AMBITION_MAX = 100
C.AMBITION_GROWTH = 0.05           -- grows over time
C.GRATITUDE_MAX = 100
C.GRATITUDE_DECAY = 0.3            -- fades over time
C.GRATITUDE_GIFT_BONUS = 25        -- per gift detected
C.GIFT_DETECT_RADIUS = 4           -- grid cells
C.GIFT_DETECT_COOLDOWN = 0.5       -- check every 0.5s for instant reaction
C.GIFT_EXCITED_SPEED_MULT = 2.0   -- movement speed multiplier when excited
C.GIFT_EXCITED_DURATION = 3.0     -- seconds of excited state
C.GIFT_BOUNCE_AMPLITUDE = 0.15    -- bounce height
C.GIFT_BOUNCE_FREQUENCY = 10      -- bounces per second
C.NPC_REACH_HEIGHT = 2             -- NPC can interact with blocks gy..gy+2

-- Stamina / Sleep system
C.STAMINA_MAX = 100
C.STAMINA_DECAY_IDLE = 0.05         -- standing/wandering per second
C.STAMINA_DECAY_WALK = 0.15         -- walking per second
C.STAMINA_DECAY_WORK = 0.3          -- building/carrying per second
C.STAMINA_REGEN_STAND = 0.1         -- standing rest
C.STAMINA_REGEN_SLEEP_GROUND = 0.3  -- sleeping on ground
C.STAMINA_REGEN_SLEEP_INDOOR = 0.5  -- sleeping on indoor floor
C.STAMINA_REGEN_SLEEP_BED = 1.0     -- sleeping in bed
C.STAMINA_TIRED = 30                -- below: fatigued (slow movement)
C.STAMINA_EXHAUSTED = 10            -- below: forced collapse (RimWorld threshold interrupt)
C.STAMINA_WAKEUP = 90               -- above: wake up naturally
C.STAMINA_HUNGRY_WAKEUP = 15        -- hunger below: wake up hungry

return C
