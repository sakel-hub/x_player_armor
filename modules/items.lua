---@class XPlayerArmorItems
local items = {}

local S = core.get_translator("x_player_armor")

local MATERIALS = {
	wood = {
		name = S("Wood"),
		uses = 80,
		level = {head = 4, torso = 6, legs = 6, feet = 4, shield = 5},
		heal = {head = 0, torso = 0, legs = 0, feet = 0, shield = 0},
	},
	cactus = {
		name = S("Cactus"),
		uses = 110,
		level = {head = 5, torso = 7, legs = 7, feet = 5, shield = 6},
		heal = {head = 0, torso = 0, legs = 0, feet = 0, shield = 0},
	},
	steel = {
		name = S("Steel"),
		uses = 350,
		level = {head = 10, torso = 15, legs = 12, feet = 8, shield = 10},
		heal = {head = 0, torso = 0, legs = 0, feet = 0, shield = 0},
	},
	bronze = {
		name = S("Bronze"),
		uses = 450,
		level = {head = 12, torso = 16, legs = 13, feet = 9, shield = 11},
		heal = {head = 0, torso = 0, legs = 0, feet = 0, shield = 0},
	},
	diamond = {
		name = S("Diamond"),
		uses = 1200,
		level = {head = 16, torso = 22, legs = 18, feet = 14, shield = 15},
		heal = {head = 0, torso = 0, legs = 0, feet = 0, shield = 0},
	},
	gold = {
		name = S("Gold"),
		uses = 200,
		level = {head = 9, torso = 14, legs = 11, feet = 6, shield = 9},
		heal = {head = 3, torso = 4, legs = 3, feet = 2, shield = 3},
	},
	mithril = {
		name = S("Mithril"),
		uses = 1800,
		level = {head = 18, torso = 25, legs = 20, feet = 17, shield = 18},
		heal = {head = 3, torso = 5, legs = 4, feet = 0, shield = 3},
		feather = {feet = 1},
	},
	crystal = {
		name = S("Crystal"),
		uses = 1500,
		level = {head = 17, torso = 23, legs = 19, feet = 16, shield = 16},
		heal = {head = 0, torso = 0, legs = 0, feet = 0, shield = 3},
		water = {head = 1},
		fire = {torso = 1},
	},
	nether = {
		name = S("Nether"),
		uses = 2200,
		level = {head = 19, torso = 27, legs = 22, feet = 17, shield = 19},
		heal = {head = 0, torso = 0, legs = 0, feet = 0, shield = 0},
		fire = {head = 1, torso = 1, legs = 1, feet = 1, shield = 1},
	},
	admin = {
		name = S("Admin"),
		uses = 0,
		level = {head = 100, torso = 100, legs = 100, feet = 100, shield = 100},
		heal = {head = 100, torso = 100, legs = 100, feet = 100, shield = 100},
		fire = {head = 1, torso = 1, legs = 1, feet = 1, shield = 1},
		water = {head = 1, torso = 1, legs = 1, feet = 1, shield = 1},
		feather = {head = 1, torso = 1, legs = 1, feet = 1, shield = 1},
	},
}

local PIECES = {
	helmet = {
		element = "head",
		group = "armor_head",
		title = "@1 Helmet",
		desc = "Helmet forged from @1.",
	},
	chestplate = {
		element = "torso",
		group = "armor_torso",
		title = "@1 Chestplate",
		desc = "Chestplate forged from @1.",
	},
	leggings = {
		element = "legs",
		group = "armor_legs",
		title = "@1 Leggings",
		desc = "Leggings forged from @1.",
	},
	boots = {
		element = "feet",
		group = "armor_feet",
		title = "@1 Boots",
		desc = "Boots forged from @1.",
	},
	shield = {
		element = "shield",
		group = "armor_shield",
		title = "@1 Shield",
		desc = "Shield crafted with @1.",
	},
}

local utils = x_player_armor.utils

