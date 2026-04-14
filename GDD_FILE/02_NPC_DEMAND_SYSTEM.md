# 02 - NPC需求系统 (Demand System)

## 设计意图

需求系统是游戏的心脏。它决定NPC什么时候喊什么，玩家需要做什么。必须满足两个矛盾的目标：
1. 让玩家感到**被压迫**（需求不断，喘不过气）
2. 让玩家感到**有方向**（任何时刻都知道该做什么）

## 需求数据结构

```lua
-- 单个需求
demand = {
    id = "demand_001",              -- 唯一ID
    type = "building",              -- "building" | "food" | "companion" | "expansion"
    npcId = "npc_ref",              -- 发起需求的NPC引用
    
    -- 材料需求（type == "building" 或 "expansion" 时）
    materials = {
        {itemType = "cobblestone", needed = 10, delivered = 0},
        {itemType = "oak_planks",  needed = 5,  delivered = 0},
    },
    
    -- 食物需求（type == "food" 时）
    foodNeeded = 3,
    foodDelivered = 0,
    
    -- 伴侣需求（type == "companion" 时）
    companionNeeded = true,
    companionDelivered = false,
    
    -- 关联模板（type == "building"/"expansion" 时）
    template = tmpl_ref,            -- NPC自动选择的建筑模板
    
    -- 状态
    state = "active",               -- "active" | "fulfilled" | "building" | "failed"
    urgency = "normal",             -- "idle" | "normal" | "urgent" | "critical"
    createdAt = 0,                  -- 游戏时间戳
    
    -- 显示
    dialogueKey = "demand_building", -- 对话类型（用于选择台词）
    progressText = "",               -- 实时更新的进度文本 "圆石 3/10"
}
```

## 需求生成规则

### 阶段1：教学脚本（前3个需求固定）

| 顺序 | 需求 | 触发条件 | 目的 |
|------|------|----------|------|
| 1 | 建造第一个房子 | 游戏开始 | 教会玩家选材料+点击投放 |
| 2 | 召唤伴侣 | 需求1完成（建造完毕） | 教会玩家按N生成NPC |
| 3 | 投放食物 | 需求2完成 | 教会玩家切换到食物类 |

### 阶段2：动态需求（第4个需求起）

需求由**需求调度器**根据以下规则动态生成：

```lua
-- 需求调度器每 3 秒检查一次
function DemandScheduler:update(dt)
    -- 规则1: 任何NPC饥饿度 < 50% → 产生食物需求（如果没有活跃食物需求）
    -- 规则2: 任何NPC无庇护 → 产生建造需求（如果没有活跃建造需求）
    -- 规则3: NPC数量 < 期望数量 → 产生伴侣需求（每座已完成的房子期望2个NPC）
    -- 规则4: 所有NPC都有房+吃饱 → 产生扩建需求（更大的房子、仓库、工坊）
    
    -- 多样性约束: 同一类型的活跃需求不超过2个
    -- 频率约束: 两个新需求之间最少间隔 5 秒
end
```

### 动态需求的优先级权重

| 需求类型 | 基础权重 | 触发条件 | 加权因素 |
|----------|----------|----------|----------|
| 食物 | 90 | NPC饥饿 < 50% | 每降低10%加权+20 |
| 建造庇护 | 85 | NPC无房 | 夜间加权+30 |
| 伴侣 | 70 | 已完成房屋 > NPC数/2 | — |
| 扩建 | 50 | 所有NPC基本满足 | 人口越多越高 |

权重最高的需求类型优先生成。但受多样性约束限制（同类不超过2个活跃）。

### NPC性格对需求权重的影响

每个NPC的性格特质会乘以对应的需求权重，让不同NPC产生不同类型的需求偏好：

```lua
PERSONALITY_DEMAND_WEIGHTS = {
    diligent = {building = 1.3, food = 0.8, expansion = 1.2, companion = 1.0},
    lazy     = {building = 0.7, food = 1.4, expansion = 0.5, companion = 1.0},
    greedy   = {building = 1.0, food = 1.3, expansion = 1.5, companion = 1.0},
    explorer = {building = 1.0, food = 0.9, expansion = 1.3, companion = 0.6},
    shy      = {building = 1.3, food = 1.0, expansion = 1.0, companion = 0.4},
    social   = {building = 0.9, food = 0.9, expansion = 1.0, companion = 1.6},
}

-- 应用方式：基础权重 × 性格系数
function DemandScheduler:calcWeight(npc, demandType, baseWeight)
    local mult = 1.0
    for trait, _ in pairs(npc.traits) do
        local weights = PERSONALITY_DEMAND_WEIGHTS[trait]
        if weights and weights[demandType] then
            mult = mult * weights[demandType]
        end
    end
    return baseWeight * mult
end
```

效果示例：
- **lazy NPC**：食物需求权重 90×1.4=126（更频繁要吃的），建造权重 85×0.7=59.5（不爱建房）
- **greedy NPC**：扩建权重 50×1.5=75（总想要更大的房子）
- **social NPC**：伴侣权重 70×1.6=112（拼命要室友）

这让每局游戏因NPC性格组合不同而产生不同的压力模式，增加重玩性。

### 无真空规则

需求调度器保证**任何时刻至少有1个活跃需求**。如果所有活跃需求都已满足或正在建造中，调度器立即产生新需求（不受频率约束的5秒间隔限制）。确保玩家永远不会出现"无事可做"的时刻。

