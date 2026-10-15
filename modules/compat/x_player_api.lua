-- X Player Armor - x_player_api Integration Adapter (modules/compat/x_player_api.lua)
-- Leverages advanced locomotion, equip montages, sounds, and visual proxies when x_player_api is present.
-- NOTE: Never depends on x_player_bridge.
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class XPlayerArmorCompatXPlayerAPI
local x_api_compat = {}

---Retrieves the active x_player_api global API table if available.
---@return table|nil
local function get_api()
	return x_player_armor.get_mod_api("x_player_api")
end
x_api_compat.get_api = get_api

---Check whether x_player_api is present and active
---@return boolean
function x_api_compat.is_present()
	return get_api() ~= nil
end

---Initialize x_player_api integrations if available
function x_api_compat.init()
	local x_api = get_api()
	if not x_api then
		return
	end

	-- Register equip sound effects for armor groups and materials
	local equip_sounds = {
		{"group:armor_head", "x_player_armor_equip_metal", 0.65, 0.05},
		{"group:armor_torso", "x_player_armor_equip_metal", 0.75, 0.05},
		{"group:armor_legs", "x_player_armor_equip_metal", 0.65, 0.05},
		{"group:armor_feet", "x_player_armor_equip_metal", 0.60, 0.05},
		{"group:armor_shield", "x_player_armor_equip_metal", 0.70, 0.05},
		-- Material-specific sound overrides
		{"group:armor_material_wood", "x_player_armor_hit_wood", 0.6, nil},
		{"group:armor_material_cactus", "x_player_armor_hit_wood", 0.6, nil},
		{"group:armor_material_crystal", "x_player_armor_hit_crystal", 0.7, nil},
	}
	for i = 1, #equip_sounds do
		local spec = equip_sounds[i]
		x_api.register_equip_sound(spec[1], {
			sound = spec[2],
			gain = spec[3],
			pitch_variance = spec[4],
		})
	end

	-- Register shield item action for defensive block stance
	x_api.register_item_action("group:armor_shield", {
		action = "block",
		alt_action = "block",
		is_shield = true,
	})

	-- Register blocking predicate so x_player_api recognizes equipped shields in armor inventory
	x_api.register_blocking_predicate(function(player, _wield_name, _item_info)
		return x_player_armor.combat.get_equipped_shield(player) ~= nil
	end)

	-- Register state transition callback for 1st-person shield blocking HUD
	x_api.register_on_state_change(function(player, out_state, _prev_loco, _prev_action)
		local is_blocking = ((out_state.blocking == true) or (out_state.action == "block"))
			and not out_state.aiming_bow and not out_state.shooting_bow
			and out_state.action ~= "bow_aim" and out_state.action ~= "bow_shoot"
		if is_blocking then
			x_player_armor.shield_hud.show(player)
		else
			x_player_armor.shield_hud.hide(player)
		end
	end)

	-- Register wield change listener for event-driven slot syncing (zero globalstep polling)
	if x_api.register_on_wield_change then
		x_api.register_on_wield_change(function(player, _wield_name, _prev_wield_name, _wielded, _current_wield_idx, _prev_wield_idx)
			-- Sync tracked wield state and combat HUD paperdoll slot 6
			x_player_armor.ui.check_wield_change(player)

			-- Immediately re-evaluate armor group modifiers, weapon enchantments, and physics
			x_player_armor.effects.update_player_armor(player)
		end)
	end

	core.log("action", "[x_player_armor] Successfully integrated advanced x_player_api methods.")
end

---Trigger equip montage and audio playback when an armor piece or shield is equipped
---@param player ObjectRef Target player
---@param item_name string Technical item name
function x_api_compat.on_equip(player, item_name)
	local x_api = get_api()
	if not x_api then
		return
	end
	local item_def = x_player_armor.get_armor_def(item_name)
	local custom_sound = item_def and (item_def.sound_equip or (item_def.sounds and item_def.sounds.equip))
	if custom_sound and custom_sound ~= "" then
		core.sound_play(custom_sound, {pos = player:get_pos(), gain = 0.8, max_hear_distance = 16.0})
	else
		x_api.play_equip_sound(player, item_name)
	end
	x_api.trigger_equip(player, item_name)
end

---Trigger hurt reaction flinch when player takes combat hit or armor absorbs damage
---@param player ObjectRef Target player
---@param duration? number Duration in seconds (default 0.3s)
function x_api_compat.trigger_hurt(player, duration)
	local x_api = get_api()
	if not x_api then
		return
	end
	x_api.trigger_hurt(player, duration or 0.3)
