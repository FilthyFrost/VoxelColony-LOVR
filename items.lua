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
}

-- Ordered list for UI carousel
Items.panel_order = {"wall", "wood", "roof", "glass", "door", "bed", "ladder", "torch", "chest", "apple"}

function Items.get(t) return Items.registry[t] end
function Items.getColor(t)
    local d = Items.registry[t]
    return d and d.color or {0.5, 0.5, 0.5}
end

return Items
