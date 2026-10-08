---@class XPlayerArmorCrafting
local crafting = {}

local RECIPE_INGREDIENTS = {
	wood = "group:wood",
	cactus = "default:cactus",
	steel = "default:steel_ingot",
	bronze = "default:bronze_ingot",
	diamond = "default:diamond",
	gold = "default:gold_ingot",
}

if core.get_modpath("moreores") then
	RECIPE_INGREDIENTS.mithril = "moreores:mithril_ingot"
end

if core.get_modpath("ethereal") then
	RECIPE_INGREDIENTS.crystal = "ethereal:crystal_ingot"
end

if core.get_modpath("nether") then
	RECIPE_INGREDIENTS.nether = "nether:nether_ingot"
end

for mat, ing in pairs(RECIPE_INGREDIENTS) do
	-- Helmet
	core.register_craft({
		output = "x_player_armor:helmet_" .. mat,
		recipe = {
			{ing, ing, ing},
			{ing, "",  ing},
		},
	})

	-- Chestplate
	core.register_craft({
		output = "x_player_armor:chestplate_" .. mat,
		recipe = {
			{ing, "",  ing},
			{ing, ing, ing},
			{ing, ing, ing},
		},
	})

	-- Leggings
	core.register_craft({
		output = "x_player_armor:leggings_" .. mat,
		recipe = {
			{ing, ing, ing},
			{ing, "",  ing},
			{ing, "",  ing},
		},
	})

	-- Boots
	core.register_craft({
		output = "x_player_armor:boots_" .. mat,
		recipe = {
			{ing, "", ing},
			{ing, "", ing},
		},
	})

	-- Shield
	core.register_craft({
		output = "x_player_armor:shield_" .. mat,
		recipe = {
			{ing, ing, ing},
			{ing, ing, ing},
			{"",  ing, ""},
		},
	})
end

-- Enhanced Shields Recipes
core.register_craft({
	output = "x_player_armor:shield_enhanced_wood",
	recipe = {
		{"default:steel_ingot"},
		{"x_player_armor:shield_wood"},
		{"default:steel_ingot"},
	},
})

core.register_craft({
	output = "x_player_armor:shield_enhanced_cactus",
	recipe = {
		{"default:steel_ingot"},
		{"x_player_armor:shield_cactus"},
		{"default:steel_ingot"},
	},
})

-- Armor Stand Recipes
core.register_craft({
	output = "x_player_armor:stand",
	recipe = {
		{"", "default:fence_wood", ""},
		{"", "default:fence_wood", ""},
		{"default:wood", "default:wood", "default:wood"},
	},
})

-- Locked Armor Stand Recipe
core.register_craft({
	output = "x_player_armor:locked_stand",
	recipe = {
		{"default:steel_ingot"},
		{"x_player_armor:stand"},
	},
})

-- Fuel recipes for flammable shields
core.register_craft({
	type = "fuel",
	recipe = "x_player_armor:shield_wood",
	burntime = 8,
})

core.register_craft({
	type = "fuel",
	recipe = "x_player_armor:shield_cactus",
	burntime = 16,
})

---Returns the registered crafting recipe ingredients mapping by material key.
---@return table<string, string> ingredients Table mapping material keys to crafting ingredient strings
function crafting.get_recipe_ingredients()
	return RECIPE_INGREDIENTS
end

x_player_armor.crafting = crafting
return crafting