```lua
function DemandScheduler:update(dt)
    -- ... 常规调度逻辑 ...
    
    -- 无真空规则：如果没有活跃需求，立即产生一个
    local hasActive = false
    for _, d in ipairs(self.activeDemands) do
        if d.state == "active" then hasActive = true; break end
    end
    if not hasActive then
        self:generateNextDemand(true)  -- force=true, 跳过间隔限制
    end
end
```

## 需求满足判定

### 建材需求
```lua
-- 当玩家在地图上点击投放方块时
function onPlayerDrop(itemType, gx, gz)
    -- 遍历所有活跃需求
    for _, demand in ipairs(activeDemands) do
        if demand.state == "active" and demand.type == "building" then
            for _, mat in ipairs(demand.materials) do
                if mat.itemType == itemType and mat.delivered < mat.needed then
                    mat.delivered = mat.delivered + dropMultiplier  -- 受升级影响
                    mat.delivered = math.min(mat.delivered, mat.needed)
                    -- 更新进度显示
                    demand:updateProgress()
                    break
                end
            end
            -- 检查是否全部满足
            if demand:isFullyDelivered() then
                demand.state = "building"
                demand.npc:startBuilding(demand.template)
            end
        end
    end
end
```

### 食物需求
```lua
-- 玩家投放苹果时
if itemType == "apple" then
    -- 找最近的有食物需求的NPC
    local nearest = findNearestNpcWithDemand("food", gx, gz)
    if nearest then
        nearest.demand.foodDelivered = nearest.demand.foodDelivered + dropMultiplier
        if nearest.demand.foodDelivered >= nearest.demand.foodNeeded then
            nearest.demand.state = "fulfilled"
        end
    end
end
```

### 伴侣需求
```lua
-- 玩家按N键时
function onSpawnNPC()
    local companionDemand = findActiveDemand("companion")
    if companionDemand then
        -- 在需求NPC附近生成新NPC
        spawnNpcNear(companionDemand.npc)
        companionDemand.state = "fulfilled"
    end
end
```

## 需求紧急度更新

```lua
function Demand:updateUrgency()
    if self.type == "food" then
        local hungerRatio = self.npc.hunger / Config.HUNGER_MAX
        if hungerRatio < 0.15 then self.urgency = "critical"     -- 即将饿死
        elseif hungerRatio < 0.30 then self.urgency = "urgent"   -- 很饿
        else self.urgency = "normal" end
    elseif self.type == "building" then
        if self.npc.world.isNight and not self.npc:hasShelter() then
            self.urgency = "critical"                              -- 夜晚无庇护
        elseif not self.npc:hasShelter() then
            self.urgency = "urgent"
        else
            self.urgency = "normal"
        end
    else
        self.urgency = "normal"
    end
end
```

## 需求与NPC AI的交互

### 现有 Utility AI 的变更

现有的 `NPC:_think()` 保留，但优先级逻辑调整：

1. **有活跃建造需求 + 材料已到位** → 最高优先：执行建造
2. **有食物在附近** → 去吃
3. **无活跃需求** → 对玩家喊新需求 / 闲逛并骂骂咧咧
4. **夜晚 + 有庇护** → 回家睡觉

关键变更：NPC不再自己决定建什么。建筑选择由需求系统控制，NPC只负责执行。

### NPC建筑选择逻辑

```lua
-- 需求系统为NPC选择建筑模板
function DemandScheduler:chooseBuildingForNpc(npc)
    -- 使用现有的 TemplateLib.chooseBest(npc, resourceCache)
    -- 但 resourceCache 替换为"玩家已投放的材料"
    -- NPC性格影响选择（shy→小房子, diligent→工坊）
    
    -- 第一个房子：从小型模板中选（small_house_1~8, small_cozy_house 等）
    -- 后续建筑：逐渐解锁更大模板
    
    local pool = self:getAvailableTemplates(npc, gamePhase)
    return TemplateLib.chooseBestFromPool(npc, pool)
end
```

## 材料计算

当NPC选好模板后，需求系统计算所需材料清单：

```lua
function DemandScheduler:calcMaterialsForTemplate(tmpl)
    -- 复用现有的 dropTemplateMaterials() 逻辑中的材料计算
    -- 但不立即投放，而是生成需求清单
    local materials = {}
    -- ... 遍历模板blocks，统计每种材料数量 ...
    -- 加5%缓冲
    return materials
end
```

## 需求显示（与 08_UI_HUD.md 配合）

每个活跃需求同时在两处显示：
1. **NPC头顶气泡**：骂人台词 + 材料图标 + 进度条 "圆石 6/10"
2. **右侧HUD列表**：紧凑格式，按紧急度排序，最多显示5条

## 边界情况

1. **NPC正在建造时不产生新建造需求**（但可以产生食物需求）
2. **所有材料都满足但NPC还没开始建** — 等NPC走到建筑区域开始拾取
3. **玩家丢了错误的材料** — 该材料算作"多余"，不计入任何需求，NPC嘲讽 "这不是我要的！"
4. **两个NPC同时要同一种材料** — 材料优先分配给最紧急的需求
5. **NPC在建造过程中死亡** — 建造中断，需求标记为 "failed"，材料保留在地上
