---Core game constants, configuration defaults, and calibration properties for armor and shields.
---@class XPlayerArmorConstants
---@field SLOT_ELEMENTS table<number, string> Numeric slot index (1-5) to element name mapping
---@field ELEMENT_GROUPS table<string, string> Element name to armor group name mapping (e.g. head -> armor_head)
---@field GROUP_ELEMENTS table<string, string> Armor group name to element name inverted mapping
---@field SLOT_LABELS table<string, string> Human-readable localized slot display names
---@field MODELS table<string, string> Default 3D model asset filenames for armor pieces, preview, and stand
---@field PREVIEW_SLOTS table<string, number> 3D model formspec bone/attachment slot indices
---@field BONES table<string, string> Target skeletal bone names for player model attachment
---@field ELEMENT_PIECES table<string, string[]> Element to constituent 3D piece IDs mapping
---@field ATTACH_TRANSFORMS table<string, table<string, XPlayerArmorTransform>> Skeletal attachment transforms for GLB and B3D rigs
---@field SOUNDS table<string, string> Built-in sound effect identifiers
---@field FIRE_NODES table<string, number> Hazard node protection thresholds (1 to 5) for fire and lava mitigation
---@field LEVEL_MULTIPLIER number Global damage mitigation scaling multiplier (setting: x_player_armor_level_multiplier)
---@field HEAL_MULTIPLIER number Global health regeneration multiplier (setting: x_player_armor_heal_multiplier)
---@field SET_BONUS boolean Whether full-set defense bonus is enabled (setting: x_player_armor_set_bonus)
---@field FIRE_PROTECT boolean Whether fire and lava protection is active (setting: x_player_armor_fire_protect)
---@field FIRE_PROTECT_TORCH boolean Whether torches deal damage requiring protection (setting: x_player_armor_fire_protect_torch)
---@field WATER_PROTECT boolean Whether underwater drowning protection is active (setting: x_player_armor_water_protect)
---@field FEATHER_FALL boolean Whether fall damage feather mitigation is active (setting: x_player_armor_feather_fall)
---@field ENABLE_SOUNDS boolean Whether equipment and combat audio effects are enabled (setting: x_player_armor_enable_sounds)
---@field DROP_ON_DEATH boolean Whether armor drops on player death (setting: x_player_armor_drop_on_death)
---@field DESTROY_ON_DEATH boolean Whether armor is permanently destroyed on player death (setting: x_player_armor_destroy_on_death)
---@field COMBAT_HUD_ENABLE boolean Whether in-combat armor status HUD is enabled (setting: x_player_armor_combat_hud)
---@field COMBAT_HUD_TIMEOUT number Combat HUD display timeout in seconds (setting: x_player_armor_combat_hud_timeout)
---@field COMBAT_HUD_POSITION string Combat HUD screen alignment ("bottom_right", "bottom_left", etc.)
---@field COMBAT_HUD_SCALE number Combat HUD scaling factor (setting: x_player_armor_combat_hud_scale)
---@field SHIELD_HUD_ENABLE boolean Whether 1st-person shield blocking HUD indicator is enabled
---@field SHIELD_HUD_DELAY number Delay in seconds before 1st-person shield HUD appears
---@field BLOCK_CONE_ANGLE number Half-width of default frontal blocking cone in degrees (52°)
---@field BLOCK_ASYMMETRIC_BIAS number Off-hand angular bias towards left guard in degrees (22°)
---@field BLOCK_DEFAULT_REDUCTION number Default frontal damage reduction fraction (0.20 = 20%)
---@field BLOCK_DEFLECT_PROJECTILES boolean Global flag enabling physical projectile deflection
---@field BLOCK_RESTITUTION number Projectile rebound velocity restitution fraction (0.50 = 50% velocity retained)
---@field BLOCK_RECOIL_IMPULSE number Physics pushback impulse magnitude applied to attacker on shield block
---@field SHIELD_TIER_PROPERTIES table<string, table<string, number>> Material-tiered defense, restitution, and blocking arc ratings
---@field SHIELD_OFFSET table<string, table<string, table<string, number>>> Forearm attachment position and rotation offsets for GLB and B3D skeletons
local constants = {}

local S = core.get_translator("x_player_armor")

constants.SLOT_ELEMENTS = {
	[1] = "head",
	[2] = "torso",
	[3] = "legs",
	[4] = "feet",
	[5] = "shield",
}

constants.ELEMENT_GROUPS = {
	head = "armor_head",
	torso = "armor_torso",
	legs = "armor_legs",
	feet = "armor_feet",
	shield = "armor_shield",
}

-- Inverted mapping derived programmatically from ELEMENT_GROUPS
constants.GROUP_ELEMENTS = {}
for element, group in pairs(constants.ELEMENT_GROUPS) do
	constants.GROUP_ELEMENTS[group] = element
end

