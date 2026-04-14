# TapTap Maker 移植指令

## 你的任务

你需要把一个已经完成的体素殖民地游戏（VoxelColony）从 LOVR 框架 100% 移植到 TapTap Maker 的 UrhoX 引擎中。游戏源码在 GitHub 上。

## 第一步：克隆代码

从这个 GitHub 仓库下载所有代码：
```
https://github.com/FilthyFrost/VoxelColony-LOVR
```

你需要下载整个仓库，特别是以下文件和文件夹：
- `main.lua` — 主程序（需要重写为 UrhoX）
- `npc.lua` — NPC AI 逻辑（直接复用）
- `world.lua` — 世界方块管理（直接复用）
- `pathfind.lua` — A* 寻路（直接复用）
- `blueprint.lua` — 蓝图系统（直接复用）
- `templatelib.lua` — 模板加载器（直接复用）
- `config.lua` — 游戏常量（直接复用）
- `items.lua` — 方块类型注册表（直接复用）
- `templates/` 文件夹 — 40 个建筑模板文件（全部直接复用）
- `PORTING_GUIDE.md` — 详细移植指南（你必须仔细阅读）

## 第二步：阅读移植指南

仔细阅读仓库中的 `PORTING_GUIDE.md` 文件。这个文件包含：
- 哪些文件直接复制、哪些需要重写
- 渲染、输入、相机、UI 的 UrhoX 等价实现
- 性能优化策略
- 逐步移植检查清单

## 第三步：理解游戏是什么

这是一个**体素殖民地建造游戏**（类似简化版 Minecraft + RimWorld）：

**核心玩法循环：**
1. 玩家用 Tab 键切换到 "Template" 模式
2. 用左右箭头浏览 40 种建筑模板（如 Armorer House, Butcher Shop 等）
3. 鼠标点击地面 → 该模板的所有建筑材料从天而降，整齐排列在地面上
4. 按 N 键生成 NPC（最多 10 个）
5. NPC 自动识别材料，自动选址，协同搬运材料到建筑工地
6. NPC 按照模板蓝图从地基到屋顶逐层建造
7. 建完一栋后，玩家可以再投放下一栋的材料
8. 还有 "Preview" 模式可以直接放置完整建筑来预览效果

**三种 UI 模式（Tab 切换）：**
- **Block 模式**：单个放置方块（左右键选方块类型，点击放置）
- **Template 模式**：整套投放建筑材料包（左右键选模板，点击投放）
- **Preview 模式**：直接放置完整建筑（用于检查模板，X 键删除）

**NPC 行为：**
- 10 个 NPC 协同建造，使用持久任务分配系统
- 每个 NPC 认领一个建造步骤，不互相抢
- NPC 走到材料堆拿方块 → 走到建筑旁 → 远程放置
- 建造顺序：低层优先（地基→墙壁→屋顶），但缺材料时会跳过
- NPC 有碰撞检测、分离力（不堆叠）、MTV 弹出（不卡进方块）

## 第四步：移植策略

**直接复用的文件（不需要改动）：**
这些文件是纯 Lua 逻辑，不依赖任何引擎 API：
- `npc.lua` — 2100 行 NPC AI
- `world.lua` — 350 行世界管理
- `pathfind.lua` — 230 行 A* 寻路
- `blueprint.lua` — 325 行蓝图系统
- `templatelib.lua` — 220 行模板系统
- `config.lua` — 110 行常量
- `items.lua` — 110 行方块注册
- `templates/*.lua` — 40 个模板文件

**唯一的例外**：`debuglog.lua` 使用了 `io.open` 写文件日志。如果你的环境不支持文件 I/O，替换为你的引擎的日志系统，或者用空函数代替：
```lua
local log = {write = function() end, init = function() end, setTime = function() end, summary = function() end, perfFrame = function() end}
```

**需要完全重写的文件：**
- `main.lua` — 渲染、输入、相机、UI、材料投放动画

## 第五步：需要你告诉我的信息

在开始移植之前，请先回答以下问题，这样我可以给你更精确的指导：

1. **你的 Lua 环境支持哪些标准库函数？** 特别是：`require()`、`setmetatable()`、`pcall()`、`math.randomseed()`、`os.time()`、`table.sort()`、`string.format()`
2. **你如何加载多个 Lua 文件？** 是用 `require("npc")` 还是其他方式？
3. **你的 3D 渲染 API 是什么？** 如何创建一个方块（Box）并设置位置、颜色？请给一个代码示例
4. **你的输入 API 是什么？** 如何检测键盘按键和鼠标点击？请给一个代码示例
5. **你如何创建 2D UI 文字？** 如何在屏幕上显示文字？
6. **你的项目文件结构是什么？** Lua 文件放在哪里？
7. **你是否支持射线检测（Raycast）？** 如何从摄像机发射射线到地面？
8. **一个场景中能放多少个 3D 对象不卡？** 给一个大概的上限

## 第六步：验证移植成功的标准

移植完成后，请按以下步骤验证：

1. **启动游戏**：应该看到绿色地面 + 蓝色天空 + 一个 NPC
2. **按 Tab**：底部 UI 应该切换到 "Template" 模式，显示模板名称
3. **按左右箭头**：模板名称应该变化（如 "Armorer House" → "Big House" → ...）
4. **点击地面**：大量方块应该从天而降，整齐排列在地面上
5. **按 N 多次**：应该生成多个 NPC（最多 10 个）
6. **等待**：NPC 应该自动走向材料，拿起方块，走到建筑工地旁边，然后建筑逐渐成型
7. **建筑完成**：应该和按 Tab 到 "Preview" 模式放置的完整建筑一模一样

## 关键代码入口点

如果你遇到问题，这些是最重要的代码路径：

**材料投放**：`main.lua` → `dropTemplateMaterials()` 
→ 计算模板所需材料 → 创建下落动画 → 加入 `buildQueue`

**NPC 建造**：`npc.lua` → `_think()` → `_scoreBuildShelter()` / `_scoreHelpBuild()` 
→ `_execBuildShelter()` → `_findBuildSite()` → `_pushBuildTask()` 
→ `_assignStepTask()` → `_doFetchBlock()` → `_doPlaceBlock()`

**方块放置**：`world.lua` → `addBlock()` / `removeBlock()` 
→ 设置 `renderDirty = true` → 渲染层重建视觉

**模板加载**：`templatelib.lua` → `TL.init()` 加载 40 个模板 
→ `TL.toBlueprint()` 转换为蓝图（含 TYPE_MAP 方块类型映射）