end

---Attaches an equipped shield to the player's left hand using x_player_api as a wielditem.
---Applies the forearm attachment transform (position and rotation) instead of generic hand grip.
---@param player ObjectRef Target player
---@param item_or_stack string|ItemStack Shield item name or stack
---@param custom_opts? XPlayerArmorShieldVisualOpts Optional transform and visual overrides
---@return ObjectRef|nil entity Attached entity reference
function x_api_compat.attach_shield(player, item_or_stack, custom_opts)
	local x_api = get_api()
	if not x_api then
		return nil
	end

	local first_person = x_api_compat.get_shield_first_person(player)
	local resolve_opts = custom_opts
	if (not custom_opts or (custom_opts.torso_item == nil and custom_opts.shield_clearance == nil)) and player then
		local _, inv = x_player_armor.get_valid_player(player)
		local torso_stack = inv and inv:get_stack("armor", 2)
		if torso_stack and not torso_stack:is_empty() then
			resolve_opts = custom_opts and table.copy(custom_opts) or {}
			resolve_opts.torso_item = torso_stack:get_name()
		end
	end
	local opts = x_player_armor.visuals.resolve_shield_visual_opts(item_or_stack, resolve_opts)

	local is_pure_b3d = (x_api.is_pure_native_b3d_active and x_api.is_pure_native_b3d_active(player)) or false
	local fp_visible = (custom_opts and custom_opts.first_person ~= nil)
		and (custom_opts.first_person == true)
		or ((first_person ~= false) and not is_pure_b3d)

	opts.first_person = fp_visible

	return x_api.attach_left_wield_item(player, item_or_stack, opts)
end

---Updates or modifies the attached left-hand shield entity using x_player_api
---@param player ObjectRef Target player
---@param item_or_stack? string|ItemStack Shield item name or stack
---@param custom_opts? XPlayerArmorShieldVisualOpts Optional transform and visual overrides
---@return ObjectRef|nil entity Attached entity reference or nil
function x_api_compat.update_shield(player, item_or_stack, custom_opts)
	local x_api = get_api()
	if not x_api or not x_api.update_left_wield_item then
		return nil
	end

	if custom_opts then
		return x_api_compat.attach_shield(player, item_or_stack, custom_opts)
	end

	return x_api.update_left_wield_item(player, item_or_stack)
end

---Removes the attached left-hand shield entity using x_player_api
---@param player ObjectRef Target player
function x_api_compat.remove_shield(player)
	local x_api = get_api()
	if not x_api or not x_api.remove_left_wield_item then
		return
	end
	x_api.remove_left_wield_item(player)
end

---Attaches a shield visual entity to an external parent entity (such as a corpse or mob)
---@param parent ObjectRef Target parent entity
---@param item_or_stack string|ItemStack Shield item name or stack
---@param format? string Model format ("glb" or "b3d")
---@param custom_opts? XPlayerArmorShieldVisualOpts Optional transform and visual overrides
---@return ObjectRef|nil entity Attached entity reference or nil
function x_api_compat.attach_shield_to_entity(parent, item_or_stack, format, custom_opts)
	return x_player_armor.visuals.attach_shield_to_entity(parent, item_or_stack, format, custom_opts)
end

---Sets whether the left-hand shield should be rendered in 1st person view
---@param player ObjectRef Target player
---@param enable boolean Whether 1st person view is enabled
function x_api_compat.set_shield_first_person(player, enable)
	local x_api = get_api()
	if not x_api or not x_api.set_left_wield_first_person then
		return
	end
	x_api.set_left_wield_first_person(player, enable)
end

---Gets whether the left-hand shield is rendered in 1st person view for a player
---@param player ObjectRef Target player
---@return boolean enabled
function x_api_compat.get_shield_first_person(player)
	local x_api = get_api()
	if not x_api or not x_api.get_left_wield_first_person then
		return false
	end
	return x_api.get_left_wield_first_person(player) == true
end

---Retrieves the item technical name currently wielded in the player's left hand via x_player_api.
---@param player ObjectRef Target player
---@return string item_name
function x_api_compat.get_left_wield_item(player)
	local x_api = get_api()
	if not x_api or not x_api.get_left_wield_item then
		return ""
	end
	return x_api.get_left_wield_item(player) or ""
end

core.register_on_mods_loaded(function()
	x_api_compat.init()
end)

x_player_armor.compat_x_player_api = x_api_compat
x_player_armor.compat.x_player_api = x_api_compat
return x_api_compat
