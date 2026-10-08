---@class XPlayerArmorUtils
local utils = {}

---Shallow copies a key-value table.
---@generic T: table
---@param t T
---@return T
function utils.copy_table(t)
	if not t then return {} end
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

---Recursively deep-copies a table or value.
---@generic T
---@param orig T
---@return T
function utils.deep_copy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = utils.deep_copy(orig_value)
		end
	else
		copy = orig
	end
	return copy
end

---Extracts the target player name from either a string or an ObjectRef.
---@param player (ObjectRef|string)?
---@return string?
function utils.get_player_name(player)
	if type(player) == "string" then
		return player
	elseif player and player:is_player() then
		return player:get_player_name()
	end
	return nil
end

local S = core.get_translator("x_player_armor")

---Memoized cache mapping item technical names to their material identifier string
utils.material_cache = {}

---Extracts the material name from an armor item name.
---Uses memoized cache to eliminate pairs() iteration and string slicing during high-frequency combat.
---@nodiscard
---@param item_name string Technical item name (e.g. "x_player_armor:helmet_steel")
---@return string? material Material identifier (e.g. "steel", "diamond", "wood") or nil
function utils.get_item_material(item_name)
	if not item_name or item_name == "" then return nil end
	local cached = utils.material_cache[item_name]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local def = core.registered_tools[item_name] or core.registered_items[item_name]
	if not def or not def.groups then
		utils.material_cache[item_name] = false
		return nil
	end

	for group in pairs(def.groups) do
		if group:sub(1, 15) == "armor_material_" then
			local mat = group:sub(16)
			utils.material_cache[item_name] = mat
			return mat
		end
	end

	utils.material_cache[item_name] = false
	return nil
end

utils.MATERIAL_COLORS = {
	wood = "#d4a373",      -- Warm natural oak
	cactus = "#7bc96f",    -- Spiky vibrant green
	steel = "#c0c7d0",     -- Sleek polished metallic
	bronze = "#e09f58",    -- Warm copper-gold bronze
	diamond = "#58d5ff",   -- Brilliant celestial blue
	gold = "#ffd700",      -- Radiant regal gold
	mithril = "#99e6ff",   -- Ethereal cyan silver
	crystal = "#56c7c2",   -- Luminous cyan crystal
	nether = "#ff6b6b",    -- Infernal crimson flame
	admin = "#ff79c6",     -- Divine omnipotent pink
}

utils.UI_COLORS = {
	label = "#c9d1d9",      -- High-contrast accessible silver-gray (WCAG AAA 10.7:1)
	defense = "#58a6ff",    -- Vibrant armor blue (WCAG AA 6.8:1)
	durability = "#c9d1d9", -- High-contrast silver text (WCAG AAA 10.7:1)
	heal = "#7ee787",       -- Emerald green (WCAG AAA 10.9:1)
	fire = "#ffa657",       -- Blazing amber (WCAG AAA 8.6:1)
	water = "#58a6ff",      -- Water blue (WCAG AA 6.8:1)
	feather = "#79c0ff",    -- Sky cyan (WCAG AAA 9.0:1)
	shield = "#d2a8ff",     -- Shield purple (WCAG AAA 8.5:1)
	thorns = "#ff7b72",     -- Coral red (WCAG AA 6.4:1)
	synergy = "#f1e05a",    -- Golden star (WCAG AAA 12.4:1)
	hint = "#9ecbff",       -- High-contrast tooltip hint sky-cyan (WCAG AAA 9.9:1)
	unbreakable = "#7ee787",-- Unbreakable green (WCAG AAA 10.9:1)
	enhanced = "#f59e0b",   -- Fortified amber (WCAG AAA 7.7:1)
	tooltip_bg = "#10141cf0",-- Sleek dark theme tooltip background
	tooltip_font = "#c9d1d9",-- High-contrast tooltip text color
}

---Registers a forced alias for backwards compatibility, overriding any existing legacy definition.
---@param legacy_name string Old or legacy item name
---@param modern_name string Replacement modern item name
function utils.force_alias(legacy_name, modern_name)
	if not legacy_name or not modern_name or legacy_name == modern_name then return end
	if core.registered_items and (core.registered_items[legacy_name] or (core.registered_nodes and core.registered_nodes[legacy_name])) then
		if core.register_alias_force then
			core.register_alias_force(legacy_name, modern_name)
		else
			if core.unregister_item then
				core.unregister_item(legacy_name)
			end
			core.register_alias(legacy_name, modern_name)
		end
	else
		core.register_alias(legacy_name, modern_name)
	end
