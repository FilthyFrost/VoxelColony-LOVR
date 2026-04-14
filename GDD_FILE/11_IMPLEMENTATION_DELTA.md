# 11 - 实现变更清单 (Implementation Delta)

## 设计意图

本文档为 AI Agent 提供从当前代码到新设计的精确变更指南。每个变更标注：改什么文件、改什么逻辑、优先级。

## 发布里程碑

### V1（最小可玩版本）— 验证核心乐趣

| 阶段 | 内容 | 目标 |
|------|------|------|
| P0 | 需求系统 + 对话系统 + 投放改造 + CJK字体 | 核心循环可玩 |
| P1 | 生存压力解锁 + HUD重构 | 有生死压力 |
| P2 | 升级系统 + 进度曲线 + 点击Juice | 有成长感 |
| P3a | 恶魔赌博（猜拳+骰子）+ 灾害 | 赌博可玩 |
| P4a | Game Over画面 + 内存计分 | 有终点和反馈 |

### V2（完善版本）— 增加深度和重玩性

| 阶段 | 内容 | 目标 |
|------|------|------|
| P3b | 21点 + 俄罗斯转盘 | 完整赌博体验 |
| P4b | 高分榜持久化到文件 | 跨局记录 |
| P5 | 成就系统 | 目标驱动 |
| P6 | 难度修饰符 | 重玩深度 |

**开发原则：做到V1即可验证核心乐趣。如果核心循环（被骂→投放→建造→赌博）不好玩，后面加再多系统也救不回来。先做V1测试手感，再决定V2方向。**

---

## P0: 核心循环（最高优先）

### 前置：CJK字体支持（P0阻塞项）

**LOVR默认字体不支持中文字符。必须在任何中文文本渲染之前解决。**

```
新增文件: assets/NotoSansSC-Regular.ttf
- 下载地址: https://fonts.google.com/noto/specimen/Noto+Sans+SC
- 选择 Regular 权重，约8MB
- 放置在项目根目录下 assets/ 文件夹

修改 main.lua lovr.load():
    hudFont = lovr.graphics.newFont("assets/NotoSansSC-Regular.ttf", 32)
    
修改所有 pass:text() 调用:
    在绘制中文文本前调用 pass:setFont(hudFont)
    注意：世界空间的NPC气泡和屏幕空间的HUD都需要使用此字体
```

### 新文件: `demand.lua`

需求系统模块。核心数据结构和逻辑见 02_NPC_DEMAND_SYSTEM.md。

```
职责:
- 需求生成（教学脚本 + 动态调度 + 性格权重）
- 需求状态管理（active → fulfilled → building → completed）
- 玩家投放与需求的匹配
- 紧急度计算和更新
- 模板材料计算
- 无真空规则（保证始终有活跃需求）
```

### 新文件: `dialogue.lua`

中文对话池模块。全部台词见 03_NPC_DIALOGUE_CN.md。

```
职责:
- 存储所有对话池（按分类 + 性格后缀）
- 台词选择逻辑（随机+去重+性格修饰）
- 模板变量替换（{count}, {material}等）
- 材料中文名映射
```

### 修改: `main.lua`

| 变更 | 细节 |
|------|------|
| 移除 `uiMode` 的 "template" 和 "preview" 模式 | 保留 "block" 模式作为唯一UI模式 |
| 移除 `dropTemplateMaterials()` | NPC自动选模板，玩家不再手动选 |
| 移除 `placePreviewBuilding()` | 不再需要预览 |
| 修改 `dropItem()` | 从凭空投放改为受需求系统控制（计入需求进度） |
| 修改 `lovr.keypressed()` | Tab不再切模式；添加数字键1-9快捷选材料 |
| 修改 `lovr.load()` | 初始化需求系统、对话系统 |
| 修改 `lovr.update()` | 每帧更新需求系统 |
| 修改 `buildQueue` 机制 | 由需求系统驱动而非玩家手动添加 |

### 修改: `npc.lua`

| 变更 | 细节 |
|------|------|
| `NPC:_think()` | 增加需求响应优先级：有活跃建造任务→建造；有食物→吃；无任务→喊需求/闲逛 |
| `NPC:_setThought()` | 替换为 `NPC:setDialogue(category, vars)`，使用 dialogue.lua |
| 气泡渲染 | 从简单文本改为多行气泡（台词+进度条），见 08_UI_HUD.md |
| `NPC:_scoreBuildShelter()` | 改为由需求系统触发，不再自主决策建什么 |
| `NPC:_execBuildShelter()` | 接收需求系统分配的模板，不再自行选择 |

### 修改: `templatelib.lua`

| 变更 | 细节 |
|------|------|
| `TL.chooseBest()` | 保留但改名为 `TL.chooseBestForDemand(npc, gamePhase)` |
| 新增 `TL.calcMaterials(tmpl)` | 计算模板所需材料清单（从 `dropTemplateMaterials` 中提取） |
| 模板池分阶段 | 按 05_PROGRESSION.md 中定义的 Phase 限制可用模板 |

