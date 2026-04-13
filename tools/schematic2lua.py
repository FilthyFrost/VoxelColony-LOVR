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
    """Classify a Minecraft block name string into our slot system."""
    name = name.lower()
    if "air" in name: return None
    if "grass" in name or "dirt" in name or "sand" in name: return None
    if "water" in name or "lava" in name: return None
    if "leaves" in name or "flower" in name or "sapling" in name: return None
    if "carpet" in name: return None
    if "torch" in name or "lantern" in name: return None
    if "button" in name or "pressure" in name or "lever" in name: return None
    if "sign" in name or "banner" in name: return None
    if "bed" in name: return None  # furniture
    if "chest" in name or "barrel" in name: return None  # furniture
    if "door" in name: return "door"
    if "glass" in name or "pane" in name: return "secondary"
    if "log" in name or "wood" in name or "plank" in name or "fence" in name: return "secondary"
    if "stair" in name or "slab" in name: return "primary"
    if "trapdoor" in name: return "secondary"
    if "bookshelf" in name or "crafting" in name: return "secondary"
    # Default: stone/brick/cobble/etc → primary
    return "primary"


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
                    slot = BLOCK_MAP.get(block_id)
                    if slot is None:
                        slot = "primary" if block_id < 256 else None
                    if slot:
                        blocks.append((x, y, z, slot))

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
                    slot = classify_block_name(bname)
                    if slot == "door":
                        if door_pos is None: door_pos = (x, 0, z)
                    elif slot:
                        blocks.append((x, y, z, slot))

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

    for x, y, z, slot in data['blocks']:
        lines.append(f'        {{x={x},y={y},z={z},slot="{slot}"}},')

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
