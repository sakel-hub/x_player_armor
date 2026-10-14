--[[
	X Player Armor - glTF 2.0 In-Memory Dynamic Model Assembler Facade
	Author: SaKeL
	License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

	Unified facade coordinating glTF binary assembly, armor piece detection,
	preview resolution, and dynamic media delivery for player formspecs and armor stands.
]]

local modpath = core.get_modpath("x_player_armor")
local constants = x_player_armor.constants

---@class XPlayerArmorGltfAssembler
---@field math XPlayerArmorAssemblerMath Linear algebra, transforms, and binary float/uint32 packing
---@field loader XPlayerArmorAssemblerLoader Model filesystem discovery and parsed glb caching
---@field builder XPlayerArmorAssemblerBuilder Binary glTF mesh transformation and chunk assembly
---@field media XPlayerArmorAssemblerMedia Dynamic media delivery pipeline and client readiness
---@field cache table<string, {bin: string, textures: string[]}> Combined GLB cache in RAM
---@field player_active_models table<string, string> Map of player names to currently active GLB models
local assembler = {
	cache = {},
	player_active_models = {},
}
x_player_armor.gltf_assembler = assembler

local math_mod = dofile(modpath .. "/modules/assembler/math.lua")
assembler.math = math_mod
local loader_mod = dofile(modpath .. "/modules/assembler/loader.lua")
assembler.loader = loader_mod
local builder_mod = dofile(modpath .. "/modules/assembler/builder.lua")
assembler.builder = builder_mod
local media_mod = dofile(modpath .. "/modules/assembler/media.lua")
assembler.media = media_mod

-- Backward-compatible delegations to sub-modules (single source of truth)
assembler.get_base_model = loader_mod.get_base_model
assembler.get_piece_model = loader_mod.get_piece_model
assembler.assemble_glb = builder_mod.assemble_glb
assembler.deliver_media = media_mod.deliver_media
assembler.is_media_ready = media_mod.is_media_ready
assembler.when_media_ready = media_mod.when_media_ready
assembler.mark_media_ready = media_mod.mark_media_ready
assembler.init = media_mod.init

-- Metatable fallback to delegate property accesses to respective sub-modules without duplicate state aliases
setmetatable(assembler, {
	__index = function(_, k)
		if loader_mod[k] ~= nil then return loader_mod[k] end
		if media_mod[k] ~= nil then return media_mod[k] end
		if builder_mod[k] ~= nil then return builder_mod[k] end
	end,
})

