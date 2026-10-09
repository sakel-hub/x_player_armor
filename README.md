# X Player Armor (`x_player_armor`)

[![ContentDB](https://content.luanti.org/packages/SaKeL/x_player_armor/shields/title/)](https://content.luanti.org/packages/SaKeL/x_player_armor/)
[![ContentDB Downloads](https://content.luanti.org/packages/SaKeL/x_player_armor/shields/downloads/)](https://content.luanti.org/packages/SaKeL/x_player_armor/)
![Luanti](https://img.shields.io/badge/Luanti-5.10%2B-5599ff.svg)
[![Luacheck](https://github.com/sakel-hub/x_player_armor/actions/workflows/luacheck.yml/badge.svg)](https://github.com/sakel-hub/x_player_armor/actions)
[![License: LGPL 2.1](https://img.shields.io/badge/License-LGPL_v2.1-blue.svg)](LICENSE.txt)
[![Media License: CC-BY 4.0](https://img.shields.io/badge/Media-CC_BY_4.0-lightgrey.svg)](LICENSE.txt)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/sakel-hub/x_player_armor/pulls)
![AI-Assisted](https://img.shields.io/badge/AI--assisted-gray)

A modern, high-performance player armor and shield mod for Luanti. Built on an advanced **entity bone attachment architecture**, `x_player_armor` attaches lightweight 3D visual entities directly to character skeletal bones instead of overriding player models with baked textures. Third-party mods can use the standalone **`x_player_armor` API** to effortlessly create and register their own custom 3D armor models (`.glb` and `.b3d`), define custom bone attachment transforms, and customize gear with **zero hard dependencies** (with optional automatic enhancement when `x_player_api` is present).

![X Player Armor Showcase](screenshot.png)

---

## Gameplay & Features

- **Modular Entity Bone Attachment Architecture**: Helmets, chestplates, leggings, boots, and shields attach directly to your character's skeletal bones (`Head`, `Body`, `Arm_Left`, `Arm_Right`, `Leg_Left`, `Leg_Right`) as lightweight, optimized visual entities. Unlike legacy mods that replace your entire character with a baked armor model, your base player mesh, custom skin, and 3D outfit layers remain 100% intact.
- **Third-Party Custom 3D Model Attachments via `x_player_armor` API**: Mod developers are completely freed from rigid baked player textures! Third-party mods can use `x_player_armor.register_armor` to design and attach their own custom 3D model meshes (`.glb` or `.b3d`)—including custom helmets, crowns, wizard hats, pauldrons, cloaks, quivers, wings, or shields. Fully customizable with bespoke bone targets, positional offsets, Euler rotations, visual scaling, multi-material textures, and glow emission—all with **zero external dependencies** required!
- **Zero Hard Dependencies (Optional `x_player_api` Synergy)**: Operates 100% standalone with standard Luanti player models out-of-the-box. When the optional `x_player_api` mod is present, `x_player_armor` automatically detects it and binds visual entities to `x_player_api`'s dual visual proxies (modern `.glb` and legacy `.b3d`) for enhanced locomotion and animation synchronization.
- **Active Shield Defense & Arrow Deflection**: Hold right-click with an equipped shield to raise your guard. Blocking absorbs frontal melee attacks, deflects flying arrows with bounce physics, protects your worn armor from taking wear, and shows a first-person shield indicator. Features a dedicated API allowing third-party projectile and ranged combat mods to easily hook into arrow deflection.
- **Dynamic Combat HUD**: During battle, a sleek on-screen armor HUD appears automatically to show your gear's real-time durability so you always know when an item needs repair without opening your inventory.
- **Sound Effects & Particle Sparks**: Enjoy distinct audio effects and particle sparks when equipping gear, absorbing strikes, blocking attacks, deflecting arrows, or shattering broken armor.
- **Interactive Armor Stands**: Display your favorite armor sets in your base. Right-click to open a visual wardrobe manager, or simply Shift + Left Click with any item in hand to swap your equipped armor and held weapon with the stand in one click.
- **3D Inventory Preview**: Rotate and inspect your character in real-time 3D right inside your inventory screen (`sfinv`, `unified_inventory`, or `i3`). Features full dual-format support for classic 64x32 skins and modern 64x64 dual-layer skins with 3D outer layers (hat, jacket, sleeves, pants) from `skinsdb`, `clothing`, and other skin mods.
- **Matching Set Bonus**: Wearing a full 4-piece or 5-piece matching armor suit grants an automatic **+10% defense bonus**.
- **Lag-Free Multiplayer Performance**: Uses static, optimized visual entities with zero Lua tick overhead (`on_step = nil`). Bone tracking is offloaded directly to the Luanti engine's C++ scene graph, keeping multiplayer servers running at a solid 20 TPS with zero entity lag.
- **Full Drop-in Compatibility**: Works out-of-the-box with mods that expect classic `3d_armor`, `shields`, or `3d_armor_stand` APIs, and automatically migrates older saved inventories.

---

## Why Choose `x_player_armor` Over Classic `3d_armor`?

`x_player_armor` is a modern upgrade designed to give you better visuals, active combat, and smooth multiplayer performance while working seamlessly with all your existing mods and gear.

| Feature | Classic `3d_armor` | `x_player_armor` |
| :--- | :--- | :--- |
| **Visual Architecture** | Overrides your entire player model with a baked mesh (`3d_armor_character.b3d`) and flattened composite textures; blurs skins and strips away 3D clothing. | **Optimized Bone Attachments**: Attaches lightweight, static visual entities directly to your skeletal bones. Your base player model is never replaced, keeping skins and 3D outfit layers 100% intact. |
| **Custom 3D Model Attachments** | Rigid and monolithic: third-party mods must bake armor textures onto a single fixed player mesh template. Cannot attach bespoke 3D meshes or unique bone attachments per piece. | **Standalone 3D Model API**: Third-party mods use `x_player_armor.register_armor` to register unique 3D meshes (`.glb` / `.b3d`) for any armor slot or shield, specifying custom skeletal bones, rotations, offsets, multi-material textures, and glow. Requires zero external dependencies. |
| **Animation & Skeletal Rigging** | Incompatible with modern dual-format player models and animation rigs; overrides or breaks visual proxies and desyncs with custom animation controllers. | **Zero Dependencies + Optional `x_player_api` Synergy**: Functions standalone attaching directly to standard player bones. If `x_player_api` is present, it automatically binds visual entities to dual visual proxies without requiring manual setup. |
| **Multiplayer Performance** | Constantly polls world blocks and recalculates composite textures, causing tick lag, packet bloat, and server stutter. | **Zero-Tick Engine Attachments**: Visual entities run with zero Lua tick overhead (`on_step = nil`), tracked natively in C++ by the Luanti scene graph for lag-free multiplayer. |
| **Shield Combat & Deflection** | Shields are passive stat-sticks—you cannot raise a guard, block attacks, or deflect incoming arrows. | Active shield defense: hold right-click to raise your shield, reducing frontal damage, deflecting flying arrows with bounce physics, and absorbing wear directly onto the shield. Includes full API support for third-party projectile mods. |
| **First-Person Shield View** | No visual indication of raising a shield in first-person view. | A sleek 3D shield appears in your first-person view whenever you raise your guard. |
| **Combat Awareness HUD** | You must open your inventory mid-fight to check if your armor is about to break. | A handy mini-HUD appears during battle with clear color bars (green to red) and chime warnings before gear breaks. |
| **Interactive Armor Stands** | Multiple attached pieces can glitch, duplicate, or leave floating ghost items. | Rock-solid armor stands: Shift + Punch with any item in hand (or empty hand) to swap your equipped suit and held weapon in one click, with zero glitching. |
| **Smooth Movement** | Can clash with sprint and potion mods, causing stuttery movement or speed resets. | Plays nicely with sprint, hunger, and potion mods without interrupting your movement speed. |
| **Drop-In Upgrade** | — | Works instantly as a replacement—keeps all existing crafting recipes, mods, and saved player inventories. |

### Highlights at a Glance

- **Entity Bone Attachment Architecture**: Attaches lightweight 3D entities directly to character skeletal bones (`Head`, `Body`, `Arm_Left`, `Arm_Right`, `Leg_Left`, `Leg_Right`) rather than overriding the player model with baked armor meshes.
- **Custom 3D Model Attachments via `x_player_armor` API**: External mods can easily attach their own custom 3D models (`.glb` and `.b3d`) to any bone with full transform control (`pos`, `rot`, `scale`, `glow`) without needing any external dependencies.
- **Zero Hard Dependencies & Optional `x_player_api` Synergy**: Operates standalone with zero hard dependencies. If `x_player_api` is installed, it automatically binds to dual visual proxies for seamless animation tracking and equip montages.
- **Zero-Tick Multiplayer Performance**: Bone tracking is handled natively by the engine's C++ scene graph (`on_step = nil`), eliminating server tick overhead and lag spikes.
- **Keeps Your Look Intact**: Wear helmets, chestplates, leggings, and boots without turning your character skin into a flattened texture. All modern 3D skin layers (hats, jackets, sleeves) stay crisp and visible.
- **Active Shield Blocking & Arrow Deflection**: Raise your shield to mitigate frontal damage, deflect arrows with realistic bounce physics, absorb wear directly onto the shield, and view your shield in first-person. Third-party mods can easily tap into the deflection API.
- **Real-Time Battle HUD**: Never get surprised by broken gear in the middle of a dungeon. Color-coded health bars and audio warnings keep you informed at a glance.
- **One-Click Wardrobe Stands**: Shift-click an armor stand with any item in hand to instantly swap your armor suit and held weapon, or right-click to open a friendly visual wardrobe.
- **Effortless Switch**: Safe and simple to install on existing worlds—your armor items and crafting recipes carry over automatically.

---

## Armor Materials & Survival Perks

| Material | Defense Level | Health Regen | Durability | Survival Perks |
| :--- | :---: | :---: | :---: | :--- |
| **Wood** | 20 | 0% | 80 | Lightweight starter gear crafted from wood planks |
| **Cactus** | 24 | 0% | 110 | Desert survival with thorns that damage attackers |
| **Steel** | 45 | 0% | 350 | Dependable mid-game metal protection |
| **Bronze** | 50 | 0% | 450 | Tough copper-tin alloy defense |
| **Diamond** | 70 | 0% | 1200 | Exceptional durability and strong damage resistance |
| **Gold** | 40 | 12% | 200 | Regenerates player health over time |
| **Mithril** | 80 | 15% | 1800 | Legendary alloy with health regen and feather falling |
| **Crystal** | 75 | 10% | 1500 | Water breathing and fire protection |
| **Nether** | 85 | 5% | 2200 | Immune to lava, fire, and heavy explosions |
| **Admin** | 100 | 100% | Infinite | Invulnerability, flight, and environmental immunity |

---

## Modding & Extensibility

`x_player_armor` provides a standalone, comprehensive API for 3rd-party mods to register custom armor items, attach bespoke 3D models (`.glb` / `.b3d`), define bone transforms, and customize combat mechanics. **No external dependencies or companion mods are required**—though it automatically adapts if optional mods like `x_player_api` are present.

### 1. Registering Custom 3D Armor Models with `x_player_armor` (Zero Dependencies)

Third-party mods use `x_player_armor.register_armor` to attach custom 3D meshes to any player skeletal bone (such as a crown, horned helm, or pauldron) with custom offsets, rotations, scales, glow, and multi-texturing:

```lua
-- Register a custom headpiece with a custom 3D model attached to the Head bone
x_player_armor.register_armor("mymod:crown_gold", {
    description = "Golden Crown",
    inventory_image = "mymod_inv_crown_gold.png",
    element = "head",
    level = 25,
    material = "gold",
    glow = 8,
    -- Custom 3D model asset (.glb or .b3d)
    mesh = "mymod_crown.glb",
    -- Skeletal bone attachment transforms
    transforms = {
        head = {
            bone = "Head",
            pos = {x = 0, y = 0.5, z = 0},
            rot = {x = 0, y = 0, z = 0},
            scale = {x = 1.05, y = 1.05, z = 1.05},
        },
    },
    groups = {
        armor_head = 1,
        armor_uses = 600,
        armor_fire = 1,
        physics_speed = 0.05,
    },
    armor_groups = {fleshy = 25},
    damage_groups = {cracky = 2, snappy = 1, level = 2},
    sounds = {
        equip = "mymod_crown_equip",
        unequip = "mymod_crown_unequip",
    },
})
```

### 2. Optional: Format-Specific Transforms for `x_player_api` Dual-Model Proxies

`x_player_api` is **strictly optional**. When `x_player_api` is installed, `x_player_armor` automatically attaches visual entities to `x_player_api`'s dual visual proxies (modern `.glb` and legacy `.b3d`). You can optionally supply format-specific transforms so your custom model aligns accurately on both skeletal orientations:

```lua
-- Optional: Provide format-specific transforms for dual GLB/B3D rigs
x_player_armor.register_armor("mymod:pauldron_obsidian", {
    description = "Obsidian Pauldron",
    inventory_image = "mymod_inv_pauldron_obsidian.png",
    element = "torso",
    level = 40,
    mesh = "mymod_pauldron.glb",
    pieces = {"torso"}, -- Only attach to torso bone; omit arm sleeves
    transforms = {
        glb = {
            torso = {bone = "Body", pos = {x = 0, y = 0.1, z = 0}, rot = {x = 0, y = 0, z = 0}},
        },
        b3d = {
            torso = {bone = "Body", pos = {x = 0, y = 0.1, z = 0}, rot = {x = 0, y = 180, z = 0}},
        },
    },
    groups = {
        armor_torso = 1,
        armor_uses = 1000,
    },
})
```

### 3. Registering Custom 3D Shields

Shields can be registered with custom 3D models, frontal damage mitigation, and physical arrow deflection. When `x_player_api` is present, shields automatically attach to the off-hand with custom forearm offsets and first-person visual indicators:

```lua
-- Register a custom 3D shield with blocking and arrow deflection
x_player_armor.register_armor("mymod:shield_dragon", {
    description = "Dragoncrest Greatshield",
    inventory_image = "mymod_inv_shield_dragon.png",
    element = "shield",
    level = 50,
    mesh = "mymod_shield_dragon.glb",
    block_reduction = 0.35, -- 35% frontal damage reduction
    block_arc = 60,         -- 60-degree frontal blocking cone
    deflect_projectiles = true,
    shield_offset = {
        glb = {pos = {x = -0.2, y = 0.1, z = 0.3}, rot = {x = 0, y = 90, z = -10}},
        b3d = {pos = {x = -0.2, y = 0.1, z = 0.3}, rot = {x = 0, y = -90, z = -10}},
    },
    groups = {
        armor_shield = 1,
        armor_uses = 1200,
    },
})
```

### 4. Combat & Lifecycle Callbacks

```lua
-- Listen for armor equip, damage, and shield block events
x_player_armor.register_on_equip(function(player, index, stack)
    -- Triggered when an armor item is equipped
end)

x_player_armor.register_on_damage(function(player, index, stack, uses)
    -- Triggered when armor absorbs damage
end)

x_player_armor.register_on_block(function(player, hitter_or_proj, damage, shield_stack)
    -- Triggered when an attack or projectile is successfully blocked with a shield
end)
```

For complete class definitions, parameter types, callbacks, and subsystem methods, see the full **[API Reference (API.md)](API.md)**.

---

## Requirements & Compatibility

- **Luanti**: Version **5.10.0** or higher
- **Hard Dependencies**: **None** (zero hard dependencies — runs 100% standalone in any Luanti game or arena server)
- **Optional Integrations**:
  - `x_player_api` (Optional: visual proxy binding for dual GLB/B3D rigs, advanced locomotion sync, off-hand shield wielding, and equip montages)
  - `player_api` (Optional: basic player model animation fallback)
  - `default` (Optional: crafting recipes for cactus, steel, bronze, diamond, and gold gear)
  - `sfinv` / `unified_inventory` / `i3` (Optional: inventory tabs and interactive 3D armor preview)
  - `shields`, `3d_armor`, `3d_armor_stand` (Optional: legacy API shims and drop-in compatibility)

---

## Developer Tooling & Verification

The mod includes full developer scripts, testing harnesses, and Luanti static analysis:

```bash
# Run the 73-assertion automated unit test suite
npm test

# Run Luanti static analysis (Luacheck)
npm run lint

# Compile API.md from EmmyLua annotations using emmylua_doc_cli
npm run doc

# Extract, merge, and validate Gettext translations (*.po / *.pot)
npm run i18n

# Validate PO and POT catalogs
npm run i18n:check

# Inspect Weblate translation status
npm run weblate:status

# Sync Weblate translations
npm run weblate:sync-in
npm run weblate:sync-out

# Publish release package to ContentDB
npm run push:ci
```

---

## Author & Attribution

- **Mod Author**: SaKeL
- **Code License**: GNU Lesser General Public License v2.1 or later (LGPL-2.1+)
- **Media License**: Creative Commons Attribution-ShareAlike 3.0 (CC BY-SA 3.0), CC-BY 4.0 & CC0 1.0 (see [LICENSE.txt](LICENSE.txt))
