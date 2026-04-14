# 04 - 玩家投放系统 (Player Dropping)

## 设计意图

玩家的唯一操作手段就是**点击鼠标投放方块**。这个操作必须：
1. 简单到0秒上手（点击 = 投放，没有二义性）
2. 有成长感（升级后一次投放更多）
3. 有操作深度（切换材料、选择投放位置、优先级判断）

## 点击反馈设计（Juice）

每次点击投放都必须给玩家"做了一件事"的满足感。反馈随升级等级演化：

### Lv.1-2（单个/少量方块）— 强调每个方块的重量感

```lua
-- 1. 摄像机微震（落地瞬间触发）
dropShake = {timer = 0, intensity = 0}
function triggerDropShake(count)
    -- Lv.1-2: 明显震动。Lv.3+: 减弱（大量方块时靠视觉壮观感替代）
    local intensity = math.max(0.005, 0.02 / math.sqrt(count))
    dropShake.timer = 0.08
    dropShake.intensity = intensity
end
-- 在cam:update中: 如果dropShake.timer > 0, 叠加随机offset到cam.x/cam.y

-- 2. 落地尘土圆环（expanding ring at ground level）
-- 方块落地时在(gx, 0.02, gz)画一个圆，半径从0.3到1.5扩大，0.3秒后消失
-- 使用 pass:circle() 半透明灰色

-- 3. NPC转头看落地点
-- 最近的NPC: self.lookAtX = gx; self.lookAtZ = gz（复用已有lookAt系统）
-- 0.5秒后清除lookAt

-- 4. 进度条弹跳
-- 气泡中的进度条在材料计入时scale从1.0→1.15→1.0（弹簧动画，0.2秒）

-- 5. "+N"浮动数字
-- 在落地位置生成浮动文字，向上飘0.5格后消失（持续0.6秒）
floatingTexts = {}  -- {x, y, z, text, timer, maxTimer}
function addFloatingText(gx, gz, count)
    floatingTexts[#floatingTexts + 1] = {
        x = gx, y = 0.5, z = gz,
        text = "+" .. count,
        timer = 0.6, maxTimer = 0.6,
    }
end
-- 在lovr.draw中: 遍历floatingTexts, y递增, alpha递减, billboard面向摄像机
```

### Lv.3+（大量方块）— 强调方块雨的壮观感

- 24个方块错开0.05秒依次落下，形成瀑布/弹幕效果
- 多个尘土圆环重叠 = 视觉上像轰炸
- 摄像机不震（否则会晕），改为落地点地面闪白（0.1秒白色平面叠加）
- 浮动数字显示总数 "+24" 而非24个 "+1"
- NPC台词可能切换到兴奋类："哦哦哦！来了来了！"

## 空间策略

### 设计意图

材料投放位置影响NPC拾取效率。NPC必须步行到材料所在位置拾取。把材料丢在NPC附近或建筑工地旁 = 减少NPC行走时间 = 更快完成建造。

这是**有意的涌现玩法** — 奖励观察力强的玩家，不需要显式教学。

**AI Agent注意：不要添加"材料自动传送到NPC位置"或"材料自动吸附"的功能。空间决策是玩家为数不多的策略维度之一。唯一的例外是赌博奖励"磁铁模式"（临时buff），它的价值恰恰建立在平时需要手动瞄准的基础上。**

## 基础投放机制

### 操作流程

```
玩家按←→或数字键选材料 → 鼠标移到目标位置 → 左键点击 → 
方块从天空落下 → 落在地面上变成loose状态 → 计入最近NPC的需求进度
```

### 投放物理行为

```lua
-- 单次点击产生的falling items数量 = dropMultiplier（受升级影响）
function dropItem()
    local gx, gz = cam:getLookTarget()
    if not gx then return end
    
    local itemType = Items.panel_order[selectedIdx]
    local count = playerUpgrade.dropMultiplier  -- 1, 3, 6, 12, 24
    
    for i = 1, count do
        -- 每个方块有轻微随机XZ偏移，形成散落效果
        local offsetX = math.random(-1, 1)
        local offsetZ = math.random(-1, 1)
        local dropX = math.max(0, math.min(Config.GRID - 1, gx + offsetX))
        local dropZ = math.max(0, math.min(Config.GRID - 1, gz + offsetZ))
        
        -- 检查目标位置的堆叠高度
        local topY = findTopY(dropX, dropZ)
        
        fallingItems[#fallingItems + 1] = {
            gx = dropX, gz = dropZ,
            y = Config.FALL_START_Y + i * 0.15,  -- 错开下落时间
            targetY = topY + 1,
            itemType = itemType,
        }
    end
    
    -- 检查是否有NPC需求匹配
    DemandSystem:onPlayerDrop(itemType, gx, gz, count)
end
```

### 投放范围

- 投放位置 = 摄像机视线与地面（y=0）的交点
- 有效范围 = 整个96x96地图（只要摄像机能看到的地方）
- 无效位置 = 视线指向天空时无法投放

## 材料选择

### 控制方式

| 按键 | 功能 |
|------|------|
| ← → | 在材料列表中前后切换 |
| 1-9 | 快捷键直接选择常用材料 |
| 鼠标左键 | 投放当前选中的材料 |

### 快捷键映射