---

## P1: 生存压力

### 修改: `npc.lua`

| 变更 | 细节 |
|------|------|
| **删除MVP模式** | 移除第166-170行的生命值锁定 |
| 修改衰减参数 | 按 07_SURVIVAL_PRESSURE.md 调整 HUNGER_DECAY 等 |
| 新增死亡流程 | `NPC:die()` 添加遗言台词、倒地动画、通知其他NPC |
| 新增 `checkGameOver()` | 所有NPC死亡时触发 |
| 新NPC初始状态 | hunger=80, temp=100, stamina=90（不是全满） |

### 修改: `config.lua`

```lua
-- 修改以下参数:
C.HUNGER_DECAY = 1.1           -- 原0.2 → 1.1（90秒饿死）
C.TEMP_DECAY = 2.2             -- 原1.0 → 2.2（45秒冻死）
-- 保持其他参数不变
```

### 修改: `main.lua`

| 变更 | 细节 |
|------|------|
| 新增死亡横幅渲染 | `drawDeathBanner(pass)` |
| 新增Game Over检测 | 在 `lovr.update()` 中检查存活NPC数 |

### 修改: `main.lua` 的 HUD

| 变更 | 细节 |
|------|------|
| 新增右侧需求列表 | 按紧急度排序的Top 5需求 |
| 修改底部材料选择器 | 添加快捷键提示、需求匹配高亮 |
| 新增升级状态显示 | 左下角的 Lv.X ×N |
| 新增屏幕边缘方向提示 | CRITICAL NPC的方向指示 |
| 移除模板相关HUD | template/preview模式的显示 |

---

## P2: 升级系统

### 新文件: `upgrade.lua`

```
职责:
- 跟踪投放等级（1→3→6→12→24）
- 计算满足需求次数
- 触发升级事件
- 提供当前 dropMultiplier
```

### 修改: `main.lua`

| 变更 | 细节 |
|------|------|
| `dropItem()` | 使用 `upgrade.dropMultiplier` 决定投放数量 |
| 新增升级特效渲染 | 全屏 "投放升级！×N" 动画 |

### 修改: `demand.lua`

| 变更 | 细节 |
|------|------|
| 需求完成时 | 调用 `upgrade:onDemandFulfilled(type)` |

---

## P3: 恶魔赌博

### 新文件: `gambling.lua`

```
职责:
- 恶魔出现时机判断
- 游戏选择UI
- 四种迷你游戏的逻辑
- 奖励/惩罚的应用和倒计时
- 恶魔3D实体的生成和移动
```

### 新文件: `disaster.lua`

```
职责:
- 灾害效果的应用（修改Config参数）
- 灾害倒计时和清理
- 灾害视觉效果
- 方块破坏逻辑
```

### 修改: `main.lua`

| 变更 | 细节 |
|------|------|
| `lovr.update()` | 更新赌博系统、灾害系统 |
| `lovr.draw()` | 绘制恶魔NPC、赌博浮层、灾害视觉效果 |
| `lovr.keypressed()` | 赌博模式下的按键处理（1-4选游戏、H/S打牌等） |

### 修改: `config.lua`

```lua
-- 新增赌博相关参数
C.DEMON_FIRST_TRIGGER = 180
C.DEMON_INTERVAL = 150
C.DEMON_INTERVAL_DECAY = 0.85
C.DEMON_MIN_INTERVAL = 90
```

---

## P4: Game Over + 重玩

### 新文件: `gameover.lua`

```
职责:
- Game Over画面渲染
- 分数计算
- NPC评价选择
- 高分榜管理（读写文件）
- 重新开始逻辑
```

### 新文件: `achievements.lua`

```
职责:
- 成就条件检测
- 成就解锁（持久化到文件）
- 赌博游戏解锁状态
```

### 修改: `main.lua`

| 变更 | 细节 |
|------|------|
| 新增游戏状态机 | `gameState = "playing" / "gambling" / "gameover"` |
| `lovr.update()` | 根据gameState执行不同逻辑 |
| `lovr.draw()` | 根据gameState绘制不同画面 |
| 重新开始 | 清空所有状态，重新初始化 |

---

## 不变更的文件

| 文件 | 原因 |
|------|------|
| `world.lua` | 体素世界逻辑完全保留 |
| `pathfind.lua` | 寻路算法完全保留 |
| `blueprint.lua` | 蓝图系统完全保留（被需求系统调用） |
| `items.lua` | 物品注册表保留（添加材料中文名映射在dialogue.lua中） |
| `textures.lua` | 纹理生成完全保留 |
| `mouse.lua` | 鼠标处理完全保留 |
| `conf.lua` | 窗口配置保留 |
| `debug.lua` | 调试工具保留 |
| `debuglog.lua` | 日志系统保留 |
| `templates/*.lua` | 所有40+建筑模板保留 |

