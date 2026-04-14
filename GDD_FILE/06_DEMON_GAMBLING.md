# 06 - 恶魔赌博系统 (Demon Gambling)

## 设计意图

赌博是游戏的"高潮时刻"。它打断点击的机械感，创造决策紧张感。关键设计：**世界不暂停** — 你在赌博时NPC还在饿肚子。这迫使玩家快速决策，并制造"打牌的时候背景传来NPC惨叫"的喜剧效果。

## 恶魔出现

### 触发条件

```lua
demonSystem = {
    firstTriggerTime = 180,     -- 首次：游戏开始后3分钟
    demandCountTrigger = 5,     -- 或满足5个需求后（先到先触发）
    interval = 150,             -- 之后每150秒
    intervalDecay = 0.85,       -- 每次间隔缩短15%
    minInterval = 90,           -- 最短90秒
    nextTriggerTime = 180,      -- 下次触发时间
}
```

### 出场动画

1. 地图边缘冒出黑色烟雾粒子（2秒预警）
2. 恶魔NPC从地图边缘走向殖民地中心（3D实体，红色+黑色方块组成的角色）
3. 所有NPC进入恐慌状态，喊 DEMON_APPEAR 台词，暂停当前任务
4. 屏幕变暗（半透明黑色遮罩），弹出赌博选择UI

### 恶魔的3D外观

```
   [■]         ← 角（红色）
  [█████]      ← 头（深红）
  [■ ■ ■]     ← 脸：白眼+嘴
  [███████]    ← 身体（黑色）
   [█ █]       ← 腿
```
尺寸：比NPC大2倍（高度约3格），在世界中实际行走，有阴影。

## 赌博选择界面

恶魔到达殖民地中心后，弹出半透明选择UI：

```
┌─────────────────────────────────────────┐
│              恶魔的游戏                    │
│                                          │
│  选择你要玩的游戏：                         │
│                                          │
│  [1] 猜拳     胜率50%  ⚡快速             │
│  [2] 骰子     胜率45%  ⏱中等             │
│  [3] 21点     胜率55%  ⏱较慢   (需解锁)   │
│  [4] 转盘     胜率17%  💀高风险高回报       │
│                                          │
│  ⚠ 游戏期间世界不暂停！NPC仍在消耗资源！     │
└─────────────────────────────────────────┘
```

- 按数字键1-4选择游戏
- **21点和转盘默认锁定**，通过成就解锁（见 09_GAME_OVER_AND_REPLAY.md）
- 选择后立即开始，无法取消

## 四种赌博游戏

### 1. 猜拳（石头剪刀布）

**耗时**：约5秒
**胜率**：50%（纯运气）
**风险**：低
**奖励等级**：普通

**演出时间线（总计~5秒）：**

```lua
RPS_TIMELINE = {
    -- Phase 1: 选择（玩家按键）
    {time = 0.0, event = "show_options"},    -- 显示 石头/剪刀/布 三选项
    -- 玩家按1/2/3，锁定选择（手型变大确认）
    
    -- Phase 2: 倒计时蓄力
    {time = 0.0, event = "countdown_3"},     -- "三..." 恶魔手缩回
    {time = 0.5, event = "countdown_2"},     -- "二..." 恶魔手抖动
    {time = 1.0, event = "countdown_1"},     -- "一..."
    
    -- Phase 3: 出手+判定
    {time = 1.5, event = "reveal"},          -- 双方同时出手（放大动画）
    {time = 2.5, event = "result"},          -- 判定（赢=金色闪光, 输=红色裂纹）
    {time = 3.5, event = "end"},             -- 结束，应用奖惩
}
```

UI：
```
┌──────────────────────┐
│      猜拳！           │
│                      │
│  [1]石头 [2]剪刀 [3]布│
│                      │
│   "三...二...一..."    │  ← 倒计时（制造紧张感）
│                      │
│   石头  vs  剪刀      │  ← 同时揭晓（放大动画）
│   你赢了！            │
└──────────────────────┘
```