end

---Builds a modern, rich, colorized tooltip for armor and shield items.
---@param params table Configuration options table
---@return string tooltip Formatted tooltip string with embedded Luanti color escapes
function utils.format_armor_tooltip(params)
	params = params or {}
	local title = params.title or S("Armor Item")
	local element = params.element
	local mat_key = params.material
	local lvl = params.level or 0
	local uses = params.uses or 200
	local heal = params.heal or 0
	local fire = params.fire or 0
	local water = params.water or 0
	local feather = params.feather or 0
	local is_shield = (element == "shield") or (params.is_shield == true)
	local is_tower = params.is_tower == true
	local reciprocate = params.reciprocate == true
	local mat_color = (mat_key and utils.MATERIAL_COLORS[mat_key])
		or (is_tower and utils.UI_COLORS.enhanced)
		or utils.UI_COLORS.defense

	local lines = {}

	-- Colored title header with theme tooltip background
	local bg_esc = core.get_background_escape_sequence(utils.UI_COLORS.tooltip_bg)
	table.insert(lines, bg_esc .. core.colorize(mat_color, title))

	-- Slot and equipment classification
	local slot_name
	if is_tower then
		slot_name = S("Type: Tower Shield (Reinforced Off-Hand)")
	elseif element == "head" then
		slot_name = S("Type: Helmet (Head Slot)")
	elseif element == "torso" then
		slot_name = S("Type: Chestplate (Torso Slot)")
	elseif element == "legs" then
		slot_name = S("Type: Leggings (Legs Slot)")
	elseif element == "feet" then
		slot_name = S("Type: Boots (Feet Slot)")
	elseif is_shield then
		slot_name = S("Type: Shield (Off-Hand Slot)")
	else
		slot_name = S("Type: Armor Equipment")
	end
	table.insert(lines, core.colorize(utils.UI_COLORS.label, slot_name))

	-- Core combat defense and durability
	if lvl > 0 then
		local def_label = is_shield and S("Passive Defense: ") or S("Defense: ")
		table.insert(lines, core.colorize(utils.UI_COLORS.label, def_label)
			.. core.colorize(utils.UI_COLORS.defense, "+" .. lvl .. "% " .. S("Damage Reduction")))
	end

	if uses == 0 then
		table.insert(lines, core.colorize(utils.UI_COLORS.label, S("Durability: "))
			.. core.colorize(utils.UI_COLORS.unbreakable, S("Unbreakable (Infinite)")))
	elseif uses > 0 then
		table.insert(lines, core.colorize(utils.UI_COLORS.label, S("Durability: "))
			.. core.colorize(utils.UI_COLORS.durability, S("@1 Uses", uses)))
	end

	-- Special wards and active perks
	if heal > 0 then
		table.insert(lines, core.colorize(utils.UI_COLORS.heal,
			S("✦ Healing Ward: +@1% Chance on hit to nullify damage & heal", heal)))
	end

	if fire > 0 then
		if mat_key == "nether" then
			table.insert(lines, core.colorize(utils.UI_COLORS.fire,
				S("✦ Fire Ward: +1 Heat Tier (Tier 5 Molten Immunity at 4+ pieces)")))
		else
			table.insert(lines, core.colorize(utils.UI_COLORS.fire,
				S("✦ Fire Ward: +1 Heat Tier (Protects against torches & hot flora)")))
		end
	end

	if water > 0 then
		table.insert(lines, core.colorize(utils.UI_COLORS.water,
			S("✦ Water Ward: Underwater Breathing (Infinite Drown Immunity)")))
	end

	if feather > 0 then
		table.insert(lines, core.colorize(utils.UI_COLORS.feather,
			S("✦ Feather Fall: -@1 Fall Damage (@2 Hearts Absorbed)", feather * 4, feather * 2)))
	end

	-- Shield guard and blocking mechanics
	if is_shield then
		local consts = x_player_armor.constants
		local shield_props = (consts and consts.SHIELD_TIER_PROPERTIES and mat_key and consts.SHIELD_TIER_PROPERTIES[mat_key]) or {}
		local arc = shield_props.arc or (consts and consts.BLOCK_CONE_ANGLE) or 52
		local bias = shield_props.bias or (consts and consts.BLOCK_ASYMMETRIC_BIAS) or 22
		local red_pct = math.floor((shield_props.reduction or (consts and consts.BLOCK_DEFAULT_REDUCTION) or 0.20) * 100)

		if is_tower then
			table.insert(lines, core.colorize(utils.UI_COLORS.enhanced, S("✦ Reinforced Tower Guard (Hold RMB):")))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  • Block Mitigation: @1% damage absorbed (reinforced)", red_pct)))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  • Frontal Guard Arc: @1° cone (@2° off-hand bias)", arc, bias)))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  • Projectile Deflection: Bounces arrows & fireballs")))
			if reciprocate then
				table.insert(lines, core.colorize(utils.UI_COLORS.thorns, S("  • Thorns: Damages melee attacker's weapon")))
			end
		else
			table.insert(lines, core.colorize(utils.UI_COLORS.shield, S("✦ Shield Guard (Hold RMB):")))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  • Block Mitigation: @1% damage absorbed", red_pct)))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  • Frontal Guard Arc: @1° cone (@2° off-hand bias)", arc, bias)))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  • Projectile Deflection: Bounces arrows & fireballs")))
			if reciprocate then
				table.insert(lines, core.colorize(utils.UI_COLORS.thorns, S("  • Thorns: Damages melee attacker's weapon")))
			end
		end
	elseif reciprocate then
		table.insert(lines, core.colorize(utils.UI_COLORS.thorns, S("✦ Thorns: Damages melee attacker's weapon")))
	end

	-- Mobility & Physics
	if params.speed and params.speed ~= 0 then
		local s_pct = math.floor(params.speed * 100)
		table.insert(lines, core.colorize(utils.UI_COLORS.feather,
			S("✦ Swiftness: @1% Movement Speed", (s_pct > 0 and "+" or "") .. s_pct)))
	end
	if params.jump and params.jump ~= 0 then
		local j_pct = math.floor(params.jump * 100)
		table.insert(lines, core.colorize(utils.UI_COLORS.heal,
			S("✦ High Jump: @1% Jump Height", (j_pct > 0 and "+" or "") .. j_pct)))
	end
	if params.gravity and params.gravity ~= 0 then
		local g_pct = math.floor(params.gravity * 100)
		table.insert(lines, core.colorize(utils.UI_COLORS.fire,
			S("✦ Gravity: @1%", (g_pct > 0 and "+" or "") .. g_pct)))
	end

	-- Custom perks
	if params.custom_perks then
		for _, perk in ipairs(params.custom_perks) do
			if type(perk) == "table" then
				table.insert(lines, core.colorize(perk.color or utils.UI_COLORS.label, perk.text))
			elseif type(perk) == "string" then
				table.insert(lines, core.colorize(utils.UI_COLORS.label, perk))
			end
		end
	end

	-- Set synergy and combination guidance
	if params.synergy_text then
		table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
		table.insert(lines, core.colorize(utils.UI_COLORS.label, "  " .. params.synergy_text))
	elseif mat_key then
		if mat_key == "wood" then
			table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  Combine 4 wood pieces for early-game defense bonus.")))
		elseif mat_key == "cactus" then
			table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  Combine 4 cactus pieces for early-game thorny protection.")))
		elseif mat_key == "steel" then
			table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  Combine 4 steel pieces for solid all-around mid-game defense.")))
		elseif mat_key == "bronze" then
			table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  Combine 4 bronze pieces for heavy durable defense exceeding steel.")))
		elseif mat_key == "diamond" then
			table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
			table.insert(lines, core.colorize(utils.UI_COLORS.label, S("  Combine 4 diamond pieces for elite end-game damage absorption.")))
		elseif mat_key == "gold" then
			table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
			table.insert(lines, core.colorize(utils.MATERIAL_COLORS.gold, S("  Full set yields +12% (+15% w/ shield) healing ward chance!")))
		elseif mat_key == "mithril" then
			table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
			table.insert(lines, core.colorize(utils.MATERIAL_COLORS.mithril, S("  Combine set for high durability, healing ward & feather falling!")))
		elseif mat_key == "crystal" then
			table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
			table.insert(lines, core.colorize(utils.MATERIAL_COLORS.crystal, S("  Hybrid Set: Water breathing (head), fire ward (chest) & healing (shield)!")))
		elseif mat_key == "nether" then
			table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Set Synergy (4+ Pieces): +10% Total Defense")))
			table.insert(lines, core.colorize(utils.MATERIAL_COLORS.nether, S("  Full 4+ piece set grants Tier 5 Molten & Lava Immunity!")))
		elseif mat_key == "admin" then
			table.insert(lines, core.colorize(utils.MATERIAL_COLORS.admin, S("★ Omnipotent Set: Total immunity, infinite durability & 100% healing ward.")))
		end
	elseif is_tower then
		table.insert(lines, core.colorize(utils.UI_COLORS.synergy, S("★ Tower Shield: Counts toward matching 4-piece set bonus")))
	end

	-- Contextual interaction hint
	if params.hint then
		table.insert(lines, core.colorize(utils.UI_COLORS.hint, params.hint))
	elseif is_shield then
		table.insert(lines, core.colorize(utils.UI_COLORS.hint, S("Tip: Equip in shield slot; hold RMB to raise guard")))
	else
		table.insert(lines, core.colorize(utils.UI_COLORS.hint, S("Tip: Right-click in hand to quick-equip or swap")))
	end

	return table.concat(lines, "\n")
