---Core public API namespace for x_player_armor.
---High-performance modular player armor, shield defense, durability, and damage mitigation system.
---@class XPlayerArmorAPI
---@field version string Semantic version of the mod
---@field def table<string, XPlayerArmorPlayerDef> Player armor state cache
---@field registered_armors table<string, XPlayerArmorItemDef> Registered armor item definitions
---@field registered_elements table<string, XPlayerArmorElementDef> Registered armor slot elements
---@field registered_materials table<string, XPlayerArmorMaterialDef> Registered armor materials
---@field registered_groups table<string, number> Base armor groups map
---@field callbacks table<string, function[]> Event callback listener tables
---@field constants XPlayerArmorConstants Constants and configuration settings
local DEFAULT_ELEMENTS = {"head", "torso", "legs", "feet", "shield"}
local DEFAULT_ATTRIBUTES = {"heal", "fire", "water", "feather"}

local default_x_player_api = {
	is_present = function() return false end,
	get_api = function() return nil end,
	attach_shield = function() return nil end,
	attach_shield_to_entity = function() return nil end,
	update_shield = function() return nil end,
	remove_shield = function() end,
	set_shield_first_person = function() end,
	get_shield_first_person = function() return false end,
	get_left_wield_item = function() return "" end,
	on_equip = function() end,
	trigger_hurt = function() end,
	init = function() end,
}

local default_hud = {
	sync_player_hud_def = function() end,
}

local api = {
	version = "2.0.0",
	def = {},
	vfx = {},
	skins = {},
	utils = {},
	registered_armors = {},
	legacy_replacements = {},
	registered_elements = {},
	registered_materials = {},
	registered_groups = {fleshy = 100},
	callbacks = {
		on_equip = {},
		on_unequip = {},
		on_damage = {},
		on_destroy = {},
		on_update = {},
		on_block = {},
	},
	compat = {
		x_player_api = default_x_player_api,
		hud = default_hud,
	},
	compat_x_player_api = default_x_player_api,
	compat_hud = default_hud,
}

_G.x_player_armor = api


---Safely retrieves the global table of an optional mod if installed and loaded.
---@param modname string The name of the optional mod
---@return table<string, any>|nil mod_api The global table or nil if absent
function api.get_mod_api(modname)
	local mod = rawget(_G, modname)
	if type(mod) == "table" then
		return mod
	end
	if core.get_modpath and core.get_modpath(modname) then
		mod = rawget(_G, modname)
		if type(mod) == "table" then
			return mod
		end
	end
	return nil
end

---Returns the canonical list of registered armor slot elements.
---@nodiscard
---@return string[] elements Array of element identifiers (e.g. {"head", "torso", "legs", "feet", "shield"})
function api.get_elements()
	local global_armor = rawget(_G, "armor")
	if global_armor and global_armor.elements then
		return global_armor.elements
	end
	return DEFAULT_ELEMENTS
end

---Returns the canonical list of registered armor attributes and environmental perks.
---@nodiscard
---@return string[] attributes Array of attribute keys (e.g. {"heal", "fire", "water", "feather"})
function api.get_attributes()
	local global_armor = rawget(_G, "armor")
	if global_armor and global_armor.attributes then
		return global_armor.attributes
	end
	return DEFAULT_ATTRIBUTES
end

---Returns the registered fire, lava, and thermal hazard node protection thresholds.
---@nodiscard
---@return table<string, number> fire_nodes Map of node names to minimum required fire protection tiers (1 to 5)
function api.get_fire_nodes()
	local global_armor = rawget(_G, "armor")
	if global_armor and global_armor.fire_nodes then
		return global_armor.fire_nodes
	end
	return api.constants and api.constants.FIRE_NODES or {}
end

---Checks whether damage reciprocation (thorns) is globally configured or active.
---@nodiscard
---@return boolean enabled True if reciprocate damage is active
function api.is_reciprocate_damage_enabled()
	local global_armor = rawget(_G, "armor")
	return (global_armor and global_armor.config and global_armor.config.reciprocate_damage) == true
end

---Registers a global callback listener invoked when an armor piece is equipped into an inventory slot.
---@param func fun(player: ObjectRef, index: number, stack: ItemStack) Callback receiving player, slot index, and equipped stack
function api.register_on_equip(func)
	table.insert(api.callbacks.on_equip, func)
end

---Registers a global callback listener invoked when an armor piece is removed from an inventory slot.
---@param func fun(player: ObjectRef, index: number, stack: ItemStack) Callback receiving player, slot index, and unequipped stack
function api.register_on_unequip(func)
	table.insert(api.callbacks.on_unequip, func)
end

---Registers a global callback listener invoked when a worn armor piece absorbs combat damage.
---@param func fun(player: ObjectRef, index: number, stack: ItemStack, uses: number) Callback receiving player, slot, stack, and wear
function api.register_on_damage(func)
	table.insert(api.callbacks.on_damage, func)
end

---Registers a global callback listener invoked when an armor item breaks due to wear exhaustion.
---@param func fun(player: ObjectRef, index: number, stack: ItemStack) Callback receiving player, slot index, and destroyed stack
function api.register_on_destroy(func)
	table.insert(api.callbacks.on_destroy, func)
end

---Registers a global callback listener invoked whenever player armor state, defense, or visuals update.
---@param func fun(player: ObjectRef) Callback receiving updated player reference
function api.register_on_update(func)
	table.insert(api.callbacks.on_update, func)
end

---Registers a global callback listener invoked when a player blocks an attack or deflects a projectile.
---@param func fun(player: ObjectRef, hitter: ObjectRef?, damage: number, shield: ItemStack) Callback receiving player, hitter, damage, shield
function api.register_on_block(func)
	table.insert(api.callbacks.on_block, func)
end

