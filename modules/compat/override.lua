-- X Player Armor - Legacy 3D Armor Override & Neutralizer (modules/compat/override.lua)
-- Provides dynamic runtime neutralization of legacy 3d_armor engine callbacks and seamless takeover.
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class XPlayerArmorOverride
---@field legacy_detected boolean
---@field join_hook_registered boolean
---@field captured_legacy_armor table|nil
local override = {
	legacy_detected = false,
	join_hook_registered = false,
	captured_legacy_armor = nil,
}


---Checks if a callback function originates from legacy 3d_armor, shields, or wieldview mods.
---Uses standard Lua debug introspection to verify the declaring file source.
---@param fn any
---@return boolean
function override.is_legacy_callback(fn)
	if type(fn) ~= "function" then return false end

	-- Introspect function source path across all operating systems
	local info = debug.getinfo(fn, "S")
	if not info or not info.source then return false end

	local src = info.source:lower():gsub("\\", "/")
	if src:find("/x_player_armor") or src:find("x_player_armor") then
		return false
	end
	return src:find("/3d_armor") ~= nil or src:find("/shields") ~= nil or src:find("/wieldview") ~= nil
end

---Neutralizes callbacks matching legacy 3d_armor in a Luanti callback table.
---@param tbl table|nil
---@param name string
---@param is_hpchange_modifier boolean|nil True if table is registered_on_player_hpchanges.modifiers
---@return integer count Number of callbacks neutralized
function override.strip_callbacks(tbl, name, is_hpchange_modifier)
	if not tbl or type(tbl) ~= "table" then return 0 end
	local count = 0
	local dummy_func = is_hpchange_modifier and function(_player, hp_change, _reason)
		return hp_change
	end or function() end

	for i = 1, #tbl do
		local entry = tbl[i]
		local fn = (type(entry) == "table" and entry.func) or entry
		if override.is_legacy_callback(fn) then
			if type(entry) == "table" then
				entry.func = dummy_func
			else
				tbl[i] = dummy_func
			end
			count = count + 1
		end
	end
	if count > 0 then
		core.log("action", string.format("[x_player_armor] Neutralized %d legacy 3d_armor callbacks in %s.", count, name))
	end
	return count
end

---Restores clean player model on join, prioritizing x_player_api over standard player_api.
---@param player ObjectRef
local function restore_clean_model(player)
	if not player or not player:is_player() then return end

	local function check_and_clean(p)
		if not p or not p:is_player() or not p:is_valid() then return end

		-- Prioritize x_player_api visual pipeline when available
		local x_api = x_player_armor.get_mod_api("x_player_api")
		if x_api and x_api.set_model then
			local cur_model = x_api.get_model_name and x_api.get_model_name(p)
			if cur_model and (cur_model == "3d_armor_character.b3d" or cur_model:find("3d_armor")) then
				local default_model = (x_api.get_default_model and x_api.get_default_model()) or "character"
				x_api.set_model(p, default_model)
			end
			return
		end

		-- Fallback to standard player_api
		local p_api = x_player_armor.get_mod_api("player_api")
		if p_api and p_api.set_model then
			local cur_model = p_api.get_model and p_api.get_model(p)
			if cur_model and (cur_model == "3d_armor_character.b3d" or cur_model:find("3d_armor")) then
				p_api.set_model(p, "character.b3d")
			end
		end
	end

	-- Clean immediately during join processing
	check_and_clean(player)

	-- Verify on tick 0 to guarantee model cleanliness against deferred join routines
	core.after(0, function()
		check_and_clean(player)
	end)
end

