# X Player Armor (`x_player_armor`)

![AI-Assisted](https://img.shields.io/badge/AI--assisted-gray)

A modern, high-performance player armor and shield mod for Luanti. Built to give players full 3D visual gear, active shield combat, and elemental survival perks while keeping your character skin completely intact and multiplayer gameplay butter-smooth.

---

## Gameplay & Features

- **Modular 3D Armor & Shields**: Helmets, chestplates, leggings, boots, and shields fit naturally over your character without replacing or hiding your skin. Works seamlessly with custom player skins and `x_player_api` biomechanical animations.
- **Active Shield Combat & Parrying**: Hold right-click with a shield equipped to brace for impact. Block frontal melee attacks, deflect flying arrows, and knock aggressive monsters backward with a physical counter-impulse.
- **Dynamic Combat HUD**: During battle, a sleek on-screen armor HUD appears automatically to show your gear's real-time durability so you always know when an item needs repair without opening your inventory.
- **Sound Effects & Particle Sparks**: Enjoy distinct audio effects and particle sparks when equipping gear, absorbing strikes, deflecting arrows, or shattering broken armor.
- **Interactive Armor Stands**: Display your favorite armor sets in your base. Right-click to open a visual wardrobe manager, or simply Shift+Left Click with an empty hand to swap your equipped armor with the stand in one click.
- **3D Inventory Preview**: Rotate and inspect your character in real-time 3D right inside your inventory screen (`sfinv`, `unified_inventory`, or `i3`).
- **Matching Set Bonus**: Wearing a full 4-piece or 5-piece matching armor suit grants an automatic **+10% defense bonus**.
- **Lag-Free Multiplayer**: Engineered for busy multiplayer servers. Equipping dozens of players and placing armor stands causes zero server tick overhead.
- **Full Drop-in Compatibility**: Works out-of-the-box with mods that expect classic `3d_armor`, `shields`, or `3d_armor_stand` APIs, and automatically migrates older saved inventories.

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

Mod developers can easily register custom armor items, shields, 3D models, sound effects, and combat callbacks:

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

For complete class definitions, parameter types, callbacks, and subsystem methods, see the full **[API Reference (API.md)](API.md)**.

---

## Developer Tooling & Verification

The mod includes full developer scripts, testing harnesses, and Luanti static analysis:

```bash
# Run the 62-assertion automated unit test suite
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
- **Media License**: Creative Commons Attribution 4.0 International (CC-BY 4.0) & CC0 1.0