for mat_key, mat_data in pairs(MATERIALS) do
	for piece_key, piece_data in pairs(PIECES) do
		local item_name = "x_player_armor:" .. piece_key .. "_" .. mat_key
		local legacy_mod = piece_key == "shield" and "shields" or "3d_armor"
		local legacy_name = legacy_mod .. ":" .. piece_key .. "_" .. mat_key

		local inv_img = "x_player_armor_inv_" .. piece_key .. "_" .. mat_key .. ".png"
		local tex_img = "x_player_armor_" .. mat_key .. ".png"

		local lvl = mat_data.level[piece_data.element] or 1
		local heal = (mat_data.heal and mat_data.heal[piece_data.element]) or 0
		local fire = (mat_data.fire and mat_data.fire[piece_data.element]) or 0
		local water = (mat_data.water and mat_data.water[piece_data.element]) or 0
		local feather = (mat_data.feather and mat_data.feather[piece_data.element]) or 0

		local item_uses = mat_data.uses or 200
		local groups = {
			[piece_data.group] = lvl,
			armor_uses = item_uses,
			["armor_material_" .. mat_key] = 1,
		}
		if piece_data.element == "shield" then
			groups.shield = 1
		end

		if heal > 0 then groups.armor_heal = heal end
		if fire > 0 then groups.armor_fire = fire end
		if water > 0 then groups.armor_water = water end
		if feather > 0 then groups.armor_feather = feather end

		local item_title = S(piece_data.title, mat_data.name)
		local item_desc = utils.format_armor_tooltip({
			title = item_title,
			element = piece_data.element,
			material = mat_key,
			level = lvl,
			uses = item_uses,
			heal = heal,
			fire = fire,
			water = water,
			feather = feather,
			is_shield = (piece_data.element == "shield"),
			reciprocate = (piece_key == "shield"),
		})

		x_player_armor.register_armor(item_name, {
			description = item_desc,
			short_description = item_title,
			inventory_image = inv_img,
			texture = tex_img,
			preview = inv_img,
			element = piece_data.element,
			groups = groups,
			armor_groups = {fleshy = lvl},
			damage_groups = {cracky = 2, snappy = 3, choppy = 2, crumbly = 1, level = 1},
			reciprocate_damage = (piece_key == "shield"),
			wear_color = {
				blend = "linear",
				color_stops = {
					[0.0] = "#e74c3c",
					[0.3] = "#e67e22",
					[0.6] = "#f1c40f",
					[1.0] = "#2ecc71",
				},
			},
		})

		-- Backward compatibility alias & forced override
		x_player_armor.legacy_replacements[legacy_name] = item_name
		utils.force_alias(legacy_name, item_name)
	end
end

-- Enhanced Shields
local enhanced_shields = {
	wood = {
		name = S("Enhanced Wood Shield"),
		inv_img = "x_player_armor_inv_shield_enhanced_wood.png",
		tex_img = "x_player_armor_shield_enhanced_wood.png",
		preview = "x_player_armor_inv_shield_enhanced_wood.png",
		level = 8,
		uses = 120,
	},
	cactus = {
		name = S("Enhanced Cactus Shield"),
		inv_img = "x_player_armor_inv_shield_enhanced_cactus.png",
		tex_img = "x_player_armor_shield_enhanced_cactus.png",
		preview = "x_player_armor_inv_shield_enhanced_cactus.png",
		level = 9,
		uses = 150,
	},
}

for mat_key, es in pairs(enhanced_shields) do
	local item_name = "x_player_armor:shield_enhanced_" .. mat_key
	local legacy_name = "shields:shield_enhanced_" .. mat_key
	local es_uses = es.uses or 200

	local es_desc = utils.format_armor_tooltip({
		title = es.name,
		element = "shield",
		material = mat_key,
		level = es.level,
		uses = es_uses,
		is_shield = true,
		is_tower = true,
		reciprocate = true,
	})

	x_player_armor.register_armor(item_name, {
		description = es_desc,
		short_description = es.name,
		inventory_image = es.inv_img,
		texture = es.tex_img,
		preview = es.preview,
		element = "shield",
		groups = {
			armor_shield = es.level,
			armor_shield_tower = 1,
			shield = 1,
			armor_uses = es_uses,
			["armor_material_" .. mat_key] = 1,
		},
		armor_groups = {fleshy = es.level},
		damage_groups = {cracky = 2, snappy = 3, choppy = 2, crumbly = 1, level = 1},
		reciprocate_damage = true,
	})

	x_player_armor.legacy_replacements[legacy_name] = item_name
	utils.force_alias(legacy_name, item_name)
end

-- Admin shield alias backward compatibility
local admin_legacy = "adminshield"
x_player_armor.legacy_replacements[admin_legacy] = "x_player_armor:shield_admin"
utils.force_alias(admin_legacy, "x_player_armor:shield_admin")

---Returns the defined armor material configurations table.
---@return table<string, table> materials
function items.get_materials()
	return MATERIALS
end

---Returns the defined armor equipment pieces configuration table.
---@return table<string, table> pieces
function items.get_pieces()
	return PIECES
end

x_player_armor.items = items
return items