---Cleans up a legacy armor/shield item registration, clearing its legacy craft recipes
---and enforcing a clean Luanti alias to its modern x_player_armor equivalent.
---@param legacy_name string Technical name of the legacy item (e.g., "3d_armor:helmet_diamond")
---@param modern_name string Technical name of the modern equivalent (e.g., "x_player_armor:helmet_diamond")
function override.cleanup_legacy_item(legacy_name, modern_name)
	if not legacy_name or not modern_name then return end
	local clean_legacy = legacy_name:gsub("^:", "")
	local clean_modern = modern_name:gsub("^:", "")

	-- Clear any legacy craft recipes producing this legacy item without emitting engine warnings
	local recipes = core.get_all_craft_recipes(clean_legacy)
	if recipes and #recipes > 0 then
		core.clear_craft({output = clean_legacy})
		core.log("action", string.format("[x_player_armor] Cleared %d legacy craft recipe(s) for '%s'.", #recipes, clean_legacy))
	end

	-- Ensure legacy item is purged from x_player_armor.registered_armors
	x_player_armor.registered_armors[clean_legacy] = nil
	x_player_armor.registered_armors[":" .. clean_legacy] = nil

	-- Also remove from captured legacy armor table to avoid redundant reprocessing
	if override.captured_legacy_armor and override.captured_legacy_armor.registered_armors then
		override.captured_legacy_armor.registered_armors[clean_legacy] = nil
		override.captured_legacy_armor.registered_armors[":" .. clean_legacy] = nil
	end

	-- Check if item was registered in engine registries
	local item_existed = (core.registered_items and core.registered_items[clean_legacy] ~= nil) or
			(core.registered_tools and core.registered_tools[clean_legacy] ~= nil) or
			(core.registered_nodes and core.registered_nodes[clean_legacy] ~= nil) or
			(core.registered_craftitems and core.registered_craftitems[clean_legacy] ~= nil)

	-- Unregister item from engine and enforce alias to modern equivalent
	core.register_alias_force(clean_legacy, clean_modern)

	-- Defensive cleanup of Luanti item registries
	if core.registered_items then rawset(core.registered_items, clean_legacy, nil) end
	if core.registered_tools then rawset(core.registered_tools, clean_legacy, nil) end
	if core.registered_nodes then rawset(core.registered_nodes, clean_legacy, nil) end
	if core.registered_craftitems then rawset(core.registered_craftitems, clean_legacy, nil) end
	if core.registered_aliases then rawset(core.registered_aliases, clean_legacy, clean_modern) end

	if item_existed then
		core.log("action", string.format("[x_player_armor] Cleaned up legacy registration: '%s' -> '%s'.", clean_legacy, clean_modern))
	end
end

---Executes runtime takeover and neutralization of legacy 3d_armor when both mods are loaded.
function override.takeover_legacy_armor()
	local current_armor = rawget(_G, "armor")
	if current_armor and not current_armor._is_x_player_armor then
		override.legacy_detected = true
		override.captured_legacy_armor = current_armor
		core.log("warning", "[x_player_armor] Legacy 3d_armor detected! Initiating runtime override and takeover.")
	end

	-- Cleanup all legacy items that x_player_armor provides replacements for
	local replacements = x_player_armor.legacy_replacements or {}
	for legacy_name, modern_name in pairs(replacements) do
		local clean_legacy = legacy_name:gsub("^:", "")
		local clean_modern = modern_name:gsub("^:", "")
		local in_legacy = override.captured_legacy_armor and
				override.captured_legacy_armor.registered_armors and
				(override.captured_legacy_armor.registered_armors[clean_legacy] ~= nil or
				 override.captured_legacy_armor.registered_armors[":" .. clean_legacy] ~= nil)
		local recipes = core.get_all_craft_recipes(clean_legacy)
		local has_recipes = recipes and #recipes > 0
		local is_registered = (core.registered_items and core.registered_items[clean_legacy] ~= nil) or
				(core.registered_tools and core.registered_tools[clean_legacy] ~= nil) or
				(core.registered_nodes and core.registered_nodes[clean_legacy] ~= nil) or
				(core.registered_craftitems and core.registered_craftitems[clean_legacy] ~= nil) or
				in_legacy or has_recipes

		if is_registered then
			override.cleanup_legacy_item(clean_legacy, clean_modern)
		else
			core.register_alias(clean_legacy, clean_modern)
		end
	end

	if not override.legacy_detected then
		return
	end

	-- Ingest already-registered armor items from legacy armor.registered_armors
	local old_armor = override.captured_legacy_armor
	if old_armor and type(old_armor.registered_armors) == "table" then
		for item_name, def in pairs(old_armor.registered_armors) do
			local clean_name = item_name:gsub("^:", "")
			local superseded_by = x_player_armor.get_legacy_replacement(clean_name)
			if superseded_by then
				override.cleanup_legacy_item(clean_name, superseded_by)
			elseif not x_player_armor.registered_armors[clean_name] and type(def) == "table" then
				local clean_def = table.copy(def)
				setmetatable(clean_def, nil)
				x_player_armor.register_armor(clean_name, clean_def)
			end
		end
	end

	-- Ingest registered armor groups from core.registered_tools
	if type(core.registered_tools) == "table" then
		for item_name, def in pairs(core.registered_tools) do
			local clean_name = item_name:gsub("^:", "")
			local superseded_by = x_player_armor.get_legacy_replacement(clean_name)
			if superseded_by then
				override.cleanup_legacy_item(clean_name, superseded_by)
			elseif def and def.groups and not x_player_armor.registered_armors[clean_name] and type(def) == "table" then
				local is_armor = (def.groups.armor_head or 0) > 0 or
						(def.groups.armor_torso or 0) > 0 or
						(def.groups.armor_legs or 0) > 0 or
						(def.groups.armor_feet or 0) > 0 or
						(def.groups.armor_shield or 0) > 0 or
						(def.groups.shield or 0) > 0
				if is_armor then
					local clean_def = table.copy(def)
					setmetatable(clean_def, nil)
					x_player_armor.register_armor(clean_name, clean_def)
				end
			end
		end
	end

	-- Transfer any non-internal callbacks registered on legacy armor
	if old_armor and type(old_armor.registered_callbacks) == "table" then
		for event, fns in pairs(old_armor.registered_callbacks) do
			if type(fns) == "table" then
				for i = 1, #fns do
					local fn = fns[i]
					if not override.is_legacy_callback(fn) then
						if event == "on_equip" then
							x_player_armor.register_on_equip(fn)
						elseif event == "on_unequip" then
							x_player_armor.register_on_unequip(fn)
						elseif event == "on_damage" then
							x_player_armor.register_on_damage(fn)
						elseif event == "on_destroy" then
							x_player_armor.register_on_destroy(fn)
						elseif event == "on_update" then
							x_player_armor.register_on_update(fn)
						end
					end
				end
			end
		end
	end

	-- Neutralize engine callbacks registered by legacy 3d_armor, shields, and wieldview
	override.strip_callbacks(core.registered_globalsteps, "registered_globalsteps")
	override.strip_callbacks(core.registered_on_joinplayers, "registered_on_joinplayers")
	override.strip_callbacks(core.registered_on_leaveplayers, "registered_on_leaveplayers")
	override.strip_callbacks(core.registered_on_dieplayers, "registered_on_dieplayers")
	override.strip_callbacks(core.registered_on_respawnplayers, "registered_on_respawnplayers")
	override.strip_callbacks(core.registered_on_punchplayers, "registered_on_punchplayers")
	override.strip_callbacks(core.registered_on_player_receive_fields, "registered_on_player_receive_fields")
	if core.registered_on_player_hpchanges then
		if core.registered_on_player_hpchanges.modifiers then
			override.strip_callbacks(core.registered_on_player_hpchanges.modifiers, "registered_on_player_hpchanges.modifiers", true)
		end
		if core.registered_on_player_hpchanges.loggers then
			override.strip_callbacks(core.registered_on_player_hpchanges.loggers, "registered_on_player_hpchanges.loggers", false)
		end
		if #core.registered_on_player_hpchanges > 0 then
			override.strip_callbacks(core.registered_on_player_hpchanges, "registered_on_player_hpchanges", true)
		end
	end

	-- Neutralize duplicate sfinv tab (3d_armor_sfinv)
	local sfinv_api = x_player_armor.get_mod_api("sfinv")
	if sfinv_api and sfinv_api.pages and sfinv_api.pages["3d_armor:armor"] then
		sfinv_api.pages["3d_armor:armor"] = nil
		if type(sfinv_api.pages_unordered) == "table" then
			for idx = #sfinv_api.pages_unordered, 1, -1 do
				local page = sfinv_api.pages_unordered[idx]
				if page and page.name == "3d_armor:armor" then
					table.remove(sfinv_api.pages_unordered, idx)
				end
			end
		end
		core.log("action", "[x_player_armor] Suppressed duplicate legacy '3d_armor:armor' sfinv tab.")
	end

	-- Neutralize duplicate unified_inventory tab (3d_armor_ui)
	local uni_inv = x_player_armor.get_mod_api("unified_inventory")
	if uni_inv and type(uni_inv.registered_buttons) == "table" then
		for idx = #uni_inv.registered_buttons, 1, -1 do
			local btn = uni_inv.registered_buttons[idx]
			if btn and btn.name == "armor" and override.is_legacy_callback(btn.action) then
				table.remove(uni_inv.registered_buttons, idx)
				core.log("action", "[x_player_armor] Suppressed duplicate legacy '3d_armor_ui' unified_inventory tab.")
				break
			end
		end
	end

	-- Ensure player model restoration hook is registered exactly once
	if not override.join_hook_registered then
		override.join_hook_registered = true
		core.register_on_joinplayer(restore_clean_model)
	end
end

x_player_armor.override = override
return override