end

---Builds a modern, rich, colorized tooltip for Armor Stand nodes.
---@param is_locked boolean? Whether this is an owner-locked armor stand
---@return string tooltip Formatted tooltip string
function utils.format_armor_stand_tooltip(is_locked)
	local bg_esc = core.get_background_escape_sequence(utils.UI_COLORS.tooltip_bg)
	local title = is_locked and S("Locked Armor Stand") or S("Armor Stand")
	local access_type = is_locked and S("Type: Equipment Display / Storage (Owner-Locked)") or S("Type: Equipment Display / Storage (Public)")
	local lines = {
		bg_esc .. core.colorize(utils.UI_COLORS.defense, title),
		core.colorize(utils.UI_COLORS.label, access_type),
		core.colorize(utils.UI_COLORS.label, S("Capacity: ")) .. core.colorize(utils.UI_COLORS.durability, S("Full 5-Piece Armor Set")),
		core.colorize(utils.UI_COLORS.heal, S("✦ Wardrobe Management & Quick Swap:")),
		core.colorize(utils.UI_COLORS.label, S("  • Live 3D character display mannequin & shield")),
		core.colorize(utils.UI_COLORS.label, S("  • Right-Click: Open Wardrobe UI")),
		core.colorize(utils.UI_COLORS.label, S("  • Shift + Left-Click: Instant full outfit swap")),
		core.colorize(utils.UI_COLORS.label, S("  • Preserves item wear, enchants, and custom metadata")),
		core.colorize(utils.UI_COLORS.hint, S("Tip: Point crosshair at stand to view equipped pieces")),
	}
	return table.concat(lines, "\n")