constants.SLOT_LABELS = {
	head = S("Helmet"),
	torso = S("Chestplate"),
	legs = S("Leggings"),
	feet = S("Boots"),
	shield = S("Shield"),
	wield = S("Weapon"),
}

constants.MODELS = {
	head = "x_player_armor_helmet.glb",
	torso = "x_player_armor_chestplate.glb",
	sleeve_l = "x_player_armor_sleeve_l.glb",
	sleeve_r = "x_player_armor_sleeve_r.glb",
	legs_l = "x_player_armor_leggings_l.glb",
	legs_r = "x_player_armor_leggings_r.glb",
	feet_l = "x_player_armor_boot_l.glb",
	feet_r = "x_player_armor_boot_r.glb",
	shield = "x_player_armor_shield.glb",
	preview = "x_player_armor_preview.glb",
	stand = "x_player_armor_stand.glb",
	stand_entity = "x_player_armor_preview.glb",
}

constants.PREVIEW_SLOTS = {
	body = 0,
	body10 = 0,
	body18 = 1,
	head = 2,
	torso = 3,
	legs = 4,
	feet = 5,
	shield = 6,
	shield_tower = 7,
	wield = 8,
}

constants.BONES = {
	head = "Head",
	body = "Body",
	arm_l = "Arm_Left",
	arm_r = "Arm_Right",
	leg_l = "Leg_Left",
	leg_r = "Leg_Right",
}

constants.ELEMENT_PIECES = {
	head = {"head"},
	torso = {"torso", "sleeve_l", "sleeve_r"},
	legs = {"legs_l", "legs_r"},
	feet = {"feet_l", "feet_r"},
}

constants.ATTACH_TRANSFORMS = {
	glb = {
		head = {bone = "Head", model = constants.MODELS.head, pos = {x = 0, y = 0, z = 0}, rot = {x = 0, y = 0, z = 0}},
		torso = {bone = "Body", model = constants.MODELS.torso, pos = {x = 0, y = 0, z = 0}, rot = {x = 0, y = 0, z = 0}},
		sleeve_l = {bone = "Arm_Left", model = constants.MODELS.sleeve_l, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 0, z = 0}},
		sleeve_r = {bone = "Arm_Right", model = constants.MODELS.sleeve_r, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 0, z = 0}},
		legs_l = {bone = "Leg_Left", model = constants.MODELS.legs_l, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 0, z = 0}},
		legs_r = {bone = "Leg_Right", model = constants.MODELS.legs_r, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 0, z = 0}},
		feet_l = {bone = "Leg_Left", model = constants.MODELS.feet_l, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 0, z = 0}},
		feet_r = {bone = "Leg_Right", model = constants.MODELS.feet_r, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 0, z = 0}},
	},
	b3d = {
		head = {bone = "Head", model = constants.MODELS.head, pos = {x = 0, y = 0, z = 0}, rot = {x = 0, y = 180, z = 0}},
		torso = {bone = "Body", model = constants.MODELS.torso, pos = {x = 0, y = 0, z = 0}, rot = {x = 0, y = 180, z = 0}},
		sleeve_l = {bone = "Arm_Left", model = constants.MODELS.sleeve_l, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 180, z = 0}},
		sleeve_r = {bone = "Arm_Right", model = constants.MODELS.sleeve_r, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 180, z = 0}},
		legs_l = {bone = "Leg_Left", model = constants.MODELS.legs_l, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 180, z = 0}},
		legs_r = {bone = "Leg_Right", model = constants.MODELS.legs_r, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 180, z = 0}},
		feet_l = {bone = "Leg_Left", model = constants.MODELS.feet_l, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 180, z = 0}},
		feet_r = {bone = "Leg_Right", model = constants.MODELS.feet_r, pos = {x = 0, y = 0, z = 0}, rot = {x = 180, y = 180, z = 0}},
	},
}

constants.SOUNDS = {
	equip = "x_player_armor_equip",
	unequip = "x_player_armor_unequip",
	hit_metal = "x_player_armor_hit_metal",
	hit_wood = "x_player_armor_hit_wood",
	hit_crystal = "x_player_armor_hit_crystal",
	break_metal = "x_player_armor_break_metal",
	break_wood = "x_player_armor_break_wood",
	break_crystal = "x_player_armor_break_crystal",
	shield_block = "x_player_armor_shield_block",
	warn = "x_player_armor_warn",
	stand_dig = "x_player_armor_stand_dig",
	stand_dug = "x_player_armor_stand_dug",
	stand_place = "x_player_armor_stand_place",
	stand_footstep = "x_player_armor_stand_footstep",
}

