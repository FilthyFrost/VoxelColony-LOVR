# 09 - Game Over与重玩系统

## 设计意图

Game Over是游戏的"结局演出"。玩家刚经历了手忙脚乱的混乱，需要一个短暂的"回味"时刻 — 看看自己的成绩，被NPC最后毒舌一次，然后一键重来。

## Game Over触发

```lua
function checkGameOver()
    local alive = 0
    for _, npc in ipairs(npcs) do
        if not npc.dead then alive = alive + 1 end
    end
    if alive == 0 then
        enterGameOver()
    end
end
```

## Game Over画面

### 过渡动画（2秒）

1. 最后一个NPC死亡后，画面逐渐变暗（1秒淡入黑色遮罩到70%透明度）
2. 摄像机自动拉远到鸟瞰视角（俯瞰整个殖民地废墟）
3. 1秒后弹出结算面板

### 结算面板

```
┌─────────────────────────────────────────┐
│                                          │
│              殖民地覆灭                    │
│                                          │
│     ┌──────────────────────────┐         │
│     │  存活时间:     8分32秒     │         │
│     │  满足需求:     14个        │         │
│     │  建造建筑:     5座         │         │
│     │  服务NPC:      6人         │         │
│     │  赌博胜率:     2胜1负      │         │
│     │  投放方块:     342个       │         │
│     │  最高等级:     Lv.4 (×12)  │         │
│     └──────────────────────────┘         │
│                                          │
│     NPC评价:                              │
│     "一般般吧...不是特别废物。6分。"        │
│                                          │
│     总分: 2,847                           │
│     最高记录: 4,120                       │
│                                          │
│         [ 再来一局 ]    [ 退出 ]           │
│                                          │
└─────────────────────────────────────────┘
```

### 统计项定义

```lua
gameStats = {
    survivalTime = 0,        -- 游戏持续秒数
    demandsFulfilled = 0,    -- 完成的需求总数
    buildingsBuilt = 0,      -- 建造完成的建筑数
    maxNpcCount = 0,         -- 同时存活的最大NPC数
    gamblingWins = 0,        -- 赌博胜场
    gamblingLosses = 0,      -- 赌博败场
    blocksDropped = 0,       -- 总投放方块数
    maxUpgradeLevel = 1,     -- 达到的最高投放等级
    npcDeaths = 0,           -- NPC死亡总数
    disastersEndured = 0,    -- 经历的灾害次数
}
```

### 计分公式

```lua
function calculateScore(stats)
    local score = 0
    
    -- 基础分：存活时间（每秒1分）
    score = score + math.floor(stats.survivalTime)
    
    -- 需求分：每完成一个需求+50
    score = score + stats.demandsFulfilled * 50
    
    -- 建筑分：每完成一座建筑+100
    score = score + stats.buildingsBuilt * 100
    
    -- NPC分：最大NPC数×30
    score = score + stats.maxNpcCount * 30
    
    -- 赌博分：每赢一场+80
    score = score + stats.gamblingWins * 80
    
    -- 效率加成：投放方块越少分越高（奖励高效玩家）
    local efficiency = stats.demandsFulfilled / math.max(1, stats.blocksDropped) * 1000
    score = score + math.floor(efficiency)
    
    return score
end
```

### NPC评价选择

```lua
function getNpcRating(score)
    -- 根据分数选择评语
    if score < 500 then return DIALOGUE.RATING[0]
    elseif score < 1000 then return DIALOGUE.RATING[2]
    elseif score < 2000 then return DIALOGUE.RATING[4]
    elseif score < 3000 then return DIALOGUE.RATING[6]
    elseif score < 4000 then return DIALOGUE.RATING[8]
    else return DIALOGUE.RATING[10]
    end
end
```

## 高分榜

### 本地存储

```lua
-- 保存在 /tmp/voxelcolony_highscores.json（或lovr的save目录）
highScores = {
    {score = 4120, time = "8:32", npcs = 6, date = "2026-04-14"},
    {score = 3200, time = "7:15", npcs = 5, date = "2026-04-13"},
    -- ... 最多保存10条
}
```

### 显示

Game Over面板上显示当前分数和历史最高分。如果打破记录，显示 "新记录！" 动画。

## 重新开始

点击"再来一局"后：
1. 清空所有游戏状态（world, npcs, demands, 升级等级等）
2. 重新调用 `lovr.load()` 的初始化逻辑
3. 从Phase 1重新开始

**关键：重启必须快**（<1秒）。不要有加载画面。街机游戏的重启体验应该像塞硬币一样即刻开始。

## 重玩性系统

### 难度修饰符

Game Over画面上有一个"难度修饰符"按钮。点击展开可选修饰符列表：

```lua
MODIFIERS = {
    {
        name = "急性子",
        desc = "NPC需求产生速度×1.5",
        scoreMultiplier = 1.3,
        effect = function() Config.DEMAND_INTERVAL_MULT = 0.67 end,
    },
    {
        name = "永冬",
        desc = "永远是夜晚",
        scoreMultiplier = 1.5,
        effect = function() Config.NIGHT_START = 0; Config.NIGHT_END = 1.0 end,
    },
    {
        name = "素食主义",
        desc = "NPC饥饿衰减×0.5但苹果恢复也×0.5",
        scoreMultiplier = 1.2,
        effect = function()
            Config.HUNGER_DECAY = Config.HUNGER_DECAY * 0.5
            Config.HUNGER_EAT_RESTORE = Config.HUNGER_EAT_RESTORE * 0.5
        end,
    },
    {
        name = "独裁者",
        desc = "只有1个NPC但HP×3、需求量×3",
        scoreMultiplier = 1.4,
        effect = function() Config.SINGLE_NPC_MODE = true end,
    },
}
```

修饰符可以叠加。叠加的scoreMultiplier相乘。

### 成就系统

成就用于解锁赌博游戏和装饰。

```lua
ACHIEVEMENTS = {
    -- 解锁赌博游戏
    {
        id = "unlock_blackjack",
        name = "初级赌徒",
        desc = "赢得3次赌博",
        condition = function(stats) return stats.gamblingWins >= 3 end,
        reward = "解锁21点",
        unlocks = "blackjack",
    },
    {
        id = "unlock_roulette",
        name = "亡命之徒",
        desc = "存活超过10分钟",
        condition = function(stats) return stats.survivalTime >= 600 end,
        reward = "解锁俄罗斯转盘",
        unlocks = "roulette",
    },
    
    -- 纯成就（无机制奖励）
    {
        id = "first_house",
        name = "包工头",
        desc = "建造第一座建筑",
    },
    {
        id = "ten_npcs",
        name = "人口大爆炸",
        desc = "同时拥有10个NPC",
    },
    {
        id = "survive_disaster",
        name = "风雨无阻",
        desc = "在灾害期间无NPC死亡",
    },
    {
        id = "speed_demon",
        name = "手速之王",
        desc = "在10秒内投放50个方块",
    },
}
```

### 成就持久化

成就解锁状态保存在本地文件中，跨局保留：

```lua
-- /tmp/voxelcolony_achievements.json
-- 或 lovr.filesystem.getSaveDirectory() 下
savedData = {
    achievements = {"first_house", "unlock_blackjack"},
    highScores = {...},
}
```
