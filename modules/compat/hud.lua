-- X Player Armor - HUD Statbar Compatibility (modules/compat/hud.lua)
-- Provides compatibility for hbarmor and custom armor HUD statbar mods.
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class XPlayerArmorCompatHUD
local hud = {}

---Default dummy defense table returned for uninitialized or offline players
local function create_default_player_def()
	return {
		state = 0,
		count = 0,
		level = 0,
		groups = setmetatable({}, {
			__index = function() return 0 end,
		}),
		heal = 0,
		fire = 0,
		water = 0,
		feather = 0,
	}
end

-- Ensure x_player_armor.def has a safe fallback metatable
setmetatable(x_player_armor.def, {
	__index = function(t, k)
		if type(k) == "string" then
			local d = create_default_player_def()
			rawset(t, k, d)
			return d
		end
		return nil
	end,
})

---Recalculate and synchronize armor.def fields specifically needed by HUD statbars (e.g. hbarmor).
---Updates player_def.state (sum of wear across worn pieces, 0..262140), count, level, and groups.
---@param player ObjectRef Target player
---@param inv any Detached armor inventory
function hud.sync_player_hud_def(player, inv)
	if not player or not player:is_player() then
		return
	end
	local name = player:get_player_name()
	local pdef = rawget(x_player_armor.def, name)
	if not pdef then
		pdef = create_default_player_def()
		rawset(x_player_armor.def, name, pdef)
	end

	if not pdef.groups or not getmetatable(pdef.groups) then
		pdef.groups = setmetatable(pdef.groups or {}, {
			__index = function() return 0 end,
		})
	end

	local list = inv and inv:get_list("armor")
	if not list then
		pdef.state = 0
		pdef.count = 0
		return
	end

	local total_wear = 0
	local item_count = 0

	for i = 1, #list do
		local stack = list[i]
		if stack and not stack:is_empty() then
			item_count = item_count + 1
			total_wear = total_wear + stack:get_wear()
		end
	end

	pdef.state = total_wear
	pdef.count = item_count
end

x_player_armor.compat_hud = hud
x_player_armor.compat.hud = hud
return hud