---Tiered fire, lava, and thermal hazard node protection thresholds matching 3d_armor standards:
---Tier 5: Deep lava & molten sources (requires full nether set or admin armor)
---Tier 3: Open flames & fire nodes (requires 3 pieces of nether armor)
---Tier 2: Hazardous hot flora & thermal crusts (requires 2 pieces of nether armor)
---Tier 1: Torches & minor heat sources (requires 1 piece of nether armor or crystal chestplate)
constants.FIRE_NODES = {
	-- Tier 5: Extreme Molten Heat & Lava
	["default:lava_source"] = 5,
	["default:lava_flowing"] = 5,
	["nether:lava_source"] = 5,

	-- Tier 3: Open Fire & Flames
	["fire:basic_flame"] = 3,
	["fire:permanent_flame"] = 3,

	-- Tier 2: Hazardous Hot Flora & Thermal Crusts
	["ethereal:crystal_spike"] = 2,
	["ethereal:fire_flower"] = 2,
	["nether:lava_crust"] = 2,

	-- Tier 1: Torches & Minor Heat Sources
	["default:torch"] = 1,
	["default:torch_ceiling"] = 1,
	["default:torch_wall"] = 1,
}

local settings = core.settings
constants.LEVEL_MULTIPLIER = tonumber(settings:get("x_player_armor_level_multiplier")) or 1.0
constants.HEAL_MULTIPLIER = tonumber(settings:get("x_player_armor_heal_multiplier")) or 1.0
constants.SET_BONUS = settings:get_bool("x_player_armor_set_bonus", true)
constants.FIRE_PROTECT = settings:get_bool("x_player_armor_fire_protect", true)
constants.FIRE_PROTECT_TORCH = settings:get_bool("x_player_armor_fire_protect_torch", false)
constants.WATER_PROTECT = settings:get_bool("x_player_armor_water_protect", true)
constants.FEATHER_FALL = settings:get_bool("x_player_armor_feather_fall", true)
constants.ENABLE_SOUNDS = settings:get_bool("x_player_armor_enable_sounds", true)
constants.DROP_ON_DEATH = settings:get_bool("x_player_armor_drop_on_death", true)
constants.DESTROY_ON_DEATH = settings:get_bool("x_player_armor_destroy_on_death", false)
constants.COMBAT_HUD_ENABLE = settings:get_bool("x_player_armor_combat_hud", true)
constants.COMBAT_HUD_TIMEOUT = tonumber(settings:get("x_player_armor_combat_hud_timeout")) or 5.0
constants.COMBAT_HUD_POSITION = settings:get("x_player_armor_combat_hud_position") or "bottom_right"
constants.COMBAT_HUD_SCALE = tonumber(settings:get("x_player_armor_combat_hud_scale")) or 1.0
constants.SHIELD_HUD_ENABLE = settings:get_bool("x_player_armor_enable_shield_hud", true)
constants.SHIELD_HUD_DELAY = tonumber(settings:get("x_player_armor_shield_hud_delay")) or 0.35

-- Shield blocking & projectile deflection baseline constants
constants.BLOCK_CONE_ANGLE = 52
constants.BLOCK_ASYMMETRIC_BIAS = 22
constants.BLOCK_DEFAULT_REDUCTION = 0.20
constants.BLOCK_DEFLECT_PROJECTILES = true
constants.BLOCK_RESTITUTION = 0.50
constants.BLOCK_RECOIL_IMPULSE = 5.5

---Material-tiered defense scaling for active shield blocking
---Arc is calibrated around the left off-hand shield quadrant (~22° left bias, spanning ~-48° to +4° on steel)
---so attacks hitting the exposed right side of the view/screen or behind penetrate unless aimed.
constants.SHIELD_TIER_PROPERTIES = {
	wood =    { reduction = 0.10, restitution = 0.35, arc = 44, recoil_mult = 1.2 },
	cactus =  { reduction = 0.12, restitution = 0.35, arc = 44, recoil_mult = 1.2 },
	steel =   { reduction = 0.15, restitution = 0.50, arc = 52, recoil_mult = 1.0 },
	bronze =  { reduction = 0.16, restitution = 0.50, arc = 52, recoil_mult = 1.0 },
	gold =    { reduction = 0.15, restitution = 0.45, arc = 50, recoil_mult = 1.0 },
	diamond = { reduction = 0.20, restitution = 0.60, arc = 56, recoil_mult = 0.8 },
	mithril = { reduction = 0.22, restitution = 0.65, arc = 60, recoil_mult = 0.7 },
	crystal = { reduction = 0.20, restitution = 0.60, arc = 56, recoil_mult = 0.8 },
	nether =  { reduction = 0.25, restitution = 0.70, arc = 64, recoil_mult = 0.6 },
	admin =   { reduction = 1.00, restitution = 0.90, arc = 180, recoil_mult = 0.0, bias = 0 },
}

-- Forearm wielditem attachment transforms for shields (attached to Arm_Left)
constants.SHIELD_OFFSET = {
	glb = {
		pos = {x = -0.8, y = 5.0, z = -2.8},
		rot = {x = 180, y = 45, z = 0},
	},
	b3d = {
		pos = {x = -0.8, y = 5.0, z = 2.8},
		rot = {x = 180, y = -45, z = 0},
	},
}

x_player_armor.constants = constants
return constants