---Dispatches a registered callback event across global listeners and item-level definitions.
---@param event_name string Event name ("on_equip", "on_unequip", "on_damage", "on_destroy", "on_update", "on_block")
---@param ... any Arguments forwarded to the callback listeners
function api.run_callbacks(event_name, ...)
	local list = api.callbacks[event_name]
	if list then
		for i = 1, #list do
			list[i](...)
		end
	end
	-- Dispatch to item-level callback if an ItemStack was passed in arguments
	local arg1, arg2, arg3, arg4 = ...
	local item_stack = nil
	if (type(arg3) == "userdata" or type(arg3) == "table") and arg3.is_empty then
		item_stack = arg3
	elseif (type(arg4) == "userdata" or type(arg4) == "table") and arg4.is_empty then
		item_stack = arg4
	elseif (type(arg2) == "userdata" or type(arg2) == "table") and arg2.is_empty then
		item_stack = arg2
	elseif (type(arg1) == "userdata" or type(arg1) == "table") and arg1.is_empty then
		item_stack = arg1
	end

	if item_stack and not item_stack:is_empty() and item_stack.get_name then
		local def = (item_stack.get_definition and item_stack:get_definition()) or api.registered_armors[item_stack:get_name()]
		if def and def[event_name] then
			def[event_name](...)
		end
	end
end

---Configuration table for registering an armor slot element.
---@class XPlayerArmorElementDef
---@field slot number? Primary inventory slot index (1 to 6)
---@field group string? Item group associated with this element (e.g. "armor_head", "armor_torso")
---@field label string? Human-readable localized slot name (e.g. "Helmet", "Chestplate")
---@field pieces string[]? List of constituent 3D piece IDs (e.g. {"torso", "sleeve_l", "sleeve_r"})
---@field preview_slot number? Preview 3D model slot index (0 to 8)
---@field bone string? Default skeletal bone name for attachment (e.g. "Head", "Body")
---@field transforms table<string, XPlayerArmorTransform>? Default skeletal bone transforms by model format

---Configuration table for registering an armor material.
---@class XPlayerArmorMaterialDef
---@field name string Localized material display name (e.g. "Steel", "Diamond")
---@field uses number Base durability uses before breaking (e.g. 350, 1200)
---@field level table<string, number> Element to defense level rating map (e.g. {head = 10, torso = 15, legs = 12, feet = 8, shield = 10})
---@field heal table<string, number>? Optional element to health regeneration level map
---@field fire table<string, number>? Optional element to fire/lava protection tier map (1 to 5)
---@field water table<string, number>? Optional element to water breathing/drowning protection level map
---@field feather table<string, number>? Optional element to fall damage feather mitigation level map
---@field speed table<string, number>? Optional element to physics movement speed multiplier map
---@field jump table<string, number>? Optional element to physics jump height multiplier map
---@field gravity table<string, number>? Optional element to physics gravity multiplier map
---@field ingredient string? Crafting recipe item or group identifier (e.g. "default:steel_ingot")
---@field sound string? Equipment sound identifier (e.g. "metal", "wood", "crystal")

---Registers an armor slot element specification (e.g. "head", "torso", "legs", "feet", "shield").
---@param element string Unique element identifier string (e.g. "head", "torso", "legs", "feet", "shield")
---@param def XPlayerArmorElementDef Element configuration table defining slot mapping, groups, labels, and model pieces
function api.register_element(element, def)
	api.registered_elements[element] = def
end

---Registers an armor material specification for tiered defense and craft generation.
---@param material string Unique material key string (e.g. "wood", "steel", "diamond")
---@param def XPlayerArmorMaterialDef Material attributes table specifying tiers, stats, and crafting ingredients
function api.register_material(material, def)
	api.registered_materials[material] = def
end

---Callback invoked when a player wearing armor or holding a shield is punched.
---Receives defending player, attacking entity or player, seconds elapsed, tool capabilities table (see Luanti doc/lua_api.md: Tool Capabilities),
---attack direction vector, and raw damage points.
---@alias XPlayerArmorPunchCallback fun(player: ObjectRef, hitter?: ObjectRef, time?: number, tool_capabilities?: table, dir?: vector, damage?: number)

---3D position and rotation offsets for skeletal bone attachment.
---@class XPlayerArmorBoneOffset
---@field pos Vector3|table<string, number> 3D position offset vector relative to bone origin {x, y, z}
---@field rot Vector3|table<string, number> Euler rotation angles in degrees {x, y, z}

---Bone attachment configuration for custom 3D models.
---@class XPlayerArmorTransform
---@field bone string Target parent skeleton bone name (e.g. "Head", "Body", "Arm_Left", "Arm_Right", "Leg_Left", "Leg_Right")
---@field model string? Optional custom 3D model asset filename (.glb or .b3d) attached to this specific bone
---@field pos Vector3|table<string, number> 3D position offset vector relative to bone origin {x, y, z}
---@field rot Vector3|table<string, number> Euler rotation angles in degrees {x, y, z}
---@field scale Vector3|table<string, number>? Scale vector override {x, y, z} (default: {x=1, y=1, z=1})

---Format-specific skeletal attachment transforms for modern GLTF/GLB and legacy B3D rigs.
---@class XPlayerArmorFormatTransforms
---@field glb? table<string, XPlayerArmorTransform> Skeletal transforms for modern GLTF/GLB models keyed by piece ID
---@field b3d? table<string, XPlayerArmorTransform> Skeletal transforms for legacy B3D models keyed by piece ID

---Skeletal bone transforms map either by piece ID or format-keyed.
---@alias XPlayerArmorTransforms table<string, XPlayerArmorTransform>|XPlayerArmorFormatTransforms

---Color gradient configuration for durability wear bar. Follows Luanti item definition standard.
---@class XPlayerArmorWearColor
---@field blend? "linear"|"constant" Color gradient interpolation mode between stops (default: "linear")
---@field color_stops? table<number, string> Map of normalized wear thresholds (0.0 to 1.0) to ColorSpec (see Luanti doc/lua_api.md: Item definition)

---Forearm attachment transform offsets for off-hand shields across model formats.
---@class XPlayerArmorShieldOffset
---@field glb? XPlayerArmorBoneOffset Attachment offsets for modern GLTF/GLB player models
---@field b3d? XPlayerArmorBoneOffset Attachment offsets for legacy B3D player models
---@field pos? Vector3|table<string, number> Shared position offset fallback vector {x, y, z}
---@field rot? Vector3|table<string, number> Shared rotation angles fallback vector in degrees {x, y, z}

