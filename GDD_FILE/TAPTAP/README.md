# Voxel Colony — New Gameplay Implementation Guide

## What This Is

This folder contains 10 step-by-step instructions to add new gameplay to the already-ported Voxel Colony game. Each step is a self-contained feature. Execute them in order.

## Game Concept (Brief)

The game reverses the player-NPC power dynamic. NPCs are demanding bosses who yell orders in Chinese. The player is a servant who must click to drop building materials and food. NPCs die if the player is too slow. A demon periodically forces the player to gamble. The game ends when all NPCs die.

## Execution Order

Execute these steps in order. After each step, the game should run and be testable.

| Step | File | Feature | New Files Created |
|------|------|---------|-------------------|
| 01 | STEP_01_DEMAND_SYSTEM.md | NPC demand generation + fulfillment tracking | `demand.lua` |
| 02 | STEP_02_DIALOGUE_SYSTEM.md | Chinese dialogue pools + personality suffixes | `dialogue.lua` |
| 03 | STEP_03_INTEGRATE_DEMAND.md | Wire demand system into game, remove old template modes | (modify main) |
| 04 | STEP_04_NPC_SURVIVAL.md | Remove MVP lock, enable hunger/cold death, tutorial protection | (modify npc.lua, config.lua) |
| 05 | STEP_05_HUD_DEMANDS.md | Right-side demand list, death banner, status bar | (modify HUD) |
| 06 | STEP_06_UPGRADE_SYSTEM.md | Drop multiplier 1→3→6→12→24 | `upgrade.lua` |
| 07 | STEP_07_CLICK_JUICE.md | Camera shake, dust rings, floating text, NPC reaction | (modify main) |
| 08 | STEP_08_SPEECH_BUBBLES.md | Chinese dialogue bubbles with progress bars above NPCs | (modify rendering) |
| 09 | STEP_09_GAMBLING_SYSTEM.md | Demon + rock-paper-scissors + dice + buffs + disasters | `gambling.lua` |
| 10 | STEP_10_GAMEOVER.md | Game over screen with stats, Chinese rating, restart | `gameover.lua` |

## Important Notes

1. **Chinese Font**: The game uses Chinese text. Ensure a CJK font (e.g. Noto Sans SC) is loaded for text rendering.
2. **Pure Lua Files**: `demand.lua`, `dialogue.lua`, `upgrade.lua`, `gambling.lua`, `gameover.lua` are pure Lua with no engine dependencies. They work on any Lua runtime.
3. **Engine-Specific Code**: HUD rendering (STEP_05), speech bubbles (STEP_08), click juice (STEP_07), gambling UI (STEP_09), and game over screen (STEP_10) use UrhoX rendering APIs. Adapt the rendering code to match your engine's API.
4. **World Does Not Pause**: During gambling, the game world keeps running. NPCs continue to lose hunger and temperature. This is intentional.
5. **Existing Files Unchanged**: `world.lua`, `pathfind.lua`, `blueprint.lua`, `items.lua`, `config.lua` (except parameter changes in STEP_04), and all `templates/*.lua` files remain unchanged.

## Quick Reference: Key Game Parameters

```
Hunger decay:     1.1/sec (death at 0, ~90 seconds from full)
Temperature decay: 2.2/sec at night without shelter (~45 seconds to freeze)
Day/night cycle:  300 seconds total, night = 75%-95% of cycle (60 seconds)
Max NPCs:         10
Grid size:        96x96
First demon:      180 seconds (3 minutes)
Demon interval:   150 seconds, decaying by 15% each time (min 90s)
Drop multiplier:  1 → 3 → 6 → 12 → 24 (at demands 1, 3, 6, 10)
```