### 2. 骰子（大小）— 含"吹骰子"点击互动

**耗时**：约10秒
**胜率**：基础45% + 玩家点击加成最多+10% = 最高55%
**风险**：中低
**奖励等级**：普通

**核心设计：让玩家疯狂点击来"吹骰子"，把核心玩法（点击）带入赌博环节。**

**演出时间线（总计~10秒）：**

```lua
DICE_TIMELINE = {
    -- Phase 1: 选择大小（~1秒）
    {time = 0.0, event = "pick_big_small"},
    
    -- Phase 2: 吹骰子！（3秒点击窗口）
    {time = 1.0, event = "blow_start"},      -- "吹骰子！快点击！"
    -- 3秒内玩家疯狂点击鼠标
    -- 每次点击 +1% 胜率（最多+10%）
    -- 屏幕显示"风力条"，随点击次数填充
    {time = 4.0, event = "blow_end"},        -- 点击窗口关闭
    
    -- Phase 3: 骰子滚动（1.5秒）
    {time = 4.5, event = "dice_roll"},       -- 骰子弹跳动画
    
    -- Phase 4: 结果（~2秒）
    {time = 6.0, event = "dice_stop"},       -- 骰子停下，数字放大
    {time = 6.5, event = "announce"},        -- "大！" 或 "小！"
    {time = 7.0, event = "judge"},           -- 判定胜负
    
    -- Phase 4b: 恶魔作弊（10%概率触发）
    -- 如果玩家猜对了，10%概率：
    -- "等等...不对！重来！" 恶魔拍桌子，骰子重掷（新随机结果）
    {time = 7.5, event = "cheat_check"},
    {time = 9.0, event = "final_result"},
}

-- 吹骰子点击加成
diceBlowClicks = 0
function onMouseClickDuringBlow()
    diceBlowClicks = diceBlowClicks + 1
    -- 更新风力条UI
end
function getDiceWinBonus()
    return math.min(10, diceBlowClicks) * 0.01  -- 最多+10%
end
```

UI：
```
┌──────────────────────────┐
│       掷骰子！            │
│                          │
│  [1] 猜大    [2] 猜小     │
│                          │
│  吹骰子！快点击！          │  ← Phase 2
│  风力: ████████░░ (+8%)   │  ← 随点击填充
│                          │
│  🎲 🎲                    │
│  [4] [5] = 9 → 大！       │
│                          │
│  "等等...不对！重来！"     │  ← 恶魔作弊（10%概率）
└──────────────────────────┘
```

### 3. 21点（简化版）

**耗时**：约15-25秒（V2解锁）
**胜率**：55%（有策略空间）
**风险**：中
**奖励等级**：好

```
流程：
1. 玩家和恶魔各发两张牌（恶魔一张暗牌）— 翻牌动画0.3秒/张
2. 玩家选择 "要牌[H]" 或 "停牌[S]"
3. 最接近21点且不爆的一方赢
4. 平局 = 恶魔赢（庄家优势）
5. 简化：只有数字牌(1-10)，无花色/人头牌概念
```

**演出要点：**
- 背景持续显示NPC的饥饿/温度条在下降（半透明叠加在世界画面上）
- 每过5秒，背景弹出NPC的抱怨文本："快点啊！我快饿死了！"
- 翻牌有动画（0.3秒，牌从背面翻到正面）
- 爆牌(>21)时：牌面碎裂特效 + "BUST!" 红色大字
- 恶魔翻暗牌时有0.5秒停顿（制造悬念）

UI：
```
┌──────────────────────────┐
│         21点              │
│                          │
│  恶魔: [7] [?]           │
│                          │
│  你:   [8] [5] = 13      │
│                          │
│  [H] 要牌    [S] 停牌    │
│                          │
│  ⚠ 小蚁-3: "快点啊！"    │  ← 背景NPC在抱怨
│  ⚠ NPC正在挨饿中...      │
└──────────────────────────┘
```