---Custom hit and break particle spawner options. Follows Luanti ParticleSpawner definition.
---@class XPlayerArmorParticleOpts
---@field texture? string Custom particle texture filename (see Luanti doc/lua_api.md: ParticleSpawner definition)
---@field count? number Number of particles spawned per burst
---@field size? number|table Visual particle size range
---@field glow? number Light emission level from 0 to 14

---Sound effects triggered during armor lifecycle and combat events.
---@class XPlayerArmorSounds
---@field equip string? Sound effect played when the item is equipped into an armor slot
---@field unequip string? Sound effect played when the item is unequipped from an armor slot
---@field hit string? Sound effect played when armor absorbs a combat strike
---@field break_sound string? Sound effect played when the item breaks from wear exhaustion
---@field block string? Sound effect played when an incoming attack or projectile is deflected by a shield

---Projectile combat metadata passed during projectile deflection queries.
---@class XPlayerArmorProjectileData
---@field damage? number Base projectile impact damage rating
---@field shooter? ObjectRef Source entity or player that launched the projectile
---@field name? string Technical projectile name or entity identifier
---@field gravity? number Custom projectile gravity acceleration modifier

---Configuration options for attaching or modifying a shield visual entity.
---@class XPlayerArmorShieldVisualOpts
---@field format? "glb"|"b3d" Target 3D model format
---@field pos? Vector3|table<string, number> 3D attachment position offset vector
---@field rot? Vector3|table<string, number> 3D Euler rotation angles vector in degrees
---@field pos_glb? Vector3|table<string, number> Position offset override for GLTF/GLB models
---@field rot_glb? Vector3|table<string, number> Rotation angles override for GLTF/GLB models
---@field pos_b3d? Vector3|table<string, number> Position offset override for B3D models
---@field rot_b3d? Vector3|table<string, number> Rotation angles override for B3D models
---@field visual? string Entity visual mode (e.g. "wielditem" or "mesh")
---@field visual_size? Vector3|table<string, number> Visual scaling factor override
---@field glow? number Light emission level (0 to 14)
---@field mesh? string Custom 3D mesh model asset filename
---@field textures? string[] Custom textures array override
---@field first_person? boolean Whether shield is visible in 1st person view
---@field bone? string Target skeletal attachment bone (defaults to "Arm_Left")
---@field entity_name? string Custom Lua entity name to spawn

---Complete configuration table for armor and shield item registration.
---Supports custom 3D models, bone transforms, audio, environmental perks, physics, and combat mechanics.
---@class XPlayerArmorItemDef
---@field description string Full descriptive tooltip text. Single-line descriptions are auto-enriched with a formatted stats card.
---@field short_description string? Compact item name displayed in HUD notifications, logs, and armor stand UI (defaults to description or item name)
---@field inventory_image string? Standard 2D inventory icon displayed in slot grids and hotbar
---@field preview string? 2D paperdoll layer image or fallback icon displayed in legacy inventories (defaults to inventory_image)
---@field texture string? Primary 3D UV texture (e.g. "mymod_helmet.png"). Mutually exclusive with textures (overridden if textures is set).
---@field textures string[]? Ordered array of texture filenames for multi-material custom 3D models. Overrides texture.
---@field element ("head"|"torso"|"legs"|"feet"|"shield")? Target equipment slot element. Slot exclusivity: exactly one element per item.
---@field level number? Primary defense rating. Auto-populates armor groups and fleshy damage mitigation.
---@field armor_uses number? Total durability uses before breaking (default: 200). Durability wear is applied via core.add_wear_by_uses.
---@field mesh string? Custom 3D mesh filename (.glb or .b3d). Mutually exclusive with meshes (overridden if meshes is set).
---@field meshes table<string, string>? Map of piece IDs to custom 3D model files (e.g. {torso = "tunic.glb"}). Overrides mesh.
---@field pieces string[]? Array of piece IDs to attach from element definition (e.g. {"torso"}). Ignored if custom meshes is used.
---@field transforms XPlayerArmorTransforms? Skeletal bone attachment transforms keyed by piece ID or model format ("glb"|"b3d")
---@field glow number? Light emission level from 0 to 14 (ideal for enchanted, crystalline, or glowing gear). Ignored if custom 3D mesh is not used.
---@field visual_size Vector3|table<string, number>? Visual scale factor override for custom 3D models. Ignored if custom 3D mesh is not used.
---@field backface_culling boolean? Whether backface culling is enabled on the model entity (default: true). Ignored if custom 3D mesh is not used.
---@field shaded boolean? Whether diffuse shading and lighting is enabled on the model entity (default: true). Ignored if custom 3D mesh is not used.
---@field sounds XPlayerArmorSounds? Custom sound effects table for equip, unequip, hit, break, and block events
---@field heal number? Passive health regeneration boost level (sets groups.armor_heal)
---@field fire number? Fire, heat, and lava damage protection tier threshold from 1 to 5 (sets groups.armor_fire)
---@field water number? Underwater breathing and drowning immunity level (sets groups.armor_water)
---@field feather number? Fall damage mitigation level (sets groups.armor_feather)
---@field speed number? Locomotion movement speed multiplier modifier applied via player physics monoid (sets groups.physics_speed)
---@field jump number? Jump height multiplier modifier applied via player physics monoid (sets groups.physics_jump)
---@field gravity number? Gravity multiplier modifier applied via player physics monoid (sets groups.physics_gravity)
---@field material string? Material category key (e.g. "wood", "steel", "diamond", "nether"). Sets groups.armor_material_<material>.
---@field reciprocate_damage boolean|number? Whether damage is reflected back to attacker (thorns). Defaults true for shields, false for armor.
---@field reciprocate_percent number? Percentage of incoming damage reflected to attacker. Ignored if reciprocate_damage is false or nil.
---@field wear_color XPlayerArmorWearColor? Durability bar color gradient configuration (see Luanti doc/lua_api.md: Item definition)
---@field shield_offset XPlayerArmorShieldOffset? Custom shield forearm attachment transforms for glb and b3d skeletons. Ignored if element is not "shield".
---@field tower_shield boolean? Whether shield renders with tower shield model variant in preview and stand. Ignored if element is not "shield".
---@field block_reduction number? Frontal damage reduction fraction 0.0 to 1.0 (default: 0.20 or tiered). Ignored if element is not "shield".
---@field block_arc number? Custom frontal blocking arc angle in degrees (default: 44-64 deg tiered). Ignored if element is not "shield".
---@field deflect_projectiles boolean? Whether shield can physically deflect incoming arrows and projectiles. Ignored if element is not "shield".
---@field particles (boolean|XPlayerArmorParticleOpts)? Custom hit and break particle spawner options, or false to disable (see Luanti doc/lua_api.md)
---@field groups table<string, number>? Item groups map. Automatically augmented with armor, perk, and material groups.
---@field armor_groups table<string, number>? Damage mitigation group ratings (e.g. {fleshy = 15})
---@field damage_groups table<string, number>? Tool durability degradation wear ratings against damage groups
---@field on_equip fun(player: ObjectRef, index: number, stack: ItemStack)? Callback invoked when equipped into armor inventory
---@field on_unequip fun(player: ObjectRef, index: number, stack: ItemStack)? Callback invoked when unequipped from armor inventory
---@field on_damage fun(player: ObjectRef, index: number, stack: ItemStack, uses: number)? Callback invoked when absorbing combat damage
---@field on_destroy fun(player: ObjectRef, index: number, stack: ItemStack)? Callback invoked when this item breaks due to wear exhaustion
---@field on_punch XPlayerArmorPunchCallback? Callback invoked when a player wearing this armor piece is punched
---@field on_block fun(player: ObjectRef, hitter: ObjectRef?, damage: number, shield_stack: ItemStack)? Block callback. Shield-only.

