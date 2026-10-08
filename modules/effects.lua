---@class XPlayerArmorEffects
local effects = {}

local constants = x_player_armor.constants
local utils = x_player_armor.utils

---Active registry of players wearing water-breathing armor: [player_name] = water_level.
---Allows the globalstep to abort immediately with zero overhead when no players need breath replenishment.
effects.active_water_players = {}

---Updates player armor statistics, fleshy armor groups, and physics overrides.
---@param player ObjectRef
function effects.update_player_armor(player)
	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then return end

	local armor_list = inv:get_list("armor")
	if not armor_list then return end

	local total_level = 0
	local speed_mod = 1.0
	local jump_mod = 1.0
	local gravity_mod = 1.0
	local count = 0
	local materials_worn = {}
	local has_shield = false
	local has_reciprocate = false

	local custom_attributes = x_player_armor.get_attributes()
	local total_attrs = {}
	for a = 1, #custom_attributes do
		total_attrs[custom_attributes[a]] = 0
	end

	local custom_group_levels = {}

	for idx = 1, 6 do
		local stack = armor_list[idx]
		if stack and not stack:is_empty() then
			local def = stack:get_definition()
			if def and def.groups then
				count = count + 1
				local groups = def.groups

				if (groups.armor_shield or 0) > 0 or (groups.shield or 0) > 0 then
					has_shield = true
				end
				if def.reciprocate_damage == true or def.thorns == true or (type(def.thorns) == "number" and def.thorns > 0) then
					has_reciprocate = true
				end

				-- Add element defense contribution (O(1) direct slot lookup, with clean loop fallback)
				local primary_el = constants.SLOT_ELEMENTS[idx]
				local primary_grp = primary_el and constants.ELEMENT_GROUPS[primary_el]
				local lvl = primary_grp and (groups[primary_grp] or 0) or 0
				if lvl == 0 then
					local dynamic_elements = x_player_armor.get_elements()
					for e = 1, #dynamic_elements do
						local req = "armor_" .. dynamic_elements[e]
						local gval = groups[req] or def[req] or 0
						if gval > 0 then
							lvl = gval
							break
						end
					end
				end
				total_level = total_level + lvl

				-- Dynamic attributes (with legacy top-level def fallback)
				for _, attr in ipairs(custom_attributes) do
					local attr_val = groups["armor_" .. attr] or def["armor_" .. attr] or def[attr] or 0
					total_attrs[attr] = total_attrs[attr] + attr_val
				end

				-- Custom armor groups
				if def.armor_groups then
					for grp, gval in pairs(def.armor_groups) do
						custom_group_levels[grp] = (custom_group_levels[grp] or 0) + gval
					end
				end

				speed_mod = speed_mod + (groups.physics_speed or def.physics_speed or def.speed or 0)
				jump_mod = jump_mod + (groups.physics_jump or def.physics_jump or def.jump or 0)
				gravity_mod = gravity_mod + (groups.physics_gravity or def.physics_gravity or def.gravity or 0)

				local mat = utils.get_item_material(stack:get_name())
				if mat then
					materials_worn[mat] = (materials_worn[mat] or 0) + 1
				end
			end
		end
	end

	local total_heal = total_attrs.heal or 0
	local total_fire = total_attrs.fire or 0
	local total_water = total_attrs.water or 0
	local total_feather = total_attrs.feather or 0

	-- Full-set bonus check (at least 4 matching pieces)
	local has_set_bonus = false
	if constants.SET_BONUS then
		for _, mat_count in pairs(materials_worn) do
			if mat_count >= 4 then
				has_set_bonus = true
				break
			end
		end
	end

	if has_set_bonus then
		total_level = math.floor(total_level * 1.10)
	end

	-- Apply server multipliers
	total_level = math.floor(total_level * constants.LEVEL_MULTIPLIER)
	total_heal = math.floor(total_heal * constants.HEAL_MULTIPLIER)

	-- Calculate fleshy group damage percentage
	-- Base 100 fleshy: with 100 armor, fleshy becomes 0 (immortal to standard hits)
	local fleshy_val = math.max(0, 100 - total_level)

	local player_def = x_player_armor.get_player_def(player)
	player_def.count = count
	player_def.level = total_level
	player_def.heal = total_heal
	player_def.fire = total_fire
	player_def.water = total_water
	player_def.feather = total_feather
	for _, attr in ipairs(custom_attributes) do
		player_def[attr] = total_attrs[attr]
	end
	player_def.speed = speed_mod
	player_def.jump = jump_mod
	player_def.gravity = gravity_mod
	player_def.set_bonus = has_set_bonus
	player_def.has_shield = has_shield
	player_def.has_reciprocate = has_reciprocate

	-- Maintain player_def.groups with safe index metatable
	if not player_def.groups or not getmetatable(player_def.groups) then
		player_def.groups = setmetatable(player_def.groups or {}, {
			__index = function() return 0 end,
		})
	end
	player_def.groups.fleshy = total_level
	for grp, val in pairs(custom_group_levels) do
		player_def.groups[grp] = val
	end

	-- Maintain active environmental water protection registry
	if constants.WATER_PROTECT and total_water > 0 then
		effects.active_water_players[name] = total_water
	else
		effects.active_water_players[name] = nil
	end

	-- Update Luanti engine armor groups
	local armor_groups = utils.copy_table(x_player_armor.registered_groups)
	armor_groups.fleshy = fleshy_val
	for grp, base in pairs(x_player_armor.registered_groups) do
		if grp ~= "fleshy" then
			local lvl = custom_group_levels[grp] or 0
			armor_groups[grp] = math.max(0, base - lvl)
		end
	end
	player:set_armor_groups(armor_groups)

	-- Apply physics overrides
	local monoids = x_player_armor.get_mod_api("player_monoids")
	local pova_mod = x_player_armor.get_mod_api("pova")
	local physics_mod = x_player_armor.get_mod_api("playerphysics")
	if monoids then
		monoids.speed:add_change(player, speed_mod, "x_player_armor:physics")
		monoids.jump:add_change(player, jump_mod, "x_player_armor:physics")
		monoids.gravity:add_change(player, gravity_mod, "x_player_armor:physics")
	elseif pova_mod then
		pova_mod.set_modifier(player, "x_player_armor", {
			speed = speed_mod,
			jump = jump_mod,
			gravity = gravity_mod,
		})
	elseif physics_mod then
		if speed_mod ~= 1.0 then
			physics_mod.add_physics_factor(player, "speed", "x_player_armor:physics", speed_mod)
		else
			physics_mod.remove_physics_factor(player, "speed", "x_player_armor:physics")
		end
		if jump_mod ~= 1.0 then
			physics_mod.add_physics_factor(player, "jump", "x_player_armor:physics", jump_mod)
		else
			physics_mod.remove_physics_factor(player, "jump", "x_player_armor:physics")
		end
		if gravity_mod ~= 1.0 then
			physics_mod.add_physics_factor(player, "gravity", "x_player_armor:physics", gravity_mod)
		else
			physics_mod.remove_physics_factor(player, "gravity", "x_player_armor:physics")
		end
	else
		player:set_physics_override({
			speed = speed_mod,
			jump = jump_mod,
			gravity = gravity_mod,
		})
	end

	-- Synchronize HUD statbars (e.g. hbarmor state wear calculation)
	x_player_armor.compat_hud.sync_player_hud_def(player, inv)

	x_player_armor.run_callbacks("on_update", player)
end

-- Clean up active player state on disconnect
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if name then
		effects.active_water_players[name] = nil
	end
	local physics_mod = x_player_armor.get_mod_api("playerphysics")
	if physics_mod then
		physics_mod.remove_physics_factor(player, "speed", "x_player_armor:physics")
		physics_mod.remove_physics_factor(player, "jump", "x_player_armor:physics")
		physics_mod.remove_physics_factor(player, "gravity", "x_player_armor:physics")
	end
end)

-- Globalstep loop for environmental breath replenishment (throttled to 1.0s intervals).
-- Optimized for multiplayer: fully idle-skipping with zero iteration when no players wear water armor.
-- Fire protection is handled 100% event-driven in combat.on_player_hpchange, eliminating map lookups.
local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 1.0 then return end
	timer = 0

	if not constants.WATER_PROTECT or not next(effects.active_water_players) then
		return
	end

	for name, water_val in pairs(effects.active_water_players) do
		local player = core.get_player_by_name(name)
		if player and player:is_player() then
			local breath = player:get_breath()
			if breath and breath < 10 then
				player:set_breath(math.min(10, breath + water_val))
			end
		else
			effects.active_water_players[name] = nil
		end
	end
end)

x_player_armor.effects = effects
return effects
