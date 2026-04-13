-- items.lua — Item registry with Minecraft-style blocks and furniture

local Items = {}

Items.registry = {
    -- Building blocks
    wall   = { label = "石墙",   category = "building", building_type = "wall",  color = {0.60, 0.60, 0.58} },
    roof   = { label = "屋顶",   category = "building", building_type = "roof",  color = {0.42, 0.22, 0.12} },
    wood   = { label = "木板",   category = "building", building_type = "wall",  color = {0.55, 0.38, 0.20} },
    glass  = { label = "玻璃",   category = "building", building_type = "wall",  color = {0.70, 0.85, 0.95}, transparent = true },

    -- Furniture (NPC knows specific placement rules)
    door   = { label = "门",     category = "furniture", furniture_type = "door",   color = {0.45, 0.28, 0.15}, size = {1, 2, 0.2} },
    bed    = { label = "床",     category = "furniture", furniture_type = "bed",    color = {0.80, 0.20, 0.15}, size = {1, 0.6, 2} },
    ladder = { label = "梯子",   category = "furniture", furniture_type = "ladder", color = {0.50, 0.35, 0.18}, size = {1, 1, 0.15} },
    torch  = { label = "火把",   category = "furniture", furniture_type = "torch",  color = {0.90, 0.75, 0.20}, size = {0.2, 0.6, 0.2} },
    chest  = { label = "箱子",   category = "furniture", furniture_type = "chest",  color = {0.55, 0.38, 0.15}, size = {0.9, 0.9, 0.9} },

    -- Food
    apple  = { label = "苹果",   category = "food",      nutrition = 40,            color = {0.80, 0.20, 0.10} },

    -- Extended block types (for schematic buildings)
    cobblestone       = { label = "cobble",  category = "building", building_type = "wall",  color = {0.50, 0.50, 0.48} },
    stone_bricks      = { label = "s.brick", category = "building", building_type = "wall",  color = {0.55, 0.55, 0.53} },
    spruce_planks     = { label = "s.plank", category = "building", building_type = "wall",  color = {0.38, 0.25, 0.14} },
    spruce_log        = { label = "s.log",   category = "building", building_type = "wall",  color = {0.30, 0.18, 0.10} },
    stripped_spruce_log = { label = "str.log", category = "building", building_type = "wall", color = {0.50, 0.35, 0.20} },
    oak_planks        = { label = "o.plank", category = "building", building_type = "wall",  color = {0.60, 0.45, 0.25} },
    dark_oak_planks   = { label = "d.plank", category = "building", building_type = "wall",  color = {0.28, 0.18, 0.08} },
    oak_log           = { label = "o.log",   category = "building", building_type = "wall",  color = {0.42, 0.30, 0.16} },
    fence             = { label = "fence",   category = "building", building_type = "wall",  color = {0.52, 0.38, 0.20} },
    trapdoor          = { label = "trap",    category = "building", building_type = "wall",  color = {0.45, 0.32, 0.17} },
    leaves            = { label = "leaves",  category = "building", building_type = "wall",  color = {0.20, 0.45, 0.15} },
    glass_pane        = { label = "g.pane",  category = "building", building_type = "wall",  color = {0.75, 0.88, 0.95}, transparent = true },
    oak_slab          = { label = "o.slab",  category = "building", building_type = "roof",  color = {0.58, 0.42, 0.22} },
    spruce_slab       = { label = "s.slab",  category = "building", building_type = "roof",  color = {0.36, 0.24, 0.13} },
    cobblestone_wall  = { label = "c.wall",  category = "building", building_type = "wall",  color = {0.50, 0.50, 0.48} },
    bookshelf         = { label = "books",   category = "building", building_type = "wall",  color = {0.55, 0.38, 0.20} },
    crafting_table    = { label = "craft",   category = "building", building_type = "wall",  color = {0.55, 0.40, 0.22} },
    -- Stairs (non-cube: L-shaped)
    spruce_stairs     = { label = "s.stair", category = "building", building_type = "roof",  color = {0.36, 0.24, 0.13} },
    oak_stairs        = { label = "o.stair", category = "building", building_type = "roof",  color = {0.58, 0.42, 0.22} },
    dark_oak_stairs   = { label = "d.stair", category = "building", building_type = "roof",  color = {0.28, 0.18, 0.08} },
    cobblestone_stairs= { label = "c.stair", category = "building", building_type = "roof",  color = {0.50, 0.50, 0.48} },
    -- Trapdoors (non-cube: thin panel)
    spruce_trapdoor   = { label = "s.trap",  category = "building", building_type = "wall",  color = {0.38, 0.25, 0.14} },
    -- Glass pane (thin)
    glass_pane        = { label = "g.pane",  category = "building", building_type = "wall",  color = {0.75, 0.88, 0.95}, transparent = true },
}

-- Ordered list for UI carousel (all block types available to player)
Items.panel_order = {
    -- Basic building
    "wall", "wood", "roof", "glass",
    -- Minecraft building blocks
    "cobblestone", "stone_bricks", "oak_planks", "oak_log",
    "dark_oak_planks", "spruce_planks", "spruce_log", "stripped_spruce_log",
    -- Non-cube blocks
    "oak_stairs", "dark_oak_stairs", "spruce_stairs", "cobblestone_stairs",
    "oak_slab", "spruce_slab",
    "glass_pane", "cobblestone_wall",
    "fence", "trapdoor", "spruce_trapdoor",
    -- Decorative
    "leaves", "bookshelf", "crafting_table",
    -- Furniture
    "door", "bed", "ladder", "torch", "chest",
    -- Food
    "apple",
}

function Items.get(t) return Items.registry[t] end
function Items.getColor(t)
    local d = Items.registry[t]
    return d and d.color or {0.5, 0.5, 0.5}
end

return Items