---Resolves the modern x_player_armor item technical name if the given name is a legacy item.
---@param name string Technical item name (e.g. "3d_armor:helmet_diamond" or ":3d_armor:helmet_diamond")
---@return string|nil modern_name Replacement modern technical name, or nil if not superseded
function api.get_legacy_replacement(name)
	if not name or type(name) ~= "string" then return nil end
	local clean_name = name:gsub("^:", "")
	if api.legacy_replacements and api.legacy_replacements[clean_name] then
		return api.legacy_replacements[clean_name]
	end
	-- Pattern fallback for standard 3d_armor pieces: 3d_armor:<piece>_<material>
	local piece, mat = clean_name:match("^3d_armor:(%w+)_(%w+)$")
	if piece and mat then
		local candidate = "x_player_armor:" .. piece .. "_" .. mat
		if api.registered_armors and api.registered_armors[candidate] then
			return candidate
		end
	end
	-- Pattern fallback for standard shields: shields:shield_<material>
	local s_mat = clean_name:match("^shields:shield_(%w+)$")
	if s_mat then
		local candidate = "x_player_armor:shield_" .. s_mat
		if api.registered_armors and api.registered_armors[candidate] then
			return candidate
		end
	end
	-- Pattern fallback for enhanced shields: shields:shield_enhanced_<material>
	local es_mat = clean_name:match("^shields:shield_enhanced_(%w+)$")
	if es_mat then
		local candidate = "x_player_armor:shield_enhanced_" .. es_mat
		if api.registered_armors and api.registered_armors[candidate] then
			return candidate
		end
	end
	return nil
end

---Retrieves the armor definition table for a registered armor item.
---Checks internal registered_armors first, falling back to core.registered_tools or core.registered_items.
---@param item_name string Technical item name
---@return XPlayerArmorItemDef? def Registered armor item definition or nil
function api.get_armor_def(item_name)
	if not item_name or item_name == "" then return nil end
	local resolved = core.registered_aliases[item_name] or item_name
	return api.registered_armors[resolved]
		or core.registered_tools[resolved]
		or core.registered_items[resolved]
end

