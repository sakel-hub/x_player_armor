# x_player_armor API Reference

High-performance modular player armor, shield defense, durability, and damage mitigation system for Luanti.

## Table of Contents

- [Core Data Structures & Types](#core-data-structures--types)
  - [XPlayerArmorItemDef](#xplayerarmoritemdef)
  - [XPlayerArmorTransform](#xplayerarmortransform)
  - [XPlayerArmorConstants](#xplayerarmorconstants)
  - [XPlayerArmorPunchCallback](#xplayerarmorpunchcallback)
  - [XPlayerArmorSounds](#xplayerarmorsounds)
- [Public API Methods](#public-api-methods)
- [Inventory Subsystem](#inventory-subsystem)
- [Combat & Deflection Subsystem](#combat--deflection-subsystem)
- [Visuals & Bones Subsystem](#visuals--bones-subsystem)
- [Effects & Physics Subsystem](#effects--physics-subsystem)
- [Armor Stand Subsystem](#armor-stand-subsystem)
- [Items & Registration Subsystem](#items--registration-subsystem)
- [Crafting Recipes Subsystem](#crafting-recipes-subsystem)
- [Skins & Textures Subsystem](#skins--textures-subsystem)
- [UI & Formspecs Subsystem](#ui--formspecs-subsystem)
- [HUD Subsystems](#hud-subsystems)
  - [Combat HUD Overlay](#combat-hud-overlay)
  - [Shield Blocking Indicator HUD](#shield-blocking-indicator-hud)
- [Compatibility Adapters](#compatibility-adapters)
  - [3d_armor Compatibility Layer](#3d_armor-compatibility-layer)
  - [shields Compatibility Layer](#shields-compatibility-layer)
  - [3d_armor_stand Compatibility Layer](#3d_armor_stand-compatibility-layer)
  - [x_player_api Integration Adapter](#x_player_api-integration-adapter)
- [Visual Particle Effects (VFX)](#visual-particle-effects-vfx)
- [Utility Methods](#utility-methods)

---

## Core Data Structures & Types

### `XPlayerArmorItemDef`

| Field | Type | Description |
| :--- | :--- | :--- |
| `description` | `string` | Complete configuration table for armor registration. Supports custom 3D models, bone transforms, audio, perks, physics, and legacy 3d_armor compatibility.  Full descriptive tooltip text (auto-enriched with stats table if single-line) |
| `short_description` | `string?` | Compact item name displayed in HUD notifications, logs, and armor stand UI |
| `inventory_image` | `string?` | Standard 2D inventory icon displayed in slot grids and hotbar |
| `preview` | `string?` | 2D paperdoll layer image or fallback icon |
| `texture` | `string?` | Primary 3D UV texture file (mapped to 3D meshes in-world, 3D preview, and stand mannequin) |
| `textures` | `string[]?` | Ordered array of textures for multi-material custom 3D models |
| `element` | `("head"\|"torso"\|"legs"\|"feet"\|"shield")?` | Target equipment slot element |
| `level` | `number?` | Primary defense rating (auto-populates armor groups and fleshy damage mitigation) |
| `armor_use` | `number?` | Total durability uses before breaking (default: 200) |
| `armor_uses` | `number?` | Durability uses alias |
| `uses` | `number?` | Durability uses alias |
| `mesh` | `string?` | Custom 3D mesh file (.glb or .b3d) for the primary armor piece |
| `model` | `string?` | Alias for mesh |
| `meshes` | `table<string,string>?` | Map of piece IDs to custom 3D models (e.g. {torso = "...", sleeve_l = "...", sleeve_r = "..."}) |
| `models` | `table<string,string>?` | Alias for meshes |
| `pieces` | `string[]?` | Array of piece IDs to attach (e.g. {"head"} or {"torso"} for a sleeveless tunic) |
| `transforms` | `table<string,(XPlayerArmorTransform\|table<...>)>?` | Custom bone attachment transforms |
| `attach_transforms` | `table?` | Alias for transforms |
| `glow` | `number?` | Light emission level from 0 to 14 (ideal for enchanted, crystalline, or nether gear) |
| `visual_size` | `(Vector3\|table<string,number>)?` | Visual scale factor override |
| `backface_culling` | `boolean?` | Whether backface culling is enabled (default: true) |
| `shaded` | `boolean?` | Whether diffuse shading is enabled on the model (default: true) |
| `sounds` | `XPlayerArmorSounds?` | Custom sound effects table |
| `sound_equip` | `string?` | Sound played when equipped |
| `sound_unequip` | `string?` | Sound played when unequipped |
| `sound_hit` | `string?` | Sound played when absorbing a hit |
| `sound_break` | `string?` | Sound played when destroyed |
| `sound_block` | `string?` | Sound played when blocking with a shield |
| `heal` | `number?` | Passive health regeneration boost level (sets groups.armor_heal) |
| `fire` | `number?` | Fire and lava protection threshold level (sets groups.armor_fire) |
| `water` | `number?` | Underwater breathing and drowning immunity level (sets groups.armor_water) |
| `feather` | `number?` | Fall damage mitigation level (sets groups.armor_feather) |
| `speed` | `number?` | Locomotion movement speed modifier (sets groups.physics_speed) |
| `jump` | `number?` | Jump height modifier (sets groups.physics_jump) |
| `gravity` | `number?` | Gravity modifier (sets groups.physics_gravity) |
| `material` | `string?` | Material category key (sets groups.armor_material_<material>) |
| `reciprocate_damage` | `(boolean\|number)?` | Whether damage is reflected back to the attacker (thorns) |
| `thorns` | `(boolean\|number)?` | Alias for reciprocate_damage |
| `reciprocate_percent` | `number?` | Percentage of incoming damage reflected to attacker |
| `wear_color` | `table?` | Durability bar color gradient configuration |
| `shield_offset` | `table?` | Custom shield forearm attachment transforms for glb and b3d skeletons |
| `shield_transform` | `table?` | Alias for shield_offset |
| `tower_shield` | `boolean?` | Whether shield renders with tower shield model variant in preview and stand |
| `tower` | `boolean?` | Alias for tower_shield |
| `block_reduction` | `number?` | Shield frontal damage reduction fraction (default: 0.20 or material-tiered) |
| `block_arc` | `number?` | Custom frontal blocking arc angle in degrees |
| `deflect_projectiles` | `boolean?` | Whether shield can deflect physical arrows and projectiles |
| `particles` | `(table\|boolean)?` | Custom hit/break particle effects configuration |
| `groups` | `table<string,number>?` | Item groups map |
| `armor_groups` | `table<string,number>?` | Damage mitigation groups (e.g. {fleshy = 15}) |
| `damage_groups` | `table<string,number>?` | Tool durability wear rates against damage groups |
| `on_equip` | `(fun(player: ObjectRef, index: number, stack: ItemStack))?` | Callback invoked when equipped |
| `on_unequip` | `(fun(player: ObjectRef, index: number, stack: ItemStack))?` | Callback invoked when unequipped |
| `on_damage` | `(fun(player: ObjectRef, index: number, stack: ItemStack, uses: number))?` | Callback when damaged |
| `on_destroy` | `(fun(player: ObjectRef, index: number, stack: ItemStack))?` | Callback when broken |

### `XPlayerArmorTransform`

| Field | Type | Description |
| :--- | :--- | :--- |
| `bone` | `string` | Bone attachment configuration for custom models.  Target parent skeleton bone (e.g. "Head", "Body", "Arm_Left", "Arm_Right", "Leg_Left", "Leg_Right") |
| `model` | `string?` | Optional custom 3D model file (.glb or .b3d) |
| `pos` | `(Vector3\|table<string,number>)` | Position offset relative to bone origin |
| `rot` | `(Vector3\|table<string,number>)` | Euler rotation angles in degrees |
| `scale` | `(Vector3\|table<string,number>)?` | Scale vector override (default: {x=1, y=1, z=1}) |

### `XPlayerArmorConstants`

| Field | Type | Description |
| :--- | :--- | :--- |
| `SLOT_ELEMENTS` | `{ [1] = "head", [2] = "torso", [3] = "legs", [4] = "feet", ... }` |  |
| `ELEMENT_GROUPS` | `{ head = "armor_head", torso = "armor_torso", legs = "armor_legs", ... }` |  |
| `GROUP_ELEMENTS` | `table` | Inverted mapping derived programmatically from ELEMENT_GROUPS |
| `SLOT_LABELS` | `{ head = any, torso = any, legs = any, feet = any, shield = any, ... }` |  |
| `MODELS` | `{ head = "x_player_armor_helmet.glb", torso = "x_player_armor_chestplate.glb", ... }` |  |
| `PREVIEW_SLOTS` | `{ body = 0, body10 = 0, body18 = 1, head = 2, torso = 3, legs = 4, ... }` |  |
| `BONES` | `{ head = "Head", body = "Body", arm_l = "Arm_Left", arm_r = "Arm_Right", ... }` |  |
| `ELEMENT_PIECES` | `{ head = ("head"), torso = ("torso","sleeve_l","sleeve_r"), ... }` |  |
| `ATTACH_TRANSFORMS` | `{ glb = table, b3d = table }` |  |
| `SOUNDS` | `{ equip = "x_player_armor_equip", unequip = "x_player_armor_unequip", ... }` |  |
| `FIRE_NODES` | `{ default:lava_source = 5, default:lava_flowing = 5, nether:lava_source = 5, ... }` | Tiered fire, lava, and thermal hazard node protection thresholds matching 3d_armor standards: Tier 5: Deep lava & molten sources (requires full nether set or admin armor) Tier 3: Open flames & fire nodes (requires 3 pieces of nether armor) Tier 2: Hazardous hot flora & thermal crusts (requires 2 pieces of nether armor) Tier 1: Torches & minor heat sources (requires 1 piece of nether armor or crystal chestplate) |
| `LEVEL_MULTIPLIER` | `number` |  |
| `HEAL_MULTIPLIER` | `number` |  |
| `SET_BONUS` | `any` |  |
| `FIRE_PROTECT` | `any` |  |
| `FIRE_PROTECT_TORCH` | `any` |  |
| `WATER_PROTECT` | `any` |  |
| `FEATHER_FALL` | `any` |  |
| `ENABLE_SOUNDS` | `any` |  |
| `DROP_ON_DEATH` | `any` |  |
| `DESTROY_ON_DEATH` | `any` |  |
| `COMBAT_HUD_ENABLE` | `any` |  |
| `COMBAT_HUD_TIMEOUT` | `number` |  |
| `COMBAT_HUD_POSITION` | `any` |  |
| `COMBAT_HUD_SCALE` | `number` |  |
| `SHIELD_HUD_ENABLE` | `any` |  |
| `SHIELD_HUD_DELAY` | `number` |  |
| `BLOCK_CONE_ANGLE` | `integer` | Shield blocking & projectile deflection baseline constants |
| `BLOCK_ASYMMETRIC_BIAS` | `integer` |  |
| `BLOCK_DEFAULT_REDUCTION` | `number` |  |
| `BLOCK_DEFLECT_PROJECTILES` | `boolean` |  |
| `BLOCK_RESTITUTION` | `number` |  |
| `BLOCK_RECOIL_IMPULSE` | `number` |  |
| `SHIELD_TIER_PROPERTIES` | `{ wood = table, cactus = table, steel = table, bronze = table, ... }` | Material-tiered defense scaling for active shield blocking Arc is calibrated around the left off-hand shield quadrant (~22° left bias, spanning ~-48° to +4° on steel) so attacks hitting the exposed right side of the view/screen or behind penetrate unless aimed. |
| `SHIELD_OFFSET` | `{ glb = table, b3d = table }` | Forearm wielditem attachment transforms for shields (attached to Arm_Left) |

### `XPlayerArmorPunchCallback`

| Field | Type | Description |
| :--- | :--- | :--- |
| `on_punch` | `XPlayerArmorPunchCallback?` | Callback when player is punched |
| `on_punched` | `XPlayerArmorPunchCallback?` | Legacy callback alias |
| `on_block` | `(fun(player: ObjectRef, hitter: ObjectRef?, damage: number, shield_stack: ItemStack))?` | Callback on shield block |

### `XPlayerArmorSounds`

| Field | Type | Description |
| :--- | :--- | :--- |
| `equip` | `string?` | Sound effects triggered during armor lifecycle and combat events.  Sound played when the item is equipped |
| `unequip` | `string?` | Sound played when the item is unequipped |
| `hit` | `string?` | Sound played when armor absorbs a combat strike |
| `break_sound` | `string?` | Sound played when the item breaks from wear exhaustion |
| `block` | `string?` | Sound played when an incoming attack or projectile is deflected by shield |

## Public API Methods

Methods exposed directly on the root `x_player_armor` namespace.

### `x_player_armor.get_mod_api(modname)`

Safely retrieves the global table of an optional mod if installed and loaded.

```lua
x_player_armor.get_mod_api(modname: string) -> table?
```

**Parameters:**
- `modname` (`string`) — The name of the optional mod

**Returns:**
- `mod_api` (`table?`) — The global table or nil if absent

---

### `x_player_armor.get_elements()`

Returns the canonical list of armor elements.

```lua
x_player_armor.get_elements() -> string[]
```

**Returns:**
- `elements` (`string[]`)

---

### `x_player_armor.get_attributes()`

Returns the list of registered armor attributes.

```lua
x_player_armor.get_attributes() -> string[]
```

**Returns:**
- `attributes` (`string[]`)

---

### `x_player_armor.get_fire_nodes()`

Returns the registered fire damage nodes.

```lua
x_player_armor.get_fire_nodes() -> table<string,boolean>
```

**Returns:**
- `fire_nodes` (`table<string,boolean>`)

---

### `x_player_armor.is_reciprocate_damage_enabled()`

Checks whether damage reciprocation (thorns) is globally configured or active.

```lua
x_player_armor.is_reciprocate_damage_enabled() -> boolean
```

**Returns:**
- `enabled` (`boolean`)

---

### `x_player_armor.register_on_equip(func)`

Registers a callback when armor is equipped.

```lua
x_player_armor.register_on_equip(func: fun(player: ObjectRef, index: number, stack: ItemStack)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, index: number, stack: ItemStack)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.register_on_unequip(func)`

Registers a callback when armor is unequipped.

```lua
x_player_armor.register_on_unequip(func: fun(player: ObjectRef, index: number, stack: ItemStack)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, index: number, stack: ItemStack)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.register_on_damage(func)`

Registers a callback when armor absorbs damage.

```lua
x_player_armor.register_on_damage(func: fun(player: ObjectRef, index: number, stack: ItemStack, uses: number)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, index: number, stack: ItemStack, uses: number)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.register_on_destroy(func)`

Registers a callback when an armor item breaks.

```lua
x_player_armor.register_on_destroy(func: fun(player: ObjectRef, index: number, stack: ItemStack)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, index: number, stack: ItemStack)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.register_on_update(func)`

Registers a callback when player armor state updates.

```lua
x_player_armor.register_on_update(func: fun(player: ObjectRef)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.register_on_block(func)`

Registers a callback when a player successfully blocks an incoming attack or deflects a projectile with a shield.

```lua
x_player_armor.register_on_block(func: fun(player: ObjectRef, hitter_or_proj: (ObjectRef|table), damage: number, shield_stack: ItemStack)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, hitter_or_proj: (ObjectRef|table), damage: number, shield_stack: ItemStack)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.run_callbacks(event_name, ...)`

Dispatches a registered callback event across listeners.

```lua
x_player_armor.run_callbacks(event_name: string, ...: any) -> nil
```

**Parameters:**
- `event_name` (`string`)
- `...` (`any`)

**Returns:**
- (`nil`)

---

### `x_player_armor.register_element(element, def)`

Registers an armor slot element (e.g. "head", "torso", "legs", "feet", "shield").

```lua
x_player_armor.register_element(element: string, def: table) -> nil
```

**Parameters:**
- `element` (`string`)
- `def` (`table`)

**Returns:**
- (`nil`)

---

### `x_player_armor.register_material(material, def)`

Registers an armor material specification.

```lua
x_player_armor.register_material(material: string, def: table) -> nil
```

**Parameters:**
- `material` (`string`)
- `def` (`table`)

**Returns:**
- (`nil`)

---

### `x_player_armor.get_legacy_replacement(name)`

Resolves the modern x_player_armor item technical name if the given name is a legacy item.

```lua
x_player_armor.get_legacy_replacement(name: string) -> string?
```

**Parameters:**
- `name` (`string`) — Technical item name (e.g. "3d_armor:helmet_diamond" or ":3d_armor:helmet_diamond")

**Returns:**
- `modern_name` (`string?`) — Replacement modern technical name, or nil if not superseded

---

### `x_player_armor.get_armor_def(item_name)`

Retrieves the armor definition table for a registered armor item.
Checks internal registered_armors first, falling back to core.registered_tools or core.registered_items.

```lua
x_player_armor.get_armor_def(item_name: string) -> table?
```

**Parameters:**
- `item_name` (`string`) — Technical item name

**Returns:**
- `def` (`table?`) — Registered armor item definition or nil

---

### `x_player_armor.register_armor(name, def)`

Registers an armor item definition with full support for custom 3D models,
skeletal bone attachments, sound effects, environmental perks, physics, and legacy 3d_armor compatibility.

```lua
x_player_armor.register_armor(name: string, def: XPlayerArmorItemDef) -> nil
```

**Parameters:**
- `name` (`string`) — Technical item name (e.g. "mymod:helmet_crystal")
- `def` (`XPlayerArmorItemDef`) — Configuration definition table

**Returns:**
- (`nil`)

---

### `x_player_armor.get_weared_armor_elements(player)`

Returns a map of armor elements currently worn by the player.

```lua
x_player_armor.get_weared_armor_elements(player: ObjectRef) -> table<string,boolean>
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`table<string,boolean>`)

---

### `x_player_armor.remove_all(player)`

Unequips all armor items from the player's equipped inventory.

```lua
x_player_armor.remove_all(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.register_armor_group(group, base)`

Registers an armor group baseline.

```lua
x_player_armor.register_armor_group(group: string, base: number) -> nil
```

**Parameters:**
- `group` (`string`)
- `base` (`number`)

**Returns:**
- (`nil`)

---

### `x_player_armor.get_shield_offset(format)`

Gets the shield attachment transform for a given model format ("glb" or "b3d")

```lua
x_player_armor.get_shield_offset(format: string?) -> table
```

**Parameters:**
- `format` (`string?`) — "glb" or "b3d" (defaults to "glb")

**Returns:**
- (`table`) — {pos = Vector3, rot = Vector3}

---

### `x_player_armor.set_shield_offset(format, pos, rot)`

Sets or overrides the shield attachment transform for a model format

```lua
x_player_armor.set_shield_offset(format: string, pos: Vector3, rot: Vector3) -> nil
```

**Parameters:**
- `format` (`string`) — "glb" or "b3d"
- `pos` (`Vector3`) — Offset position
- `rot` (`Vector3`) — Euler rotation in degrees

**Returns:**
- (`nil`)

---

### `x_player_armor.get_player_def(player)`

Returns the active armor definition cache for a player.

```lua
x_player_armor.get_player_def(player: ObjectRef) -> table
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`table`)

---

### `x_player_armor.get_valid_player(player)`

Returns the detached armor inventory and player name if valid.

```lua
x_player_armor.get_valid_player(player: ObjectRef) -> string?, InvRef?
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `name` (`string?`)
- `inv` (`InvRef?`)

---

### `x_player_armor.equip(player, itemstack)`

Equips an armor item into the appropriate slot.

```lua
x_player_armor.equip(player: ObjectRef, itemstack: ItemStack) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`)
- `itemstack` (`ItemStack`)

**Returns:**
- `success` (`boolean`)

---

### `x_player_armor.unequip(player, element)`

Unequips an armor item by slot element.

```lua
x_player_armor.unequip(player: ObjectRef, element: string) -> ItemStack
```

**Parameters:**
- `player` (`ObjectRef`)
- `element` (`string`)

**Returns:**
- `unequipped_stack` (`ItemStack`)

---

### `x_player_armor.damage(player, index, stack, uses)`

Applies durability damage to a worn armor item.

```lua
x_player_armor.damage(player: ObjectRef, index: number, stack: ItemStack, uses: number) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`)
- `index` (`number`)
- `stack` (`ItemStack`)
- `uses` (`number`)

**Returns:**
- `destroyed` (`boolean`)

---

### `x_player_armor.punch(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)`

Calculates armor mitigation and wear on punch.

```lua
x_player_armor.punch(player: ObjectRef, hitter: ObjectRef?, time_from_last_punch: number?, tool_capabilities: table?, dir: vector?, damage: number?) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)
- `hitter` (`ObjectRef?`)
- `time_from_last_punch` (`number?`)
- `tool_capabilities` (`table?`)
- `dir` (`vector?`)
- `damage` (`number?`)

**Returns:**
- (`nil`)

---

### `x_player_armor.set_player_armor(player)`

Re-evaluates armor stats, groups, and physics for a player.

```lua
x_player_armor.set_player_armor(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.update_player_visuals(player)`

Updates modular bone attachments and visual entity state for a player.

```lua
x_player_armor.update_player_visuals(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.clear_player_visuals(player)`

Clears all modular visual entities for a player.

```lua
x_player_armor.clear_player_visuals(player: (ObjectRef|string)) -> nil
```

**Parameters:**
- `player` (`(ObjectRef|string)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.restore_all_player_visuals()`

Restores modular armor visual entities for all connected players.

```lua
x_player_armor.restore_all_player_visuals() -> nil
```

**Returns:**
- (`nil`)

---

### `x_player_armor.schedule_player_visual_restore(player_name)`

Schedules debounced restoration for a specific player's visual armor pieces.

```lua
x_player_armor.schedule_player_visual_restore(player_name: string) -> nil
```

**Parameters:**
- `player_name` (`string`)

**Returns:**
- (`nil`)

---

### `x_player_armor.get_player_preview_texture(player)`

Returns the composite preview texture string for 3D model formspecs.

```lua
x_player_armor.get_player_preview_texture(player: ObjectRef) -> string
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `preview_texture` (`string`)

---

### `x_player_armor.show_armor_formspec(player)`

Opens the armor and equipment inventory formspec for a player.

```lua
x_player_armor.show_armor_formspec(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.refresh_player_formspec(player)`

Refreshes open armor formspecs for a player across active inventory engines.

```lua
x_player_armor.refresh_player_formspec(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.show_shield_block_hud(player, immediate)`

Displays or updates the 2D shield block HUD indicator on the target player.

```lua
x_player_armor.show_shield_block_hud(player: ObjectRef, immediate: (boolean|number)?) -> number?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `immediate` (`(boolean|number)?`) — If true or 0, renders immediately without debounce delay

**Returns:**
- `hud_id` (`number?`) — Active HUD element ID if shown immediately, or nil if debounced

---

### `x_player_armor.hide_shield_block_hud(player)`

Hides the 2D shield block HUD indicator from the target player.

```lua
x_player_armor.hide_shield_block_hud(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.get_shield_block_hud(player)`

Retrieves the active shield block HUD element ID for a player if one exists.

```lua
x_player_armor.get_shield_block_hud(player: ObjectRef) -> number?
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `hud_id` (`number?`)

---

### `x_player_armor.can_block(player)`

Evaluates whether a player is capable of blocking with an equipped shield.

```lua
x_player_armor.can_block(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `can_block` (`boolean`)

---

### `x_player_armor.is_blocking(player)`

Checks whether a player is actively holding a shield block stance.

```lua
x_player_armor.is_blocking(player: ObjectRef) -> boolean, ItemStack?, number?, string?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `is_blocking` (`boolean`)
- `shield_stack` (`ItemStack?`)
- `slot_idx` (`number?`)
- `mat_key` (`string?`)

---

### `x_player_armor.is_facing_attack(player, attack_dir, max_arc_deg)`

Validates whether an incoming attack or projectile vector falls within the player's frontal blocking cone.

```lua
x_player_armor.is_facing_attack(player: ObjectRef, attack_dir: vector, max_arc_deg: number?) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `attack_dir` (`vector`) — Direction pointing from the attacker/projectile towards the player
- `max_arc_deg` (`number?`) — Maximum blocking arc in degrees (default 130)

**Returns:**
- `is_facing` (`boolean`)

---

### `x_player_armor.try_deflect_projectile(player, proj_obj, hit_pos, flight_dir, proj_data)`

Attempts to deflect an incoming projectile with the player's active shield.
Simulates realistic reflection physics, energy restitution, glancing drag, and orientation.

```lua
x_player_armor.try_deflect_projectile(player: ObjectRef, proj_obj: ObjectRef, hit_pos: vector, flight_dir: vector?, proj_data: table?) -> boolean, vector?
```

**Parameters:**
- `player` (`ObjectRef`) — Defending player
- `proj_obj` (`ObjectRef`) — Incoming projectile entity
- `hit_pos` (`vector`) — Impact position
- `flight_dir` (`vector?`) — Incoming normalized flight direction
- `proj_data` (`table?`) — Optional projectile state data

**Returns:**
- `deflected` (`boolean`)
- `bounce_velocity` (`vector?`)

---

### `x_player_armor.trigger_combat_hud(player)`

Displays or updates the combat armor HUD overlay on the target player.

```lua
x_player_armor.trigger_combat_hud(player: ObjectRef) -> number?
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `hud_id` (`number?`)

---

### `x_player_armor.hide_combat_hud(player)`

Hides the combat armor HUD overlay from the target player.

```lua
x_player_armor.hide_combat_hud(player: (ObjectRef|string)) -> nil
```

**Parameters:**
- `player` (`(ObjectRef|string)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.get_combat_hud_id(player)`

Retrieves the active combat armor HUD element ID for a player if one exists.

```lua
x_player_armor.get_combat_hud_id(player: ObjectRef) -> number?
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `hud_id` (`number?`)

---

### `x_player_armor.attach_shield(player_or_parent, item_or_stack, format_or_opts, custom_opts)`

Attaches an off-hand shield entity to a player's left forearm or target entity (such as a corpse or mob) with proper forearm transforms.

```lua
x_player_armor.attach_shield(player_or_parent: ObjectRef, item_or_stack: (string|ItemStack), format_or_opts: (string|table)?, custom_opts: table?) -> ObjectRef?
```

**Parameters:**
- `player_or_parent` (`ObjectRef`) — Target player or parent entity
- `item_or_stack` (`(string|ItemStack)`) — Shield item name or stack
- `format_or_opts` (`(string|table)?`) — Optional model format ("glb"|"b3d") or custom options table
- `custom_opts` (`table?`) — Optional transform and visual overrides

**Returns:**
- `entity` (`ObjectRef?`) — Attached entity reference or nil

---

### `x_player_armor.attach_shield_to_entity(parent, item_or_stack, format, custom_opts)`

Attaches a shield visual entity to an external parent entity (such as a corpse or mob) with proper forearm transforms.

```lua
x_player_armor.attach_shield_to_entity(parent: ObjectRef, item_or_stack: (string|ItemStack), format: string?, custom_opts: table?) -> ObjectRef?
```

**Parameters:**
- `parent` (`ObjectRef`) — Target parent entity
- `item_or_stack` (`(string|ItemStack)`) — Shield item name or stack
- `format` (`string?`) — Optional model format ("glb" or "b3d")
- `custom_opts` (`table?`) — Optional transform and visual overrides

**Returns:**
- `entity` (`ObjectRef?`) — Attached shield entity reference or nil

---

### `x_player_armor.update_shield(player, item_or_stack, custom_opts)`

Updates or modifies an attached off-hand shield entity via x_player_api.

```lua
x_player_armor.update_shield(player: ObjectRef, item_or_stack: (string|ItemStack)?, custom_opts: table?) -> ObjectRef?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `item_or_stack` (`(string|ItemStack)?`) — Shield item name or stack
- `custom_opts` (`table?`) — Optional transform and visual overrides

**Returns:**
- `entity` (`ObjectRef?`) — Attached entity reference or nil

---

### `x_player_armor.remove_shield(player)`

Removes an attached off-hand shield entity from a player via x_player_api.

```lua
x_player_armor.remove_shield(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- (`nil`)

---

### `x_player_armor.set_shield_first_person(player, enable)`

Sets whether an off-hand shield is visible in 1st person view via x_player_api.

```lua
x_player_armor.set_shield_first_person(player: ObjectRef, enable: boolean) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `enable` (`boolean`) — Whether 1st person view is enabled

**Returns:**
- (`nil`)

---

### `x_player_armor.get_shield_first_person(player)`

Gets whether an off-hand shield is visible in 1st person view via x_player_api.

```lua
x_player_armor.get_shield_first_person(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `enabled` (`boolean`) — Whether 1st person shield visibility is active

---

### `x_player_armor.get_equipped_shield(player)`

Resolves the equipped shield ItemStack, slot index, and material key for a player.
Shields must be equipped in the armor inventory (slot 5 or auxiliary slot 6).
Used by dependent combat and corpse mods (such as deathstats, x_bows, and x_mob_core).

```lua
x_player_armor.get_equipped_shield(player: ObjectRef) -> ItemStack?, number?, string?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `shield_stack` (`ItemStack?`) — Active equipped shield ItemStack or nil
- `slot_idx` (`number?`) — Armor inventory slot index (5 or 6) or nil
- `mat_key` (`string?`) — Material identifier string (e.g. "steel", "diamond") or nil

---

### `x_player_armor.get_shield_contact_pos(player)`

Calculates the 3D world origin position of the shield contact surface (Tier 1 deflection origin).
Biased to the lower-left viewport where the off-hand shield is actively held in guard stance.

```lua
x_player_armor.get_shield_contact_pos(player: ObjectRef) -> vector
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `shield_pos` (`vector`) — 3D world coordinate of shield surface

---

### `x_player_armor.is_armor_ui_open(player)`

Checks whether a specific player is currently viewing an armor equipment interface.

```lua
x_player_armor.is_armor_ui_open(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `is_open` (`boolean`) — True if armor UI is open for player

---

### `x_player_armor.has_any_open_armor_ui()`

Checks whether any connected player has an active armor inventory interface open.
Optimizes multiplayer performance by idle-skipping background updates when no UI is open.

```lua
x_player_armor.has_any_open_armor_ui() -> boolean
```

**Returns:**
- `has_any` (`boolean`) — True if any player has armor UI open

---

### `x_player_armor.cleanup_orphaned_visuals()`

Cleans up any orphaned or detached x_player_armor:visual entities near connected players.

```lua
x_player_armor.cleanup_orphaned_visuals() -> number
```

**Returns:**
- `count` (`number`) — Number of cleaned up entities

---

### `x_player_armor.resolve_player_skin(player)`

Resolves the player's active skin and produces the canonical dual-slot texture pair.

```lua
x_player_armor.resolve_player_skin(player: ObjectRef) -> SkinResolution
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `resolution` (`SkinResolution`)

---

### `x_player_armor.get_skin_info(player)`

Retrieves skin information for a player.

```lua
x_player_armor.get_skin_info(player: ObjectRef) -> SkinResolution
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `resolution` (`SkinResolution`)

---

### `x_player_armor.can_block(player)`

Evaluates whether a player is capable of blocking with an equipped shield.
Delegates to x_player_api.evaluate_can_block when available to respect two-handed weapons,
bow drawing, and item classification, with a robust standalone fallback.

```lua
x_player_armor.can_block(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `can_block` (`boolean`)

---

### `x_player_armor.is_blocking(player)`

Checks whether a player is actively holding a shield block stance.

```lua
x_player_armor.is_blocking(player: ObjectRef) -> boolean, ItemStack?, number?, string?
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `is_blocking` (`boolean`)
- `shield_stack` (`ItemStack?`)
- `slot_idx` (`number?`)
- `mat_key` (`string?`)

---

### `x_player_armor.get_shield_contact_pos(player)`

```lua
x_player_armor.get_shield_contact_pos(player: ObjectRef) -> vector
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `shield_pos` (`vector`) — 3D world coordinate of shield surface

---

### `x_player_armor.is_facing_attack(player, attack_dir, max_arc_deg, bias_deg)`

```lua
x_player_armor.is_facing_attack(player: ObjectRef, attack_dir: vector, max_arc_deg: number?, bias_deg: number?) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`)
- `attack_dir` (`vector`) — Direction pointing from the attacker/projectile towards the player
- `max_arc_deg` (`number?`) — Maximum blocking arc in degrees (default constants.BLOCK_CONE_ANGLE or 52)
- `bias_deg` (`number?`) — Custom lateral bias angle in degrees (default constants.BLOCK_ASYMMETRIC_BIAS or 22)

**Returns:**
- `is_facing` (`boolean`)

---

### `x_player_armor.try_deflect_projectile(player, proj_obj, hit_pos, flight_dir, _proj_data)`

Attempts to deflect an incoming projectile with the player's active shield.
Simulates realistic reflection physics, energy restitution, glancing drag, and orientation.
Enforces Tier 2 asymmetric guard cone bias and spatial hit position filtering (only deflecting
projectiles striking the forward off-hand shield quadrant; rear hits and right flank hits penetrate).

```lua
x_player_armor.try_deflect_projectile(player: ObjectRef, proj_obj: ObjectRef, hit_pos: vector?, flight_dir: vector?, _proj_data: table?) -> boolean, vector?
```

**Parameters:**
- `player` (`ObjectRef`) — Defending player
- `proj_obj` (`ObjectRef`) — Incoming projectile entity
- `hit_pos` (`vector?`) — Impact position
- `flight_dir` (`vector?`) — Incoming normalized flight direction
- `_proj_data` (`table?`) — Optional projectile state data

**Returns:**
- `deflected` (`boolean`)
- `bounce_velocity` (`vector?`)

---

### `x_player_armor.copy_table(t)`

```lua
x_player_armor.copy_table(t: T) -> T
```

**Parameters:**
- `t` (`T`)

**Returns:**
- (`T`)

---

### `x_player_armor.format_armor_tooltip(params)`

```lua
x_player_armor.format_armor_tooltip(params: table) -> string
```

**Parameters:**
- `params` (`table`) — Configuration options table

**Returns:**
- `tooltip` (`string`) — Formatted tooltip string with embedded Luanti color escapes

---

### `x_player_armor.format_armor_stand_tooltip(is_locked)`

```lua
x_player_armor.format_armor_stand_tooltip(is_locked: boolean?) -> string
```

**Parameters:**
- `is_locked` (`boolean?`) — Whether this is an owner-locked armor stand

**Returns:**
- `tooltip` (`string`) — Formatted tooltip string

---

### `x_player_armor.format_armor_tooltip_from_def(name, def)`

```lua
x_player_armor.format_armor_tooltip_from_def(name: string, def: table) -> string?
```

**Parameters:**
- `name` (`string`) — Item technical name
- `def` (`table`) — Armor item definition

**Returns:**
- `tooltip` (`string?`) — Formatted tooltip or nil

---

### `x_player_armor.force_alias(legacy_name, modern_name)`

```lua
x_player_armor.force_alias(legacy_name: string, modern_name: string) -> nil
```

**Parameters:**
- `legacy_name` (`string`) — Old or legacy item name
- `modern_name` (`string`) — Replacement modern item name

**Returns:**
- (`nil`)

---

### `x_player_armor.is_armor_ui_open(player)`

```lua
x_player_armor.is_armor_ui_open(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `is_open` (`boolean`)

---

### `x_player_armor.has_any_open_armor_ui()`

```lua
x_player_armor.has_any_open_armor_ui() -> boolean
```

**Returns:**
- `has_any` (`boolean`)

---

## Inventory Subsystem

Detached inventory management, equipment persistence, and slot serialization.

### `x_player_armor.inventory.is_valid_slot_item(stack, slot_idx)`

```lua
x_player_armor.inventory.is_valid_slot_item(stack: ItemStack, slot_idx: number) -> boolean
```

**Parameters:**
- `stack` (`ItemStack`)
- `slot_idx` (`number`)

**Returns:**
- `valid` (`boolean`)

---

### `x_player_armor.inventory.save_inventory(player, inv)`

```lua
x_player_armor.inventory.save_inventory(player: ObjectRef, inv: InvRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)
- `inv` (`InvRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.inventory.init_player_inventory(player)`

Initializes detached inventory callbacks and registers detached inventory for a player.

```lua
x_player_armor.inventory.init_player_inventory(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.inventory.equip_item(player, itemstack)`

Equips an armor item into the player's appropriate slot.
Returns displaced ItemStack (or empty ItemStack if empty slot), or nil on failure.

```lua
x_player_armor.inventory.equip_item(player: ObjectRef, itemstack: (ItemStack|string)) -> ItemStack?
```

**Parameters:**
- `player` (`ObjectRef`)
- `itemstack` (`(ItemStack|string)`)

**Returns:**
- `displaced_stack` (`ItemStack?`)

---

### `x_player_armor.inventory.unequip_element(player, element)`

Unequips an armor item by slot element or index.

```lua
x_player_armor.inventory.unequip_element(player: ObjectRef, element: (string|number)) -> ItemStack
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `element` (`(string|number)`) — Slot element name ("head", "torso", etc.) or slot index (1..6)

**Returns:**
- `unequipped_stack` (`ItemStack`)

---

### `x_player_armor.inventory.handle_player_death(player)`

Handles armor drops upon player death.

```lua
x_player_armor.inventory.handle_player_death(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

## Combat & Deflection Subsystem

Punch damage calculations, active shield blocking cone evaluation, recoil physics, and arrow deflection.

### `x_player_armor.combat.damage_item(player, index, stack, uses)`

Applies durability wear to an armor item in the player's inventory using engine add_wear_by_uses.

```lua
x_player_armor.combat.damage_item(player: ObjectRef, index: number, stack: ItemStack, uses: number) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`)
- `index` (`number`)
- `stack` (`ItemStack`)
- `uses` (`number`)

**Returns:**
- `destroyed` (`boolean`)

---

### `x_player_armor.combat.get_equipped_shield(player)`

Resolves the equipped shield ItemStack, slot index, and material key for a player.
Shields must be equipped in the armor inventory (slot 5 or auxiliary slot 6) and
wielded in the left hand (queried via x_player_api when available).
Holding a shield in the main (right) hand from hotbar does not count.

```lua
x_player_armor.combat.get_equipped_shield(player: ObjectRef) -> ItemStack?, number?, string?
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `shield_stack` (`ItemStack?`)
- `slot_idx` (`number?`)
- `mat_key` (`string?`)

---

### `x_player_armor.combat.can_block(player)`

```lua
x_player_armor.combat.can_block(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `can_block` (`boolean`)

---

### `x_player_armor.combat.is_blocking(player)`

```lua
x_player_armor.combat.is_blocking(player: ObjectRef) -> boolean, ItemStack?, number?, string?
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `is_blocking` (`boolean`)
- `shield_stack` (`ItemStack?`)
- `slot_idx` (`number?`)
- `mat_key` (`string?`)

---

### `x_player_armor.combat.get_shield_contact_pos(player)`

Calculates the 3D world origin position of the shield contact surface (Tier 1 deflection origin).
Biased to the lower-left viewport where the off-hand shield is actively held in guard stance.

```lua
x_player_armor.combat.get_shield_contact_pos(player: ObjectRef) -> vector
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `shield_pos` (`vector`) — 3D world coordinate of shield surface

---

### `x_player_armor.combat.is_facing_attack(player, attack_dir, max_arc_deg, bias_deg)`

Validates whether an incoming attack or projectile vector falls within the player's blocking cone.
Incorporates Tier 2 asymmetric guard cone bias rotating the cone axis ~22 degrees counter-clockwise
towards the player's left side (where the shield is physically held in the off-hand).
Attacks outside this cone (on the exposed right weapon side or from the rear) penetrate.

```lua
x_player_armor.combat.is_facing_attack(player: ObjectRef, attack_dir: vector, max_arc_deg: number?, bias_deg: number?) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`)
- `attack_dir` (`vector`) — Direction pointing from the attacker/projectile towards the player
- `max_arc_deg` (`number?`) — Maximum blocking arc in degrees (default constants.BLOCK_CONE_ANGLE or 52)
- `bias_deg` (`number?`) — Custom lateral bias angle in degrees (default constants.BLOCK_ASYMMETRIC_BIAS or 22)

**Returns:**
- `is_facing` (`boolean`)

---

### `x_player_armor.combat.get_attack_direction(player, reason)`

Resolves the attack direction pointing from attacker towards the player.

```lua
x_player_armor.combat.get_attack_direction(player: ObjectRef, reason: table) -> vector?
```

**Parameters:**
- `player` (`ObjectRef`)
- `reason` (`table`)

**Returns:**
- `attack_dir` (`vector?`)

---

### `x_player_armor.combat.handle_punch(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)`

Handles on_punchplayer event and wear calculations.

```lua
x_player_armor.combat.handle_punch(player: ObjectRef, hitter: ObjectRef?, time_from_last_punch: number?, tool_capabilities: table?, dir: vector?, damage: number?) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)
- `hitter` (`ObjectRef?`)
- `time_from_last_punch` (`number?`)
- `tool_capabilities` (`table?`)
- `dir` (`vector?`)
- `damage` (`number?`)

**Returns:**
- (`nil`)

---

## Visuals & Bones Subsystem

Direct bone attachment visual entities, skeletal transformation reconciliation, and multi-format support.

### `x_player_armor.visuals.get_item_texture(item_name)`

Retrieves or resolves the texture for an armor item stack.

```lua
x_player_armor.visuals.get_item_texture(item_name: string) -> string?
```

**Parameters:**
- `item_name` (`string`)

**Returns:**
- `texture` (`string?`)

---

### `x_player_armor.visuals.update_player_visuals(player)`

Updates all modular bone attachments for a player based on worn armor items.

```lua
x_player_armor.visuals.update_player_visuals(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.visuals.clear_all(player_name)`

Removes all visual armor entities for a player.

```lua
x_player_armor.visuals.clear_all(player_name: (string|ObjectRef)) -> nil
```

**Parameters:**
- `player_name` (`(string|ObjectRef)`) — Target player name or ObjectRef

**Returns:**
- (`nil`)

---

### `x_player_armor.visuals.cleanup_orphaned_visuals()`

Cleans up any orphaned or detached x_player_armor:visual entities near connected players

```lua
x_player_armor.visuals.cleanup_orphaned_visuals() -> number
```

**Returns:**
- `count` (`number`) — Cleaned up entities count

---

### `x_player_armor.visuals.schedule_player_restore(player_name)`

Schedules debounced visual restoration for a player.
Avoids multi-spawn thrashing when multiple armor pieces or entities are cleared simultaneously.

```lua
x_player_armor.visuals.schedule_player_restore(player_name: string) -> nil
```

**Parameters:**
- `player_name` (`string`) — Target player name

**Returns:**
- (`nil`)

---

### `x_player_armor.visuals.restore_all_players()`

Restores armor visuals for all currently connected players.

```lua
x_player_armor.visuals.restore_all_players() -> nil
```

**Returns:**
- (`nil`)

---

## Effects & Physics Subsystem

Periodic environmental protection (fire, drown, heal, feather fall) and player physics monoid integration.

### `x_player_armor.effects.update_player_armor(player)`

Updates player armor statistics, fleshy armor groups, and physics overrides.

```lua
x_player_armor.effects.update_player_armor(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

## Armor Stand Subsystem

Interactive armor stand node, 3D entity preview, shift-click wardrobe swap, and management UI.

### `x_player_armor.stand.schedule_restore(pos)`

Registers a stand position for deferred rehydration.

```lua
x_player_armor.stand.schedule_restore(pos: vector) -> nil
```

**Parameters:**
- `pos` (`vector`)

**Returns:**
- (`nil`)

---

### `x_player_armor.stand.can_interact(pos, player, is_locked)`

```lua
x_player_armor.stand.can_interact(pos: vector, player: ObjectRef, is_locked: boolean?) -> boolean
```

**Parameters:**
- `pos` (`vector`) — Node position
- `player` (`ObjectRef`) — Player reference
- `is_locked` (`boolean?`) — Whether the stand is an owner-locked variant

**Returns:**
- `can_interact` (`boolean`)

---

### `x_player_armor.stand.is_valid_stand_item(stack, index)`

```lua
x_player_armor.stand.is_valid_stand_item(stack: ItemStack, index: number) -> boolean
```

**Parameters:**
- `stack` (`ItemStack`)
- `index` (`number`) — (1..6)

**Returns:**
- `is_valid` (`boolean`)

---

### `x_player_armor.stand.get_slot_from_intersection(pos, intersection_point, node)`

```lua
x_player_armor.stand.get_slot_from_intersection(pos: vector, intersection_point: vector?, node: table?) -> number
```

**Parameters:**
- `pos` (`vector`) — Node coordinates
- `intersection_point` (`vector?`) — Hit coordinates
- `node` (`table?`) — Optional node table (retrieved if nil)

**Returns:**
- `slot` (`number`) — (1..6)

---

### `x_player_armor.stand.get_stand_formspec(pos, player)`

Builds the Formspec Version 7 UI for the Armor Stand.

```lua
x_player_armor.stand.get_stand_formspec(pos: vector, player: ObjectRef) -> string
```

**Parameters:**
- `pos` (`vector`) — Node coordinates
- `player` (`ObjectRef`) — Player viewing the formspec

**Returns:**
- `formspec` (`string`)

---

### `x_player_armor.stand.swap_armor(pos, player, is_locked)`

Swaps all equipped armor pieces and held weapon between player and stand.

```lua
x_player_armor.stand.swap_armor(pos: vector, player: ObjectRef, is_locked: boolean?) -> boolean
```

**Parameters:**
- `pos` (`vector`) — Stand coordinates
- `player` (`ObjectRef`) — Player reference
- `is_locked` (`boolean?`) — Whether the stand is owner-locked

**Returns:**
- `success` (`boolean`)

---

### `x_player_armor.stand.ray_aabb_intersection(origin, dir, bmin, bmax)`

```lua
x_player_armor.stand.ray_aabb_intersection(origin: vector, dir: vector, bmin: vector, bmax: vector) -> vector?
```

**Parameters:**
- `origin` (`vector`)
- `dir` (`vector`)
- `bmin` (`vector`)
- `bmax` (`vector`)

**Returns:**
- `intersection` (`vector?`)

---

### `x_player_armor.stand.resolve_stand_intersection(pos, player, pointed_thing)`

```lua
x_player_armor.stand.resolve_stand_intersection(pos: vector, player: ObjectRef, pointed_thing: table?) -> vector?
```

**Parameters:**
- `pos` (`vector`) — Node position
- `player` (`ObjectRef`) — Player reference
- `pointed_thing` (`table?`) — Pointed thing table from engine callback

**Returns:**
- `hit_point` (`vector?`)

---

### `x_player_armor.stand.handle_sneak_punch(pos, player, _pointed_thing, is_locked)`

Handles Shift + LMB full armor outfit and weapon swap between player and stand.

```lua
x_player_armor.stand.handle_sneak_punch(pos: vector, player: ObjectRef, _pointed_thing: table?, is_locked: boolean) -> boolean
```

**Parameters:**
- `pos` (`vector`) — Node position
- `player` (`ObjectRef`) — Player reference
- `_pointed_thing` (`table?`) — Pointed thing data (unused)
- `is_locked` (`boolean`) — Whether the stand is owner-locked

**Returns:**
- `handled` (`boolean`)

---

### `x_player_armor.stand.take_all_armor(pos, player, is_locked)`

Takes all mounted armor pieces and weapons from stand and moves them to player inventory.

```lua
x_player_armor.stand.take_all_armor(pos: vector, player: ObjectRef, is_locked: boolean?) -> boolean
```

**Parameters:**
- `pos` (`vector`) — Stand coordinates
- `player` (`ObjectRef`) — Player reference
- `is_locked` (`boolean?`) — Whether the stand is owner-locked

**Returns:**
- `success` (`boolean`)

---

### `x_player_armor.stand.run_callbacks(event, ...)`

Dispatches a registered callback event across listeners.

```lua
x_player_armor.stand.run_callbacks(event: string, ...: any) -> nil
```

**Parameters:**
- `event` (`string`)
- `...` (`any`)

**Returns:**
- (`nil`)

---

### `x_player_armor.stand.register_on_equip(func)`

Registers an on_equip callback for armor stands.

```lua
x_player_armor.stand.register_on_equip(func: fun(pos: vector, slot: number, stack: ItemStack, player: ObjectRef)) -> nil
```

**Parameters:**
- `func` (`fun(pos: vector, slot: number, stack: ItemStack, player: ObjectRef)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.stand.register_on_take(func)`

Registers an on_take callback for armor stands.

```lua
x_player_armor.stand.register_on_take(func: fun(pos: vector, slot: number, stack: ItemStack, player: ObjectRef)) -> nil
```

**Parameters:**
- `func` (`fun(pos: vector, slot: number, stack: ItemStack, player: ObjectRef)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.stand.register_on_swap(func)`

Registers an on_swap callback for armor stands.

```lua
x_player_armor.stand.register_on_swap(func: fun(pos: vector, player: ObjectRef)) -> nil
```

**Parameters:**
- `func` (`fun(pos: vector, player: ObjectRef)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.stand.update_stand_entity(pos)`

```lua
x_player_armor.stand.update_stand_entity(pos: vector) -> nil
```

**Parameters:**
- `pos` (`vector`)

**Returns:**
- (`nil`)

---

### `x_player_armor.stand.get_stand_entity(pos)`

```lua
x_player_armor.stand.get_stand_entity(pos: vector) -> ObjectRef?
```

**Parameters:**
- `pos` (`vector`)

**Returns:**
- `entity` (`ObjectRef?`)

---

### `x_player_armor.stand.get_stand_shield(pos)`

```lua
x_player_armor.stand.get_stand_shield(pos: vector) -> ObjectRef?
```

**Parameters:**
- `pos` (`vector`)

**Returns:**
- `entity` (`ObjectRef?`)

---

## Items & Registration Subsystem

Armor item registration, tier generation, textures, and craft recipe orchestration.

### `x_player_armor.items.get_materials()`

Returns the defined armor material configurations table.

```lua
x_player_armor.items.get_materials() -> table<string,table>
```

**Returns:**
- `materials` (`table<string,table>`)

---

### `x_player_armor.items.get_pieces()`

Returns the defined armor equipment pieces configuration table.

```lua
x_player_armor.items.get_pieces() -> table<string,table>
```

**Returns:**
- `pieces` (`table<string,table>`)

---

## Crafting Recipes Subsystem

Crafting recipe definitions and ingredient queries for armor equipment.

### `x_player_armor.crafting.get_recipe_ingredients()`

Returns the registered crafting recipe ingredients mapping by material key.

```lua
x_player_armor.crafting.get_recipe_ingredients() -> table<string,string>
```

**Returns:**
- `ingredients` (`table<string,string>`) — Table mapping material keys to crafting ingredient strings

---

## Skins & Textures Subsystem

Player skin resolution, 1.0 vs 1.8 format detection, and clothing layer compositing.

### `x_player_armor.skins.detect_texture_format(texture_name)`

Detects whether a skin texture represents a 1.8 (64x64) or 1.0 (64x32) layout.
Inspects naming conventions, skinsdb metadata, and cached dimensions.

```lua
x_player_armor.skins.detect_texture_format(texture_name: string) -> string
```

**Parameters:**
- `texture_name` (`string`) — Texture filename or modifier string

**Returns:**
- `format` (`string`) — Format identifier ("1.0" or "1.8")

---

### `x_player_armor.skins.get_clothing_overlay(player_name)`

Resolves active clothing overlays for a player if the clothing mod is installed.

```lua
x_player_armor.skins.get_clothing_overlay(player_name: string) -> string?
```

**Parameters:**
- `player_name` (`string`) — Technical player name

**Returns:**
- `overlay_string` (`string?`) — Combined clothing overlay texture string or nil

---

### `x_player_armor.skins.resolve_player_skin(player)`

Resolves the player's active skin and produces the canonical dual-slot texture pair.

```lua
x_player_armor.skins.resolve_player_skin(player: ObjectRef) -> SkinResolution
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `resolution` (`SkinResolution`) — Resolved skin data with body10 and body18 textures

---

### `x_player_armor.skins.get_skin_info(player)`

Convenience accessor for skin info.

```lua
x_player_armor.skins.get_skin_info(player: ObjectRef) -> SkinResolution
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `resolution` (`SkinResolution`) — Resolved skin data

---

## UI & Formspecs Subsystem

Modern responsive formspecs, sfinv tab integration, unified_inventory, and i3 adapters.

### `x_player_armor.ui.get_player_skin(player)`

```lua
x_player_armor.ui.get_player_skin(player: ObjectRef) -> string
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `skin_texture` (`string`)

---

### `x_player_armor.ui.get_composite_armor_texture(player)`

Builds the composite overlay texture for all worn armor pieces (64x32 UV layout).

```lua
x_player_armor.ui.get_composite_armor_texture(player: ObjectRef) -> string
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `armor_overlay` (`string`)

---

### `x_player_armor.ui.get_item_wield_texture(stack)`

Resolves the texture string for an item stack in the 3D preview / stand wield mesh.
Supports 2D wield/inventory images, overlays, color tinting, and cubic node tiles.

```lua
x_player_armor.ui.get_item_wield_texture(stack: ItemStack?) -> string
```

**Parameters:**
- `stack` (`ItemStack?`)

**Returns:**
- `wield_texture` (`string`)

---

### `x_player_armor.ui.get_wield_texture(player)`

Resolves the texture string for the player's active wielded item in the 3D preview.

```lua
x_player_armor.ui.get_wield_texture(player: ObjectRef) -> string
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `wield_texture` (`string`)

---

### `x_player_armor.ui.get_preview_texture(player, _preview_model)`

Builds the composite preview texture for the 3D formspec model.
For 9-material meshes (e.g. x_player_armor_preview.glb): returns "body10,body18,head,torso,legs,feet,shield_std,shield_tower,wield"

```lua
x_player_armor.ui.get_preview_texture(player: ObjectRef, _preview_model: string?) -> string
```

**Parameters:**
- `player` (`ObjectRef`)
- `_preview_model` (`string?`) — Optional preview model override (unused, maintained for compatibility)

**Returns:**
- `composite_texture` (`string`)

---

### `x_player_armor.ui.get_preview_model(_player)`

Resolves the 3D preview model mesh for the player.
The 3D preview is a dedicated preview of the armor and uses the production preview model.

```lua
x_player_armor.ui.get_preview_model(_player: ObjectRef?) -> string
```

**Parameters:**
- `_player` (`ObjectRef?`) — Optional player reference (maintained for API compatibility)

**Returns:**
- `model_name` (`string`)

---

### `x_player_armor.ui.render_slots(target, col_xs, row_ys, slot_size, inv_ref, custom_slots)`

Renders the 6 equipped armor slots with their blueprint silhouette icons and empty slot tooltips.

```lua
x_player_armor.ui.render_slots(target: string, col_xs: number[], row_ys: number[], slot_size: number?, inv_ref: InvRef?, custom_slots: table?) -> string
```

**Parameters:**
- `target` (`string`) — Player name or inventory target string (e.g. "detached:name_armor" or "nodemeta:x,y,z")
- `col_xs` (`number[]`) — Array of 3 X coordinates
- `row_ys` (`number[]`) — Array of 2 Y coordinates
- `slot_size` (`number?`) — Slot width/height (defaults to 1.0)
- `inv_ref` (`InvRef?`) — Optional inventory reference for empty slot tooltip checks
- `custom_slots` (`table?`) — Optional custom slot definitions

**Returns:**
- `formspec` (`string`)

---

### `x_player_armor.ui.render_player_inventory(x, y)`

Renders the 8x3 player inventory grid.

```lua
x_player_armor.ui.render_player_inventory(x: number, y: number) -> string
```

**Parameters:**
- `x` (`number`)
- `y` (`number`)

**Returns:**
- `formspec` (`string`)

---

### `x_player_armor.ui.render_player_hotbar(x, y, spacing)`

Renders the 8x1 player hotbar with consistent slot backgrounds.

```lua
x_player_armor.ui.render_player_hotbar(x: number, y: number, spacing: number?) -> string
```

**Parameters:**
- `x` (`number`)
- `y` (`number`)
- `spacing` (`number?`) — Horizontal slot spacing (default 0.15)

**Returns:**
- `formspec` (`string`)

---

### `x_player_armor.ui.build_stats_hypertext(pdef, player)`

Builds the scrollable hypertext markup aggregating armor attributes and active perks.

```lua
x_player_armor.ui.build_stats_hypertext(pdef: table, player: ObjectRef?) -> string
```

**Parameters:**
- `pdef` (`table`) — Player armor definition
- `player` (`ObjectRef?`) — Optional player reference for contextual resolution

**Returns:**
- `hypertext_markup` (`string`)

---

### `x_player_armor.ui.get_formspec(player)`

Generates the modern Formspec Version 7 UI for armor and equipment.

```lua
x_player_armor.ui.get_formspec(player: ObjectRef) -> string
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `formspec` (`string`)

---

### `x_player_armor.ui.check_wield_change(player, skip_refresh)`

Checks if the player's active wielded item or hotbar slot changed, and refreshes UI if needed.

```lua
x_player_armor.ui.check_wield_change(player: ObjectRef, skip_refresh: boolean?) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`)
- `skip_refresh` (`boolean?`) — If true, synchronizes internal tracked state without triggering refresh_player_formspec

**Returns:**
- `changed` (`boolean`)

---

### `x_player_armor.ui.refresh_player_formspec(player)`

Refreshes open formspecs for a player across active inventory engines.

```lua
x_player_armor.ui.refresh_player_formspec(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.ui.is_armor_ui_open(player)`

Checks whether a specific player is currently viewing an armor equipment interface.

```lua
x_player_armor.ui.is_armor_ui_open(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `is_open` (`boolean`)

---

### `x_player_armor.ui.has_any_open_armor_ui()`

Checks whether any connected player has an active armor inventory interface open.
Optimizes multiplayer performance by idle-skipping background updates when no UI is open.

```lua
x_player_armor.ui.has_any_open_armor_ui() -> boolean
```

**Returns:**
- `has_any` (`boolean`)

---

### `x_player_armor.ui.show_armor_formspec(player)`

Opens the armor and equipment inventory for a player.

```lua
x_player_armor.ui.show_armor_formspec(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

### `x_player_armor.ui.get_unified_inventory_formspec(player, perplayer_formspec)`

Generates the formspec content table for Unified Inventory's armor page.
Reuses the 3D player preview, 6 equipped armor slots, and aggregated stats hypertext.

```lua
x_player_armor.ui.get_unified_inventory_formspec(player: ObjectRef, perplayer_formspec: table?) -> table
```

**Parameters:**
- `player` (`ObjectRef`)
- `perplayer_formspec` (`table?`) — Optional style definition from Unified Inventory

**Returns:**
- `page_data` (`table`) — Table with formspec, draw_inventory, and draw_item_list

---

### `x_player_armor.ui.get_2d_preview_texture(player)`

Returns a 2D composite preview texture overlay string for legacy formspecs.

```lua
x_player_armor.ui.get_2d_preview_texture(player: ObjectRef) -> string
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `preview_2d` (`string`)

---

### `x_player_armor.ui.get_legacy_formspec(player, _page)`

Returns legacy formspec for player name/player.

```lua
x_player_armor.ui.get_legacy_formspec(player: (ObjectRef|string), _page: number?) -> string
```

**Parameters:**
- `player` (`(ObjectRef|string)`)
- `_page` (`number?`)

**Returns:**
- (`string`)

---

## Combat HUD Overlay

Screen overlay displaying equipment durability and active loadout during combat.

### `x_player_armor.combat_hud.get_durability_color(wear)`

5 Transitional durability colors based on wear ratio:
Tier 5 (80% - 100%): Emerald Green
Tier 4 (60% - 79%): Lime Green
Tier 3 (40% - 59%): Amber Yellow
Tier 2 (20% - 39%): Vivid Orange
Tier 1 (0% - 19%): Crimson Red

```lua
x_player_armor.combat_hud.get_durability_color(wear: number) -> string
```

**Parameters:**
- `wear` (`number`) — Engine wear integer (0 to 65535)

**Returns:**
- `hex_color` (`string`)

---

### `x_player_armor.combat_hud.get_proportional_geometry(player)`

Calculates dynamic scale and offset for the combat HUD overlay based on player viewport size.
Ensures clear legibility and tactical scaling on 1080p, 1440p (2K), 4K, and ultra-wide screens.

```lua
x_player_armor.combat_hud.get_proportional_geometry(player: ObjectRef) -> { x: number, y: number }, { x: number, y: number }, { x: number, y: number }, { x: number, y: number }
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `scale` (`{ x: number, y: number }`)
- `offset` (`{ x: number, y: number }`)
- `position` (`{ x: number, y: number }`)
- `alignment` (`{ x: number, y: number }`)

---

### `x_player_armor.combat_hud.build_overlay_texture(player)`

Constructs the single 96x128 composite texture representation of the combat HUD.
Generated 100% programmatically via native [fill and [combine modifiers (zero static file overhead).

```lua
x_player_armor.combat_hud.build_overlay_texture(player: ObjectRef) -> string
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `composite_texture` (`string`)

---

### `x_player_armor.combat_hud.trigger(player)`

Displays or updates the combat armor HUD overlay on the target player.
Resets timeout on subsequent calls and updates existing HUD in-place with dirty checking.

```lua
x_player_armor.combat_hud.trigger(player: ObjectRef) -> number?
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `hud_id` (`number?`)

---

### `x_player_armor.combat_hud.hide(player_or_name)`

Hides and removes the combat armor HUD element from the target player.

```lua
x_player_armor.combat_hud.hide(player_or_name: (ObjectRef|string)) -> nil
```

**Parameters:**
- `player_or_name` (`(ObjectRef|string)`)

**Returns:**
- (`nil`)

---

### `x_player_armor.combat_hud.cleanup(player_name)`

Cleans up player HUD tracking on disconnect or death without stale pointer assumptions.

```lua
x_player_armor.combat_hud.cleanup(player_name: string) -> nil
```

**Parameters:**
- `player_name` (`string`)

**Returns:**
- (`nil`)

---

### `x_player_armor.combat_hud.shutdown()`

Gracefully cleans up all active combat HUD elements on server shutdown.

```lua
x_player_armor.combat_hud.shutdown() -> nil
```

**Returns:**
- (`nil`)

---

### `x_player_armor.combat_hud.init()`

Initializes engine lifecycle hooks and throttled timer.

```lua
x_player_armor.combat_hud.init() -> nil
```

**Returns:**
- (`nil`)

---

## Shield Blocking Indicator HUD

1st-person perspective dynamic shield blocking guard and cooldown crosshair HUD indicator.

### `x_player_armor.shield_hud.build_extruded_texture(base_img)`

```lua
x_player_armor.shield_hud.build_extruded_texture(base_img: string) -> string
```

**Parameters:**
- `base_img` (`string`) — Base inventory image filename or modifier string

**Returns:**
- `composite_texture` (`string`)

---

### `x_player_armor.shield_hud.get_proportional_geometry(player)`

```lua
x_player_armor.shield_hud.get_proportional_geometry(player: ObjectRef) -> { x: number, y: number }, { x: number, y: number }
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `scale` (`{ x: number, y: number }`)
- `offset` (`{ x: number, y: number }`)

---

### `x_player_armor.shield_hud.get_shield_texture(player)`

Resolves the equipped or wielded shield item and returns the memoized extruded texture string.
Uses build_extruded_texture with ambient occlusion depth layers and reference canvas dimensions.

```lua
x_player_armor.shield_hud.get_shield_texture(player: ObjectRef) -> string?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `texture_string` (`string?`) — Extruded composite texture string or nil

---

### `x_player_armor.shield_hud.show(player, immediate)`

Displays or updates the 2D shield block HUD indicator on the target player.
When the HUD is not yet visible, debounces presentation by SHIELD_HUD_DELAY (default 0.35s)
to prevent flashing the overlay on right-click taps for block placement or node interaction.

```lua
x_player_armor.shield_hud.show(player: ObjectRef, immediate: (boolean|number)?) -> number?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `immediate` (`(boolean|number)?`) — If true or 0, renders immediately without debounce delay

**Returns:**
- `hud_id` (`number?`) — Active HUD element ID if shown immediately, or nil if debounced

---

### `x_player_armor.shield_hud.hide(player)`

Removes the 2D shield block HUD indicator from the target player and cancels any pending show timer.

```lua
x_player_armor.shield_hud.hide(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- (`nil`)

---

### `x_player_armor.shield_hud.cleanup(player_name)`

Cleans up player HUD tracking and pending timers on disconnect or death.

```lua
x_player_armor.shield_hud.cleanup(player_name: string) -> nil
```

**Parameters:**
- `player_name` (`string`) — Technical name of player

**Returns:**
- (`nil`)

---

### `x_player_armor.shield_hud.init()`

Initializes lifecycle hooks and standalone input fallback.

```lua
x_player_armor.shield_hud.init() -> nil
```

**Returns:**
- (`nil`)

---

## Visual Particle Effects (VFX)

Hit particle bursts, durability break sparks, shield deflection visual particles, and sound effects.

### `x_player_armor.vfx.spawn_particles(def)`

Spawns a particlespawner populated with both modern structured definitions and legacy fallback keys.
Ensures 100% compatibility across all Luanti engine versions while keeping code DRY and optimized
for multiplayer performance with targeted networking support.

```lua
x_player_armor.vfx.spawn_particles(def: table) -> integer?
```

**Parameters:**
- `def` (`table`) — Modern structured particlespawner definition

**Returns:**
- `spawner_id` (`integer?`) — ID of registered particlespawner or nil

---

### `x_player_armor.vfx.spawn_heal_particles(pos, player)`

Spawns modern regenerative healing ward particles around a position.
Optimized for multiplayer: lean particle count, non-colliding, and supports targeted player transmission.

```lua
x_player_armor.vfx.spawn_heal_particles(pos: vector, player: (ObjectRef|string)?) -> integer?
```

**Parameters:**
- `pos` (`vector`) — Center position
- `player` (`(ObjectRef|string)?`) — Optional player reference or playername for targeted networking

**Returns:**
- `spawner_id` (`integer?`)

---

### `x_player_armor.vfx.spawn_shield_block_particles(pos, player)`

Spawns modern shield block deflection sparks at a position.
Optimized for multiplayer: fast burst, immediate collision cleanup, and optional targeted networking.

```lua
x_player_armor.vfx.spawn_shield_block_particles(pos: vector, player: (ObjectRef|string)?) -> integer?
```

**Parameters:**
- `pos` (`vector`) — Center position
- `player` (`(ObjectRef|string)?`) — Optional player reference or playername for targeted networking

**Returns:**
- `spawner_id` (`integer?`)

---

### `x_player_armor.vfx.spawn_armor_break_particles(pos, item_name, player)`

Spawns modern armor destruction shatter particles matching the broken item's material.
Optimized for multiplayer: lean shard count, short lifetime, collision removal, and optional targeted networking.

```lua
x_player_armor.vfx.spawn_armor_break_particles(pos: vector, item_name: string, player: (ObjectRef|string)?) -> integer?
```

**Parameters:**
- `pos` (`vector`) — Center position
- `item_name` (`string`) — Name of broken armor item
- `player` (`(ObjectRef|string)?`) — Optional player reference or playername for targeted networking

**Returns:**
- `spawner_id` (`integer?`)

---

### `x_player_armor.vfx.spawn_impact_particles(pos, dominant_material, player)`

Spawns modern armor impact deflection sparks matching the armor's material.
Triggered when armor absorbs incoming damage or deflects hits.
Optimized for multiplayer: lean particle count, short burst, collision removal, and optional targeted networking.

```lua
x_player_armor.vfx.spawn_impact_particles(pos: vector, dominant_material: string?, player: (ObjectRef|string)?) -> integer?
```

**Parameters:**
- `pos` (`vector`) — Center position
- `dominant_material` (`string?`) — Material category ("metal", "crystal", "diamond", "wood", "cactus", etc.)
- `player` (`(ObjectRef|string)?`) — Optional player reference or playername for targeted networking

**Returns:**
- `spawner_id` (`integer?`)

---

## Utility Methods

Shared mathematical, spatial, and vector helpers.

### `x_player_armor.utils.copy_table(t)`

Shallow copies a key-value table.

```lua
x_player_armor.utils.copy_table(t: T) -> T
```

**Parameters:**
- `t` (`T`)

**Returns:**
- (`T`)

---

### `x_player_armor.utils.deep_copy(orig)`

Recursively deep-copies a table or value.

```lua
x_player_armor.utils.deep_copy(orig: T) -> T
```

**Parameters:**
- `orig` (`T`)

**Returns:**
- (`T`)

---

### `x_player_armor.utils.get_player_name(player)`

Extracts the target player name from either a string or an ObjectRef.

```lua
x_player_armor.utils.get_player_name(player: (ObjectRef|string)?) -> string?
```

**Parameters:**
- `player` (`(ObjectRef|string)?`)

**Returns:**
- (`string?`)

---

### `x_player_armor.utils.get_item_material(item_name)`

Extracts the material name from an armor item name.
Uses memoized cache to eliminate pairs() iteration and string slicing during high-frequency combat.

```lua
x_player_armor.utils.get_item_material(item_name: string) -> string?
```

**Parameters:**
- `item_name` (`string`) — Technical item name (e.g. "x_player_armor:helmet_steel")

**Returns:**
- `material` (`string?`) — Material identifier (e.g. "steel", "diamond", "wood") or nil

---

### `x_player_armor.utils.force_alias(legacy_name, modern_name)`

Registers a forced alias for backwards compatibility, overriding any existing legacy definition.

```lua
x_player_armor.utils.force_alias(legacy_name: string, modern_name: string) -> nil
```

**Parameters:**
- `legacy_name` (`string`) — Old or legacy item name
- `modern_name` (`string`) — Replacement modern item name

**Returns:**
- (`nil`)

---

### `x_player_armor.utils.format_armor_tooltip(params)`

Builds a modern, rich, colorized tooltip for armor and shield items.

```lua
x_player_armor.utils.format_armor_tooltip(params: table) -> string
```

**Parameters:**
- `params` (`table`) — Configuration options table

**Returns:**
- `tooltip` (`string`) — Formatted tooltip string with embedded Luanti color escapes

---

### `x_player_armor.utils.format_armor_stand_tooltip(is_locked)`

Builds a modern, rich, colorized tooltip for Armor Stand nodes.

```lua
x_player_armor.utils.format_armor_stand_tooltip(is_locked: boolean?) -> string
```

**Parameters:**
- `is_locked` (`boolean?`) — Whether this is an owner-locked armor stand

**Returns:**
- `tooltip` (`string`) — Formatted tooltip string

---

### `x_player_armor.utils.format_armor_tooltip_from_def(name, def)`

Builds a modern formatted tooltip from an arbitrary armor definition table.

```lua
x_player_armor.utils.format_armor_tooltip_from_def(name: string, def: table) -> string?
```

**Parameters:**
- `name` (`string`) — Item technical name
- `def` (`table`) — Armor item definition

**Returns:**
- `tooltip` (`string?`) — Formatted tooltip or nil

---

## x_player_api Integration Adapter

Biomechanical off-hand shield attachment, multi-track animation synchronization, and hurt triggers.

### `x_player_armor.compat.x_player_api.get_api()`

```lua
x_player_armor.compat.x_player_api.get_api() -> table?
```

**Returns:**
- (`table?`)

---

### `x_player_armor.compat.x_player_api.is_present()`

Check whether x_player_api is present and active

```lua
x_player_armor.compat.x_player_api.is_present() -> boolean
```

**Returns:**
- (`boolean`)

---

### `x_player_armor.compat.x_player_api.init()`

Initialize x_player_api integrations if available

```lua
x_player_armor.compat.x_player_api.init() -> nil
```

**Returns:**
- (`nil`)

---

### `x_player_armor.compat.x_player_api.on_equip(player, item_name)`

Trigger equip montage and audio playback when an armor piece or shield is equipped

```lua
x_player_armor.compat.x_player_api.on_equip(player: ObjectRef, item_name: string) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `item_name` (`string`) — Technical item name

**Returns:**
- (`nil`)

---

### `x_player_armor.compat.x_player_api.trigger_hurt(player, duration)`

Trigger hurt reaction flinch when player takes combat hit or armor absorbs damage

```lua
x_player_armor.compat.x_player_api.trigger_hurt(player: ObjectRef, duration: number?) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `duration` (`number?`) — Duration in seconds (default 0.3s)

**Returns:**
- (`nil`)

---

### `x_player_armor.compat.x_player_api.attach_shield(player, item_or_stack, custom_opts)`

Attaches an equipped shield to the player's left hand using x_player_api as a wielditem.
Applies the forearm attachment transform (position and rotation) instead of generic hand grip.

```lua
x_player_armor.compat.x_player_api.attach_shield(player: ObjectRef, item_or_stack: (string|ItemStack), custom_opts: table?) -> ObjectRef?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `item_or_stack` (`(string|ItemStack)`) — Shield item name or stack
- `custom_opts` (`table?`) — Optional transform and visual overrides

**Returns:**
- `entity` (`ObjectRef?`) — Attached entity reference

---

### `x_player_armor.compat.x_player_api.update_shield(player, item_or_stack, custom_opts)`

Updates or modifies the attached left-hand shield entity using x_player_api

```lua
x_player_armor.compat.x_player_api.update_shield(player: ObjectRef, item_or_stack: (string|ItemStack)?, custom_opts: table?) -> ObjectRef?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `item_or_stack` (`(string|ItemStack)?`) — Shield item name or stack
- `custom_opts` (`table?`) — Optional transform and visual overrides

**Returns:**
- `entity` (`ObjectRef?`) — Attached entity reference or nil

---

### `x_player_armor.compat.x_player_api.remove_shield(player)`

Removes the attached left-hand shield entity using x_player_api

```lua
x_player_armor.compat.x_player_api.remove_shield(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- (`nil`)

---

### `x_player_armor.compat.x_player_api.set_shield_first_person(player, enable)`

Sets whether the left-hand shield should be rendered in 1st person view

```lua
x_player_armor.compat.x_player_api.set_shield_first_person(player: ObjectRef, enable: boolean) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `enable` (`boolean`) — Whether 1st person view is enabled

**Returns:**
- (`nil`)

---

### `x_player_armor.compat.x_player_api.get_shield_first_person(player)`

Gets whether the left-hand shield is rendered in 1st person view for a player

```lua
x_player_armor.compat.x_player_api.get_shield_first_person(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `enabled` (`boolean`)

---

### `x_player_armor.compat.x_player_api.get_left_wield_item(player)`

Retrieves the item technical name currently wielded in the player's left hand via x_player_api.

```lua
x_player_armor.compat.x_player_api.get_left_wield_item(player: ObjectRef) -> string
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `item_name` (`string`)

---

## 3d_armor Compatibility Layer

Full backward-compatible drop-in shim providing legacy 3d_armor API functions.

### `armor.get_valid_player(self_or_player, maybe_player, _mod)`

Validates player reference and returns player name and detached armor inventory.

```lua
armor.get_valid_player(self_or_player: any, maybe_player: any, _mod: any) -> string?, InvRef?
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)
- `_mod` (`any`)

**Returns:**
- `name` (`string?`)
- `inv` (`InvRef?`)

---

### `armor.get_weared_armor_elements(self_or_player, maybe_player)`

Returns a map of armor elements currently worn by the player.

```lua
armor.get_weared_armor_elements(self_or_player: any, maybe_player: any) -> table<string,boolean>
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)

**Returns:**
- (`table<string,boolean>`)

---

### `armor.remove_all(self_or_player, maybe_player)`

Removes all armor items from the player's equipped inventory.

```lua
armor.remove_all(self_or_player: any, maybe_player: any) -> nil
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)

**Returns:**
- (`nil`)

---

### `armor.get_player_skin(self_or_player, maybe_player)`

Retrieves the player's skin texture.

```lua
armor.get_player_skin(self_or_player: any, maybe_player: any) -> string
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)

**Returns:**
- (`string`)

---

### `armor.update_skin(self_or_player, maybe_player)`

Updates skin texture and refreshes visual entity.

```lua
armor.update_skin(self_or_player: any, maybe_player: any) -> nil
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)

**Returns:**
- (`nil`)

---

### `armor.add_preview(_self_or_preview, _preview)`

Handled dynamically via composite textures

```lua
armor.add_preview(_self_or_preview: any, _preview: any) -> void
```

**Parameters:**
- `_self_or_preview` (`any`)
- `_preview` (`any`)

---

### `armor.get_preview(self_or_player, maybe_player)`

Returns the composite preview texture for a player.

```lua
armor.get_preview(self_or_player: any, maybe_player: any) -> string
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)

**Returns:**
- (`string`)

---

### `armor.get_armor_formspec(self_or_name, maybe_name, _page)`

Returns the armor formspec string for a player.

```lua
armor.get_armor_formspec(self_or_name: any, maybe_name: any, _page: any) -> string
```

**Parameters:**
- `self_or_name` (`any`)
- `maybe_name` (`any`)
- `_page` (`any`)

**Returns:**
- (`string`)

---

### `armor.get_element(self_or_item, maybe_item)`

Determines which armor element an item belongs to.

```lua
armor.get_element(self_or_item: any, maybe_item: any) -> string?
```

**Parameters:**
- `self_or_item` (`any`)
- `maybe_item` (`any`)

**Returns:**
- (`string?`)

---

### `armor.serialize_inventory_list(self_or_list, maybe_list)`

Serializes an inventory list of ItemStacks to strings.

```lua
armor.serialize_inventory_list(self_or_list: any, maybe_list: any) -> string[]
```

**Parameters:**
- `self_or_list` (`any`)
- `maybe_list` (`any`)

**Returns:**
- (`string[]`)

---

### `armor.deserialize_inventory_list(self_or_list, maybe_list)`

Deserializes an array of item strings to ItemStacks.

```lua
armor.deserialize_inventory_list(self_or_list: any, maybe_list: any) -> ItemStack[]
```

**Parameters:**
- `self_or_list` (`any`)
- `maybe_list` (`any`)

**Returns:**
- (`ItemStack[]`)

---

### `armor.load_armor_inventory(self_or_player, maybe_player)`

Loads armor inventory from player metadata.

```lua
armor.load_armor_inventory(self_or_player: any, maybe_player: any) -> nil
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)

**Returns:**
- (`nil`)

---

### `armor.save_armor_inventory(self_or_player, maybe_player)`

Saves armor inventory to player metadata.

```lua
armor.save_armor_inventory(self_or_player: any, maybe_player: any) -> nil
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)

**Returns:**
- (`nil`)

---

### `armor.set_inventory_stack(self_or_player, maybe_player, i, stack)`

Sets stack at specific slot in detached armor inventory.

```lua
armor.set_inventory_stack(self_or_player: any, maybe_player: any, i: any, stack: any) -> nil
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)
- `i` (`any`)
- `stack` (`any`)

**Returns:**
- (`nil`)

---

### `armor.drop_armor(self_or_pos, maybe_pos, stack)`

Drops an armor item at the given position.

```lua
armor.drop_armor(self_or_pos: any, maybe_pos: any, stack: any) -> ObjectRef?
```

**Parameters:**
- `self_or_pos` (`any`)
- `maybe_pos` (`any`)
- `stack` (`any`)

**Returns:**
- (`ObjectRef?`)

---

### `armor.equip(self_or_player, maybe_player, stack)`

Equips an armor item into the player's armor inventory.
Returns the displaced ItemStack (or nil on failure).

```lua
armor.equip(self_or_player: any, maybe_player: any, stack: any) -> ItemStack?
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)
- `stack` (`any`)

**Returns:**
- `displaced_stack` (`ItemStack?`)

---

### `armor.unequip(self_or_player, maybe_player, element)`

Unequips an armor item by slot element or index.

```lua
armor.unequip(self_or_player: any, maybe_player: any, element: any) -> ItemStack
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)
- `element` (`any`)

**Returns:**
- `unequipped_stack` (`ItemStack`)

---

### `armor.damage(self_or_player, maybe_player, index, stack, uses)`

Damages worn armor item.

```lua
armor.damage(self_or_player: any, maybe_player: any, index: any, stack: any, uses: any) -> boolean
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)
- `index` (`any`)
- `stack` (`any`)
- `uses` (`any`)

**Returns:**
- `destroyed` (`boolean`)

---

### `armor.punch(self_or_player, maybe_player, hitter, time_from_last_punch, tool_capabilities, dir, damage)`

Handles punch combat event.

```lua
armor.punch(self_or_player: any, maybe_player: any, hitter: any, time_from_last_punch: any, tool_capabilities: any, dir: any, damage: any) -> nil
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)
- `hitter` (`any`)
- `time_from_last_punch` (`any`)
- `tool_capabilities` (`any`)
- `dir` (`any`)
- `damage` (`any`)

**Returns:**
- (`nil`)

---

### `armor.set_player_armor(self_or_player, maybe_player)`

Re-evaluates player armor attributes, defense levels, and physics.

```lua
armor.set_player_armor(self_or_player: any, maybe_player: any) -> nil
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)

**Returns:**
- (`nil`)

---

### `armor.update_player_visuals(self_or_player, maybe_player)`

Updates visual attachment entities for a player.

```lua
armor.update_player_visuals(self_or_player: any, maybe_player: any) -> nil
```

**Parameters:**
- `self_or_player` (`any`)
- `maybe_player` (`any`)

**Returns:**
- (`nil`)

---

### `armor.register_armor(self_or_name, maybe_name, def)`

Registers an armor item definition.

```lua
armor.register_armor(self_or_name: any, maybe_name: any, def: any) -> nil
```

**Parameters:**
- `self_or_name` (`any`)
- `maybe_name` (`any`)
- `def` (`any`)

**Returns:**
- (`nil`)

---

### `armor.register_armor_group(self_or_group, maybe_group, base)`

Registers a custom armor defense group.

```lua
armor.register_armor_group(self_or_group: any, maybe_group: any, base: any) -> nil
```

**Parameters:**
- `self_or_group` (`any`)
- `maybe_group` (`any`)
- `base` (`any`)

**Returns:**
- (`nil`)

---

### `armor.register_on_equip(self_or_func, maybe_func)`

Registers an on_equip callback.

```lua
armor.register_on_equip(self_or_func: any, maybe_func: any) -> nil
```

**Parameters:**
- `self_or_func` (`any`)
- `maybe_func` (`any`)

**Returns:**
- (`nil`)

---

### `armor.register_on_unequip(self_or_func, maybe_func)`

Registers an on_unequip callback.

```lua
armor.register_on_unequip(self_or_func: any, maybe_func: any) -> nil
```

**Parameters:**
- `self_or_func` (`any`)
- `maybe_func` (`any`)

**Returns:**
- (`nil`)

---

### `armor.register_on_damage(self_or_func, maybe_func)`

Registers an on_damage callback.

```lua
armor.register_on_damage(self_or_func: any, maybe_func: any) -> nil
```

**Parameters:**
- `self_or_func` (`any`)
- `maybe_func` (`any`)

**Returns:**
- (`nil`)

---

### `armor.register_on_destroy(self_or_func, maybe_func)`

Registers an on_destroy callback.

```lua
armor.register_on_destroy(self_or_func: any, maybe_func: any) -> nil
```

**Parameters:**
- `self_or_func` (`any`)
- `maybe_func` (`any`)

**Returns:**
- (`nil`)

---

### `armor.register_on_update(self_or_func, maybe_func)`

Registers an on_update callback.

```lua
armor.register_on_update(self_or_func: any, maybe_func: any) -> nil
```

**Parameters:**
- `self_or_func` (`any`)
- `maybe_func` (`any`)

**Returns:**
- (`nil`)

---

## shields Compatibility Layer

Full backward-compatible drop-in shim providing legacy shields API functions.

### `shields.register_shield(self_or_name, maybe_name, maybe_def)`

Registers a shield item, ensuring it has armor_shield group.
Supports both shields:register_shield and shields.register_shield syntax.

```lua
shields.register_shield(self_or_name: any, maybe_name: any, maybe_def: any) -> nil
```

**Parameters:**
- `self_or_name` (`any`)
- `maybe_name` (`any`)
- `maybe_def` (`any`)

**Returns:**
- (`nil`)

---

## 3d_armor_stand Compatibility Layer

Compatibility shim for legacy 3d_armor_stand registrations and nodes.

### `armor_stand.get_armor_formspec(pos, player)`

Returns formspec for armor stand (stub for legacy mods).

```lua
armor_stand.get_armor_formspec(pos: vector, player: ObjectRef?) -> string
```

**Parameters:**
- `pos` (`vector`)
- `player` (`ObjectRef?`)

**Returns:**
- (`string`)

---

### `armor_stand.update_entity(pos)`

Forces visual update on stand entity at pos.

```lua
armor_stand.update_entity(pos: vector) -> nil
```

**Parameters:**
- `pos` (`vector`)

**Returns:**
- (`nil`)

---

### `armor_stand.get_stand_object(pos)`

Finds the mannequin entity at pos.

```lua
armor_stand.get_stand_object(pos: vector) -> ObjectRef?
```

**Parameters:**
- `pos` (`vector`)

**Returns:**
- (`ObjectRef?`)

---

### `armor_stand.drop_armor(pos)`

Drops all armor from stand inventory onto the ground.

```lua
armor_stand.drop_armor(pos: vector) -> nil
```

**Parameters:**
- `pos` (`vector`)

**Returns:**
- (`nil`)

---

### `armor_stand.has_locked_armor_stand_privilege(meta, player)`

Checks if player owns or has bypass privileges for a locked stand.

```lua
armor_stand.has_locked_armor_stand_privilege(meta: NodeMetaRef, player: ObjectRef?) -> boolean
```

**Parameters:**
- `meta` (`NodeMetaRef`)
- `player` (`ObjectRef?`)

**Returns:**
- (`boolean`)

---