```lua
HOTKEYS = {
    ["1"] = "cobblestone",   -- 圆石（最常用建材）
    ["2"] = "oak_planks",    -- 木板
    ["3"] = "spruce_planks", -- 云杉木板
    ["4"] = "stone_bricks",  -- 石砖
    ["5"] = "glass_pane",    -- 玻璃板
    ["6"] = "door",          -- 门
    ["7"] = "bed",           -- 床
    ["8"] = "torch",         -- 火把
    ["9"] = "apple",         -- 苹果（食物）
}
```

### 材料面板显示

底部中央显示当前选中材料：
```
    ◀  [■] 圆石  3/26  ▶
         当前材料  快捷键/总数
```

当NPC有活跃需求时，需要的材料名称在面板上高亮标注（黄色小圆点）。

## 升级系统

### 投放等级

| 等级 | 每点击投放数 | 升级条件 |
|------|-------------|----------|
| Lv.1 | 1 | 初始 |
| Lv.2 | 3 | 满足第1个完整建造需求 |
| Lv.3 | 6 | 满足第3个完整需求（任意类型） |
| Lv.4 | 12 | 满足第6个完整需求 |
| Lv.5 | 24 | 满足第10个完整需求 |

### "满足需求"的定义

一个**完整建造需求**被满足 = NPC建造完毕（不是材料凑齐，是建筑实际完成）。
食物需求和伴侣需求也计入总满足数，但权重较低（食物=0.5次，伴侣=0.3次）。

### 升级数据结构

```lua
playerUpgrade = {
    dropMultiplier = 1,        -- 当前每点击投放数量
    level = 1,                  -- 当前等级
    totalDemandsSatisfied = 0,  -- 总满足需求计数（加权）
    
    -- 升级阈值
    thresholds = {1, 3, 6, 10}, -- 对应Lv2, Lv3, Lv4, Lv5
    multipliers = {1, 3, 6, 12, 24},
}

function playerUpgrade:onDemandFulfilled(demandType)
    local weight = 1.0
    if demandType == "food" then weight = 0.5
    elseif demandType == "companion" then weight = 0.3 end
    
    self.totalDemandsSatisfied = self.totalDemandsSatisfied + weight
    
    -- 检查升级
    if self.level < #self.multipliers then
        if self.totalDemandsSatisfied >= self.thresholds[self.level] then
            self.level = self.level + 1
            self.dropMultiplier = self.multipliers[self.level]
            -- 触发升级特效 + 提示
            showUpgradeEffect(self.level, self.dropMultiplier)
        end
    end
end
```

### 升级视觉反馈

升级瞬间：
1. 屏幕中央大字闪烁："投放升级！ ×3" （持续2秒）
2. 下一次点击时，多个方块同时从天空落下，视觉上很爽
3. NPC反应："嗯...速度还行"（罕见的半夸奖）

### 升级永久性

- 当局内永久，不会降级
- 赌博惩罚不影响投放等级
- 每局游戏重新从Lv.1开始

## 投放与需求的关联

### 材料分配逻辑

当玩家投放材料时，系统需要判断这些材料"算谁的"：

```lua
function DemandSystem:onPlayerDrop(itemType, gx, gz, count)
    -- 1. 找所有需要这种材料的活跃需求
    local matching = {}
    for _, demand in ipairs(self.activeDemands) do
        if demand.state == "active" then
            for _, mat in ipairs(demand.materials or {}) do
                if mat.itemType == itemType and mat.delivered < mat.needed then
                    matching[#matching + 1] = {demand = demand, mat = mat}
                end
            end
            if demand.type == "food" and itemType == "apple" then
                if demand.foodDelivered < demand.foodNeeded then
                    matching[#matching + 1] = {demand = demand, isFood = true}
                end
            end
        end
    end
    
    -- 2. 按紧急度排序（critical > urgent > normal）
    table.sort(matching, function(a, b)
        return urgencyRank(a.demand.urgency) > urgencyRank(b.demand.urgency)
    end)
    
    -- 3. 分配投放数量
    local remaining = count
    for _, m in ipairs(matching) do
        if remaining <= 0 then break end
        if m.isFood then
            local give = math.min(remaining, m.demand.foodNeeded - m.demand.foodDelivered)
            m.demand.foodDelivered = m.demand.foodDelivered + give
            remaining = remaining - give
        else
            local give = math.min(remaining, m.mat.needed - m.mat.delivered)
            m.mat.delivered = m.mat.delivered + give
            remaining = remaining - give
        end
    end
    
    -- 4. 如果没有匹配的需求，NPC可能喊 WRONG_MATERIAL 台词
    if #matching == 0 and #self.activeDemands > 0 then
        local nearest = findNearestNpcWithDemand(gx, gz)
        if nearest then
            nearest.npc:setDialogue("WRONG_MATERIAL", {material = nearest.neededMaterial})
        end
    end
end
```

## 边界情况

1. **升级后投放数 > 需求剩余数** — 多余的方块仍然物理地落在地面上，不计入需求，但NPC可以用于未来的建造
2. **快速连续点击** — 每次点击都立即生效，没有冷却时间。这是故意的：让玩家可以疯狂连点
3. **投放在NPC头顶** — 方块落在NPC所在格子旁边（±1偏移），不会砸到NPC
4. **投放在已有建筑上** — 方块堆叠在建筑顶部（已有的topY+1），不会替换现有方块
