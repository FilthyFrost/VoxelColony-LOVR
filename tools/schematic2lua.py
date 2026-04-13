#!/usr/bin/env python3
"""
Convert Minecraft .schematic files to Lua template format.
Usage: python schematic2lua.py <input.schematic> <output.lua> [--name "Name"]
"""

import sys
import os
from nbt.nbt import NBTFile

# Minecraft block ID → our slot mapping
# Reference: https://minecraft.wiki/w/Java_Edition_data_values/Pre-flattening
BLOCK_MAP = {
    0: None,           # air
    1: "primary",      # stone
    2: None,           # grass (skip ground)
    3: None,           # dirt
    4: "primary",      # cobblestone
    5: "secondary",    # oak planks
    6: None,           # sapling
    8: None, 9: None,  # water
    12: None,          # sand
    13: None,          # gravel
    17: "secondary",   # oak log
    18: None,          # leaves (skip decoration)
    20: "secondary",   # glass
    24: "primary",     # sandstone
    35: "secondary",   # wool (any color → secondary)
    43: "primary",     # double slab
    44: "primary",     # slab → roof
    45: "primary",     # brick
    47: "secondary",   # bookshelf
    48: "primary",     # mossy cobblestone
    50: None,          # torch (skip, furniture handled separately)
    53: "primary",     # oak stairs → roof
    54: None,          # chest (furniture)
    58: "secondary",   # crafting table
    61: "primary",     # furnace
    64: None,          # door (handled as doorPos)
    65: None,          # ladder
    67: "primary",     # cobblestone stairs
    71: None,          # iron door
    72: None,          # pressure plate
    77: None,          # button
    85: "secondary",   # fence
    96: "secondary",   # trapdoor
    98: "primary",     # stone bricks
    101: "secondary",  # iron bars
    102: "secondary",  # glass pane
    109: "primary",    # stone brick stairs
    114: "primary",    # nether brick stairs (→ roof)
    125: "secondary",  # oak double slab
    126: "secondary",  # oak slab
    128: "primary",    # sandstone stairs
    134: "secondary",  # spruce stairs
    135: "secondary",  # birch stairs
    136: "secondary",  # jungle stairs
    139: "primary",    # cobblestone wall
    143: None,         # button
    155: "primary",    # quartz block
    156: "primary",    # quartz stairs
    157: None,         # activator rail
    158: None,         # dropper
    159: "primary",    # stained clay
    160: "secondary",  # stained glass pane
    161: None,         # leaves2
    162: "secondary",  # log2
    163: "secondary",  # acacia stairs
    164: "secondary",  # dark oak stairs
    170: "secondary",  # hay bale
    171: None,         # carpet
    172: "primary",    # hardened clay
}

# Door block IDs (to detect door position)
DOOR_IDS = {64, 71, 193, 194, 195, 196, 197}

def classify_block_name(name):
    """Classify a Minecraft block name string into our slot system.
    Rule: include ALL solid structural blocks. Only skip truly non-structural ones."""
    name = name.lower()
    # Skip: air, water, lava
    if "air" in name: return None
    if "water" in name or "lava" in name: return None
    # Skip: pure decoration (flowers, carpet, signs, banners, buttons)
    if "flower" in name or "tulip" in name or "poppy" in name or "cornflower" in name: return None
    if "carpet" in name: return None
    if "button" in name or "pressure" in name or "lever" in name: return None
    if "sign" in name or "banner" in name or "painting" in name: return None
    if "torch" in name or "lantern" in name: return None
    if "campfire" in name: return None
    if "vine" in name or "sugar_cane" in name or "wheat" in name: return None
    if "potted" in name or "brewing" in name or "grindstone" in name: return None
    if "stonecutter" in name or "bell" in name: return None
    if "cobweb" in name: return None
    # Furniture (skip — handled separately)
    if "bed" in name: return None
    if "chest" in name or "barrel" in name: return None
    # Door (mark for doorPos detection)
    if "door" in name and "trapdoor" not in name: return "door"
    # Glass → secondary
    if "glass" in name and "pane" not in name: return "secondary"
    if "pane" in name: return "secondary"
    # Wood family → secondary
    if "log" in name or "plank" in name or "wood" in name: return "secondary"
    if "stripped" in name: return "secondary"
    if "fence" in name and "gate" not in name: return "secondary"
    if "fence_gate" in name: return "secondary"
    if "bookshelf" in name or "crafting" in name: return "secondary"
    if "trapdoor" in name: return "secondary"
    # Stairs and slabs → primary (structural/roof)
    if "stair" in name: return "primary"
    if "slab" in name: return "primary"
    # Ground blocks → primary (foundation)
    if "dirt" in name or "grass_block" in name or "path" in name: return "primary"
    if "farmland" in name: return "primary"
    if "sand" in name: return "primary"
    if "gravel" in name: return "primary"
    # Leaves → secondary (decorative but visible)
    if "leaves" in name: return "secondary"
    # Ladder → secondary
    if "ladder" in name: return "secondary"
    # Default: all other solid blocks → primary
    return "primary"


