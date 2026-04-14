# VoxelColony Porting Guide: LOVR → TapTap Maker (UrhoX)

## Purpose

This document is for an **AI agent** inside TapTap Maker to read and execute. It describes how to 100% port VoxelColony from LOVR framework to UrhoX engine. The game source is at: https://github.com/FilthyFrost/VoxelColony-LOVR

## Architecture Overview

The game has two layers:
1. **Engine layer** (MUST rewrite for UrhoX): rendering, input, resource loading, UI
2. **Logic layer** (COPY as-is): NPC AI, pathfinding, world management, building system, templates

```
┌─────────────────────────────────┐
│         main.lua (REWRITE)      │  ← Rendering, input, UI, camera
├─────────────────────────────────┤
│  npc.lua      (COPY)           │  ← NPC AI, utility scoring, tasks
│  world.lua    (COPY)           │  ← Block grid, collision, markers
│  pathfind.lua (COPY)           │  ← A* pathfinding
│  blueprint.lua(COPY)           │  ← Blueprint generation
│  templatelib.lua (COPY)        │  ← Template loader, toBlueprint
│  config.lua   (COPY)           │  ← Game constants
│  items.lua    (COPY)           │  ← Block type registry
│  templates/*.lua (COPY ALL)    │  ← 40 building templates
└─────────────────────────────────┘
```

## Step 0: Download Source

Clone or download: `https://github.com/FilthyFrost/VoxelColony-LOVR`

Files to copy directly (no changes needed):
- `npc.lua` — 2000+ lines of NPC AI (utility scoring, cooperative building, pathfinding integration)
- `world.lua` — Voxel grid, block management, door system, markers
- `pathfind.lua` — A* 3D pathfinding with jump/drop support
- `blueprint.lua` — Blueprint generation and step management
- `templatelib.lua` — Template loading, dedup, TYPE_MAP normalization, toBlueprint
- `config.lua` — All game constants (grid size, speeds, thresholds)
- `items.lua` — Block type registry with 60+ types
- `templates/` folder — All 40 Lua template files
- `tools/blueprint2lua.py` — Template converter tool

## Step 1: Understand the Game Loop

The LOVR game loop:
```lua
lovr.load()     → Initialize world, NPCs, textures, UI state
lovr.update(dt) → Physics: falling items, world.update, NPC.update (×10)
lovr.draw(pass) → Render: ground grid, blocks (instanced), NPCs, HUD
lovr.keypressed(key)    → Tab/arrows/N/X/Q
lovr.mousepressed(...)  → Drop items/templates
lovr.mousemoved(...)    → Camera rotation
lovr.wheelmoved(...)    → Camera speed
lovr.focus(focused)     → Re-lock mouse
```

In UrhoX, map this to:
```lua
-- If UrhoX uses Component scripts:
function Start()         -- equivalent to lovr.load()
function Update(dt)      -- equivalent to lovr.update(dt) + lovr.draw()
function HandleKeyDown() -- equivalent to lovr.keypressed()

-- If UrhoX uses a main loop:
function init()
function update(dt)
function render()
```

## Step 2: World Rendering (CRITICAL)

### LOVR approach (DO NOT copy):
```lua
-- Custom shader + GPU instancing (LOVR-specific)
pass:setShader(instanceShader)
pass:send('InstanceData', buffer)
pass:draw(cubeMesh, mat4(), count)
```

### UrhoX approach:

Since UrhoX does NOT support custom shaders, use **Node + StaticModel per block** with these optimizations:

**Option A: One Node per block (simplest, works for <5000 blocks)**
```lua
function createBlock(scene, x, y, z, blockType)
    local node = scene:CreateChild("block")
    node:SetPosition(Vector3(x, y + 0.5, z))
    node:SetScale(Vector3(0.98, 0.98, 0.98))
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(getMaterial(blockType))
    return node
end
```

**Option B: StaticModelGroup (batch rendering, UrhoX optimization)**
```lua
-- Group same-material blocks into one StaticModelGroup
local group = scene:CreateChild("cobblestone_group")
local smg = group:CreateComponent("StaticModelGroup")
smg:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
smg:SetMaterial(getMaterial("cobblestone"))
-- Add instance nodes
for _, b in ipairs(cobblestoneBlocks) do
    local inst = group:CreateChild()
    inst:SetPosition(Vector3(b.gx, b.gy + 0.5, b.gz))
    smg:AddInstanceNode(inst)
end
```