---

## 新文件清单总览

### V1 文件

| 文件 | 阶段 | 行数估计 |
|------|------|---------|
| `assets/NotoSansSC-Regular.ttf` | P0 | 字体文件（~8MB） |
| `demand.lua` | P0 | ~350行 |
| `dialogue.lua` | P0 | ~300行 |
| `upgrade.lua` | P2 | ~100行 |
| `gambling.lua` | P3a | ~300行（猜拳+骰子） |
| `disaster.lua` | P3a | ~150行 |
| `gameover.lua` | P4a | ~150行 |

### V2 文件

| 文件 | 阶段 | 行数估计 |
|------|------|---------|
| `gambling_blackjack.lua` | P3b | ~200行 |
| `gambling_roulette.lua` | P3b | ~150行 |
| `achievements.lua` | P5 | ~100行 |

---

## 测试检查清单

每个阶段完成后应通过以下测试：

### P0完成后
- [ ] 中文字体加载成功，所有中文文本正常显示（不是方块/乱码）
- [ ] 游戏开始，NPC头顶弹出中文气泡要建材
- [ ] NPC性格影响台词后缀（diligent NPC带"效率效率！"，lazy NPC带"好累啊"）
- [ ] 玩家点击投放方块，气泡计数器实时更新
- [ ] 多材料需求时，气泡显示当前最缺的材料，凑齐后自动切换到下一种
- [ ] 材料够了，NPC自动开始建造
- [ ] 建造完成，NPC喊新需求（伴侣/食物）
- [ ] 按N生成新NPC
- [ ] 多NPC同时有不同需求时各自独立喊
- [ ] NPC性格影响需求权重（lazy NPC更频繁要食物，social NPC更频繁要伴侣）
- [ ] 无真空规则：所有需求都满足后立即产生新需求

### P1完成后
- [ ] 不投食物，NPC在~90秒后饿死
- [ ] 夜晚无庇护NPC在~45秒后冻死
- [ ] NPC死亡显示死亡横幅+遗言
- [ ] 所有NPC死亡触发Game Over
- [ ] 右侧HUD显示需求列表，按紧急度排序
- [ ] CRITICAL NPC的屏幕边缘有红色提示

### P2完成后
- [ ] 完成第1个建造需求，投放升级到×3
- [ ] 升级后点击确实掉落3个方块（散落在地面，轻微XZ偏移）
- [ ] 屏幕显示升级特效（"投放升级！×3"）
- [ ] 升级进度在HUD上可见
- [ ] 点击Juice：Lv.1-2方块落地有微震+尘土圆环+"+N"浮动数字
- [ ] 点击Juice：Lv.3+大量方块落下有瀑布效果，地面闪白
- [ ] NPC在收到投放时转头看落地点

### P3a完成后（V1赌博）
- [ ] 3分钟后恶魔出现（3D实体从地图边缘走来）
- [ ] NPC有恐慌反应（喊DEMON_APPEAR台词）
- [ ] 显示游戏选择界面（猜拳/骰子两个可选）
- [ ] 猜拳有倒计时蓄力演出（"三...二...一..."，共5秒）
- [ ] 骰子有"吹骰子"点击阶段（3秒疯狂点击加成胜率）
- [ ] 骰子有10%恶魔作弊重掷
- [ ] 赌博期间世界不暂停（NPC继续衰减）
- [ ] 赢了获得buff（60-120秒），buff图标显示在右下角
- [ ] 输了触发灾害（寒潮/饥荒），灾害有视觉效果
- [ ] 灾害有倒计时，结束后参数恢复

### P4a完成后（V1终局）
- [ ] 所有NPC死亡后进入Game Over画面
- [ ] 显示统计（存活时间、满足需求数、建筑数等）
- [ ] 显示NPC中文毒舌评价（根据分数）
- [ ] 显示总分
- [ ] 点击"再来一局"可在<1秒内重新开始
- [ ] 新局从Lv.1开始，所有状态重置

### === V1完成 === 以下为V2 ===

### P3b完成后（V2赌博扩展）
- [ ] 21点可玩（背景显示NPC饥饿条下降）
- [ ] 俄罗斯转盘可玩（6秒演出含0.5秒静默紧张时刻）
- [ ] 默认锁定，通过成就解锁

### P4b完成后
- [ ] 高分保存到本地文件，跨局保留
- [ ] 新记录时显示"新记录！"动画

### P5完成后
- [ ] 成就在满足条件时解锁并通知
- [ ] 解锁的赌博游戏在下一局可选

### P6完成后
- [ ] 难度修饰符可在Game Over画面选择
- [ ] 修饰符影响游戏参数
- [ ] 分数乘以修饰符倍率