### 4. 俄罗斯转盘

**耗时**：约6秒（V2解锁）
**胜率**：83%存活（6格弹巢，1颗子弹）
**输的后果**：极为严重（超级灾害）
**赢的奖励**：极其丰厚

**演出时间线（总计~6秒，最大化紧张感）：**

```lua
ROULETTE_TIMELINE = {
    {time = 0.0, event = "show_cylinder"},   -- 转盘出现，6个格子可见
    {time = 0.5, event = "prompt"},          -- "准备好了吗？" （无法回头）
    -- 玩家按空格
    {time = 0.0, event = "spin"},            -- 弹巢旋转（动画2秒）
    {time = 2.0, event = "slow_down"},       -- 旋转减速，指针滑过格子
    -- 如果指针经过"子弹格"附近：镜头放大、时间感变慢
    {time = 3.5, event = "stop"},            -- 完全停止
    {time = 4.0, event = "silence"},         -- 0.5秒绝对静默 ← 全游戏最紧张的时刻
    {time = 4.5, event = "trigger"},         -- 判定：
    -- "咔" = 空枪 → 金色爆炸特效 + 超级奖励文字
    -- "砰" = 中弹 → 屏幕红闪 + 裂纹特效 + 超级灾害
    {time = 5.5, event = "end"},
}
```

UI：
```
┌────────────────────────┐
│     俄罗斯转盘          │
│                        │
│      ╭──╮              │
│     │●○○│  ← 旋转中... │
│     │○○○│              │
│      ╰──╯              │
│                        │
│   [空格] 扣扳机         │
│                        │
│  ⚠ 1/6概率：超级灾害    │
│  ✨ 5/6概率：超级奖励    │
│                        │
│   ...（0.5秒静默）...   │  ← 最紧张的半秒
│                        │
│      "咔"  安全！       │  ← 或 "砰" 中弹！
└────────────────────────┘
```

## 奖励系统

赢了赌博获得临时buff（持续时间根据游戏类型不同）。

### 奖励池

```lua
GAMBLING_REWARDS = {
    -- 普通奖励（猜拳/骰子赢）
    normal = {
        {
            name = "双料模式",
            desc = "点击同时投放两种材料",
            duration = 60,
            effect = "dual_material",
        },
        {
            name = "磁铁模式",  
            desc = "方块落地后自动滑向最近的需求NPC",
            duration = 90,
            effect = "magnet",
        },
        {
            name = "缓时光环",
            desc = "NPC需求衰减速度减半",
            duration = 120,
            effect = "slow_decay",
        },
    },
    
    -- 好奖励（21点赢）
    good = {
        {
            name = "连射模式",
            desc = "按住鼠标持续喷射方块流",
            duration = 45,
            effect = "autofire",  -- 按住鼠标，每0.15秒投放一次
        },
        {
            name = "建造加速",
            desc = "NPC建造速度×3",
            duration = 90,
            effect = "build_speed",
        },
    },
    
    -- 超级奖励（俄罗斯转盘赢）
    super = {
        {
            name = "神之手",
            desc = "投放倍率临时×5 + 方块自动飞向需求位置",
            duration = 60,
            effect = "god_hand",
        },
        {
            name = "时间停止",
            desc = "所有NPC需求冻结（不衰减），但可以继续投放",
            duration = 45,
            effect = "time_stop",
        },
    },
}
```

### 奖励效果实现

```lua
-- 双料模式: 每次点击同时投放 selectedMaterial + 第二常用材料
-- 磁铁模式: fallingItem落地后，添加一个滑动动画向最近NPC移动
-- 缓时光环: Config.HUNGER_DECAY *= 0.5, Config.TEMP_DECAY *= 0.5
-- 连射模式: lovr.update里检测鼠标按下状态，每0.15秒调用dropItem()
-- 建造加速: Config.NPC_STEP_TIME *= 0.33
-- 神之手: dropMultiplier *= 5, 方块带追踪效果
-- 时间停止: hunger/temp/stamina decay = 0
```