**Dirty flag sync**: The game sets `world.renderDirty = true` when blocks change. In UrhoX, when this flag is true, destroy and recreate the block nodes/groups:
```lua
if world.renderDirty then
    world.renderDirty = false
    destroyAllBlockNodes()
    rebuildBlockNodes()  -- create nodes from world.blocks
end
```

### Non-cube block shapes

The game has special shapes. In UrhoX, create custom models or approximate:

| LOVR Shape | UrhoX Equivalent |
|-----------|------------------|
| `pass:box(x,y,z, w,h,d)` | `Box.mdl` with SetScale(w,h,d) |
| Stairs (L-shape) | Two Box nodes (slab + step) grouped under parent |
| Slab (half-height) | `Box.mdl` with SetScale(0.98, 0.48, 0.98) |
| Fence (post + rails) | Three thin Box nodes |
| Glass pane (thin) | `Box.mdl` with SetScale(0.08, 0.98, 0.98) |
| Door (thin panel) | `Box.mdl` with SetScale(0.95, 1.95, 0.15) |

For stairs with facing rotation:
```lua
local parent = scene:CreateChild("stair")
parent:SetPosition(Vector3(x, y + 0.5, z))
parent:SetRotation(Quaternion(facingAngle, Vector3(0, 1, 0)))
-- Bottom slab
local slab = parent:CreateChild()
slab:SetPosition(Vector3(0, -0.25, 0))
slab:SetScale(Vector3(0.98, 0.48, 0.98))
local m1 = slab:CreateComponent("StaticModel")
m1:SetModel(boxModel)
m1:SetMaterial(mat)
-- Top step
local step = parent:CreateChild()
step:SetPosition(Vector3(0, 0.25, 0.25))
step:SetScale(Vector3(0.98, 0.48, 0.48))
local m2 = step:CreateComponent("StaticModel")
m2:SetModel(boxModel)
m2:SetMaterial(mat)
```

## Step 3: Materials / Textures

LOVR uses procedural 16x16 textures generated in `textures.lua`. In UrhoX:

**Option A: Pre-generate texture images**
Run the LOVR game once, screenshot each texture, save as PNG files. Load in UrhoX:
```lua
local mat = Material:new()
mat:SetTexture(TU_DIFFUSE, cache:GetResource("Texture2D", "Textures/cobblestone.png"))
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/Diff.xml"))
```

**Option B: Solid color materials**
Use the color values from `items.lua` as solid-color materials:
```lua
function getMaterial(blockType)
    local color = Items.getColor(blockType)  -- returns {r, g, b}
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(color[1], color[2], color[3])))
    return mat
end
```

## Step 4: Camera System

LOVR camera in `main.lua` (lines 21-133):
- Free-fly camera: WASD + mouse look
- Follow NPC mode
- Ant-eye (first person) mode

In UrhoX:
```lua
-- Create camera node
local cameraNode = scene:CreateChild("Camera")
cameraNode:SetPosition(Vector3(48, 25, 28))
local camera = cameraNode:CreateComponent("Camera")
camera:SetFarClip(300)

-- In Update(dt): move camera based on input
local input = GetInput()
if input:GetKeyDown(KEY_W) then
    cameraNode:Translate(Vector3(0, 0, 1) * speed * dt)
end
-- Mouse look
local mouseMove = input:GetMouseMove()
cameraNode.yaw = cameraNode.yaw - mouseMove.x * sensitivity
cameraNode.pitch = cameraNode.pitch - mouseMove.y * sensitivity
cameraNode:SetRotation(Quaternion(cameraNode.pitch, cameraNode.yaw, 0))
```

## Step 5: Input Handling

Map LOVR input to UrhoX:

| LOVR | UrhoX |
|------|-------|
| `lovr.keypressed(key)` | `SubscribeToEvent("KeyDown", handler)` or `input:GetKeyPress(KEY_xxx)` |
| `lovr.mousepressed(x,y,btn)` | `SubscribeToEvent("MouseButtonDown", handler)` |
| `lovr.mousemoved(x,y,dx,dy)` | `input:GetMouseMove()` |
| `lovr.wheelmoved(x,y)` | `input:GetMouseMoveWheel()` |
| `mouse.setRelativeMode(true)` | `input:SetMouseVisible(false); input:SetMouseMode(MM_RELATIVE)` |

