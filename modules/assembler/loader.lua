--[[
	X Player Armor - glTF 2.0 In-Memory Dynamic Model Assembler: Model Loader Subsystem
	Author: SaKeL
	License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

	Handles model filesystem discovery, binary .glb chunk parsing, and in-memory
	caching with automatic SHA-1 checksum hot-reload invalidation.
]]

local modpath = core.get_modpath("x_player_armor")
local math_mod = x_player_armor.gltf_assembler.math
local constants = x_player_armor.constants

---@class XPlayerArmorAssemblerLoader
---@field piece_cache table<string, table> Cached parsed piece models
---@field base_model table? Cached parsed base preview model
---@field math XPlayerArmorAssemblerMath Math submodule reference
local loader = {
	piece_cache = {},
	base_model = nil,
	math = math_mod,
}

---Parses an in-memory or loaded binary .glb file into JSON table and BIN string.
---@param content string Raw binary .glb string
---@return table? gltf_json, string? bin_data
function loader.parse_glb_content(content)
	if not content or #content < 20 then return nil, nil end
	local magic = math_mod.read_uint32(content, 1)
	local ver = math_mod.read_uint32(content, 5)
	if magic ~= 0x46546C67 or ver ~= 2 then
		return nil, nil
	end

	local json_len = math_mod.read_uint32(content, 13)
	local json_type = math_mod.read_uint32(content, 17)
	if json_type ~= 0x4E4F534A then
		return nil, nil
	end

	local json_str = string.sub(content, 21, 21 + json_len - 1)
	local gltf_json = core.parse_json(json_str)
	if not gltf_json then
		return nil, nil
	end

	local bin_header_pos = 21 + json_len
	local bin_data = ""
	if #content >= bin_header_pos + 8 then
		local bin_len = math_mod.read_uint32(content, bin_header_pos)
		local bin_type = math_mod.read_uint32(content, bin_header_pos + 4)
		if bin_type == 0x004E4942 then
			bin_data = string.sub(content, bin_header_pos + 8, bin_header_pos + 8 + bin_len - 1)
		end
	end

	return gltf_json, bin_data
end

local path_cache = {}

---Resolves the filesystem path for a 3D model across installed Luanti mods.
---@param filename string Model filename (e.g. "x_mobs_helmet_titan_bastion.glb")
---@param mod_hint string? Optional originating mod name hint
---@return string? full_path
function loader.find_model_path(filename, mod_hint)
	if not filename or filename == "" then return nil end

	local cache_key = (mod_hint or "") .. ":" .. filename
	if path_cache[cache_key] then
		return path_cache[cache_key]
	end

	-- Check mod hint first
	if mod_hint and mod_hint ~= "" then
		local mpath = core.get_modpath(mod_hint)
		if mpath then
			local candidate = mpath .. "/models/" .. filename
			local f = io.open(candidate, "rb")
			if f then
				f:close()
				path_cache[cache_key] = candidate
				return candidate
			end
		end
	end

	-- Check x_player_armor
	local self_path = modpath .. "/models/" .. filename
	local f_self = io.open(self_path, "rb")
	if f_self then
		f_self:close()
		path_cache[cache_key] = self_path
		return self_path
	end

	-- Extract mod prefix from filename if present (e.g. "x_mobs_helmet.glb" -> "x_mobs")
	local prefix = filename:match("^([%w_]+)_")
	if prefix and prefix ~= mod_hint then
		local ppath = core.get_modpath(prefix)
		if ppath then
			local candidate = ppath .. "/models/" .. filename
			local f = io.open(candidate, "rb")
			if f then
				f:close()
				path_cache[cache_key] = candidate
				return candidate
			end
		end
	end

	-- Search all active mods
	for _, mname in ipairs(core.get_modnames()) do
		local mpath = core.get_modpath(mname)
		if mpath then
			local candidate = mpath .. "/models/" .. filename
			local f = io.open(candidate, "rb")
			if f then
				f:close()
				path_cache[cache_key] = candidate
				return candidate
			end
		end
	end

	return nil
end

---Retrieves and caches the parsed structure of a modular armor piece .glb model in RAM.
---Returns directly from RAM cache if already parsed, eliminating synchronous disk I/O.
---@param filename string Model filename
---@param mod_hint string? Optional originating mod name hint
---@return table? gltf_json, string? bin_data, string? file_sha1
function loader.get_piece_model(filename, mod_hint)
	local cached = loader.piece_cache[filename]
	if cached then
		return cached.json, cached.bin, cached.sha1
	end

	local filepath = loader.find_model_path(filename, mod_hint)
	if not filepath then return nil, nil, nil end

	local f = io.open(filepath, "rb")
	if not f then return nil, nil, nil end
	local content = f:read("*a")
	f:close()

	local file_sha1 = core.sha1(content)
	local json_data, bin_data = loader.parse_glb_content(content)
	if json_data and bin_data then
		loader.piece_cache[filename] = {
			json = json_data,
			bin = bin_data,
			sha1 = file_sha1,
		}
		return json_data, bin_data, file_sha1
	end

	return nil, nil, nil
end

---Retrieves and caches the base preview model structure (x_player_armor_preview.glb) in RAM.
---Returns directly from RAM cache if already parsed, eliminating synchronous disk I/O.
---@return table? gltf_json, string? bin_data, string? base_sha1
function loader.get_base_model()
	if loader.base_model then
		return loader.base_model.json, loader.base_model.bin, loader.base_model.sha1
	end

	local base_file = constants.MODELS.preview or "x_player_armor_preview.glb"
	local filepath = loader.find_model_path(base_file, "x_player_armor")
	if not filepath then return nil, nil, nil end

	local f = io.open(filepath, "rb")
	if not f then return nil, nil, nil end
	local content = f:read("*a")
	f:close()

	local file_sha1 = core.sha1(content)
	local json_data, bin_data = loader.parse_glb_content(content)
	if json_data and bin_data then
		loader.base_model = {
			json = json_data,
			bin = bin_data,
			sha1 = file_sha1,
		}
		return json_data, bin_data, file_sha1
	end

	return nil, nil, nil
end

---Clears all in-memory loaded models and path discovery cache.
function loader.clear_cache()
	loader.piece_cache = {}
	loader.base_model = nil
	path_cache = {}
end

return loader