## 惩罚系统

输了赌博触发天气灾害。

### 灾害类型

```lua
DISASTERS = {
    -- 普通灾害（猜拳/骰子输）
    normal = {
        {
            name = "寒潮",
            desc = "气温骤降，无庇护NPC冻伤速度×3",
            duration = 30,
            effect = function()
                Config.TEMP_DECAY = Config.TEMP_DECAY * 3
            end,
            cleanup = function()
                Config.TEMP_DECAY = originalTempDecay
            end,
        },
        {
            name = "饥荒",
            desc = "所有NPC饥饿速度×2",
            duration = 45,
            effect = function()
                Config.HUNGER_DECAY = Config.HUNGER_DECAY * 2
            end,
        },
    },
    
    -- 严重灾害（21点输）
    severe = {
        {
            name = "暴风",
            desc = "随机摧毁2-3个建筑方块",
            effect = function()
                -- 随机选择已放置方块，移除（模拟被风吹走）
                destroyRandomBlocks(math.random(2, 3))
            end,
        },
    },
    
    -- 超级灾害（俄罗斯转盘输）
    catastrophic = {
        {
            name = "末日风暴",
            desc = "寒潮+饥荒+暴风同时发生",
            duration = 45,
            effect = function()
                Config.TEMP_DECAY = Config.TEMP_DECAY * 4
                Config.HUNGER_DECAY = Config.HUNGER_DECAY * 3
                destroyRandomBlocks(math.random(5, 10))
            end,
        },
    },
}
```

### 灾害视觉效果

```lua
-- 寒潮: 屏幕边缘蓝色渐变 + 雪花粒子
-- 饥荒: 屏幕色调偏黄 + NPC头顶饥饿图标加大
-- 暴风: 屏幕震动 + 方块飞离建筑的动画 + 风声（如果有音频）
-- 末日风暴: 以上全部 + 屏幕裂纹特效
```

## 赌博期间的世界行为

**世界不暂停**。具体表现：
1. `lovr.update(dt)` 正常执行：NPC继续移动、饥饿继续衰减、夜晚继续来
2. 赌博UI是半透明浮层：玩家能看到背景中NPC的动态
3. NPC在赌博期间可能喊 "快点啊！我在等你呢！" / "别赌了！快给我吃的！"
4. 如果赌博期间有NPC死亡，显示死亡通知但不中断赌博

这是故意的设计选择：它制造了**时间压力下的决策紧张感**。21点是高胜率但耗时最长的游戏 — 你赢面大但NPC多饿45秒。猜拳是50/50但只要5秒。玩家在"胜率"和"速度"之间权衡。

## 数据结构

```lua
gamblingSystem = {
    active = false,          -- 是否正在赌博
    currentGame = nil,       -- "rps" | "dice" | "blackjack" | "roulette"
    demon = nil,             -- 恶魔NPC引用（3D实体）
    
    -- 赌博状态
    gameState = {},          -- 游戏特定状态（手牌、骰子值等）
    result = nil,            -- "win" | "lose" | nil
    
    -- 活跃buff/灾害
    activeBuff = nil,        -- {effect, remainingTime, name}
    activeDisaster = nil,    -- {effect, remainingTime, name, cleanup}
    
    -- 解锁状态（跨局不保存，通过成就解锁）
    unlockedGames = {rps = true, dice = true, blackjack = false, roulette = false},
}
```

## 边界情况

1. **赌博中所有NPC死亡** — 赌博立即结束，直接进入Game Over
2. **灾害叠加** — 允许。两个寒潮叠加 = TEMP_DECAY × 9。这是故意的，制造极端压力
3. **buff和灾害同时存在** — 允许。可能出现"连射模式（buff）+ 寒潮（灾害）"的同时存在
4. **恶魔走到目的地前NPC全死了** — 恶魔消失，直接Game Over