Key mappings:
```lua
-- Tab: cycle UI mode (block → template → preview)
if input:GetKeyPress(KEY_TAB) then
    if uiMode == "block" then uiMode = "template"
    elseif uiMode == "template" then uiMode = "preview"
    else uiMode = "block" end
end
-- Left/Right: change selection
-- N: spawn NPC
-- X: delete preview building
-- V: follow NPC
-- Q: quit
```

## Step 6: Ground Plane

LOVR draws a green ground plane with grid lines:
```lua
pass:setColor(0.35, 0.55, 0.25)
pass:plane(g/2, 0, g/2, g, g, ...)
```

In UrhoX:
```lua
local groundNode = scene:CreateChild("Ground")
groundNode:SetPosition(Vector3(48, 0, 48))
groundNode:SetScale(Vector3(96, 1, 96))
local ground = groundNode:CreateComponent("StaticModel")
ground:SetModel(cache:GetResource("Model", "Models/Plane.mdl"))
local groundMat = Material:new()
groundMat:SetShaderParameter("MatDiffColor", Variant(Color(0.35, 0.55, 0.25)))
ground:SetMaterial(groundMat)
```

## Step 7: NPC Rendering

Each NPC is rendered as a simple humanoid (head + body + legs):
```lua
function renderNPC(scene, npc)
    local node = scene:CreateChild("npc_" .. npc.npcId)
    node:SetPosition(Vector3(npc.x, npc.y, npc.z))
    
    -- Head (skin color)
    local head = node:CreateChild("head")
    head:SetPosition(Vector3(0, 1.6, 0))
    head:SetScale(Vector3(0.35, 0.35, 0.35))
    addBoxModel(head, Color(0.85, 0.7, 0.55))
    
    -- Body (shirt color from npc.shirtColor)
    local body = node:CreateChild("body")
    body:SetPosition(Vector3(0, 1.1, 0))
    body:SetScale(Vector3(0.4, 0.55, 0.25))
    addBoxModel(body, Color(npc.shirtColor[1], npc.shirtColor[2], npc.shirtColor[3]))
    
    -- Legs (pants color)
    local legs = node:CreateChild("legs")
    legs:SetPosition(Vector3(0, 0.5, 0))
    legs:SetScale(Vector3(0.35, 0.55, 0.2))
    addBoxModel(legs, Color(npc.pantsColor[1], npc.pantsColor[2], npc.pantsColor[3]))
    
    return node
end
```

Update NPC positions every frame:
```lua
for i, npc in ipairs(npcs) do
    npcNodes[i]:SetPosition(Vector3(npc.x, npc.y, npc.z))
end
```

## Step 8: HUD / UI

LOVR draws text directly in 3D. UrhoX uses a 2D UI system:

```lua
-- Create UI elements
local uiRoot = GetUI():GetRoot()

-- Bottom selector bar
local selectorBar = uiRoot:CreateChild("BorderImage")
selectorBar:SetAlignment(HA_CENTER, VA_BOTTOM)
selectorBar:SetSize(360, 50)

-- Template/block name text
local nameText = selectorBar:CreateChild("Text")
nameText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 16)
nameText:SetText("Armorer House")
nameText:SetAlignment(HA_CENTER, VA_CENTER)

-- NPC status panel (right side)
for i, npc in ipairs(npcs) do
    local label = uiRoot:CreateChild("Text")
    label:SetPosition(IntVector2(width - 240, 16 + (i-1) * 20))
    label:SetText(npc.name .. " " .. npc:getState())
end
```

## Step 9: Falling Items Animation

LOVR animates falling blocks with `fi.y -= FALL_SPEED * dt`. In UrhoX, either:

**Option A: Manual position update (same as LOVR)**
```lua
for i = #fallingItems, 1, -1 do
    local fi = fallingItems[i]
    fi.y = fi.y - Config.FALL_SPEED * dt
    if fi.y <= fi.targetY + 0.5 then
        world:addBlock(fi.gx, fi.targetY, fi.gz, fi.itemType, "loose")
        fi.node:Remove()  -- remove visual node
        table.remove(fallingItems, i)
    else
        fi.node:SetPosition(Vector3(fi.gx, fi.y, fi.gz))
    end
end
```

**Option B: Use UrhoX's ValueAnimation**
```lua
local anim = ValueAnimation:new()
anim:SetKeyFrame(0, Variant(Vector3(gx, 10, gz)))
anim:SetKeyFrame(0.8, Variant(Vector3(gx, 0, gz)))
node:SetAttributeAnimation("Position", anim, WM_ONCE)
```

## Step 10: Raycast for Block Placement