---Registers an armor item definition with full support for custom 3D models,
---skeletal bone attachments, sound effects, environmental perks, physics, and legacy 3d_armor compatibility.
---@param name string Technical item name (e.g. "mymod:helmet_crystal")
---@param def XPlayerArmorItemDef Configuration definition table
function api.register_armor(name, def)
	def = table.copy(def or {})
	setmetatable(def, nil)
	if name:sub(1, 1) == ":" then
		name = name:sub(2)
	end

	-- Intercept registration of superseded legacy armor and cleanup duplicate
	local replacement = api.get_legacy_replacement(name)
	if replacement then
		local ov = rawget(api, "override") or (api.compat and api.compat.override)
		if ov and ov.cleanup_legacy_item then
			ov.cleanup_legacy_item(name, replacement)
		else
			local force_alias = x_player_armor.force_alias or (api.utils and api.utils.force_alias)
			if force_alias then
				force_alias(name, replacement)
			else
				core.register_alias_force(name, replacement)
			end
		end
		return
	end

	def.groups = def.groups or {}
	local constants = x_player_armor.constants or {}
	local element_groups = constants.ELEMENT_GROUPS or {
		head = "armor_head",
		torso = "armor_torso",
		legs = "armor_legs",
		feet = "armor_feet",
		shield = "armor_shield",
	}

	-- Resolve target armor slot element
	local element = def.element
	if not element then
		for el, grp in pairs(element_groups) do
			if (def.groups[grp] or 0) > 0 or (def[grp] and def[grp] > 0) then
				element = el
				break
			end
		end
		if not element and ((def.groups.shield or 0) > 0 or def.shield or def.tower_shield or def.tower) then
			element = "shield"
		end
		def.element = element
	end

	-- Resolve defense level rating
	local level = def.level
	if not level and element then
		local grp_name = element_groups[element]
		level = grp_name and (def.groups[grp_name] or def[grp_name])
	end
	if not level and def.armor_groups and def.armor_groups.fleshy then
		level = def.armor_groups.fleshy
	end
	level = level or 1
	def.level = level

	if element then
		local grp_name = element_groups[element]
		if grp_name then
			def.groups[grp_name] = def.groups[grp_name] or def[grp_name] or level
		end
	end

	-- Normalize durability uses
	def.groups.armor_uses = def.groups.armor_uses or def.groups.armor_use or def.armor_use or def.armor_uses or def.uses or 200

	-- Normalize shield groups and flags
	if (def.groups.armor_shield and def.groups.armor_shield > 0) or def.element == "shield" then
		def.groups.shield = def.groups.shield or 1
	end
	if def.tower_shield or def.tower or (def.groups.armor_shield_tower and def.groups.armor_shield_tower > 0)
			or (def.groups.armor_tower_shield and def.groups.armor_tower_shield > 0) then
		def.groups.armor_shield_tower = 1
		def.tower_shield = true
	end

	-- Normalize combat damage mitigation groups (e.g. fleshy)
	def.armor_groups = def.armor_groups or {}
	if not def.armor_groups.fleshy and level then
		def.armor_groups.fleshy = level
	end
	def.damage_groups = def.damage_groups or {cracky = 2, snappy = 3, choppy = 2, crumbly = 1, level = 1}

	-- Normalize environmental protection attributes (groups and legacy top-level fallbacks)
	local heal = def.groups.armor_heal or def.armor_heal or def.heal
	if heal and heal > 0 then
		def.groups.armor_heal = heal
		def.heal = heal
	end

	local fire = def.groups.armor_fire or def.armor_fire or def.fire
	if fire and fire > 0 then
		def.groups.armor_fire = fire
		def.fire = fire
	end

	local water = def.groups.armor_water or def.armor_water or def.water
	if water and water > 0 then
		def.groups.armor_water = water
		def.water = water
	end

	local feather = def.groups.armor_feather or def.armor_feather or def.feather
	if feather and feather > 0 then
		def.groups.armor_feather = feather
		def.feather = feather
	end

	local material = def.material or def.armor_material
	if material and material ~= "" then
		def.groups["armor_material_" .. material] = 1
		def.material = material
	end

	-- Normalize player physics modifiers (speed, jump, gravity)
	local speed = def.groups.physics_speed or def.physics_speed or def.speed
	if speed then
		def.groups.physics_speed = speed
		def.speed = speed
	end

	local jump = def.groups.physics_jump or def.physics_jump or def.jump
	if jump then
		def.groups.physics_jump = jump
		def.jump = jump
	end

	local gravity = def.groups.physics_gravity or def.physics_gravity or def.gravity
	if gravity then
		def.groups.physics_gravity = gravity
		def.gravity = gravity
	end

	-- Normalize damage reciprocation (thorns)
	if def.reciprocate_damage == nil then
		if def.thorns ~= nil then
			def.reciprocate_damage = (def.thorns == true or (type(def.thorns) == "number" and def.thorns > 0))
		elseif def.element == "shield" then
			def.reciprocate_damage = true
		else
			def.reciprocate_damage = false
		end
	end

	-- Normalize textures and preview
	if def.texture and type(def.texture) == "string" and def.texture ~= "" and not def.texture:match("%.%w+$") then
		def.texture = def.texture .. ".png"
	end
	if not def.texture or def.texture == "" then
		def.texture = name:gsub(":", "_") .. ".png"
	end
	if def.preview and type(def.preview) == "string" and def.preview ~= "" and not def.preview:match("%.%w+$") then
		def.preview = def.preview .. ".png"
	end
	if not def.preview and def.inventory_image then
		def.preview = def.inventory_image
	end

	-- Normalize custom 3D model meshes and transforms
	def.model = def.model or def.mesh
	def.mesh = def.mesh or def.model
	def.models = def.models or def.meshes
	def.meshes = def.meshes or def.models
	def.transforms = def.transforms or def.attach_transforms
	def.attach_transforms = def.attach_transforms or def.transforms
	def.shield_offset = def.shield_offset or def.shield_transform
	def.shield_transform = def.shield_transform or def.shield_offset

	-- Normalize sound effects
	if type(def.sounds) ~= "table" then
		def.sounds = {}
	end
	def.sounds.equip = def.sounds.equip or def.sound_equip
	def.sounds.unequip = def.sounds.unequip or def.sound_unequip
	def.sounds.hit = def.sounds.hit or def.sound_hit
	def.sounds.break_sound = def.sounds.break_sound or def.sounds.destroy or def.sounds["break"] or def.sound_break or def.sound_destroy
	def.sounds.block = def.sounds.block or def.sound_block

	-- Auto-attach on_secondary_use and on_place for seamless right-click equipping
	if not def.on_secondary_use then
		def.on_secondary_use = function(itemstack, user, _pointed_thing)
			if user and user:is_player() then
				api.equip(user, itemstack)
			end
			return itemstack
		end
	end

	if not def.on_place then
		def.on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing and pointed_thing.type == "node" then
				local node = core.get_node(pointed_thing.under)
				local ndef = core.registered_nodes[node.name]
				if ndef and ndef.on_rightclick and not (placer and placer:get_player_control().sneak) then
					return ndef.on_rightclick(pointed_thing.under, node, placer, itemstack, pointed_thing)
				end
			end
			if placer and placer:is_player() then
				api.equip(placer, itemstack)
			end
			return itemstack
		end
	end

	-- Ensure short_description is set for clean UI and chat notifications
	if not def.short_description then
		def.short_description = def.description or name
	end

	-- Auto-enrich single-line description with modern structured tooltip if not already formatted
	if def.description and not def.description:find("\n") then
		local enriched = api.utils.format_armor_tooltip_from_def(name, def)
		if enriched then
			def.description = enriched
		end
	end

	api.registered_armors[name] = def
	if core.registered_items[name] then
		local redef = table.copy(def)
		redef.name = nil
		redef.type = nil
		core.override_item(name, redef)
	else
		core.register_tool(":" .. name, def)
	end
