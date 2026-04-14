# 08 - UI/HUD设计 (User Interface)

## 设计意图

HUD必须在"提供信息"和"不遮挡视野"之间平衡。玩家需要在0.5秒内识别最紧急的事，同时保持对殖民地的视觉掌控。

## 屏幕布局

```
┌──────────────────────────────────────────────────────────────┐
│ [昼/夜 NPC:5]                        [右侧需求列表]          │
│ [操作提示]                           [! 小蚁-1: 圆石 3/10]   │
│                                      [  小蚁-3: 苹果 0/3]    │
│                                      [  小蚁-2: 等待中...]   │
│                        ┌────┐                                │
│                        │ +  │ ← 准星                         │
│                        └────┘                                │
│                                                              │
│            [NPC气泡和世界内容]                                 │
│                                                              │
│                                                              │
│  [升级状态]                                                   │
│  Lv.3 ×6                                                     │
│                                                              │
│ [N]+NPC              ◀ [■] 圆石 1/26 ▶              [BUFF图标]│
└──────────────────────────────────────────────────────────────┘
```

## 各HUD元素详细设计

### 1. 顶部左侧：时间与NPC计数

```
[日/夜  NPC:5/10  存活: 3:42]
```
- 白天显示白色"日"，夜晚显示蓝色"夜"
- NPC数量：当前存活/曾经最大
- 存活时间：分:秒格式

### 2. 右侧：需求列表（Top 5）

```lua
-- 显示规则
-- 1. 按紧急度排序：CRITICAL > URGENT > NORMAL
-- 2. 最多显示5条
-- 3. 每条格式：[紧急标记] NPC名: 材料 进度/需要

-- 颜色编码
CRITICAL = {1.0, 0.2, 0.2, 1.0}  -- 红色，脉冲闪烁
URGENT   = {1.0, 0.8, 0.2, 1.0}  -- 黄色
NORMAL   = {0.9, 0.9, 0.9, 0.8}  -- 白色
IDLE     = {0.5, 0.5, 0.5, 0.5}  -- 灰色（不显示在列表中）
```

单条需求的渲染：
```
┌────────────────────────────┐
│ !! 小蚁-1: 圆石 ████░░ 6/10│  ← CRITICAL：红色+闪烁
│    小蚁-3: 苹果 ░░░░░░ 0/3 │  ← NORMAL：白色
│    小蚁-5: 木板 ██░░░░ 3/8 │  ← URGENT：黄色
└────────────────────────────┘
```

### 3. 底部中央：材料选择器

```
    ◀  [■] 圆石  [1]  ▶
```
- [■] = 材料颜色方块预览
- 材料中文名
- [1] = 快捷键提示
- ◀ ▶ = 可用←→切换
- 当前选中材料如果匹配任何活跃需求 → 名称颜色变**黄色**（提示"这个有人要"）

### 4. 左下角：升级状态

```
Lv.3  ×6
[████████░░] 下次升级: 还差2个需求
```
- 当前等级 + 倍率
- 升级进度条（到下一级的进度）

### 5. 右下角：活跃Buff/灾害图标

```
[🧲 磁铁 42s]  [❄ 寒潮 15s]
```
- Buff图标绿色背景，倒计时
- 灾害图标红色背景，倒计时
- 最多同时显示3个

### 6. 准星

屏幕正中央的十字准星（已有），加上地面高亮方块（已有）。

投放时的额外反馈：
- 点击瞬间准星短暂放大（0.1秒缩放动画）
- 如果投放的材料匹配某个需求 → 准星变绿闪烁
- 如果不匹配 → 准星变灰

### 7. 屏幕边缘方向提示

当某个NPC进入CRITICAL状态时：

```lua
-- 计算NPC在屏幕外的方向
-- 在屏幕对应边缘绘制红色渐变楔形
-- 楔形大小根据紧急程度缩放

function drawDirectionHint(pass, npc, w, h)
    -- 将NPC世界坐标投影到屏幕空间
    -- 如果在屏幕外，在对应边缘画红色箭头
    local screenX, screenY = worldToScreen(npc.x, npc.y, npc.z)
    if screenX < 0 or screenX > w or screenY < 0 or screenY > h then
        -- 画边缘指示器
        local edgeX = math.max(20, math.min(w - 20, screenX))
        local edgeY = math.max(20, math.min(h - 20, screenY))
        pass:setColor(1, 0.2, 0.1, 0.6 + 0.3 * math.sin(gameTime * 5))
        pass:circle(edgeX, edgeY, 0, 15)
    end
end
```

## NPC头顶气泡（世界空间UI）

### 气泡分层

一个NPC头顶最多同时显示：
1. **对话气泡**（最高优先，有需求时显示）
2. **状态图标**（建造锤子/睡觉Zzz/吃东西）

不会同时显示两种 — 对话气泡存在时状态图标隐藏。

### 对话气泡结构

```
Billboard面向摄像机，始终正面朝向玩家

┌────────────────────────────┐
│  喂！给我木板！快点！         │  ← 台词文本（见 03_NPC_DIALOGUE_CN.md）
│  ████████░░  木板 3/8        │  ← 当前最缺材料的进度条
│  建筑总进度: 65%             │  ← 总体完成百分比
└────────────────────────────┘
         ▽                      ← 尖角指向NPC头顶
       [NPC]
```

