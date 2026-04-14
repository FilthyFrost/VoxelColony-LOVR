#!/usr/bin/env python3
"""
Convert blueprint text data (from wiki extraction) into Lua template files.
Reads a text file with === STRUCTURE_NAME === sections and block listings.

Usage: python3 blueprint2lua.py input.txt [output_dir]

Block substitution rules:
- white_terracotta, grass_block, dirt, farmland, hay_bale → cobblestone
- white_bed, yellow_bed, red_bed → bed
- white_wool, yellow_wool → oak_planks
- white_carpet, yellow_carpet, green_carpet → SKIP
- wheat, poppy, dandelion → SKIP
- brewing_stand, smithing_table → crafting_table
- lava → SKIP
- iron_bars → glass_pane
- furnace → cobblestone
- yellow_stained_glass_pane, white_stained_glass_pane → glass_pane
- water_cauldron → cauldron
- oak_leaves → leaves
- oak_door → door
- oak_pressure_plate → SKIP
- water → SKIP (can't place water blocks)
- dirt_path → cobblestone
"""

import re
import os
import sys

# Block substitution map
SUBSTITUTE = {
    "white_terracotta": "cobblestone",
    "grass_block": "cobblestone",
    "dirt": "cobblestone",
    "farmland": "cobblestone",
    "hay_bale": "cobblestone",
    "dirt_path": "cobblestone",
    "smooth_stone": "cobblestone",
    "furnace": "cobblestone",
    "white_bed": "bed",
    "yellow_bed": "bed",
    "red_bed": "bed",
    "white_wool": "oak_planks",
    "yellow_wool": "oak_planks",
    "oak_leaves": "leaves",
    "oak_door": "door",
    "brewing_stand": "crafting_table",
    "smithing_table": "crafting_table",
    "iron_bars": "glass_pane",
    "yellow_stained_glass_pane": "glass_pane",
    "white_stained_glass_pane": "glass_pane",
    "water_cauldron": "cauldron",
}

# Blocks to skip entirely (decorative/non-placeable)
SKIP = {
    "white_carpet", "yellow_carpet", "green_carpet", "red_carpet",
    "wheat", "poppy", "dandelion", "rose_bush",
    "oak_pressure_plate", "stone_pressure_plate",
    "lava", "water", "air",
}

# Known valid block types in our game
VALID_TYPES = {
    # Cubes
    "cobblestone", "stone_bricks", "oak_planks", "oak_log", "dark_oak_planks",
    "dark_oak_log", "spruce_planks", "spruce_log", "stripped_spruce_log",
    "stripped_oak_log", "bookshelf", "crafting_table", "leaves", "wall", "wood",
    "roof", "glass", "hay_bale", "smooth_stone",
    # Non-cube
    "oak_stairs", "dark_oak_stairs", "spruce_stairs", "cobblestone_stairs",
    "stone_stairs", "stone_brick_stairs",
    "oak_slab", "spruce_slab", "dark_oak_slab", "smooth_stone_slab",
    "cobblestone_slab", "stone_slab",
    "glass_pane", "cobblestone_wall",
    "fence", "oak_fence", "dark_oak_fence", "oak_fence_gate",
    "door", "bed", "ladder", "torch", "chest",
    "trapdoor", "spruce_trapdoor", "oak_trapdoor",
    # Job site blocks
    "barrel", "smoker", "blast_furnace", "composter", "lectern",
    "loom", "stonecutter", "cartography_table", "fletching_table",
    "grindstone", "anvil", "cauldron", "bell", "campfire",
}


def parse_structures(text):
    """Parse blueprint text into structure dicts."""
    structures = []
    current = None

    for line in text.split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        # Structure header
        m = re.match(r"===\s*(.+?)\s*===", line)
        if m:
            if current:
                structures.append(current)
            name = m.group(1).strip()
            current = {"name": name, "blocks": [], "door": None, "dims": None}
            continue

        if not current:
            continue

        # Dimensions
        if line.startswith("dimensions:"):
            current["dims"] = line.split(":")[1].strip()
            continue

        # Door
        if line.startswith("door:"):
            val = line.split(":")[1].strip()
            if val.lower() != "none" and "open" not in val.lower():
                parts = val.split(",")
                if len(parts) >= 3:
                    try:
                        current["door"] = (int(parts[0]), int(parts[1]), int(parts[2]))
                    except ValueError:
                        pass
            continue

        # Skip metadata lines
        if line.startswith("BLOCKS:") or line.startswith("--") or line.startswith("Note:"):
            continue
        if line.startswith("Materials:") or line.startswith("["):
            continue

        # Parse block entry: x,y,z,type[,facing][,half][,shape]
        parts = line.split(",")
        if len(parts) >= 4:
            try:
                x = int(parts[0].strip())
                y = int(parts[1].strip())
                z = int(parts[2].strip())
                block_type = parts[3].strip()

                # Skip negative Y (sub-ground)
                if y < 0:
                    continue

                # Apply substitution
                if block_type in SKIP:
                    continue
                block_type = SUBSTITUTE.get(block_type, block_type)
                if block_type in SKIP:
                    continue

                # Warn about unknown types
                if block_type not in VALID_TYPES:
                    print(f"  WARNING: Unknown block type '{block_type}' in {current['name']} at ({x},{y},{z}) - using cobblestone")
                    block_type = "cobblestone"

                facing = parts[4].strip() if len(parts) > 4 and parts[4].strip() and parts[4].strip() != "nil" else None
                half = parts[5].strip() if len(parts) > 5 and parts[5].strip() and parts[5].strip() != "nil" else None
                shape = parts[6].strip() if len(parts) > 6 and parts[6].strip() and parts[6].strip() != "nil" else None

                current["blocks"].append({
                    "x": x, "y": y, "z": z,
                    "t": block_type,
                    "f": facing, "h": half, "s": shape,
                })
            except (ValueError, IndexError):
                continue

    if current:
        structures.append(current)

    return structures


