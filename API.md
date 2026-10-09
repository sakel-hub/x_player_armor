# x_player_armor API Reference

High-performance modular player armor, shield defense, durability, and damage mitigation system for Luanti.

- **Author**: SaKeL
- **License**: LGPL-2.1-or-later (code), CC-BY-4.0 / CC0-1.0 (assets)
- **Target Engine**: Luanti 5.10.0+

## Table of Contents

- [Core Data Structures & Types](#core-data-structures--types)
  - [XPlayerArmorItemDef](#xplayerarmoritemdef)
  - [XPlayerArmorTransform](#xplayerarmortransform)
  - [XPlayerArmorConstants](#xplayerarmorconstants)
  - [XPlayerArmorElementDef](#xplayerarmorelementdef)
  - [XPlayerArmorMaterialDef](#xplayerarmormaterialdef)
  - [XPlayerArmorPlayerDef](#xplayerarmorplayerdef)
  - [XPlayerArmorPunchCallback](#xplayerarmorpunchcallback)
  - [XPlayerArmorSounds](#xplayerarmorsounds)
  - [SkinResolution](#skinresolution)
- [Public API Reference](#public-api-reference)
  - [Registration & Definitions](#registration--definitions)
  - [Lifecycle & Event Callbacks](#lifecycle--event-callbacks)
  - [Equipment & Inventory State](#equipment--inventory-state)
  - [Combat, Defense & Shield Mechanics](#combat-defense--shield-mechanics)
  - [Visuals & 3D Attachments](#visuals--3d-attachments)
  - [User Interface & Formspecs](#user-interface--formspecs)
  - [HUD Overlays](#hud-overlays)
  - [Mod Integration & Utilities](#mod-integration--utilities)
- [Backward Compatibility Layer](#backward-compatibility-layer)
  - [3d_armor Compatibility](#3d_armor-compatibility)
  - [shields Compatibility](#shields-compatibility)
  - [3d_armor_stand Compatibility](#3d_armor_stand-compatibility)

---

## Core Data Structures & Types

Fundamental tables, callback signatures, and configuration structures utilized by `x_player_armor`.

### `XPlayerArmorItemDef`

Complete configuration table for armor and shield item registration.
Supports custom 3D models, bone transforms, audio, environmental perks, physics, and combat mechanics.

| Field | Type | Description |
| :--- | :--- | :--- |
| `description` | `string` | Full descriptive tooltip text. Single-line descriptions are auto-enriched with a formatted stats card. |
| `short_description` | `string?` | Compact item name displayed in HUD notifications, logs, and armor stand UI (defaults to description or item name) |
| `inventory_image` | `string?` | Standard 2D inventory icon displayed in slot grids and hotbar |
| `preview` | `string?` | 2D paperdoll layer image or fallback icon displayed in legacy inventories (defaults to inventory_image) |
| `texture` | `string?` | Primary 3D UV texture (e.g. "mymod_helmet.png"). Mutually exclusive with textures (overridden if textures is set). |
| `textures` | `string[]?` | Ordered array of texture filenames for multi-material custom 3D models. Overrides texture. |
| `element` | `("head"\|"torso"\|"legs"\|"feet"\|"shield")?` | Target equipment slot element. Slot exclusivity: exactly one element per item. |
| `level` | `number?` | Primary defense rating. Auto-populates armor groups and fleshy damage mitigation. |
| `armor_uses` | `number?` | Total durability uses before breaking (default: 200). Durability wear is applied via core.add_wear_by_uses. |
| `mesh` | `string?` | Custom 3D mesh filename (.glb or .b3d). Mutually exclusive with meshes (overridden if meshes is set). |
| `meshes` | `table<string,string>?` | Map of piece IDs to custom 3D model files (e.g. {torso = "tunic.glb"}). Overrides mesh. |
| `pieces` | `string[]?` | Array of piece IDs to attach from element definition (e.g. {"torso"}). Ignored if custom meshes is used. |
| `transforms` | `table<string,(XPlayerArmorTransform\|table<...>)>?` | Skeletal bone attachment transforms. |
| `glow` | `number?` | Light emission level from 0 to 14 (ideal for enchanted, crystalline, or glowing gear). Ignored if custom 3D mesh is not used. |
| `visual_size` | `(Vector3\|table<string,number>)?` | Visual scale factor override for custom 3D models. Ignored if custom 3D mesh is not used. |
| `backface_culling` | `boolean?` | Whether backface culling is enabled on the model entity (default: true). Ignored if custom 3D mesh is not used. |
| `shaded` | `boolean?` | Whether diffuse shading and lighting is enabled on the model entity (default: true). Ignored if custom 3D mesh is not used. |
| `sounds` | `XPlayerArmorSounds?` | Custom sound effects table for equip, unequip, hit, break, and block events |
| `heal` | `number?` | Passive health regeneration boost level (sets groups.armor_heal) |
| `fire` | `number?` | Fire, heat, and lava damage protection tier threshold from 1 to 5 (sets groups.armor_fire) |
| `water` | `number?` | Underwater breathing and drowning immunity level (sets groups.armor_water) |
| `feather` | `number?` | Fall damage mitigation level (sets groups.armor_feather) |
| `speed` | `number?` | Locomotion movement speed multiplier modifier applied via player physics monoid (sets groups.physics_speed) |
| `jump` | `number?` | Jump height multiplier modifier applied via player physics monoid (sets groups.physics_jump) |
| `gravity` | `number?` | Gravity multiplier modifier applied via player physics monoid (sets groups.physics_gravity) |
| `material` | `string?` | Material category key (e.g. "wood", "steel", "diamond", "nether"). Sets groups.armor_material_<material>. |
| `reciprocate_damage` | `(boolean\|number)?` | Whether damage is reflected back to attacker (thorns). Defaults true for shields, false for armor. |
| `reciprocate_percent` | `number?` | Percentage of incoming damage reflected to attacker. Ignored if reciprocate_damage is false or nil. |
| `wear_color` | `table?` | Durability bar color gradient configuration table |
| `shield_offset` | `table?` | Custom shield forearm attachment transforms for glb and b3d skeletons. Ignored if element is not "shield". |
| `tower_shield` | `boolean?` | Whether shield renders with tower shield model variant in preview and stand. Ignored if element is not "shield". |
| `block_reduction` | `number?` | Frontal damage reduction fraction 0.0 to 1.0 (default: 0.20 or tiered). Ignored if element is not "shield". |
| `block_arc` | `number?` | Custom frontal blocking arc angle in degrees (default: 44-64 deg tiered). Ignored if element is not "shield". |
| `deflect_projectiles` | `boolean?` | Whether shield can physically deflect incoming arrows and projectiles. Ignored if element is not "shield". |
| `particles` | `(table\|boolean)?` | Custom hit and break particle effects configuration, or false to disable |
| `groups` | `table<string,number>?` | Item groups map. Automatically augmented with armor, perk, and material groups. |
| `armor_groups` | `table<string,number>?` | Damage mitigation group ratings (e.g. {fleshy = 15}) |
| `damage_groups` | `table<string,number>?` | Tool durability degradation wear ratings against damage groups |
| `on_equip` | `(fun(player: ObjectRef, index: number, stack: ItemStack))?` | Callback invoked when equipped into armor inventory |
| `on_unequip` | `(fun(player: ObjectRef, index: number, stack: ItemStack))?` | Callback invoked when unequipped from armor inventory |
| `on_damage` | `(fun(player: ObjectRef, index: number, stack: ItemStack, uses: number))?` | Callback invoked when absorbing combat damage |
| `on_destroy` | `(fun(player: ObjectRef, index: number, stack: ItemStack))?` | Callback invoked when this item breaks due to wear exhaustion |
| `on_punch` | `XPlayerArmorPunchCallback?` | Callback invoked when a player wearing this armor piece is punched |
| `on_block` | `(fun(player: ObjectRef, hitter: ObjectRef?, damage: number, shield_stack: ItemStack))?` | Block callback. Shield-only. |

### `XPlayerArmorTransform`

Bone attachment configuration for custom 3D models.

| Field | Type | Description |
| :--- | :--- | :--- |
| `bone` | `string` | Target parent skeleton bone name (e.g. "Head", "Body", "Arm_Left", "Arm_Right", "Leg_Left", "Leg_Right") |
| `model` | `string?` | Optional custom 3D model asset filename (.glb or .b3d) attached to this specific bone |
| `pos` | `(Vector3\|table<string,number>)` | 3D position offset vector relative to bone origin {x, y, z} |
| `rot` | `(Vector3\|table<string,number>)` | Euler rotation angles in degrees {x, y, z} |
| `scale` | `(Vector3\|table<string,number>)?` | Scale vector override {x, y, z} (default: {x=1, y=1, z=1}) |

### `XPlayerArmorConstants`

Core game constants, configuration defaults, and calibration properties for armor and shields.

| Field | Type | Description |
| :--- | :--- | :--- |
| `SLOT_ELEMENTS` | `table<number,string>` | Numeric slot index (1-5) to element name mapping |
| `ELEMENT_GROUPS` | `table<string,string>` | Element name to armor group name mapping (e.g. head -> armor_head) |
| `GROUP_ELEMENTS` | `table<string,string>` | Armor group name to element name inverted mapping |
| `SLOT_LABELS` | `table<string,string>` | Human-readable localized slot display names |
| `MODELS` | `table<string,string>` | Default 3D model asset filenames for armor pieces, preview, and stand |
| `PREVIEW_SLOTS` | `table<string,number>` | 3D model formspec bone/attachment slot indices |
| `BONES` | `table<string,string>` | Target skeletal bone names for player model attachment |
| `ELEMENT_PIECES` | `table<string,string[]>` | Element to constituent 3D piece IDs mapping |
| `ATTACH_TRANSFORMS` | `table<string,table<string,XPlayerArmorTransform>>` | Skeletal attachment transforms for GLB and B3D rigs |
| `SOUNDS` | `table<string,string>` | Built-in sound effect identifiers |
| `FIRE_NODES` | `table<string,number>` | Hazard node protection thresholds (1 to 5) for fire and lava mitigation |
| `LEVEL_MULTIPLIER` | `number` | Global damage mitigation scaling multiplier (setting: x_player_armor_level_multiplier) |
| `HEAL_MULTIPLIER` | `number` | Global health regeneration multiplier (setting: x_player_armor_heal_multiplier) |
| `SET_BONUS` | `boolean` | Whether full-set defense bonus is enabled (setting: x_player_armor_set_bonus) |
| `FIRE_PROTECT` | `boolean` | Whether fire and lava protection is active (setting: x_player_armor_fire_protect) |
| `FIRE_PROTECT_TORCH` | `boolean` | Whether torches deal damage requiring protection (setting: x_player_armor_fire_protect_torch) |
| `WATER_PROTECT` | `boolean` | Whether underwater drowning protection is active (setting: x_player_armor_water_protect) |
| `FEATHER_FALL` | `boolean` | Whether fall damage feather mitigation is active (setting: x_player_armor_feather_fall) |
| `ENABLE_SOUNDS` | `boolean` | Whether equipment and combat audio effects are enabled (setting: x_player_armor_enable_sounds) |
| `DROP_ON_DEATH` | `boolean` | Whether armor drops on player death (setting: x_player_armor_drop_on_death) |
| `DESTROY_ON_DEATH` | `boolean` | Whether armor is permanently destroyed on player death (setting: x_player_armor_destroy_on_death) |
| `COMBAT_HUD_ENABLE` | `boolean` | Whether in-combat armor status HUD is enabled (setting: x_player_armor_combat_hud) |
| `COMBAT_HUD_TIMEOUT` | `number` | Combat HUD display timeout in seconds (setting: x_player_armor_combat_hud_timeout) |
| `COMBAT_HUD_POSITION` | `string` | Combat HUD screen alignment ("bottom_right", "bottom_left", etc.) |
| `COMBAT_HUD_SCALE` | `number` | Combat HUD scaling factor (setting: x_player_armor_combat_hud_scale) |
| `SHIELD_HUD_ENABLE` | `boolean` | Whether 1st-person shield blocking HUD indicator is enabled |
| `SHIELD_HUD_DELAY` | `number` | Delay in seconds before 1st-person shield HUD appears |
| `BLOCK_CONE_ANGLE` | `number` | Half-width of default frontal blocking cone in degrees (52°) |
| `BLOCK_ASYMMETRIC_BIAS` | `number` | Off-hand angular bias towards left guard in degrees (22°) |
| `BLOCK_DEFAULT_REDUCTION` | `number` | Default frontal damage reduction fraction (0.20 = 20%) |
| `BLOCK_DEFLECT_PROJECTILES` | `boolean` | Global flag enabling physical projectile deflection |
| `BLOCK_RESTITUTION` | `number` | Projectile rebound velocity restitution fraction (0.50 = 50% velocity retained) |
| `BLOCK_RECOIL_IMPULSE` | `number` | Physics pushback impulse magnitude applied to attacker on shield block |
| `SHIELD_TIER_PROPERTIES` | `table<string,table<string,number>>` | Material-tiered defense, restitution, and blocking arc ratings |
| `SHIELD_OFFSET` | `table<string,table<string,table<string,number>>>` | Forearm attachment position and rotation offsets for GLB and B3D skeletons |

### `XPlayerArmorElementDef`

Configuration table for registering an armor slot element.

| Field | Type | Description |
| :--- | :--- | :--- |
| `slot` | `number?` | Primary inventory slot index (1 to 6) |
| `group` | `string?` | Item group associated with this element (e.g. "armor_head", "armor_torso") |
| `label` | `string?` | Human-readable localized slot name (e.g. "Helmet", "Chestplate") |
| `pieces` | `string[]?` | List of constituent 3D piece IDs (e.g. {"torso", "sleeve_l", "sleeve_r"}) |
| `preview_slot` | `number?` | Preview 3D model slot index (0 to 8) |
| `bone` | `string?` | Default skeletal bone name for attachment (e.g. "Head", "Body") |
| `transforms` | `table<string,XPlayerArmorTransform>?` | Default skeletal bone transforms by model format |

### `XPlayerArmorMaterialDef`

Configuration table for registering an armor material.

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | `string` | Localized material display name (e.g. "Steel", "Diamond") |
| `uses` | `number` | Base durability uses before breaking (e.g. 350, 1200) |
| `level` | `table<string,number>` | Element to defense level rating map (e.g. {head = 10, torso = 15, legs = 12, feet = 8, shield = 10}) |
| `heal` | `table<string,number>?` | Optional element to health regeneration level map |
| `fire` | `table<string,number>?` | Optional element to fire/lava protection tier map (1 to 5) |
| `water` | `table<string,number>?` | Optional element to water breathing/drowning protection level map |
| `feather` | `table<string,number>?` | Optional element to fall damage feather mitigation level map |
| `speed` | `table<string,number>?` | Optional element to physics movement speed multiplier map |
| `jump` | `table<string,number>?` | Optional element to physics jump height multiplier map |
| `gravity` | `table<string,number>?` | Optional element to physics gravity multiplier map |
| `ingredient` | `string?` | Crafting recipe item or group identifier (e.g. "default:steel_ingot") |
| `sound` | `string?` | Equipment sound identifier (e.g. "metal", "wood", "crystal") |

### `XPlayerArmorPlayerDef`

Runtime state definition cache for an active player.

| Field | Type | Description |
| :--- | :--- | :--- |
| `state` | `number` | Bitmask or numeric state flag of worn armor |
| `count` | `number` | Number of equipped armor pieces |
| `level` | `number` | Total aggregated defense level rating across all worn gear |
| `heal` | `number` | Total health regeneration boost rating |
| `jump` | `number` | Aggregated jump height multiplier modifier |
| `speed` | `number` | Aggregated movement speed multiplier modifier |
| `gravity` | `number` | Aggregated gravity multiplier modifier |
| `fire` | `number` | Maximum fire/lava protection tier rating |
| `water` | `number` | Total water breathing/drowning protection level |
| `feather` | `number` | Total fall damage mitigation level |
| `has_shield` | `boolean` | Whether a shield is currently equipped |
| `has_reciprocate` | `boolean` | Whether damage reciprocation (thorns) is active |
| `groups` | `table<string,number>` | Active defense ratings map against damage groups |
| `textures` | `string[]` | Array of resolved texture strings for player mesh |
| `skin` | `string` | Base skin texture filename |

### `XPlayerArmorPunchCallback`

Callback invoked when a player wearing armor or holding a shield is punched.

### `XPlayerArmorSounds`

Sound effects triggered during armor lifecycle and combat events.

| Field | Type | Description |
| :--- | :--- | :--- |
| `equip` | `string?` | Sound effect played when the item is equipped into an armor slot |
| `unequip` | `string?` | Sound effect played when the item is unequipped from an armor slot |
| `hit` | `string?` | Sound effect played when armor absorbs a combat strike |
| `break_sound` | `string?` | Sound effect played when the item breaks from wear exhaustion |
| `block` | `string?` | Sound effect played when an incoming attack or projectile is deflected by a shield |

### `SkinResolution`

| Field | Type | Description |
| :--- | :--- | :--- |
| `body10` | `string` | Texture specifier for 64x32 Slot 0 ("blank.png" if 1.8) |
| `body18` | `string` | Texture specifier for 64x64 Slot 1 ("blank.png" if 1.0) |
| `format` | `string` | "1.0" \| "1.8" |
| `raw_texture` | `string` | Base skin texture filename |
| `composite_texture` | `string` | Skin texture with clothing overlays |

---

## Public API Reference

All public functions are exposed under the canonical `x_player_armor.*` namespace.
Internal implementation modules (e.g. `visuals`, `combat`, `inventory`, `compat`) are decoupled behind this unified facade following SOLID architecture.

### Registration & Definitions

Methods for registering custom armor items, slot elements, materials, defense groups, and resolving technical item names.

#### `x_player_armor.register_armor(name, def)`

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

#### `x_player_armor.register_element(element, def)`

Registers an armor slot element specification (e.g. "head", "torso", "legs", "feet", "shield").

```lua
x_player_armor.register_element(element: string, def: XPlayerArmorElementDef) -> nil
```

**Parameters:**
- `element` (`string`) — Unique element identifier string (e.g. "head", "torso", "legs", "feet", "shield")
- `def` (`XPlayerArmorElementDef`) — Element configuration table defining slot mapping, groups, labels, and model pieces

**Returns:**
- (`nil`)

---

#### `x_player_armor.register_material(material, def)`

Registers an armor material specification for tiered defense and craft generation.

```lua
x_player_armor.register_material(material: string, def: XPlayerArmorMaterialDef) -> nil
```

**Parameters:**
- `material` (`string`) — Unique material key string (e.g. "wood", "steel", "diamond")
- `def` (`XPlayerArmorMaterialDef`) — Material attributes table specifying tiers, stats, and crafting ingredients

**Returns:**
- (`nil`)

---

#### `x_player_armor.register_armor_group(group, base)`

Registers an armor group baseline.

```lua
x_player_armor.register_armor_group(group: string, base: number) -> nil
```

**Parameters:**
- `group` (`string`) — Armor group name (e.g. "fleshy")
- `base` (`number`) — Baseline value (default: 100)

**Returns:**
- (`nil`)

---

#### `x_player_armor.get_armor_def(item_name)`

Retrieves the armor definition table for a registered armor item.
Checks internal registered_armors first, falling back to core.registered_tools or core.registered_items.

```lua
x_player_armor.get_armor_def(item_name: string) -> XPlayerArmorItemDef?
```

**Parameters:**
- `item_name` (`string`) — Technical item name

**Returns:**
- `def` (`XPlayerArmorItemDef?`) — Registered armor item definition or nil

---

#### `x_player_armor.get_legacy_replacement(name)`

Resolves the modern x_player_armor item technical name if the given name is a legacy item.

```lua
x_player_armor.get_legacy_replacement(name: string) -> string?
```

**Parameters:**
- `name` (`string`) — Technical item name (e.g. "3d_armor:helmet_diamond" or ":3d_armor:helmet_diamond")

**Returns:**
- `modern_name` (`string?`) — Replacement modern technical name, or nil if not superseded

---

### Lifecycle & Event Callbacks

Global callback registration hooks invoked during armor equipment changes, combat strikes, item destruction, state updates, and shield blocks.

#### `x_player_armor.register_on_equip(func)`

Registers a global callback listener invoked when an armor piece is equipped into an inventory slot.

```lua
x_player_armor.register_on_equip(func: fun(player: ObjectRef, index: number, stack: ItemStack)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, index: number, stack: ItemStack)`) — Callback receiving player, slot index, and equipped stack

**Returns:**
- (`nil`)

---

#### `x_player_armor.register_on_unequip(func)`

Registers a global callback listener invoked when an armor piece is removed from an inventory slot.

```lua
x_player_armor.register_on_unequip(func: fun(player: ObjectRef, index: number, stack: ItemStack)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, index: number, stack: ItemStack)`) — Callback receiving player, slot index, and unequipped stack

**Returns:**
- (`nil`)

---

#### `x_player_armor.register_on_damage(func)`

Registers a global callback listener invoked when a worn armor piece absorbs combat damage.

```lua
x_player_armor.register_on_damage(func: fun(player: ObjectRef, index: number, stack: ItemStack, uses: number)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, index: number, stack: ItemStack, uses: number)`) — Callback receiving player, slot, stack, and wear

**Returns:**
- (`nil`)

---

#### `x_player_armor.register_on_destroy(func)`

Registers a global callback listener invoked when an armor item breaks due to wear exhaustion.

```lua
x_player_armor.register_on_destroy(func: fun(player: ObjectRef, index: number, stack: ItemStack)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, index: number, stack: ItemStack)`) — Callback receiving player, slot index, and destroyed stack

**Returns:**
- (`nil`)

---

#### `x_player_armor.register_on_update(func)`

Registers a global callback listener invoked whenever player armor state, defense, or visuals update.

```lua
x_player_armor.register_on_update(func: fun(player: ObjectRef)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef)`) — Callback receiving updated player reference

**Returns:**
- (`nil`)

---

#### `x_player_armor.register_on_block(func)`

Registers a global callback listener invoked when a player blocks an attack or deflects a projectile.

```lua
x_player_armor.register_on_block(func: fun(player: ObjectRef, hitter: (ObjectRef|table), damage: number, shield: ItemStack)) -> nil
```

**Parameters:**
- `func` (`fun(player: ObjectRef, hitter: (ObjectRef|table), damage: number, shield: ItemStack)`) — Callback receiving player, hitter, damage, shield

**Returns:**
- (`nil`)

---

#### `x_player_armor.run_callbacks(event_name, ...)`

Dispatches a registered callback event across global listeners and item-level definitions.

```lua
x_player_armor.run_callbacks(event_name: string, ...: any) -> nil
```

**Parameters:**
- `event_name` (`string`) — Event name ("on_equip", "on_unequip", "on_damage", "on_destroy", "on_update", "on_block")
- `...` (`any`) — Arguments forwarded to the callback listeners

**Returns:**
- (`nil`)

---

### Equipment & Inventory State

Methods for equipping and unequipping items, querying worn armor elements, inspecting player state definitions, and checking environmental protection rules.

#### `x_player_armor.equip(player, itemstack)`

Equips an armor item into the appropriate slot.

```lua
x_player_armor.equip(player: ObjectRef, itemstack: ItemStack) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `itemstack` (`ItemStack`) — Armor item to equip

**Returns:**
- `success` (`boolean`) — True if the item was equipped into a valid slot

---

#### `x_player_armor.unequip(player, element)`

Unequips an armor item by slot element.

```lua
x_player_armor.unequip(player: ObjectRef, element: string) -> ItemStack
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `element` (`string`) — Slot element to unequip ("head", "torso", "legs", "feet", "shield")

**Returns:**
- `unequipped_stack` (`ItemStack`) — The removed item stack

---

#### `x_player_armor.remove_all(player)`

Unequips all armor items from the player's equipped inventory.

```lua
x_player_armor.remove_all(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player to remove all equipped armor from

**Returns:**
- (`nil`)

---

#### `x_player_armor.get_worn_elements(player)`

Returns a map of armor elements currently worn by the player.

```lua
x_player_armor.get_worn_elements(player: ObjectRef) -> table<string,boolean>
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `worn_elements` (`table<string,boolean>`) — Map of worn element names to true (e.g. {head = true, torso = true})

---

#### `x_player_armor.get_valid_player(player)`

Returns the detached armor inventory and player name if valid.

```lua
x_player_armor.get_valid_player(player: ObjectRef) -> string?, InvRef?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `name` (`string?`) — Validated player name and detached armor inventory reference, or nil, nil
- `inv` (`InvRef?`) — Validated player name and detached armor inventory reference, or nil, nil

---

#### `x_player_armor.get_player_def(player)`

Returns the active armor definition cache for a player.

```lua
x_player_armor.get_player_def(player: ObjectRef) -> XPlayerArmorPlayerDef
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `state` (`XPlayerArmorPlayerDef`) — Active player armor runtime state table (stats, groups, levels)

---

#### `x_player_armor.get_elements()`

Returns the canonical list of registered armor slot elements.

```lua
x_player_armor.get_elements() -> string[]
```

**Returns:**
- `elements` (`string[]`) — Array of element identifiers (e.g. {"head", "torso", "legs", "feet", "shield"})

---

#### `x_player_armor.get_attributes()`

Returns the canonical list of registered armor attributes and environmental perks.

```lua
x_player_armor.get_attributes() -> string[]
```

**Returns:**
- `attributes` (`string[]`) — Array of attribute keys (e.g. {"heal", "fire", "water", "feather"})

---

#### `x_player_armor.get_fire_nodes()`

Returns the registered fire, lava, and thermal hazard node protection thresholds.

```lua
x_player_armor.get_fire_nodes() -> table<string,number>
```

**Returns:**
- `fire_nodes` (`table<string,number>`) — Map of node names to minimum required fire protection tiers (1 to 5)

---

#### `x_player_armor.is_reciprocate_damage_enabled()`

Checks whether damage reciprocation (thorns) is globally configured or active.

```lua
x_player_armor.is_reciprocate_damage_enabled() -> boolean
```

**Returns:**
- `enabled` (`boolean`) — True if reciprocate damage is active

---

### Combat, Defense & Shield Mechanics

Methods for evaluating punch damage mitigation, shield blocking state, frontal defense cones, projectile deflection physics, and shield transforms.

#### `x_player_armor.damage(player, index, stack, uses)`

Applies durability damage to a worn armor item.

```lua
x_player_armor.damage(player: ObjectRef, index: number, stack: ItemStack, uses: number) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `index` (`number`) — Slot index in armor inventory (1-6)
- `stack` (`ItemStack`) — Current armor item stack
- `uses` (`number`) — Durability wear amount to apply

**Returns:**
- `destroyed` (`boolean`) — True if the armor item broke from wear exhaustion

---

#### `x_player_armor.punch(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)`

Calculates armor mitigation and wear on punch.

```lua
x_player_armor.punch(player: ObjectRef, hitter: ObjectRef?, time_from_last_punch: number?, tool_capabilities: table?, dir: vector?, damage: number?) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Defending player taking the punch
- `hitter` (`ObjectRef?`) — Attacking entity or player
- `time_from_last_punch` (`number?`) — Seconds elapsed since previous punch
- `tool_capabilities` (`table?`) — Tool capabilities table of the punch
- `dir` (`vector?`) — Direction vector of the incoming attack
- `damage` (`number?`) — Raw damage points before armor mitigation

**Returns:**
- (`nil`)

---

#### `x_player_armor.can_block(player)`

Evaluates whether a player is capable of blocking with an equipped shield.

```lua
x_player_armor.can_block(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `can_block` (`boolean`)

---

#### `x_player_armor.is_blocking(player)`

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

#### `x_player_armor.is_facing_attack(player, attack_dir, max_arc_deg, bias_deg)`

Validates whether an incoming attack or projectile vector falls within the player's frontal blocking cone.

```lua
x_player_armor.is_facing_attack(player: ObjectRef, attack_dir: vector, max_arc_deg: number?, bias_deg: number?) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `attack_dir` (`vector`) — Direction pointing from the attacker/projectile towards the player
- `max_arc_deg` (`number?`) — Maximum blocking arc in degrees (default: 52 + tier bonus)
- `bias_deg` (`number?`) — Custom lateral bias angle in degrees (default: 22 deg off-hand bias)

**Returns:**
- `is_facing` (`boolean`) — True if the attack angle falls within the player's frontal shield arc

---

#### `x_player_armor.try_deflect_projectile(player, proj_obj, hit_pos, flight_dir, proj_data)`

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
- `deflected` (`boolean`) — True if the projectile was successfully deflected
- `bounce_velocity` (`vector?`) — Deflected projectile velocity vector

---

#### `x_player_armor.get_equipped_shield(player)`

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

#### `x_player_armor.get_shield_contact_pos(player)`

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

#### `x_player_armor.get_shield_offset(format)`

Gets the shield attachment transform for a given model format ("glb" or "b3d").

```lua
x_player_armor.get_shield_offset(format: string?) -> table
```

**Parameters:**
- `format` (`string?`) — Model format ("glb" or "b3d", defaults to "glb")

**Returns:**
- `offset` (`table`) — Offset table containing pos and rot vectors for forearm shield attachment

---

#### `x_player_armor.set_shield_offset(format, pos, rot)`

Sets or overrides the shield attachment transform for a model format.

```lua
x_player_armor.set_shield_offset(format: string, pos: Vector3, rot: Vector3) -> nil
```

**Parameters:**
- `format` (`string`) — Model format ("glb" or "b3d")
- `pos` (`Vector3`) — Offset position vector
- `rot` (`Vector3`) — Euler rotation angles in degrees

**Returns:**
- (`nil`)

---

### Visuals & 3D Attachments

Methods for managing 3D skeletal bone attachments, off-hand shield positioning, skin resolution, visual entity restoration, and third-party entity attachments.

#### `x_player_armor.set_player_armor(player)`

Re-evaluates armor stats, groups, and physics for a player.

```lua
x_player_armor.set_player_armor(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player to recalculate armor groups, physics, and stats for

**Returns:**
- (`nil`)

---

#### `x_player_armor.update_player_visuals(player)`

Updates modular bone attachments and visual entity state for a player.

```lua
x_player_armor.update_player_visuals(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player to update modular 3D armor visual attachments on

**Returns:**
- (`nil`)

---

#### `x_player_armor.clear_player_visuals(player)`

Clears all modular visual entities for a player.

```lua
x_player_armor.clear_player_visuals(player: (ObjectRef|string)) -> nil
```

**Parameters:**
- `player` (`(ObjectRef|string)`) — Player object or player name whose attached visuals should be cleared

**Returns:**
- (`nil`)

---

#### `x_player_armor.restore_all_player_visuals()`

Restores modular armor visual entities for all connected players.

```lua
x_player_armor.restore_all_player_visuals() -> nil
```

**Returns:**
- (`nil`)

---

#### `x_player_armor.schedule_player_visual_restore(player_name)`

Schedules debounced restoration for a specific player's visual armor pieces.

```lua
x_player_armor.schedule_player_visual_restore(player_name: string) -> nil
```

**Parameters:**
- `player_name` (`string`) — Name of the player to schedule visual restoration for

**Returns:**
- (`nil`)

---

#### `x_player_armor.attach_armor_to_entity(parent, player_or_name, format)`

Attaches modular armor visual entities to an arbitrary parent entity (such as a deathstats corpse).

```lua
x_player_armor.attach_armor_to_entity(parent: ObjectRef, player_or_name: (ObjectRef|string|table), format: string?) -> ObjectRef[]
```

**Parameters:**
- `parent` (`ObjectRef`) — The entity to attach armor to
- `player_or_name` (`(ObjectRef|string|table)`) — Player object, player name, or explicit armor item list
- `format` (`string?`) — Model format ("glb" or "b3d")

**Returns:**
- `entities` (`ObjectRef[]`) — List of spawned armor visual entities

---

#### `x_player_armor.attach_shield(player_or_parent, item_or_stack, format_or_opts, custom_opts)`

Attaches an off-hand shield entity to a player's left forearm or a target entity (such as a corpse).

```lua
x_player_armor.attach_shield(player_or_parent: ObjectRef, item_or_stack: (string|ItemStack), format_or_opts: (table|string)?, custom_opts: table?) -> ObjectRef?
```

**Parameters:**
- `player_or_parent` (`ObjectRef`) — Target player or parent entity
- `item_or_stack` (`(string|ItemStack)`) — Shield item name or stack
- `format_or_opts` (`(table|string)?`) — Optional model format ("glb"|"b3d") or options table
- `custom_opts` (`table?`) — Optional transform and visual overrides

**Returns:**
- `entity` (`ObjectRef?`) — Attached entity reference or nil on failure

---

#### `x_player_armor.attach_shield_to_entity(parent, item_or_stack, format, custom_opts)`

Attaches a shield visual entity to a target parent entity (such as a corpse or mob) with proper forearm transforms.

```lua
x_player_armor.attach_shield_to_entity(parent: ObjectRef, item_or_stack: (string|ItemStack), format: string?, custom_opts: table?) -> ObjectRef?
```

**Parameters:**
- `parent` (`ObjectRef`) — The entity to attach the shield to
- `item_or_stack` (`(string|ItemStack)`) — Shield item name or stack
- `format` (`string?`) — Model format ("glb" or "b3d")
- `custom_opts` (`table?`) — Optional custom overrides

**Returns:**
- `entity` (`ObjectRef?`) — The attached shield entity or nil

---

#### `x_player_armor.update_shield(player, item_or_stack, custom_opts)`

Updates or modifies an attached off-hand shield entity via x_player_api.

```lua
x_player_armor.update_shield(player: ObjectRef, item_or_stack: (string|ItemStack)?, custom_opts: table?) -> ObjectRef?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player
- `item_or_stack` (`(string|ItemStack)?`) — Shield item name or stack
- `custom_opts` (`table?`) — Optional transform and visual overrides

**Returns:**
- `entity` (`ObjectRef?`) — Updated shield entity reference or nil

---

#### `x_player_armor.remove_shield(player)`

Removes an attached off-hand shield entity from a player via x_player_api.

```lua
x_player_armor.remove_shield(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player to remove shield from

**Returns:**
- (`nil`)

---

#### `x_player_armor.set_shield_first_person(player, enable)`

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

#### `x_player_armor.get_shield_first_person(player)`

Gets whether an off-hand shield is visible in 1st person view via x_player_api.

```lua
x_player_armor.get_shield_first_person(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `enabled` (`boolean`) — Whether 1st person shield visibility is active

---

#### `x_player_armor.cleanup_orphaned_visuals()`

Cleans up any orphaned or detached x_player_armor:visual entities near connected players.

```lua
x_player_armor.cleanup_orphaned_visuals() -> number
```

**Returns:**
- `count` (`number`) — Number of cleaned up entities

---

#### `x_player_armor.resolve_player_skin(player)`

Resolves the player's active skin and produces the canonical dual-slot texture pair.

```lua
x_player_armor.resolve_player_skin(player: ObjectRef) -> SkinResolution
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `resolution` (`SkinResolution`)

---

#### `x_player_armor.get_skin_info(player)`

Retrieves skin information for a player.

```lua
x_player_armor.get_skin_info(player: ObjectRef) -> SkinResolution
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `resolution` (`SkinResolution`)

---

### User Interface & Formspecs

Methods for displaying and refreshing player armor equipment dialogs across standard, sfinv, unified_inventory, and i3 interfaces.

#### `x_player_armor.show_armor_formspec(player)`

Opens the armor and equipment inventory formspec for a player.

```lua
x_player_armor.show_armor_formspec(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player to open the armor formspec for

**Returns:**
- (`nil`)

---

#### `x_player_armor.refresh_player_formspec(player)`

Refreshes open armor formspecs for a player across active inventory engines.

```lua
x_player_armor.refresh_player_formspec(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`) — Target player whose open armor formspec should be refreshed

**Returns:**
- (`nil`)

---

#### `x_player_armor.is_armor_ui_open(player)`

Checks whether a specific player is currently viewing an armor equipment interface.

```lua
x_player_armor.is_armor_ui_open(player: ObjectRef) -> boolean
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `is_open` (`boolean`) — True if armor UI is open for player

---

#### `x_player_armor.has_any_open_armor_ui()`

Checks whether any connected player has an active armor inventory interface open.
Optimizes multiplayer performance by idle-skipping background updates when no UI is open.

```lua
x_player_armor.has_any_open_armor_ui() -> boolean
```

**Returns:**
- `has_any` (`boolean`) — True if any player has armor UI open

---

#### `x_player_armor.get_player_preview_texture(player)`

Returns the composite preview texture string for 3D model formspecs.

```lua
x_player_armor.get_player_preview_texture(player: ObjectRef) -> string
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `preview_texture` (`string`) — Composite preview texture string for 3D model formspecs

---

### HUD Overlays

Methods for triggering and controlling the combat durability HUD overlay and the 1st-person shield blocking reticle indicator.

#### `x_player_armor.show_shield_block_hud(player, immediate)`

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

#### `x_player_armor.hide_shield_block_hud(player)`

Hides the 2D shield block HUD indicator from the target player.

```lua
x_player_armor.hide_shield_block_hud(player: ObjectRef) -> nil
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- (`nil`)

---

#### `x_player_armor.get_shield_block_hud(player)`

Retrieves the active shield block HUD element ID for a player if one exists.

```lua
x_player_armor.get_shield_block_hud(player: ObjectRef) -> number?
```

**Parameters:**
- `player` (`ObjectRef`)

**Returns:**
- `hud_id` (`number?`)

---

#### `x_player_armor.trigger_combat_hud(player)`

Displays or updates the combat armor HUD overlay on the target player.

```lua
x_player_armor.trigger_combat_hud(player: ObjectRef) -> number?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player to display the combat HUD on

**Returns:**
- `hud_id` (`number?`) — Active combat HUD element ID, or nil

---

#### `x_player_armor.hide_combat_hud(player)`

Hides the combat armor HUD overlay from the target player.

```lua
x_player_armor.hide_combat_hud(player: (ObjectRef|string)) -> nil
```

**Parameters:**
- `player` (`(ObjectRef|string)`) — Target player or player name

**Returns:**
- (`nil`)

---

#### `x_player_armor.get_combat_hud_id(player)`

Retrieves the active combat armor HUD element ID for a player if one exists.

```lua
x_player_armor.get_combat_hud_id(player: ObjectRef) -> number?
```

**Parameters:**
- `player` (`ObjectRef`) — Target player

**Returns:**
- `hud_id` (`number?`) — Active combat HUD element ID, or nil if not active

---

### Mod Integration & Utilities

Integration helpers for optional mod environments.

#### `x_player_armor.get_mod_api(modname)`

Safely retrieves the global table of an optional mod if installed and loaded.

```lua
x_player_armor.get_mod_api(modname: string) -> table?
```

**Parameters:**
- `modname` (`string`) — The name of the optional mod

**Returns:**
- `mod_api` (`table?`) — The global table or nil if absent

---

## Backward Compatibility Layer

`x_player_armor` provides full, transparent, drop-in backward compatibility for legacy mods designed around `3d_armor`, `shields`, and `3d_armor_stand`. External mods requiring these APIs continue to function seamlessly without modification.

### 3d_armor Compatibility
- **Global Table**: The global `armor` table is virtualized and registered with standard methods (`armor:register_armor`, `armor:equip`, `armor:damage`, `armor:punch`, `armor:update_player_visuals`, `armor:get_valid_player`, etc.).
- **Legacy Item Mapping**: Legacy items prefixed with `3d_armor:*` are automatically redirected, aliased, and migrated to modern `x_player_armor:*` equivalents.
- **Inventory Format**: Detached inventories and metadata structures are automatically migrated to modern `x_player_armor` format.

### shields Compatibility
- **Global Table**: The global `shields` table is provided with complete support for shield registration (`shields:register_shield`), punch mitigation, and blocking logic.
- **Legacy Item Mapping**: Legacy shields prefixed with `shields:shield_*` and `shields:shield_enhanced_*` are mapped to modern tiered shield equivalents.

### 3d_armor_stand Compatibility
- **Registered Nodes & Entities**: Compatible node definitions and entity handlers for `3d_armor_stand:armor_stand` and locked variants are maintained.
- **Wardrobe Swap**: Shift+click and formspec interaction remain fully functional with legacy and modern armor pieces.

> [!NOTE]
> New mods developed for Luanti should directly target the canonical `x_player_armor.*` API namespace documented above for optimal performance, strict typing, and full feature access.
