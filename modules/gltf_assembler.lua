--[[
	X Player Armor - glTF 2.0 In-Memory Dynamic Model Assembler Facade
	Author: SaKeL
	License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

	Unified facade coordinating glTF binary assembly, armor piece detection,
	preview resolution, and dynamic media delivery for player formspecs and armor stands.
]]

local modpath = core.get_modpath("x_player_armor")
local math_mod = dofile(modpath .. "/modules/assembler/math.lua")
local loader_mod = dofile(modpath .. "/modules/assembler/loader.lua")
local builder_mod = dofile(modpath .. "/modules/assembler/builder.lua")
local media_mod = dofile(modpath .. "/modules/assembler/media.lua")
local constants = x_player_armor.constants

---@class XPlayerArmorGltfAssembler
---@field math XPlayerArmorAssemblerMath Linear algebra, transforms, and binary float/uint32 packing
---@field loader XPlayerArmorAssemblerLoader Model filesystem discovery and parsed glb caching
---@field builder XPlayerArmorAssemblerBuilder Binary glTF mesh transformation and chunk assembly
---@field media XPlayerArmorAssemblerMedia Dynamic media delivery pipeline and client readiness
---@field cache table<string, {bin: string, textures: string[]}> Combined GLB cache in RAM
---@field piece_cache table<string, table> Parsed piece models cache
---@field base_model table? Parsed base preview model cache
---@field delivered_media table<string, boolean> Map of media files sent to dynamic_add_media
---@field client_ready_media table<string, boolean> Map of media files acknowledged as ready on client
---@field ready_callbacks table<string, fun()[]> Pending client readiness callbacks
---@field player_active_models table<string, string> Map of player names to currently active GLB models
local assembler = {
	math = math_mod,
	loader = loader_mod,
	builder = builder_mod,
	media = media_mod,
	cache = {},
	piece_cache = loader_mod.piece_cache,
	base_model = loader_mod.base_model,
	delivered_media = media_mod.delivered_media,
	client_ready_media = media_mod.client_ready_media,
	ready_callbacks = media_mod.ready_callbacks,
	player_active_models = {},
}

-- Backward-compatible delegations to sub-modules
assembler.get_base_model = loader_mod.get_base_model
assembler.get_piece_model = loader_mod.get_piece_model
assembler.assemble_glb = builder_mod.assemble_glb
assembler.deliver_media = media_mod.deliver_media
assembler.is_media_ready = media_mod.is_media_ready
assembler.when_media_ready = media_mod.when_media_ready
assembler.mark_media_ready = media_mod.mark_media_ready
assembler.init = media_mod.init

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
					or (x_player_armor.registered_armors and x_player_armor.registered_armors[item_name])
					or core.registered_items[item_name]

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
					if not custom_only and not model_file and constants.MODELS and constants.MODELS[piece_id] then
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

---Resolves the standard 6-slot base textures array for preview model or armor stand.
---@param armor_list (ItemStack|table)[] Array of equipped armor items
---@param skin_info? table Player skin definition { body10 = string, body18 = string }
---@param _wield_tex? string Held item texture (deprecated, kept for compatibility)
---@return string[] textures 6-slot material texture array
function assembler.resolve_base_preview_textures(armor_list, skin_info, _wield_tex)
	local head_tex = "blank.png"
	local torso_tex = "blank.png"
	local legs_tex = "blank.png"
	local feet_tex = "blank.png"

	if armor_list then
		if armor_list[1] and not armor_list[1]:is_empty() then
			head_tex = x_player_armor.visuals.get_item_texture(armor_list[1]:get_name()) or "blank.png"
		end
		if armor_list[2] and not armor_list[2]:is_empty() then
			torso_tex = x_player_armor.visuals.get_item_texture(armor_list[2]:get_name()) or "blank.png"
		end
		if armor_list[3] and not armor_list[3]:is_empty() then
			legs_tex = x_player_armor.visuals.get_item_texture(armor_list[3]:get_name()) or "blank.png"
		end
		if armor_list[4] and not armor_list[4]:is_empty() then
			feet_tex = x_player_armor.visuals.get_item_texture(armor_list[4]:get_name()) or "blank.png"
		end
	end

	return {
		(skin_info and skin_info.body10) or "blank.png",
		(skin_info and skin_info.body18) or "blank.png",
		head_tex,
		torso_tex,
		legs_tex,
		feet_tex,
	}
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
	local combo_hash = "x_pa_v16_" .. core.sha1(table.concat(hash_parts, "|"))
	local model_filename = combo_hash .. ".glb"

	local assembled_data = assembler.cache[combo_hash]
	if not assembled_data then
		local bin_str, assembled_tex_list = builder_mod.assemble_glb(pieces)
		if bin_str then
			assembler.cache[combo_hash] = {
				bin = bin_str,
				textures = assembled_tex_list,
			}
			assembled_data = assembler.cache[combo_hash]
		end
	end

	if not assembled_data then
		return nil, nil
	end

	-- Deliver via core.dynamic_add_media (in memory)
	media_mod.deliver_media(model_filename, assembled_data.bin, name)
	assembler.player_active_models[name] = model_filename

	-- Helper to resolve slot texture or blank if masked
	local function resolve_slot_tex(slot_num, is_masked)
		if is_masked then return "blank.png" end
		local stack = armor_list[slot_num]
		if stack and not stack:is_empty() then
			return x_player_armor.visuals.get_item_texture(stack:get_name()) or "blank.png"
		end
		return "blank.png"
	end

	-- Compose 6 base material slots + custom slots
	local skin_info = x_player_armor.skins.resolve_player_skin(player)
	local head_tex = resolve_slot_tex(1, slot_mask.head)
	local torso_tex = resolve_slot_tex(2, slot_mask.torso)
	local legs_tex = resolve_slot_tex(3, slot_mask.legs)
	local feet_tex = resolve_slot_tex(4, slot_mask.feet)

	local textures_array = {
		skin_info.body10,
		skin_info.body18,
		head_tex,
		torso_tex,
		legs_tex,
		feet_tex,
	}

	for _, ctex in ipairs(assembled_data.textures or {}) do
		table.insert(textures_array, ctex)
	end

	return model_filename, table.concat(textures_array, ",")