end

---Returns a map of armor elements currently worn by the player.
---@nodiscard
---@param player ObjectRef Target player
---@return table<string, boolean> worn_elements Map of worn element names to true (e.g. {head = true, torso = true})
function api.get_worn_elements(player)
	local name, inv = api.get_valid_player(player)
	if not name or not inv then return {} end
	local worn = {}
	local list = inv:get_list("armor")
	if not list then return worn end
	local elements = api.get_elements()
	for i = 1, #list do
		local stack = list[i]
		if stack and not stack:is_empty() then
			local iname = stack:get_name()
			for _, el in ipairs(elements) do
				if core.get_item_group(iname, "armor_" .. el) > 0
						or (el == "shield" and core.get_item_group(iname, "shield") > 0) then
					worn[el] = true
					break
				end
			end
		end
	end
	return worn
end

api.get_weared_armor_elements = api.get_worn_elements

---Unequips all armor items from the player's equipped inventory.
---@param player ObjectRef Target player to remove all equipped armor from
function api.remove_all(player)
	local name, inv = api.get_valid_player(player)
	if not name or not inv then return end
	for i = 1, 6 do
		inv:set_stack("armor", i, ItemStack(""))
	end
	api.inventory.save_inventory(player, inv)
	api.set_player_armor(player)
	api.update_player_visuals(player)
	api.run_callbacks("on_update", player)
	api.refresh_player_formspec(player)
end

---Registers an armor group baseline.
---@param group string Armor group name (e.g. "fleshy")
---@param base number Baseline value (default: 100)
function api.register_armor_group(group, base)
	api.registered_groups[group] = base
end

---Gets the shield attachment transform for a given model format ("glb" or "b3d").
---@nodiscard
---@param format? string Model format ("glb" or "b3d", defaults to "glb")
---@return XPlayerArmorBoneOffset offset Offset table containing pos and rot vectors for forearm shield attachment
function api.get_shield_offset(format)
	local fmt = format or "glb"
	local consts = x_player_armor.constants
	local tbl = consts.SHIELD_OFFSET and consts.SHIELD_OFFSET[fmt]
	if not tbl and consts.SHIELD_OFFSET then
		tbl = consts.SHIELD_OFFSET.glb
	end
	return tbl or {pos = {x = -0.8, y = 5.0, z = -2.8}, rot = {x = 180, y = 45, z = 0}}
end

---Sets or overrides the shield attachment transform for a model format.
---@param format string Model format ("glb" or "b3d")
---@param pos Vector3 Offset position vector
---@param rot Vector3 Euler rotation angles in degrees
function api.set_shield_offset(format, pos, rot)
	local consts = x_player_armor.constants
	if not consts.SHIELD_OFFSET then
		consts.SHIELD_OFFSET = {}
	end
	if not consts.SHIELD_OFFSET[format] then
		consts.SHIELD_OFFSET[format] = {}
	end
	if pos then
		consts.SHIELD_OFFSET[format].pos = {x = pos.x or 0, y = pos.y or 0, z = pos.z or 0}
	end
	if rot then
		consts.SHIELD_OFFSET[format].rot = {x = rot.x or 0, y = rot.y or 0, z = rot.z or 0}
	end
end

---Runtime state definition cache for an active player.
---@class XPlayerArmorPlayerDef
---@field state number Bitmask or numeric state flag of worn armor
---@field count number Number of equipped armor pieces
---@field level number Total aggregated defense level rating across all worn gear
---@field heal number Total health regeneration boost rating
---@field jump number Aggregated jump height multiplier modifier
---@field speed number Aggregated movement speed multiplier modifier
---@field gravity number Aggregated gravity multiplier modifier
---@field fire number Maximum fire/lava protection tier rating
---@field water number Total water breathing/drowning protection level
---@field feather number Total fall damage mitigation level
---@field has_shield boolean Whether a shield is currently equipped
---@field has_reciprocate boolean Whether damage reciprocation (thorns) is active
---@field groups table<string, number> Active defense ratings map against damage groups
---@field textures string[] Array of resolved texture strings for player mesh
---@field skin string Base skin texture filename

---Returns the active armor definition cache for a player.
---@nodiscard
---@param player ObjectRef Target player
---@return XPlayerArmorPlayerDef state Active player armor runtime state table (stats, groups, levels)
function api.get_player_def(player)
	local name = player:get_player_name()
	local pdef = rawget(api.def, name)
	if not pdef then
		pdef = {
			state = 0,
			count = 0,
			level = 0,
			heal = 0,
			jump = 1.0,
			speed = 1.0,
			gravity = 1.0,
			fire = 0,
			water = 0,
			feather = 0,
			has_shield = false,
			has_reciprocate = false,
			groups = api.utils.copy_table(api.registered_groups),
			textures = {},
			skin = "x_player_armor_character.png",
		}
		rawset(api.def, name, pdef)
	end
	return pdef
end

---Returns the detached armor inventory and player name if valid.
---@nodiscard
---@param player ObjectRef Target player
---@return string? name, InvRef? inv Validated player name and detached armor inventory reference, or nil, nil
function api.get_valid_player(player)
	if not player or not player:is_player() then
		return nil, nil
	end
	local name = player:get_player_name()
	local inv = core.get_inventory({type = "detached", name = name .. "_armor"})
	return name, inv
end

---Equips an armor item into the appropriate slot.
---@param player ObjectRef Target player
---@param itemstack ItemStack Armor item to equip
---@return boolean success True if the item was equipped into a valid slot
function api.equip(player, itemstack)
	return api.inventory.equip_item(player, itemstack)
end

---Unequips an armor item by slot element.
---@param player ObjectRef Target player
---@param element string Slot element to unequip ("head", "torso", "legs", "feet", "shield")
---@return ItemStack unequipped_stack The removed item stack
function api.unequip(player, element)
	return api.inventory.unequip_element(player, element)
end