def compute_dims(blocks):
    """Compute actual dimensions from blocks."""
    if not blocks:
        return 1, 1, 1
    max_x = max(b["x"] for b in blocks) + 1
    max_y = max(b["y"] for b in blocks) + 1
    max_z = max(b["z"] for b in blocks) + 1
    return max_x, max_z, max_y  # w, d, h


def structure_to_lua(struct):
    """Convert structure dict to Lua template string."""
    blocks = struct["blocks"]
    if not blocks:
        return None

    w, d, h = compute_dims(blocks)
    name = struct["name"]
    door = struct["door"]
    lua_name = name.replace(" ", "_").replace("'", "").lower()

    # Determine tags
    tags = []
    name_lower = name.lower()
    if "small" in name_lower:
        tags.append('"small"')
    elif "medium" in name_lower:
        tags.append('"medium"')
    elif "big" in name_lower or "large" in name_lower:
        tags.append('"large"')
    if "house" in name_lower:
        tags.append('"cozy"')
    if "shop" in name_lower or "smith" in name_lower:
        tags.append('"workshop"')
    if "temple" in name_lower:
        tags.append('"spiritual"')
    if "farm" in name_lower:
        tags.append('"farm"')
    if "stable" in name_lower:
        tags.append('"stable"')
    if "meeting" in name_lower or "fountain" in name_lower:
        tags.append('"social"')
    if "library" in name_lower:
        tags.append('"library"')
    tags.append('"village"')
    tags_str = ", ".join(tags)

    # Door position
    if door:
        door_str = f"{{x={door[0]}, y={door[1]}, z={door[2]}}}"
    else:
        door_str = f"{{x={w // 2}, y=0, z=0}}"

    # Generate block entries
    block_lines = []
    for b in blocks:
        args = [str(b["x"]), str(b["y"]), str(b["z"]), f'"{b["t"]}"']
        if b["f"]:
            args.append(f'"{b["f"]}"')
            if b["h"]:
                args.append(f'"{b["h"]}"')
                if b["s"]:
                    args.append(f'"{b["s"]}"')
            elif b["s"]:
                args.append("nil")
                args.append(f'"{b["s"]}"')
        block_lines.append(f"        add({','.join(args)})")

    blocks_code = "\n".join(block_lines)

    lua = f"""-- {name} (Plains Village)
-- Auto-generated from Minecraft Wiki blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints
return {{
    name = "{name}",
    w = {w}, d = {d}, h = {h},
    doorPos = {door_str},
    tags = {{{tags_str}}},
    blocks = (function()
        local b = {{}}
        local function add(x,y,z,t,f,h,s)
            local entry = {{x=x, y=y, z=z, t=t}}
            if f then entry.f = f end
            if h then entry.h = h end
            if s then entry.s = s end
            b[#b+1] = entry
        end

{blocks_code}

        return b
    end)()
}}
"""
    return lua, lua_name


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 blueprint2lua.py input.txt [output_dir]")
        print("  input.txt can contain multiple === STRUCTURE_NAME === sections")
        sys.exit(1)

    input_file = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "templates"

    os.makedirs(output_dir, exist_ok=True)

    with open(input_file, "r") as f:
        text = f.read()

    structures = parse_structures(text)
    print(f"Parsed {len(structures)} structures")

    for struct in structures:
        result = structure_to_lua(struct)
        if result is None:
            print(f"  SKIP {struct['name']}: no blocks")
            continue
        lua_code, lua_name = result
        output_path = os.path.join(output_dir, f"{lua_name}.lua")
        with open(output_path, "w") as f:
            f.write(lua_code)
        print(f"  Created {output_path} ({len(struct['blocks'])} blocks)")


if __name__ == "__main__":
    main()