LOVR uses `cam:getLookTarget()` to find where the player is looking at ground level. In UrhoX:

```lua
function getLookTarget()
    local ray = camera:GetScreenRay(0.5, 0.5)  -- center of screen
    -- Intersect with Y=0 plane
    local t = -ray.origin.y / ray.direction.y
    if t > 0 then
        local hit = ray.origin + ray.direction * t
        local gx = math.floor(hit.x + 0.5)
        local gz = math.floor(hit.z + 0.5)
        if gx >= 0 and gx < Config.GRID and gz >= 0 and gz < Config.GRID then
            return gx, gz
        end
    end
    return nil, nil
end
```

## Step 11: Performance Optimization for Mobile

Since custom shaders are not available, use these UrhoX-specific optimizations:

1. **StaticModelGroup**: Batch same-material blocks (see Step 2 Option B)
2. **Occlusion culling**: Enable `renderer:SetMaxOccluderTriangles(5000)`
3. **LOD**: Use simplified models for distant blocks
4. **View distance**: Set `camera:SetFarClip(100)` on mobile (vs 300 on PC)
5. **Reduce block count**: On mobile, skip decorative blocks (torches, fences) beyond 30 units

## Step 12: Sound (Optional)

The LOVR version has no sound. To add:
```lua
-- Block placement sound
local source = scene:CreateComponent("SoundSource3D")
source:Play(cache:GetResource("Sound", "Sounds/place.wav"))

-- NPC walking sound
-- Ambient music
```

## Critical Logic Files — What Each Does

| File | Lines | Purpose | Port Notes |
|------|-------|---------|------------|
| `npc.lua` | ~2100 | NPC AI: 11 utility actions, cooperative building, pathfinding, combat | COPY. Only change: remove `lovr` references in debug logging |
| `world.lua` | ~350 | Voxel grid, addBlock/removeBlock, isSolid, canStandAt, door system, gravity | COPY as-is |
| `pathfind.lua` | ~230 | A* with binary heap, jump/drop/climb | COPY as-is |
| `blueprint.lua` | ~325 | Dynamic room generation, step management, furnishing | COPY as-is |
| `templatelib.lua` | ~220 | Load templates, TYPE_MAP normalization, toBlueprint, chooseBest | COPY as-is |
| `config.lua` | ~110 | All tuning constants | COPY, may adjust GRID size for mobile |
| `items.lua` | ~110 | Block type registry, colors, categories | COPY as-is |
| `templates/*.lua` | 40 files | Building blueprints | COPY all files |
| `main.lua` | ~1200 | REWRITE entirely for UrhoX | See Steps 1-11 |
| `debuglog.lua` | ~45 | File-based logging | REWRITE: use UrhoX's log system |

## File-by-File Porting Checklist

- [ ] Create UrhoX project structure
- [ ] Copy all logic files (npc, world, pathfind, blueprint, templatelib, config, items)
- [ ] Copy templates/ folder (all 40 files)
- [ ] Create ground plane
- [ ] Implement block rendering (Box models with materials)
- [ ] Implement dirty-flag rebuild system
- [ ] Implement camera (free-fly + follow modes)
- [ ] Implement input handling (Tab, arrows, N, click)
- [ ] Implement HUD (mode indicator, template name, NPC status)
- [ ] Implement NPC rendering (head + body + legs)
- [ ] Implement falling items animation
- [ ] Implement raycast for placement target
- [ ] Implement material drop system (dropTemplateMaterials)
- [ ] Implement preview building placement
- [ ] Test with Armorer House template
- [ ] Test with 10 NPCs building cooperatively
- [ ] Performance test on target platform
- [ ] Adjust Config values for mobile if needed

## Common Pitfalls

1. **`require()` paths**: LOVR uses `require("npc")`. UrhoX may need full paths or different module loading.
2. **`math.random`**: Ensure random seed is set (`math.randomseed(os.time())`)
3. **`table.sort` stability**: The game relies on stable sort with `_origIdx` tiebreaker. Lua's sort is unstable — the tiebreaker code handles this.
4. **`world.renderDirty`**: This flag is set by world.lua. The rendering layer MUST check it and rebuild visuals.
5. **`NPC.buildQueue`**: This is a shared table set from the main script (`NPC.buildQueue = buildQueue`). Must be set before NPCs are created.
6. **Frame timing**: `dt` must be in seconds. Some engines use milliseconds.
7. **Coordinate system**: LOVR uses Y-up. UrhoX also uses Y-up. No conversion needed.