---Applies durability damage to a worn armor item.
---@param player ObjectRef Target player
---@param index number Slot index in armor inventory (1-6)
---@param stack ItemStack Current armor item stack
---@param uses number Durability wear amount to apply
---@return boolean destroyed True if the armor item broke from wear exhaustion
function api.damage(player, index, stack, uses)
	return api.combat.damage_item(player, index, stack, uses)
end

---Calculates armor mitigation and wear on punch.
---@param player ObjectRef Defending player taking the punch
---@param hitter ObjectRef? Attacking entity or player
---@param time_from_last_punch number? Seconds elapsed since previous punch
---@param tool_capabilities table? Tool capabilities table of the punch (see Luanti doc/lua_api.md: Tool Capabilities)
---@param dir vector? Direction vector of the incoming attack
---@param damage number? Raw damage points before armor mitigation
function api.punch(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	api.combat.handle_punch(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
end


---Re-evaluates armor stats, groups, and physics for a player.
---@param player ObjectRef Target player to recalculate armor groups, physics, and stats for
function api.set_player_armor(player)
	api.effects.update_player_armor(player)
end

---Updates modular bone attachments and visual entity state for a player.
---@param player ObjectRef Target player to update modular 3D armor visual attachments on
function api.update_player_visuals(player)
	api.visuals.update_player_visuals(player)
end

---Clears all modular visual entities for a player.
---@param player ObjectRef|string Player object or player name whose attached visuals should be cleared
function api.clear_player_visuals(player)
	api.visuals.clear_all(player)
end

---Restores modular armor visual entities for all connected players.
function api.restore_all_player_visuals()
	api.visuals.restore_all_players()
end

---Schedules debounced restoration for a specific player's visual armor pieces.
---@param player_name string Name of the player to schedule visual restoration for
function api.schedule_player_visual_restore(player_name)
	api.visuals.schedule_player_restore(player_name)
end

---Attaches modular armor visual entities to an arbitrary parent entity (such as a deathstats corpse).
---@param parent ObjectRef The entity to attach armor to
---@param player_or_name ObjectRef|string|(string|ItemStack)[] Player object, player name, or explicit armor item list
---@param format string? Model format ("glb" or "b3d")
---@return ObjectRef[] entities List of spawned armor visual entities
function api.attach_armor_to_entity(parent, player_or_name, format)
	return api.visuals.attach_armor_to_entity(parent, player_or_name, format)
end

---Returns the composite preview texture string for 3D model formspecs.
---@nodiscard
---@param player ObjectRef Target player
---@return string preview_texture Composite preview texture string for 3D model formspecs
function api.get_player_preview_texture(player)
	return api.ui.get_preview_texture(player)
end

---Opens the armor and equipment inventory formspec for a player.
---@param player ObjectRef Target player to open the armor formspec for
function api.show_armor_formspec(player)
	api.ui.show_armor_formspec(player)
end

---Refreshes open armor formspecs for a player across active inventory engines.
---@param player ObjectRef Target player whose open armor formspec should be refreshed
function api.refresh_player_formspec(player)
	api.ui.refresh_player_formspec(player)
end

---Displays or updates the 2D shield block HUD indicator on the target player.
---@param player ObjectRef Target player
---@param immediate? boolean|number If true or 0, renders immediately without debounce delay
---@return number? hud_id Active HUD element ID if shown immediately, or nil if debounced
function api.show_shield_block_hud(player, immediate)
	return api.shield_hud.show(player, immediate)
end

---Hides the 2D shield block HUD indicator from the target player.
---@param player ObjectRef
function api.hide_shield_block_hud(player)
	api.shield_hud.hide(player)
end

---Retrieves the active shield block HUD element ID for a player if one exists.
---@param player ObjectRef
---@return number? hud_id
function api.get_shield_block_hud(player)
	if not player or not player:is_player() then return nil end
	return api.shield_hud.active_huds[player:get_player_name()]
end

---Evaluates whether a player is capable of blocking with an equipped shield.
---@nodiscard
---@param player ObjectRef Target player
---@return boolean can_block
function api.can_block(player)
	return api.combat.can_block(player)
end

---Checks whether a player is actively holding a shield block stance.
---@param player ObjectRef Target player
---@return boolean is_blocking, ItemStack? shield_stack, number? slot_idx, string? mat_key
function api.is_blocking(player)
	return api.combat.is_blocking(player)
end

---Validates whether an incoming attack or projectile vector falls within the player's frontal blocking cone.
---@nodiscard
---@param player ObjectRef Target player
---@param attack_dir vector Direction pointing from the attacker/projectile towards the player
---@param max_arc_deg number? Maximum blocking arc in degrees (default: 52 + tier bonus)
---@param bias_deg number? Custom lateral bias angle in degrees (default: 22 deg off-hand bias)
---@return boolean is_facing True if the attack angle falls within the player's frontal shield arc
function api.is_facing_attack(player, attack_dir, max_arc_deg, bias_deg)
	return api.combat.is_facing_attack(player, attack_dir, max_arc_deg, bias_deg)
end

---Attempts to deflect an incoming projectile with the player's active shield.
---Simulates realistic reflection physics, energy restitution, glancing drag, and orientation.
---@param player ObjectRef Defending player
---@param proj_obj ObjectRef Incoming projectile entity
---@param hit_pos vector Impact position
---@param flight_dir vector? Incoming normalized flight direction
---@param proj_data? XPlayerArmorProjectileData Optional projectile combat metadata
---@return boolean deflected True if the projectile was successfully deflected
---@return vector? bounce_velocity Deflected projectile velocity vector
function api.try_deflect_projectile(player, proj_obj, hit_pos, flight_dir, proj_data)
	return api.combat.try_deflect_projectile(player, proj_obj, hit_pos, flight_dir, proj_data)
end

---Displays or updates the combat armor HUD overlay on the target player.
---@param player ObjectRef Target player to display the combat HUD on
---@return number? hud_id Active combat HUD element ID, or nil
function api.trigger_combat_hud(player)
	if not api.combat_hud then return nil end
	return api.combat_hud.trigger(player)
end

---Hides the combat armor HUD overlay from the target player.
---@param player ObjectRef|string Target player or player name
function api.hide_combat_hud(player)
	if not api.combat_hud then return end
	api.combat_hud.hide(player)
end

---Retrieves the active combat armor HUD element ID for a player if one exists.
---@nodiscard
---@param player ObjectRef Target player
---@return number? hud_id Active combat HUD element ID, or nil if not active
function api.get_combat_hud_id(player)
	if not player or not player:is_player() or not api.combat_hud then return nil end
	local state = api.combat_hud.active_players[player:get_player_name()]
	return state and state.hud_id or nil
end

---Attaches an off-hand shield entity to a player's left forearm or a target entity (such as a corpse).
---@param player_or_parent ObjectRef Target player or parent entity
---@param item_or_stack string|ItemStack Shield item name or stack
---@param format_or_opts? string|XPlayerArmorShieldVisualOpts Optional model format ("glb"|"b3d") or options table
---@param custom_opts? XPlayerArmorShieldVisualOpts Optional transform and visual overrides
---@return ObjectRef? entity Attached entity reference or nil on failure
function api.attach_shield(player_or_parent, item_or_stack, format_or_opts, custom_opts)
	if not player_or_parent or (player_or_parent.is_valid and not player_or_parent:is_valid()) then
		return nil
	end
	if player_or_parent.is_player and player_or_parent:is_player() then
		local opts = (type(format_or_opts) == "table" and format_or_opts) or custom_opts
		return api.compat_x_player_api.attach_shield(player_or_parent, item_or_stack, opts)
	end
	local fmt = (type(format_or_opts) == "string" and format_or_opts)
		or (type(format_or_opts) == "table" and format_or_opts.format)
		or (custom_opts and custom_opts.format)
	local opts = (type(format_or_opts) == "table" and format_or_opts) or custom_opts
	return api.visuals.attach_shield_to_entity(player_or_parent, item_or_stack, fmt, opts)
end

---Attaches a shield visual entity to a target parent entity (such as a corpse or mob) with proper forearm transforms.
---@param parent ObjectRef The entity to attach the shield to
---@param item_or_stack string|ItemStack Shield item name or stack
---@param format string? Model format ("glb" or "b3d")
---@param custom_opts? XPlayerArmorShieldVisualOpts Optional custom overrides
---@return ObjectRef? entity The attached shield entity or nil
function api.attach_shield_to_entity(parent, item_or_stack, format, custom_opts)
	return api.visuals.attach_shield_to_entity(parent, item_or_stack, format, custom_opts)
end

---Updates or modifies an attached off-hand shield entity via x_player_api.
---@param player ObjectRef Target player
---@param item_or_stack? string|ItemStack Shield item name or stack
---@param custom_opts? XPlayerArmorShieldVisualOpts Optional transform and visual overrides
---@return ObjectRef? entity Updated shield entity reference or nil
function api.update_shield(player, item_or_stack, custom_opts)
	return api.compat_x_player_api.update_shield(player, item_or_stack, custom_opts)
end

---Removes an attached off-hand shield entity from a player via x_player_api.
---@param player ObjectRef Target player to remove shield from
function api.remove_shield(player)
	api.compat_x_player_api.remove_shield(player)
end

---Sets whether an off-hand shield is visible in 1st person view via x_player_api.
---@param player ObjectRef Target player
---@param enable boolean Whether 1st person view is enabled
function api.set_shield_first_person(player, enable)
	api.compat_x_player_api.set_shield_first_person(player, enable)
end

---Gets whether an off-hand shield is visible in 1st person view via x_player_api.
---@nodiscard
---@param player ObjectRef Target player
---@return boolean enabled Whether 1st person shield visibility is active
function api.get_shield_first_person(player)
	return api.compat_x_player_api.get_shield_first_person(player)
end

---Resolves the equipped shield ItemStack, slot index, and material key for a player.
---Shields must be equipped in the armor inventory (slot 5 or auxiliary slot 6).
---Used by dependent combat and corpse mods (such as deathstats, x_bows, and x_mob_core).
---@nodiscard
---@param player ObjectRef Target player
---@return ItemStack? shield_stack Active equipped shield ItemStack or nil
---@return number? slot_idx Armor inventory slot index (5 or 6) or nil
---@return string? mat_key Material identifier string (e.g. "steel", "diamond") or nil
function api.get_equipped_shield(player)
	return api.combat.get_equipped_shield(player)
end

---Calculates the 3D world origin position of the shield contact surface (Tier 1 deflection origin).
---Biased to the lower-left viewport where the off-hand shield is actively held in guard stance.
---@nodiscard
---@param player ObjectRef Target player
---@return vector shield_pos 3D world coordinate of shield surface
function api.get_shield_contact_pos(player)
	return api.combat.get_shield_contact_pos(player)
end

---Checks whether a specific player is currently viewing an armor equipment interface.
---@nodiscard
---@param player ObjectRef Target player
---@return boolean is_open True if armor UI is open for player
function api.is_armor_ui_open(player)
	return api.ui.is_armor_ui_open(player)
end

---Checks whether any connected player has an active armor inventory interface open.
---Optimizes multiplayer performance by idle-skipping background updates when no UI is open.
---@nodiscard
---@return boolean has_any True if any player has armor UI open
function api.has_any_open_armor_ui()
	return api.ui.has_any_open_armor_ui()
end

---Cleans up any orphaned or detached x_player_armor:visual entities near connected players.
---@return number count Number of cleaned up entities
function api.cleanup_orphaned_visuals()
	return api.visuals.cleanup_orphaned_visuals()
end

---Resolves the player's active skin and produces the canonical dual-slot texture pair.
---@nodiscard
---@param player ObjectRef Target player
---@return SkinResolution resolution
function api.resolve_player_skin(player)
	return api.skins.resolve_player_skin(player)
end

---Retrieves skin information for a player.
---@nodiscard
---@param player ObjectRef Target player
---@return SkinResolution resolution
function api.get_skin_info(player)
	return api.skins.get_skin_info(player)
end

return api