end

---Builds a modern formatted tooltip from an arbitrary armor definition table.
---@param name string Item technical name
---@param def table Armor item definition
---@return string? tooltip Formatted tooltip or nil
function utils.format_armor_tooltip_from_def(name, def)
	if not def then return nil end
	local groups = def.groups or {}
	local element = def.element
	if not element then
		for el, grp in pairs(x_player_armor.constants.ELEMENT_GROUPS or {}) do
			if (groups[grp] or 0) > 0 then
				element = el
				break
			end
		end
		if not element and (groups.shield or 0) > 0 then
			element = "shield"
		end
	end

	local mat = utils.get_item_material(name)
	local title = def.short_description or def.description or name
	-- Strip any existing color codes if present in title
	if type(title) == "string" and title:sub(1, 1) == "\27" then
		title = title:gsub("\27%b()", ""):gsub("\27%a", "")
	end

	local lvl = 0
	if element then
		lvl = groups["armor_" .. element] or 0
	end
	if lvl == 0 and def.armor_groups and def.armor_groups.fleshy then
		lvl = def.armor_groups.fleshy
	end

	local uses = groups.armor_uses or def.armor_uses or 200
	local is_tower = (groups.armor_shield_tower or 0) > 0 or (groups.armor_tower_shield or 0) > 0 or def.tower_shield == true

	return utils.format_armor_tooltip({
		title = title,
		element = element,
		material = mat,
		level = lvl,
		uses = uses,
		heal = groups.armor_heal or 0,
		fire = groups.armor_fire or 0,
		water = groups.armor_water or 0,
		feather = groups.armor_feather or 0,
		is_shield = (element == "shield") or (groups.shield or 0) > 0,
		is_tower = is_tower,
		reciprocate = def.reciprocate_damage == true,
		speed = groups.physics_speed,
		jump = groups.physics_jump,
		gravity = groups.physics_gravity,
	})
end

x_player_armor.utils = utils
x_player_armor.copy_table = utils.copy_table
x_player_armor.format_armor_tooltip = utils.format_armor_tooltip
x_player_armor.format_armor_stand_tooltip = utils.format_armor_stand_tooltip
x_player_armor.format_armor_tooltip_from_def = utils.format_armor_tooltip_from_def
x_player_armor.force_alias = utils.force_alias
return utils