end

---Resolves the dynamic preview model and composite textures array for an armor stand.
---@param armor_list (ItemStack|table)[] Stand armor inventory list
---@param base_textures string[] Standard stand 6-slot textures array
---@return string? model_name, string[]? textures_array
function assembler.resolve_stand_preview(armor_list, base_textures)
	local has_custom, pieces, slot_mask = assembler.detect_custom_pieces(armor_list, true)
	if not has_custom or #pieces == 0 then
		return nil, nil
	end

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
	local combo_hash = "x_pa_stand_v16_" .. core.sha1(table.concat(hash_parts, "|"))
	local model_filename = combo_hash .. ".glb"

	local assembled_data = assembler.cache[combo_hash]
	if not assembled_data then
		local bin_str, assembled_tex_list = builder_mod.assemble_glb(pieces)
		if bin_str then
			assembler.cache[combo_hash] = {
				bin = bin_str,
				textures = assembled_tex_list,
			}
			assembled_data = assembler.cache[combo_hash]
		end
	end

	if not assembled_data then
		return nil, nil
	end

	-- Broadcast stand models globally to all players so anyone walking up can see it
	media_mod.deliver_media(model_filename, assembled_data.bin, nil)

	-- Clone base textures and mask replaced prebaked slots
	local textures_array = table.copy(base_textures)
	if slot_mask.head then textures_array[3] = "blank.png" end
	if slot_mask.torso then textures_array[4] = "blank.png" end
	if slot_mask.legs then textures_array[5] = "blank.png" end
	if slot_mask.feet then textures_array[6] = "blank.png" end

	for _, ctex in ipairs(assembled_data.textures or {}) do
		table.insert(textures_array, ctex)
	end

	return model_filename, textures_array
end

---Unified preview resolution entry point for both player formspec and in-world armor stand.
---@param armor_list (ItemStack|table)[] Equipped items array
---@param opts? table Options: { player = ObjectRef, is_stand = boolean, base_textures = string[], wield_tex = string }
---@return string model_name, string|string[] textures Resolved model filename and texture specification
function assembler.resolve_preview(armor_list, opts)
	opts = opts or {}
	if opts.is_stand then
		local base_tex = opts.base_textures or assembler.resolve_base_preview_textures(armor_list, nil, opts.wield_tex)
		local mesh, texs = assembler.resolve_stand_preview(armor_list, base_tex)
		return mesh or constants.MODELS.stand_entity, texs or base_tex
	else
		local dyn_model, dyn_tex_str = nil, nil
		if opts.player then
			dyn_model, dyn_tex_str = assembler.resolve_player_preview(opts.player)
		end
		if dyn_model and dyn_tex_str then
			return dyn_model, dyn_tex_str
		end
		local skin_info = opts.player and x_player_armor.skins.resolve_player_skin(opts.player)
		local wield_tex = opts.wield_tex or (opts.player and x_player_armor.ui.get_wield_texture(opts.player)) or "blank.png"
		local base_texs = assembler.resolve_base_preview_textures(armor_list, skin_info, wield_tex)
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
	assembler.piece_cache = loader_mod.piece_cache
	assembler.base_model = loader_mod.base_model
	assembler.delivered_media = media_mod.delivered_media
	assembler.client_ready_media = media_mod.client_ready_media
	assembler.ready_callbacks = media_mod.ready_callbacks
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

x_player_armor.gltf_assembler = assembler

if core.register_on_mods_loaded then
	core.register_on_mods_loaded(function()
		assembler.init()
	end)
else
	assembler.init()
end

return assembler
