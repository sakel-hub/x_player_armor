-- X Player Armor - Engine Compatibility Hook (modules/compat/engine.lua)
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

-- luacheck: push
-- luacheck: ignore 122

local orig_get_modpath = core.get_modpath

local VIRTUAL_MODS = {
	["3d_armor"] = true,
	["shields"] = true,
	["3d_armor_stand"] = true,
	["3d_armor_ui"] = true,
	["3d_armor_sfinv"] = true,
	["3d_armor_ip"] = true,
}

---Virtual modpath resolver allowing 3rd-party mods to detect 3d_armor/shields support.
---@param modname string Name of queried mod
---@return string|nil path Filesystem path of requested or providing mod
core.get_modpath = function(modname)
	local real_path = orig_get_modpath(modname)
	if real_path then
		return real_path
	end
	if VIRTUAL_MODS[modname] then
		return orig_get_modpath("x_player_armor")
	end
	return nil
end

minetest.get_modpath = core.get_modpath

-- luacheck: pop

core.log("action", "[x_player_armor] Engine modpath virtualization active for 3d_armor and shields.")