---Scans an armor inventory list and detects 3D mesh pieces to attach to the preview armature.
---@param armor_list (ItemStack|table)[] Armor inventory list
---@param custom_only boolean? If true, only detects explicitly defined custom 3D models (excluding standard fallbacks)
---@return boolean has_custom, table[] pieces_to_attach, table<string, boolean> slot_mask
function assembler.detect_custom_pieces(armor_list, custom_only)
	local pieces_to_attach = {}
	local slot_mask = {}
	local has_custom = false

	if not armor_list then
		return false, pieces_to_attach, slot_mask
	end

	for slot_idx = 1, 5 do
		local stack = armor_list[slot_idx]
		local element = constants.SLOT_ELEMENTS[slot_idx]
		if stack and element then
			local item_name = (type(stack) == "userdata" and stack:get_name())
				or (type(stack) == "table" and stack.get_name and stack:get_name())
				or (type(stack) == "table" and (stack.name or stack.item))
				or (type(stack) == "string" and stack)
				or ""

			local is_empty = (stack.is_empty and stack:is_empty()) or (item_name == "")

			if not is_empty and item_name ~= "" then
				local idef = (stack.get_definition and stack:get_definition())
					or x_player_armor.get_armor_def(item_name)

				local mod_hint = item_name:match("^([%w_]+):")
				local piece_ids = (idef and idef.pieces) or constants.ELEMENT_PIECES[element] or {element}

				local item_has_custom = false
				local found_pieces = {}

				for _, piece_id in ipairs(piece_ids) do
					local model_file = nil
					if idef then
						if idef.models and idef.models[piece_id] then
							model_file = idef.models[piece_id]
						elseif idef.meshes and idef.meshes[piece_id] then
							model_file = idef.meshes[piece_id]
						elseif (piece_id == element or #piece_ids == 1) and (idef.model or idef.mesh) then
							model_file = idef.model or idef.mesh
						end
					end

					-- Unified Pipeline: If no custom model defined on the item, resolve to standard modular 3D piece model
					if not custom_only and not model_file and constants.MODELS[piece_id] then
						model_file = constants.MODELS[piece_id]
					end

					-- Process valid 3D .glb / .gltf files
					if model_file and (model_file:find("%.glb$") or model_file:find("%.gltf$")) then
						local _, _, piece_sha1 = loader_mod.get_piece_model(model_file, mod_hint)
						table.insert(found_pieces, {
							piece_id = piece_id,
							element = element,
							model_file = model_file,
							mod_hint = mod_hint,
							item_def = idef,
							item_name = item_name,
							content_sha1 = piece_sha1 or "",
						})
						item_has_custom = true
					end
				end

				if item_has_custom then
					has_custom = true
					slot_mask[element] = true
					for i = 1, #found_pieces do
						table.insert(pieces_to_attach, found_pieces[i])
					end
				end
			end
		end
	end

	return has_custom, pieces_to_attach, slot_mask
end

---Resolves all custom textures in order for a set of attached pieces.
---@param pieces table[] Array of piece descriptor tables
---@return string[] textures List of texture filenames
local function resolve_pieces_textures(pieces)
	local result = {}
	for _, p in ipairs(pieces) do
		local p_json, _ = loader_mod.get_piece_model(p.model_file, p.mod_hint)
		local p_texs = builder_mod.get_piece_textures(p, p_json)
		for _, t in ipairs(p_texs) do
			table.insert(result, t)
		end
	end
	return result
end

local function get_stack_item_name(stack)
	if not stack then return "" end
	if type(stack) == "userdata" or (type(stack) == "table" and stack.get_name) then
		if stack.is_empty and stack:is_empty() then return "" end
		return stack:get_name() or ""
	elseif type(stack) == "table" then
		return stack.name or stack.item or ""
	elseif type(stack) == "string" then
		return stack:match("%S+") or ""
	end
	return ""
end

---Resolves the standard 6-slot base textures array for preview model or armor stand.
---@param armor_list (ItemStack|table)[] Array of equipped armor items
---@param skin_info? table Player skin definition { body10 = string, body18 = string }
---@return string[] textures 6-slot material texture array
function assembler.resolve_base_preview_textures(armor_list, skin_info)
	local textures = {
		(skin_info and skin_info.body10) or "blank.png",
		(skin_info and skin_info.body18) or "blank.png",
		"blank.png",
		"blank.png",
		"blank.png",
		"blank.png",
	}

	if armor_list then
		for slot = 1, 4 do
			local iname = get_stack_item_name(armor_list[slot])
			if iname ~= "" then
				textures[slot + 2] = x_player_armor.visuals.get_item_texture(iname) or "blank.png"
			end
		end
	end

	return textures
end

---Retrieves or creates the assembled GLB binary and textures from RAM cache or bounded disk cache.
---@param pieces table[] Array of piece descriptor tables
---@param prefix string Cache key and model filename prefix
---@return string model_filename, table? assembled_data
local function get_or_assemble_glb(pieces, prefix)
	local custom_tex_list = resolve_pieces_textures(pieces)
	local _, _, base_sha1 = loader_mod.get_base_model()

	-- Calculate deterministic combination hash including content SHA-1 and textures for hot-reloading
	local hash_parts = { "base:" .. (base_sha1 or "") }
	for _, p in ipairs(pieces) do
		table.insert(hash_parts, p.piece_id .. ":" .. p.model_file .. ":" .. (p.content_sha1 or ""))
	end
	for _, t in ipairs(custom_tex_list) do
		table.insert(hash_parts, "tex:" .. t)
	end
	table.sort(hash_parts)
	local combo_hash = prefix .. core.sha1(table.concat(hash_parts, "|"))
	local model_filename = combo_hash .. ".glb"

	local assembled_data = assembler.cache[combo_hash]
	if not assembled_data then
		-- Check L2 disk cache first for zero-rebuild hit
		local cached_filepath = media_mod.get_cached_filepath(model_filename)
		if cached_filepath then
			assembled_data = {
				filepath = cached_filepath,
				textures = custom_tex_list,
			}
			assembler.cache[combo_hash] = assembled_data
		else
			local bin_str, assembled_tex_list = builder_mod.assemble_glb(pieces)
			if bin_str then
				local saved_filepath = media_mod.save_cached_file(model_filename, bin_str)
				assembled_data = {
					bin = bin_str,
					filepath = saved_filepath,
					textures = assembled_tex_list or custom_tex_list,
				}
				assembler.cache[combo_hash] = assembled_data
			end
		end
	end

	return model_filename, assembled_data
end

---Resolves the dynamic preview model and composite textures for a player.
---@param player ObjectRef Player object reference
---@return string? model_name, string? textures_str Comma-separated textures string
function assembler.resolve_player_preview(player)
	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then return nil, nil end

	local armor_list = inv:get_list("armor")
	if not armor_list then return nil, nil end

	local has_custom, pieces, slot_mask = assembler.detect_custom_pieces(armor_list)
	if not has_custom or #pieces == 0 then
		assembler.player_active_models[name] = nil
		return nil, nil
	end

	local model_filename, assembled_data = get_or_assemble_glb(pieces, "x_pa_v21_")
	if not assembled_data then
		return nil, nil
	end

	-- Deliver via core.dynamic_add_media (in memory or bounded on-disk cache)
	media_mod.deliver_media(model_filename, assembled_data.bin, name, assembled_data.filepath)
	assembler.player_active_models[name] = model_filename

	-- Compose 6 base material slots + custom slots
	local skin_info = x_player_armor.skins.resolve_player_skin(player)
	local textures_array = assembler.resolve_base_preview_textures(armor_list, skin_info)
	if slot_mask.head then textures_array[3] = "blank.png" end
	if slot_mask.torso then textures_array[4] = "blank.png" end
	if slot_mask.legs then textures_array[5] = "blank.png" end
	if slot_mask.feet then textures_array[6] = "blank.png" end

	for _, ctex in ipairs(assembled_data.textures or {}) do
		table.insert(textures_array, ctex)
	end

	return model_filename, table.concat(textures_array, ",")
end

---Resolves the preview model and composite textures array for an armor stand.
---Stands now use the canonical static mannequin (x_player_armor_stand.glb) with modular bone attachments.
---Kept for backward compatibility.
---@param _armor_list (ItemStack|table)[] Stand armor inventory list
---@param base_textures? string[] Standard stand textures array
---@return string model_name, string[] textures_array
function assembler.resolve_stand_preview(_armor_list, base_textures)
	return constants.MODELS.stand, base_textures or {"x_player_armor_stand_shared.png"}
end

---Unified preview resolution entry point for both player formspec and in-world armor stand.
---@param armor_list (ItemStack|table)[] Equipped items array
---@param opts? table Options: { player = ObjectRef, is_stand = boolean, base_textures = string[] }
---@return string model_name, string|string[] textures Resolved model filename and texture specification
function assembler.resolve_preview(armor_list, opts)
	opts = opts or {}
	if opts.is_stand then
		local base_tex = opts.base_textures or {"x_player_armor_stand_shared.png"}
		return constants.MODELS.stand, base_tex
	else
		local dyn_model, dyn_tex_str = nil, nil
		if opts.player then
			dyn_model, dyn_tex_str = assembler.resolve_player_preview(opts.player)
		end
		if dyn_model and dyn_tex_str then
			return dyn_model, dyn_tex_str
		end
		local skin_info = opts.player and x_player_armor.skins.resolve_player_skin(opts.player)
		local base_texs = assembler.resolve_base_preview_textures(armor_list, skin_info)
		return constants.MODELS.preview, table.concat(base_texs, ",")
	end
end

---Eagerly triggers background assembly and delivery when a player's equipment changes.
---@param player ObjectRef Player reference
function assembler.update_player(player)
	if not player or not player:is_player() then return end
	assembler.resolve_player_preview(player)
end

---Retrieves the active dynamic model for a player if one is active.
---@param player ObjectRef Player reference
---@return string? model_name Active model filename or nil
function assembler.get_active_player_model(player)
	local name = player:get_player_name()
	if name then
		return assembler.player_active_models[name]
	end
	return nil
end

---Clears all in-memory dynamic media caches and active player previews.
function assembler.clear_cache()
	assembler.cache = {}
	assembler.player_active_models = {}
	loader_mod.clear_cache()
	media_mod.clear_cache()
end

x_player_armor.clear_media_cache = assembler.clear_cache

core.register_chatcommand("armor_reload_cache", {
	params = "",
	description = "Reload and re-assemble all dynamic 3D armor models and clear media cache",
	privs = {server = true},
	func = function()
		assembler.clear_cache()
		for _, player in ipairs(core.get_connected_players()) do
			assembler.update_player(player)
		end
		return true, "Player armor dynamic media cache cleared and refreshed."
	end,
})

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if name then
		assembler.player_active_models[name] = nil
		media_mod.cleanup_player(name)
	end
end)

core.register_on_mods_loaded(function()
	assembler.init()
end)

return assembler