### 多材料需求的显示规则

一个建筑模板可能需要5-10种不同材料。气泡空间有限，采用以下策略：

**NPC气泡：只显示"当前最缺的那一种材料"**

```lua
-- 选择当前最缺材料的逻辑
function Demand:getMostNeededMaterial()
    local worst = nil
    local worstRatio = 2.0  -- 大于1，确保找到最低的
    for _, mat in ipairs(self.materials) do
        if mat.delivered < mat.needed then
            local ratio = mat.delivered / mat.needed
            if ratio < worstRatio then
                worstRatio = ratio
                worst = mat
            end
        end
    end
    return worst
end
```

当一种材料凑齐后，气泡自动切换到下一种未满足的材料，NPC台词也更新："现在要1个门！"

**右侧HUD需求列表：显示完整材料清单**

```
  小蚁-1 建造中 (65%):
    ✓ 圆石 10/10        ← 已完成（灰色，打钩）
    ▶ 木板 3/8          ← 当前正在要的（高亮黄色）
      门 0/1            ← 排队中（白色）
      床 0/1
```

这样气泡提供"现在该扔什么"的即时信息，HUD提供"还差什么"的全局视图。

### 气泡大小根据紧急度

| 紧急度 | 气泡宽度 | 字体大小 | 特效 |
|--------|---------|---------|------|
| NORMAL | 0.8 | 0.08 | 无 |
| URGENT | 1.0 | 0.10 | 黄色边框 |
| CRITICAL | 1.3 | 0.12 | 红色脉冲+震动 |

### 进度条渲染

```lua
function drawProgressBar(pass, x, y, z, delivered, needed, materialName)
    local ratio = delivered / needed
    local barWidth = 0.6
    local barHeight = 0.06
    
    -- 背景（灰色）
    pass:setColor(0.3, 0.3, 0.3, 0.8)
    pass:box(x, y, z, barWidth, barHeight, 0.01)
    
    -- 填充（绿色渐变到黄色）
    local r = 1 - ratio
    local g = ratio
    pass:setColor(r, g, 0.2, 0.9)
    pass:box(x - barWidth * (1 - ratio) / 2, y, z - 0.005, 
             barWidth * ratio, barHeight, 0.01)
    
    -- 文本
    pass:setColor(1, 1, 1, 0.9)
    pass:text(string.format("%s %d/%d", materialName, delivered, needed),
              x, y - 0.08, z - 0.01, 0.06)
end
```

## 跟随模式的HUD变更

当按V进入跟随模式时：
- 右侧需求列表仍然显示
- 底部材料选择器仍然可用
- 增加跟随模式横幅（已有）
- 仍然可以点击投放（在跟随模式下也能工作）

### 蚁眼模式（F键）

第一人称视角下：
- HUD元素保持不变
- 但NPC气泡变成屏幕空间指示器（不再是世界空间billboard）
- 增加沉浸感：能看到其他NPC在远处建造/叫喊

## 赌博浮层

赌博UI是覆盖在游戏画面上的半透明面板：

```lua
-- 赌博UI绘制
function drawGamblingOverlay(pass, w, h)
    -- 半透明黑色背景（能看到后面的世界）
    pass:setColor(0, 0, 0, 0.5)
    pass:plane(w/2, h/2, 0, w, h)
    
    -- 赌博面板（居中，不全屏）
    local panelW, panelH = 500, 350
    pass:setColor(0.15, 0.1, 0.1, 0.95)
    pass:plane(w/2, h/2, 0, panelW, panelH)
    
    -- 赌博内容（根据当前游戏类型绘制）
    -- ...
    
    -- 右下角小提示："世界仍在运行中！"
    pass:setColor(1, 0.3, 0.3, 0.8)
    pass:text("⚠ NPC仍在消耗资源！", w/2, h/2 + panelH/2 - 20, 0, 12)
end
```

## 死亡横幅

NPC死亡时顶部弹出的通知：

```lua
-- 在屏幕顶部居中显示3秒
deathBanner = {
    active = false,
    text = "",
    timer = 0,
}

function showDeathBanner(npcName, deathCause, lastWords)
    deathBanner.active = true
    deathBanner.text = string.format("☠ %s %s... \"%s\"", npcName, deathCause, lastWords)
    deathBanner.timer = 3.0
end

-- deathCause映射
DEATH_CAUSE = {
    hunger = "饿死了",
    cold = "冻死了",
    hp = "伤重不治",
}
```

## 升级特效

投放等级提升时的全屏提示：

```
[屏幕中央，持续2秒，带缩放动画]

    ╔═══════════════╗
    ║  投放升级！     ║
    ║    ×3 → ×6    ║
    ╚═══════════════╝
```

## 移除的UI元素

以下现有UI元素在新设计中**移除**：
- Tab切换的"template"和"preview"模式（NPC自动选模板）
- 模板选择器（底部的模板名+左右切换）
- [N]+NPC按钮的固定位置（改为仅在伴侣需求时显示提示）

保留的元素：
- 材料选择器（底部中央）
- 准星
- 跟随模式切换（V键、F键）
- 时间/NPC计数（左上角）
