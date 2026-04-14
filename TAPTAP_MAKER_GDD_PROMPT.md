# TapTap Maker Entry Prompt

Copy and paste the text below into TapTap Maker as your prompt:

---

## Your Task

You are implementing new gameplay features for an existing game called **Voxel Colony**. The game is already built and working — it has voxel world rendering, NPC AI, pathfinding, cooperative building, and 40+ building templates. Your job is to add the new gameplay layer on top.

## Step 1: Download the implementation guide

Clone this GitHub repository. It contains your step-by-step instructions:

```
https://github.com/FilthyFrost/VoxelColony-GDD
```

## Step 2: Read the overview

Open `TAPTAP/README.md` in the repository. It explains:
- What the game is (NPCs boss the player around in Chinese, player clicks to drop blocks, demon gambling)
- The execution order (10 steps)
- Key game parameters (hunger speed, day/night timing, upgrade thresholds)

## Step 3: Execute each step in order

Go to the `TAPTAP/` folder. Open and execute each file in numerical order:

1. `STEP_01_DEMAND_SYSTEM.md` — Create `demand.lua`: NPC demand generation and fulfillment tracking
2. `STEP_02_DIALOGUE_SYSTEM.md` — Create `dialogue.lua`: Chinese dialogue pools with personality suffixes
3. `STEP_03_INTEGRATE_DEMAND.md` — Wire demand system into game loop, remove old template selection modes
4. `STEP_04_NPC_SURVIVAL.md` — Enable hunger/cold death, adjust survival parameters, add tutorial protection
5. `STEP_05_HUD_DEMANDS.md` — Add demand list HUD, death notification banner, urgency indicators
6. `STEP_06_UPGRADE_SYSTEM.md` — Create `upgrade.lua`: drop multiplier 1→3→6→12→24
7. `STEP_07_CLICK_JUICE.md` — Add click feedback: camera shake, dust rings, floating "+N" text
8. `STEP_08_SPEECH_BUBBLES.md` — Add Chinese speech bubbles with progress bars above NPCs
9. `STEP_09_GAMBLING_SYSTEM.md` — Create `gambling.lua`: demon, rock-paper-scissors, dice, buffs, disasters
10. `STEP_10_GAMEOVER.md` — Create `gameover.lua`: game over screen with Chinese NPC rating and restart

**After completing each step, test the game before moving to the next.**

Each step file contains:
- Complete Lua code to create or modify
- Exact instructions on what to change
- A Verification section listing what to test

## Step 4: If you need more context

The root of the repository has detailed design documents (in Chinese) numbered `00_` through `11_`. These explain the design rationale. Reference them if you need to understand WHY a feature works a certain way.

## Important Notes

- The game displays Chinese text. Make sure you have a CJK font loaded (e.g. Noto Sans SC).
- Files like `demand.lua`, `dialogue.lua`, `upgrade.lua`, `gambling.lua`, `gameover.lua` are pure Lua with no engine dependencies. They work as-is.
- HUD rendering, speech bubbles, and gambling UI use UrhoX APIs. Adapt the rendering code examples to match your available API.
- The world does NOT pause during gambling. This is intentional — NPCs keep starving while the player gambles.
- The existing game files (`npc.lua`, `world.lua`, `pathfind.lua`, `blueprint.lua`, `templatelib.lua`, `config.lua`, `items.lua`, `templates/*.lua`) should not be modified except where explicitly stated in STEP_04.
