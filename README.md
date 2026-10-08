# X Player Armor (`x_player_armor`)

![AI-Assisted](https://img.shields.io/badge/AI--assisted-gray)

High-performance, engine-native modular player armor and shield mod for Luanti. Built from the ground up on SOLID architecture principles, `x_player_armor` completely eliminates the limitations of monolithic player mesh replacement by leaving the player's base character model 100% untouched and mounting lightweight visual entities directly to skeletal bones via engine `set_attach`.

---

## Key Features

- **Untouched Player Model**: Compatible with custom player models, female character meshes, modern high-resolution skins, and `x_player_api` multi-track visual proxies.
- **Multiplayer Performance Blueprint**:
  - Zero server tick overhead (`on_step = nil`).
  - Completely bypasses physics, collisions, and raycasting (`physical = false`, `collide_with_objects = false`, `pointable = false`).
  - Zero database writes (`static_save = false`).
  - Frustum clipping prevention (`forced_visible = false`).
  - Static texture path caching in memory.
- **Modern Interactive UI (`formspec_version[7]`)**:
  - Interactive 3D model preview with 360° mouse rotation and vertical tilt.
  - Reactive live updates on armor equip, unequip, and slot swap.
  - Full drop-in compatibility with `i3`, `unified_inventory`, and `sfinv`.
- **100% glTF 2.0 Binary Pipeline & Unified Textures**:
  - All 9 modular armor and shield parts, armor stands, and display mannequins are supplied in high-efficiency binary `.glb` format.
  - Master `.blend` source files preserved in `assets/`.
  - Unified 64x32 full-set sheets (`x_player_armor_<mat>.png`) for helmet, chestplate, leggings, boots, and shield, drastically reducing asset count and GPU VRAM footprint.
  - Formspec v7 3D interactive model preview powered by multi-material slot isolation (`x_player_armor_preview.glb`), featuring dynamic dual-mesh shield support for both compact bucklers and boots-to-neckline tower shields.
- **Engine-Mastered Audio (`luanti-sounds`)**:
  - High-fidelity mono 44.1 kHz Ogg Vorbis sound effects with anti-click zero-crossing fades and peak normalization (-1.0 dBFS).
  - Multi-sample randomized audio variations for equip, unequip, impacts, and shield blocks.
- **Full Backward Compatibility**:
  - Optional `_G.armor` shim ensuring third-party mods (`mobs_redo`, custom weapons, quest trees) continue operating transparently.
  - Automatic migration from legacy `3d_armor_inventory` metadata.

---

## Armor Materials & Stats

| Material | Defense Level | Heal % | Durability | Special Attributes |
| :--- | :---: | :---: | :---: | :--- |
| **Wood** | 20 | 0% | 80 | Lightweight, early-game crafted from wooden planks |
| **Cactus** | 24 | 0% | 110 | Thorns protection, early desert survival |
| **Steel** | 45 | 0% | 350 | Reliable mid-tier metallurgical protection |
| **Bronze** | 50 | 0% | 450 | Heavy metallurgical alloy protection |
| **Diamond** | 70 | 0% | 1200 | Superior durability and penetration resistance |
| **Gold** | 40 | 12% | 200 | High healing resonance with regenerative ward |
| **Mithril** | 80 | 15% | 1800 | Legendary elven alloy with healing and fall mitigation |
| **Crystal** | 75 | 10% | 1500 | Water breathing and fireward resonance |
| **Nether** | 85 | 5% | 2200 | Netherworldly flame immunity and extreme blast defense |
| **Admin** | 100 | 100% | Infinite | Invulnerability, full flight, and environmental immunity |

Equipping a complete 4-piece or 5-piece matching set grants an automatic **+10% defense bonus**.

---

## API Overview

```lua
-- Register a custom armor item
x_player_armor.register_armor("mymod:helmet_obsidian", {
    description = "Obsidian Greathelm",
    inventory_image = "mymod_inv_helmet_obsidian.png",
    texture = "mymod_helmet_obsidian.png",
    element = "head",
    groups = {
        armor_head = 1,
        armor_uses = 800,
        armor_fire = 1,
        physics_speed = 0.05,
    },
    armor_groups = {fleshy = 85},
    damage_groups = {cracky = 2, snappy = 1, level = 3},
})

-- Listen for armor equip and damage events
x_player_armor.register_on_equip(function(player, index, stack)
    -- Triggered when an armor item is equipped
end)

x_player_armor.register_on_damage(function(player, index, stack, uses)
    -- Triggered when armor absorbs damage
end)
```

For detailed classes, signatures, callbacks, and subsystem methods, see [API.md](API.md).

---

## Developer Tooling

```bash
# Run unit tests
npm test

# Run Luacheck linter
npm run lint

# Compile API.md from EmmyLua annotations via emmylua_doc_cli
npm run doc
```

---

## Author & Attribution

- **Mod Author**: SaKeL
- **Code License**: GNU Lesser General Public License v2.1 or later (LGPL-2.1+)
- **Media License**: Creative Commons Attribution 4.0 International (CC-BY 4.0) & CC0 1.0
