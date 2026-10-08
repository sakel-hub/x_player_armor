-- X Player Armor - 3D Armor Stand API Compatibility Shim (modules/compat/stand.lua)
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class ArmorStandCompat
local stand_compat = {
	---Returns formspec for armor stand (stub for legacy mods).
	---@param pos vector
	---@param player? ObjectRef
	---@return string
	get_armor_formspec = function(pos, player)
		if player and x_player_armor.stand and x_player_armor.stand.get_stand_formspec then
			return x_player_armor.stand.get_stand_formspec(pos, player)
		end
		return ""
	end,

	---Forces visual update on stand entity at pos.
	---@param pos vector
	update_entity = function(pos)
		x_player_armor.stand.update_stand_entity(pos)
	end,

	---Finds the mannequin entity at pos.
	---@param pos vector
	---@return ObjectRef?
	get_stand_object = function(pos)
		return x_player_armor.stand.get_stand_entity(pos)
	end,

	---Drops all armor from stand inventory onto the ground.
	---@param pos vector
	drop_armor = function(pos)
		local meta = core.get_meta(pos)
		local inv = meta:get_inventory()
		if not inv then return end
		local list = inv:get_list("armor")
		if not list then return end
		for i = 1, #list do
			local stack = list[i]
			if stack and not stack:is_empty() then
				core.add_item(pos, stack)
				inv:set_stack("armor", i, ItemStack(""))
			end
		end
		x_player_armor.stand.update_stand_entity(pos)
	end,

	---Checks if player owns or has bypass privileges for a locked stand.
	---@param meta NodeMetaRef
	---@param player? ObjectRef
	---@return boolean
	has_locked_armor_stand_privilege = function(meta, player)
		if not player or not player:is_player() then return false end
		local name = player:get_player_name()
		if core.check_player_privs(name, {protection_bypass = true}) then
			return true
		end
		return name == meta:get_string("owner")
	end,
}

_G["3d_armor_stand"] = stand_compat
x_player_armor.compat_stand = stand_compat
x_player_armor.compat.stand = stand_compat
core.log("action", "[x_player_armor] Global '3d_armor_stand' compatibility shim registered.")
return stand_compat