def extract_facing(name):
    """Extract facing direction from block state string."""
    import re
    m = re.search(r'facing=(\w+)', name)
    return m.group(1) if m else None

def extract_half(name):
    """Extract half (top/bottom) from block state."""
    import re
    m = re.search(r'half=(\w+)', name)
    if m: return m.group(1)
    m = re.search(r'type=(\w+)', name)  # slabs use type=top/bottom/double
    if m and m.group(1) in ('top','bottom','double'): return m.group(1)
    return None

def extract_shape(name):
    """Extract shape for stairs (straight, inner_left, inner_right, outer_left, outer_right)."""
    import re
    m = re.search(r'shape=(\w+)', name)
    return m.group(1) if m else None

def extract_open(name):
    """Extract open state for trapdoors/doors."""
    import re
    m = re.search(r'open=(\w+)', name)
    return m.group(1) == 'true' if m else False

def extract_axis(name):
    """Extract axis for logs (x/y/z)."""
    import re
    m = re.search(r'axis=(\w+)', name)
    return m.group(1) if m else None


def classify_block_to_material(name):
    """Map Minecraft block to specific block type matching our textures.
    Returns the exact texture key used in textures.lua loadAll()."""
    # Strip block state properties for classification (check base name only)
    base = name.lower().split("[")[0].replace("minecraft:", "")

    if base == "air" or base == "cave_air" or base == "void_air": return None
    if base in ("water","lava"): return None

    # Skip non-structural blocks
    skip_blocks = {"poppy","dandelion","cornflower","lily_of_the_valley","oxeye_daisy",
        "red_tulip","orange_tulip","white_tulip","pink_tulip","blue_orchid","allium","azure_bluet",
        "carpet","red_carpet","white_carpet","black_carpet",
        "stone_button","oak_button","spruce_button","birch_button",
        "stone_pressure_plate","oak_pressure_plate","heavy_weighted_pressure_plate","light_weighted_pressure_plate",
        "lever","redstone_wire","redstone_torch","redstone_wall_torch","repeater","comparator",
        "wall_sign","oak_wall_sign","spruce_wall_sign","oak_sign","spruce_sign",
        "wall_banner","white_banner",
        "painting","item_frame",
        "torch","wall_torch","soul_torch","soul_wall_torch",
        "lantern","soul_lantern",
        "campfire","soul_campfire",
        "vine","sugar_cane","wheat","carrots","potatoes","beetroots","sweet_berry_bush",
        "potted_poppy","potted_orange_tulip","potted_red_tulip","potted_cactus","potted_fern",
        "brewing_stand","grindstone","stonecutter","bell","anvil","cauldron","composter",
        "cobweb","snow","snow_block","ice",
        "red_bed","green_bed","white_bed","blue_bed","cyan_bed",
        "chest","trapped_chest","ender_chest","barrel","shulker_box",
        "grass_block","dirt","dirt_path","coarse_dirt","podzol","farmland","sand","gravel","clay",
    }
    if base in skip_blocks: return None

    # Specific block type mapping using base name (no bracket properties)
    # Doors
    if base in ("oak_door","spruce_door","birch_door","dark_oak_door","iron_door"): return "door"

    # Glass
    if "glass_pane" in base: return "glass_pane"
    if "glass" in base: return "glass"

    # Spruce
    if "stripped_spruce" in base: return "stripped_spruce_log"
    if base == "spruce_planks": return "spruce_planks"
    if "spruce_stairs" in base: return "spruce_stairs"
    if "spruce_slab" in base: return "spruce_slab"
    if "spruce_trapdoor" in base: return "spruce_trapdoor"
    if "spruce_fence_gate" in base: return "fence"
    if "spruce_fence" in base: return "fence"
    if "spruce_log" in base: return "spruce_log"

    # Dark oak
    if base == "dark_oak_planks": return "dark_oak_planks"
    if "dark_oak_stairs" in base: return "dark_oak_stairs"
    if "dark_oak_slab" in base: return "dark_oak_slab"
    if "dark_oak_trapdoor" in base: return "trapdoor"

    # Oak
    if base == "oak_planks": return "oak_planks"
    if "oak_stairs" in base: return "oak_stairs"
    if "oak_slab" in base: return "oak_slab"
    if "oak_log" in base: return "oak_log"
    if "oak_fence" in base: return "fence"

    # Misc wood/decoration
    if "leaves" in base: return "leaves"
    if base == "bookshelf": return "bookshelf"
    if base == "crafting_table": return "crafting_table"
    if "ladder" in base: return "ladder"

    # Stone family
    if "stone_brick" in base: return "stone_bricks"
    if "cobblestone_wall" in base: return "cobblestone_wall"
    if "cobblestone_stairs" in base: return "cobblestone"
    if "cobblestone" in base: return "cobblestone"

    if "sandstone" in base: return "wall"
    if "stone" in base: return "wall"

    # Fallback by keyword
    if "fence" in base: return "fence"
    if "trapdoor" in base: return "trapdoor"
    if "stairs" in base: return "oak_stairs"
    if "slab" in base: return "oak_slab"
    if "log" in base or "wood" in base: return "oak_log"
    if "planks" in base: return "oak_planks"

    return "wall"


