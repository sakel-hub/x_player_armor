-- X Player Armor - Shields Mod API Compatibility Shim (modules/compat/shields.lua)
-- Provides compatibility for third-party mods registering shields.
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class ShieldsCompat
local shields = {
	config = {
		drop = false,
		destroy = false,
		level_multiplier = 1,
		heal_multiplier = 1,
		water_protect = true,
	},
}

---Registers a shield item, ensuring it has armor_shield group.
---Supports both shields:register_shield and shields.register_shield syntax.
---@param self_or_name any
---@param maybe_name any
---@param maybe_def any
function shields.register_shield(self_or_name, maybe_name, maybe_def)
	local name, def
	if self_or_name == shields then
		name, def = maybe_name, maybe_def
	else
		name, def = self_or_name, maybe_name
	end

	def = def or {}
	def.groups = def.groups or {}
	def.groups.armor_shield = def.groups.armor_shield or 1
	def.groups.shield = def.groups.shield or 1
	if def.reciprocate_damage == nil then
		def.reciprocate_damage = true
	end
	x_player_armor.register_armor(name, def)
end

_G.shields = shields
x_player_armor.compat_shields = shields
x_player_armor.compat.shields = shields
core.log("action", "[x_player_armor] Global 'shields' compatibility shim successfully registered.")
return shields
