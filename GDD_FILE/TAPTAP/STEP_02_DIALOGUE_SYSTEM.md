# STEP 02: Create Dialogue System

## Task

Create a new file `dialogue.lua` that stores all Chinese dialogue lines for NPCs and provides a function to select appropriate lines based on demand type, NPC personality, and game state.

## Create file: dialogue.lua

```lua
-- dialogue.lua — Chinese NPC Dialogue System
-- All NPC speech in Chinese. NPCs are bratty, entitled bosses who boss the player around.
-- Personality traits append short suffixes to base dialogue lines.

local Dialogue = {}

-- Material name mapping: engine item type -> Chinese display name
Dialogue.MATERIAL_NAMES = {
    cobblestone = "圆石", oak_planks = "木板", spruce_planks = "云杉木板",
    stone_bricks = "石砖", wall = "石墙", wood = "木头", roof = "屋顶",
    glass = "玻璃", glass_pane = "玻璃板", door = "门", bed = "床",
    torch = "火把", chest = "箱子", apple = "苹果", fence = "栅栏",
    spruce_log = "云杉原木", oak_log = "橡木原木", dark_oak_planks = "深色木板",
    dark_oak_log = "深色原木", leaves = "树叶", bookshelf = "书架",
    crafting_table = "工作台", barrel = "木桶", anvil = "铁砧",
    cobblestone_wall = "圆石墙", spruce_stairs = "云杉楼梯",
    oak_stairs = "橡木楼梯", dark_oak_stairs = "深色楼梯",
    spruce_slab = "云杉台阶", oak_slab = "橡木台阶",
    stripped_spruce_log = "去皮云杉", stripped_oak_log = "去皮橡木",
    hay_bale = "干草", campfire = "营火", bell = "钟",
    cauldron = "炼药锅", grindstone = "砂轮", composter = "堆肥桶",
    lectern = "讲台", loom = "织布机", smoker = "烟熏炉",
    blast_furnace = "高炉", stonecutter = "切石机", ladder = "梯子",
    trapdoor = "活板门", spruce_trapdoor = "云杉活板门",
    oak_trapdoor = "橡木活板门", oak_fence = "橡木栅栏",
    dark_oak_fence = "深色栅栏", oak_fence_gate = "栅栏门",
    smooth_stone_slab = "磨制石台阶", cobblestone_slab = "圆石台阶",
    stone_slab = "石头台阶", dark_oak_slab = "深色台阶",
    cobblestone_stairs = "圆石楼梯", stone_stairs = "石头楼梯",
    stone_brick_stairs = "石砖楼梯", cartography_table = "制图台",
    fletching_table = "制箭台", smooth_stone = "磨制石头",
}

function Dialogue.getMaterialName(itemType)
    return Dialogue.MATERIAL_NAMES[itemType] or itemType
end

----------------------------------------------------------------------------
-- DIALOGUE POOLS
----------------------------------------------------------------------------
local LINES = {}

LINES.DEMAND_BUILDING = {
    first = {
        "喂！你！给我搬{count}个{material}来！快点！",
        "嘿！{material}！{count}个！听到没！",
        "我要{count}个{material}！快点的！",
        "赶紧给我弄{count}个{material}过来！",
        "还等什么呢？{material}，{count}个！",
    },
    waiting = {
        "还在等呢...", "今天能搞定吗？", "你是第一天上班？",
        "我自己搬都比你快！", "有没有在做事啊？喂？",
        "你是不是挂机了？", "慢死了！！",
        "地球都要爆炸了你还在磨蹭！", "我等得花都谢了...",
        "再不来我就投诉了！", "要不你直接别干了？",
        "睡着了？？？", "说好的{material}呢？",
        "我数到三！一...二...",
    },
    progress = {
        "就这？继续啊！", "才{delivered}个？还差{remaining}个呢！",
        "终于动了...继续！", "嗯，继续继续，别停！",
        "速度还行...别骄傲！",
    },
    fulfilled = {
        "总算好了！这很难吗？", "哼，勉强及格吧",
        "搞了这么久...算了不说了", "还行吧...下次快点",
        "终于！我都快长蘑菇了！",
    },
}

LINES.DEMAND_FOOD = {
    first = {
        "饿死了！！给我吃的！", "要饿死人了！快给食物！",
        "肚子在叫了！苹果！现在！", "我快饿死了你知道吗？！",
        "吃的！吃的！吃的！",
    },
    waiting = {
        "我的肚子...咕咕咕...", "饿...得...不行了...",
        "你是想饿死我吗？", "别的先不说，先给我吃的！",
        "我已经在啃指甲了...", "再不给吃的我要暴动了！",
        "你自己不饿吗？？",
    },
    fulfilled = {
        "嗯...还行 *嚼嚼嚼*", "总算有吃的了...",
        "哼，味道一般", "下次能不能给点好的？",
    },
}

LINES.DEMAND_COMPANION = {
    first = {
        "太无聊了！给我找个伙伴来！",
        "一个人住太孤单了，再来一个人！",
        "这破地方就我一个人？搞什么？",
        "我需要室友！快去找一个！",
        "人呢？怎么就我一个在干活？",
    },
    waiting = {
        "我跟谁说话啊...跟空气吗？", "孤独...好孤独...",
        "按N键啊！你不识字吗？", "我需要social！懂不懂！",
        "一个人吃饭太惨了...",
    },
    fulfilled = {
        "终于来人了！", "嗯...看着还行吧",
        "新来的！我是老大，记住了！", "不错不错，多来几个！",
    },
}

LINES.DEMAND_EXPANSION = {
    first = {
        "这房子太小了！要扩建！给我{count}个{material}！",
        "我们需要仓库！{material}！{count}个！",
        "该建个新房子了！快搬{material}来！",
        "人越来越多了，需要更多空间！",
    },
    waiting = {
        "挤死了挤死了！", "我连转身的地方都没有！",
        "这也太破了吧...", "你看看人家的房子，再看看我的！",
    },
    fulfilled = {
        "这还差不多", "嗯，比之前好多了", "还行...勉勉强强",
    },
}

LINES.BUILDING = {
    "我来建，你闪开", "看好了，这才叫专业",
    "这房子会很棒的（不是因为你）", "建筑大师在此！",
    "你就在旁边看着学吧",
}

LINES.WRONG_MATERIAL = {
    "这不是我要的！", "我说的是{material}！不是这个！",
    "你眼睛有问题吗？", "错了错了错了！", "能不能认真点？？",
}

LINES.NIGHT_UNSHELTERED = {
    "冷死了！！！", "我没有房子！你想冻死我吗？！",
    "快给我建房子！！我快冻成冰棍了！！", "你晚上有被窝，我呢？？",
}

LINES.DEMON_APPEAR = {
    "不！不要！", "完了完了完了...", "快把那个东西赶走！",
    "救命啊！！", "妈呀！那是什么！", "不不不不不！",
}

LINES.DEATH = {
    "都...怪你...", "最差劲的...仆人...", "我就知道...靠不住...",
    "要是换个人...就好了...", "下辈子...不找你了...",
}

LINES.IDLE = {
    "还行吧...暂时没什么要你做的", "别站着！去找点活干！",
    "嗯...难得清静", "哼 *翘二郎腿*",
}

LINES.UPGRADE_REACT = {
    "嗯...速度还行", "没想到你还有点用", "今天表现...凑合",
}

LINES.GAMEOVER_RATING = {
    [0] = "你是我见过最差劲的仆人。0分。",
    [1] = "烂透了，回去重新投胎吧。1分。",
    [2] = "就这？就这？？2分。",
    [3] = "一般般吧...不是特别废物。3分。",
    [4] = "勉强...算你有手。4分。",
    [5] = "刚好及格，别太得意。5分。",
    [6] = "还行吧...不是特别废物。6分。",
    [7] = "不错嘛...没想到。7分。",
    [8] = "哼...算你及格了。8分。",
    [9] = "勉强...勉强还行啦。9分。",
    [10] = "你...挺厉害的（小声）...才不是夸你！10分。",
}

----------------------------------------------------------------------------
-- PERSONALITY SUFFIXES
-- Appended to base lines 50% of the time to give each NPC distinct voice.
----------------------------------------------------------------------------
local PERSONALITY_SUFFIX = {
    lazy     = {"...好累啊...", "...能不能偷懒...", "...不想动...", "...算了算了..."},
    greedy   = {"...多来点！", "...不够不够！", "...还要更多！", "...翻倍！"},
    shy      = {"...拜托了...", "...那个...", "...小声说...", "...可以吗？"},
    social   = {"大家一起！", "热闹点！", "人多力量大！", "叫上其他人！"},
    diligent = {"效率效率！", "快快快！", "别磨蹭！", "时间就是金钱！"},
    explorer = {"...远处也看看...", "...世界那么大...", "...外面有什么？"},
}

----------------------------------------------------------------------------
-- LINE SELECTION
----------------------------------------------------------------------------

-- Get a dialogue line with variable substitution and personality suffix.
-- category: "DEMAND_BUILDING", "DEMAND_FOOD", etc.
-- subcategory: "first", "waiting", "progress", "fulfilled" (or nil for flat lists)
-- npc: NPC reference (for personality traits)
-- vars: {count=N, material="xxx", delivered=N, remaining=N}
function Dialogue.getLine(category, subcategory, npc, vars)
    local pool
    if subcategory then
        pool = LINES[category] and LINES[category][subcategory]
    else
        pool = LINES[category]
    end
    if not pool or #pool == 0 then return "..." end

    -- Pick random line
    local line = pool[math.random(#pool)]

    -- Variable substitution
    if vars then
        if vars.count then line = line:gsub("{count}", tostring(vars.count)) end
        if vars.material then
            line = line:gsub("{material}", Dialogue.getMaterialName(vars.material))
        end
        if vars.delivered then line = line:gsub("{delivered}", tostring(vars.delivered)) end
        if vars.remaining then line = line:gsub("{remaining}", tostring(vars.remaining)) end
    end

    -- Personality suffix (50% chance, pick first matching trait)
    if npc and npc.traits and math.random() < 0.5 then
        for trait, _ in pairs(npc.traits) do
            local suffixes = PERSONALITY_SUFFIX[trait]
            if suffixes then
                line = line .. suffixes[math.random(#suffixes)]
                break
            end
        end
    end

    return line
end

-- Get game-over rating based on score
function Dialogue.getRating(score)
    if score < 500 then return LINES.GAMEOVER_RATING[0]
    elseif score < 1000 then return LINES.GAMEOVER_RATING[2]
    elseif score < 1500 then return LINES.GAMEOVER_RATING[3]
    elseif score < 2000 then return LINES.GAMEOVER_RATING[4]
    elseif score < 2500 then return LINES.GAMEOVER_RATING[5]
    elseif score < 3000 then return LINES.GAMEOVER_RATING[6]
    elseif score < 3500 then return LINES.GAMEOVER_RATING[7]
    elseif score < 4000 then return LINES.GAMEOVER_RATING[8]
    elseif score < 5000 then return LINES.GAMEOVER_RATING[9]
    else return LINES.GAMEOVER_RATING[10]
    end
end

return Dialogue
```

## Verification

1. `local Dialogue = require("dialogue")`
2. `print(Dialogue.getLine("DEMAND_BUILDING", "first", npcs[1], {count=10, material="cobblestone"}))` should output a Chinese string like "喂！你！给我搬10个圆石来！快点！...效率效率！"
3. `print(Dialogue.getMaterialName("cobblestone"))` should output "圆石"
4. `print(Dialogue.getRating(2800))` should output a Chinese rating string

## Important Notes

- This file is pure Lua with no engine dependencies. It works on any Lua runtime.
- Chinese text rendering requires a CJK font. Make sure your font supports Simplified Chinese characters.
- All NPC speech should use `Dialogue.getLine()` instead of hardcoded strings.