def parse_schematic(filepath):
    """Parse a .schematic NBT file (classic or Sponge v2 format)."""
    nbt = NBTFile(filepath, "rb")

    width = int(nbt["Width"].value)
    height = int(nbt["Height"].value)
    length = int(nbt["Length"].value)

    print(f"  Dimensions: {width}x{length}x{height} (W x D x H)")

    blocks = []
    door_pos = None

    # Detect format: classic (has "Blocks") vs Sponge v2 (has "Palette" + "BlockData")
    if "Blocks" in [t.name for t in nbt.tags]:
        # Classic .schematic format
        print("  Format: Classic")
        blocks_raw = nbt["Blocks"].value
        block_ids_used = set()

        for y in range(height):
            for z in range(length):
                for x in range(width):
                    idx = (y * length + z) * width + x
                    block_id = blocks_raw[idx] if idx < len(blocks_raw) else 0
                    if block_id == 0: continue
                    block_ids_used.add(block_id)
                    if block_id in DOOR_IDS:
                        if door_pos is None: door_pos = (x, 0, z)
                        continue
                    # Map classic block IDs to direct material types
                    mat = None
                    if block_id in (1,4,45,48,98,109,139,159): mat = "wall"      # stone types
                    elif block_id in (5,17,47,53,85,96,126,134,135,136,162,163,164): mat = "wood"  # wood types
                    elif block_id in (44,67,108,114,128,43): mat = "roof"         # stairs/slabs
                    elif block_id in (20,102,160): mat = "glass"                  # glass types
                    elif block_id in (2,3,12,13): mat = None                      # dirt/sand skip
                    elif block_id in (6,18,31,37,38,39,40,50,65,66,69,70,72,77,143,171): mat = None  # decoration
                    elif block_id < 256: mat = "wall"                             # unknown solid → wall
                    if mat:
                        blocks.append((x, y, z, mat))

        print(f"  Block IDs used: {sorted(block_ids_used)}")

    elif "Palette" in [t.name for t in nbt.tags]:
        # Sponge Schematic v2 format
        print("  Format: Sponge v2")
        palette = nbt["Palette"]
        block_data = nbt["BlockData"].value

        # Build reverse palette: id → block name
        id_to_name = {}
        for tag_name in palette.keys():
            block_id = int(palette[tag_name].value)
            id_to_name[block_id] = tag_name

        print(f"  Palette entries: {len(id_to_name)}")
        for bid, bname in sorted(id_to_name.items()):
            slot = classify_block_name(bname)
            print(f"    {bid}: {bname} → {slot}")

        # Decode varint block data
        idx = 0
        data_idx = 0
        for y in range(height):
            for z in range(length):
                for x in range(width):
                    if data_idx >= len(block_data):
                        break
                    # Varint decoding
                    value = 0
                    varint_length = 0
                    while True:
                        if data_idx >= len(block_data): break
                        byte = block_data[data_idx]
                        value |= (byte & 0x7F) << (varint_length * 7)
                        data_idx += 1
                        varint_length += 1
                        if (byte & 0x80) == 0: break

                    bname = id_to_name.get(value, "")
                    mat = classify_block_to_material(bname)
                    if mat == "door":
                        if door_pos is None: door_pos = (x, 0, z)
                    elif mat:
                        meta = {
                            'facing': extract_facing(bname),
                            'half': extract_half(bname),
                            'shape': extract_shape(bname),
                            'axis': extract_axis(bname),
                            'open': extract_open(bname),
                        }
                        # Strip None values
                        meta = {k:v for k,v in meta.items() if v is not None and v is not False}
                        blocks.append((x, y, z, mat, meta))

    blocks.sort(key=lambda b: (b[1], b[2], b[0]))

    # Auto-detect ground level: find lowest Y where dirt/grass is < 50%
    from collections import Counter
    y_ground = Counter()
    y_total_c = Counter()
    for b in blocks:
        y_total_c[b[1]] += 1

    # Simpler approach: strip Y levels where dirt/grass dominates
    # Re-parse to check ground blocks specifically
    ground_y = 0
    if "Palette" in [t.name for t in nbt.tags]:
        pal = nbt["Palette"]
        id_map = {}
        for tn in pal.keys():
            id_map[int(pal[tn].value)] = tn
        bd = nbt["BlockData"].value
        y_dirt_cnt = Counter()
        y_all_cnt = Counter()
        di = 0
        for y in range(height):
            for z in range(length):
                for x in range(width):
                    if di >= len(bd): break
                    val = 0; vl = 0
                    while di < len(bd):
                        by = bd[di]; val |= (by & 0x7F) << (vl * 7); di += 1; vl += 1
                        if (by & 0x80) == 0: break
                    nm = id_map.get(val, "")
                    if "air" not in nm:
                        y_all_cnt[y] += 1
                        if "dirt" in nm or "grass" in nm:
                            y_dirt_cnt[y] += 1
        # Find first Y where dirt < 30%
        for y in range(height):
            if y_all_cnt[y] > 0:
                pct = y_dirt_cnt[y] / y_all_cnt[y]
                if pct < 0.3:
                    ground_y = y
                    break
            ground_y = y + 1

    if ground_y > 0:
        print(f"  Ground level detected: y=0 to y={ground_y-1} (stripped)")
        # Shift all blocks down and remove ground blocks
        new_blocks = []
        for b in blocks:
            if b[1] >= ground_y:
                new_blocks.append((b[0], b[1] - ground_y, b[2], b[3], b[4] if len(b) > 4 else {}))
        blocks = new_blocks
        # Adjust door position
        if door_pos:
            door_pos = (door_pos[0], 0, door_pos[2])
        # Adjust height
        height = height - ground_y

    blocks.sort(key=lambda b: (b[1], b[2], b[0]))

    print(f"  Blocks placed: {len(blocks)}")
    if door_pos:
        print(f"  Door detected at: {door_pos}")
    else:
        door_pos = (width // 2, 0, 0)
        print(f"  No door found, defaulting to: {door_pos}")

    return {
        'width': width,
        'height': height,
        'depth': length,
        'blocks': blocks,
        'door_pos': door_pos,
    }

def to_lua(data, name):
    """Convert parsed schematic data to Lua template string."""
    lines = []
    lines.append(f'-- {name}: {data["width"]}x{data["depth"]}x{data["height"]}')
    lines.append(f'-- Converted from Minecraft .schematic')
    lines.append(f'return {{')
    lines.append(f'    name = "{name}",')
    lines.append(f'    w = {data["width"]}, d = {data["depth"]}, h = {data["height"]},')

    dp = data['door_pos']
    lines.append(f'    doorPos = {{x={dp[0]}, y={dp[1]}, z={dp[2]}}},')
    lines.append(f'    tags = {{"community", "minecraft"}},')
    lines.append(f'    blocks = {{')

    for entry in data['blocks']:
        x, y, z, mat = entry[0], entry[1], entry[2], entry[3]
        meta = entry[4] if len(entry) > 4 else {}
        extra = ""
        if meta.get('facing'): extra += f',f="{meta["facing"]}"'
        if meta.get('half'): extra += f',h="{meta["half"]}"'
        if meta.get('shape'): extra += f',s="{meta["shape"]}"'
        if meta.get('axis'): extra += f',a="{meta["axis"]}"'
        if meta.get('open'): extra += f',o=true'
        lines.append(f'        {{x={x},y={y},z={z},t="{mat}"{extra}}},')

    lines.append(f'    }}')
    lines.append(f'}}')

    return '\n'.join(lines)

def main():
    if len(sys.argv) < 3:
        print("Usage: python schematic2lua.py <input.schematic> <output.lua> [--name Name]")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    name = os.path.splitext(os.path.basename(input_path))[0]
    if "--name" in sys.argv:
        idx = sys.argv.index("--name")
        if idx + 1 < len(sys.argv):
            name = sys.argv[idx + 1]

    print(f"Converting: {input_path}")
    data = parse_schematic(input_path)
    lua = to_lua(data, name)

    with open(output_path, 'w') as f:
        f.write(lua)

    print(f"Written to: {output_path}")
    print(f"  {len(data['blocks'])} blocks in template")

if __name__ == "__main__":
    main()
