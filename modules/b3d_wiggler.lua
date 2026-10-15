-- X Player Armor - Standalone B3D Model Rotation Wiggler (modules/b3d_wiggler.lua)
-- Resolves Irrlicht skeletal animation matrix decomposition bug (Luanti Issue #15692)
-- when running without x_player_api or x_player_bridge.
--
-- Portions adapted with credit and appreciation from:
--   modlib (https://github.com/appgurueu/modlib) and character_anim by Lars Mueller (LMD / appgurueu)
--   Licensed under the MIT License:
--   Copyright (c) 2020-2024 Lars Mueller
--
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class XPlayerArmorB3DWiggler
---@field processed_models table<string, string>
---@field added_dynamic_media table<string, boolean>
---@field is_runtime boolean
local b3d_wiggler = {
	processed_models = {},
	added_dynamic_media = {},
	is_runtime = false,
}

local floor = math.floor
local frexp = math.frexp
local abs = math.abs
local sqrt = math.sqrt

local str_pack = rawget(string, "pack")
local str_unpack = rawget(string, "unpack")
local has_native_pack = type(str_pack) == "function" and type(str_unpack) == "function"

---Reads a 32-bit unsigned integer (little-endian).
---@param str string
---@param pos integer
---@return integer val
local function read_u32_le(str, pos)
	if has_native_pack then
		return (str_unpack("<I4", str, pos))
	end
	local b1, b2, b3, b4 = str:byte(pos, pos + 3)
	if not b4 then return 0 end
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

---Reads a 32-bit IEEE-754 float (little-endian).
---@param str string
---@param pos integer
---@return number val
local function read_f32_le(str, pos)
	if has_native_pack then
		return (str_unpack("<f", str, pos))
	end
	local b1, b2, b3, b4 = str:byte(pos, pos + 3)
	if not b4 then return 0.0 end
	local sign = (b4 >= 128) and -1 or 1
	local exp = (b4 % 128) * 2 + floor(b3 / 128)
	local mant = ((b3 % 128) * 256 + b2) * 256 + b1
	if exp == 0 then
		if mant == 0 then return 0.0 end
		return sign * (mant / 8388608) * (2 ^ -126)
	elseif exp == 255 then
		return (mant == 0) and (sign * (1 / 0)) or (0 / 0)
	end
	return sign * (1 + mant / 8388608) * (2 ^ (exp - 127))
end

---Writes a 32-bit IEEE-754 float (little-endian).
---@param val number
---@return string bytes 4-byte binary string
local function write_f32_le(val)
	if has_native_pack then
		return str_pack("<f", val)
	end
	if val == 0 then
		return string.char(0, 0, 0, 0)
	end
	local sign = 0
	if val < 0 then
		sign = 128
		val = -val
	end
	local mant, exp = frexp(val)
	mant = mant * 2 - 1
	exp = exp - 1 + 127
	if exp <= 0 then
		mant = (val / (2 ^ -126)) * 8388608
		exp = 0
	elseif exp >= 255 then
		return string.char(0, 0, 128, sign + 127)
	else
		mant = floor(mant * 8388608 + 0.5)
	end
	local b1 = mant % 256
	mant = floor(mant / 256)
	local b2 = mant % 256
	mant = floor(mant / 256)
	local b3 = (exp % 2) * 128 + mant
	local b4 = sign + floor(exp / 2)
	return string.char(b1, b2, b3, b4)
end

---Checks if a quaternion produces an Irrlicht-buggy matrix (zero off-diagonals and ~180 degree rotation).
---@param _w number
---@param x number
---@param y number
---@param z number
---@return boolean is_perfect True if rotation causes matrix decomposition flip
local function is_perfect_rotation(_w, x, y, z)
	if abs(x) + abs(y) + abs(z) < 1e-5 then
		return false
	end
	local m11 = 1.0 - 2.0 * (y * y + z * z)
	local m22 = 1.0 - 2.0 * (x * x + z * z)
	local m33 = 1.0 - 2.0 * (x * x + y * y)
	local diag_abs_sum = abs(m11) + abs(m22) + abs(m33)
	return abs(diag_abs_sum - 3.0) < 1e-5
end

---Perturbs a perfect rotation quaternion by +/- 1e-3 to break zero off-diagonals.
---@param w number
---@param x number
---@param y number
---@param z number
---@return number nw, number nx, number ny, number nz
local function wiggle_quaternion(w, x, y, z)
	if not is_perfect_rotation(w, x, y, z) then
		return w, x, y, z
	end
	for _, sign in ipairs({1e-3, -1e-3}) do
		local nw = w + sign
		local nx = x + sign
		local ny = y + sign
		local nz = z + sign
		local len = sqrt(nw * nw + nx * nx + ny * ny + nz * nz)
		if len > 0 then
			nw = nw / len
			nx = nx / len
			ny = ny / len
			nz = nz / len
			if not is_perfect_rotation(nw, nx, ny, nz) then
				return nw, nx, ny, nz
			end
		end
	end
	return w, x, y, z
end

---Processes raw B3D binary data and wiggles all perfect NODE and KEYS rotation quaternions.
---@param data string Binary B3D file contents
---@return string patched_data, integer nodes_wiggled, integer keys_wiggled
function b3d_wiggler.wiggle_b3d_data(data)
	if type(data) ~= "string" or #data < 12 or data:sub(1, 4) ~= "BB3D" then
		return data or "", 0, 0
	end

	local nodes_wiggled = 0
	local keys_wiggled = 0

	local rope = {}
	local last_pos = 1

	local function emit_up_to(pos)
		if pos > last_pos then
			table.insert(rope, data:sub(last_pos, pos - 1))
			last_pos = pos
		end
	end

	local function walk_chunks(start_pos, end_pos)
		local pos = start_pos
		while pos < end_pos do
			if pos + 7 > end_pos then break end
			local chunk_tag = data:sub(pos, pos + 3)
			local chunk_size = read_u32_le(data, pos + 4)
			local payload_start = pos + 8
			local payload_end = payload_start + chunk_size
			if payload_end > #data + 1 then break end

			if chunk_tag == "NODE" then
				local zero_idx = data:find("\0", payload_start, true)
				if zero_idx and zero_idx < payload_end then
					local rot_offset = zero_idx + 1 + 12 + 12 -- name\0 + 3 floats pos + 3 floats scale
					if rot_offset + 15 <= payload_end then
						local w = read_f32_le(data, rot_offset)
						local x = read_f32_le(data, rot_offset + 4)
						local y = read_f32_le(data, rot_offset + 8)
						local z = read_f32_le(data, rot_offset + 12)
						if is_perfect_rotation(w, x, y, z) then
							local nw, nx, ny, nz = wiggle_quaternion(w, x, y, z)
							emit_up_to(rot_offset)
							table.insert(rope, write_f32_le(nw))
							table.insert(rope, write_f32_le(nx))
							table.insert(rope, write_f32_le(ny))
							table.insert(rope, write_f32_le(nz))
							last_pos = rot_offset + 16
							nodes_wiggled = nodes_wiggled + 1
						end
						walk_chunks(rot_offset + 16, payload_end)
					end
				end
			elseif chunk_tag == "KEYS" then
				if payload_start + 4 <= payload_end then
					local flags = read_u32_le(data, payload_start)
					local k_pos = payload_start + 4
					while k_pos < payload_end do
						k_pos = k_pos + 4 -- frame
						if (flags % 2) >= 1 then -- bit 0: position
							k_pos = k_pos + 12
						end
						if (floor(flags / 2) % 2) >= 1 then -- bit 1: scale
							k_pos = k_pos + 12
						end
						if (floor(flags / 4) % 2) >= 1 then -- bit 2: rotation
							if k_pos + 15 <= payload_end then
								local w = read_f32_le(data, k_pos)
								local x = read_f32_le(data, k_pos + 4)
								local y = read_f32_le(data, k_pos + 8)
								local z = read_f32_le(data, k_pos + 12)
								if is_perfect_rotation(w, x, y, z) then
									local nw, nx, ny, nz = wiggle_quaternion(w, x, y, z)
									emit_up_to(k_pos)
									table.insert(rope, write_f32_le(nw))
									table.insert(rope, write_f32_le(nx))
									table.insert(rope, write_f32_le(ny))
									table.insert(rope, write_f32_le(nz))
									last_pos = k_pos + 16
									keys_wiggled = keys_wiggled + 1
								end
							end
							k_pos = k_pos + 16
						end
					end
				end
			end

			pos = payload_end
		end
	end

	walk_chunks(13, #data + 1)

	if nodes_wiggled == 0 and keys_wiggled == 0 then
		return data, 0, 0
	end

	emit_up_to(#data + 1)
	return table.concat(rope), nodes_wiggled, keys_wiggled
end

---Locates a B3D model file on disk across active mods.
---@param filename string
---@return string|nil full_path
function b3d_wiggler.find_model_path(filename)
	if not filename or filename == "" or not core.get_modpath then
		return nil
	end

	-- Priority 1: Check common player model providers (player_api, skinsdb, 3d_armor)
	local priority_mods = {"player_api", "skinsdb", "3d_armor"}
	for i = 1, #priority_mods do
		local mpath = core.get_modpath(priority_mods[i])
		if mpath then
			local candidate = mpath .. "/models/" .. filename
			local f = io.open(candidate, "rb")
			if f then
				f:close()
				return candidate
			end
		end
	end

	-- Priority 2: Search all active mods in reverse order
	if core.get_modnames then
		local modnames = core.get_modnames()
		if type(modnames) == "table" then
			for i = #modnames, 1, -1 do
				local mpath = core.get_modpath(modnames[i])
				if mpath then
					local candidate = mpath .. "/models/" .. filename
					local f = io.open(candidate, "rb")
					if f then
						f:close()
						return candidate
					end
				end
			end
		end
	end

	return nil
end

---Aliases a wiggled B3D mesh in player_api.registered_models so animation lookups succeed.
---@param orig_name string
---@param wiggled_name string
local function alias_in_player_api(orig_name, wiggled_name)
	if not orig_name or not wiggled_name or orig_name == wiggled_name then
		return
	end
	local p_api = x_player_armor.get_mod_api and x_player_armor.get_mod_api("player_api")
	if p_api and type(p_api.registered_models) == "table" then
		local def = p_api.registered_models[orig_name]
		if def and not p_api.registered_models[wiggled_name] then
			p_api.registered_models[wiggled_name] = def
		end
	end
end

---Scans and wiggles a B3D model file, registering dynamic media when needed.
---@param mesh_name string The original mesh filename (e.g. "character.b3d")
---@param full_path? string Optional absolute path to the mesh file
---@return string resolved_name The wiggled or original mesh filename
function b3d_wiggler.scan_and_wiggle_b3d_model(mesh_name, full_path)
	if not mesh_name or not mesh_name:match("%.b3d$") then
		return mesh_name
	end

	if mesh_name:find("^_wiggled_") then
		return mesh_name
	end

	-- If x_player_api is active, delegate to its wiggler to avoid duplicate media registration
	if x_player_armor.compat_x_player_api and x_player_armor.compat_x_player_api.is_present() then
		local x_api = x_player_armor.get_mod_api("x_player_api")
		if x_api and x_api.scan_and_wiggle_b3d_model then
			return x_api.scan_and_wiggle_b3d_model(mesh_name, full_path)
		end
		return mesh_name
	end

	if b3d_wiggler.processed_models[mesh_name] then
		local cached = b3d_wiggler.processed_models[mesh_name]
		alias_in_player_api(mesh_name, cached)
		return cached
	end

	full_path = full_path or b3d_wiggler.find_model_path(mesh_name)
	if not full_path then
		b3d_wiggler.processed_models[mesh_name] = mesh_name
		return mesh_name
	end

	local f = io.open(full_path, "rb")
	if not f then
		b3d_wiggler.processed_models[mesh_name] = mesh_name
		return mesh_name
	end
	local raw_data = f:read("*a")
	f:close()

	local wiggled_data, nodes_count, keys_count = b3d_wiggler.wiggle_b3d_data(raw_data)
	if nodes_count == 0 and keys_count == 0 then
		b3d_wiggler.processed_models[mesh_name] = mesh_name
		return mesh_name
	end

	local target_name = "_wiggled_" .. mesh_name
	b3d_wiggler.processed_models[mesh_name] = target_name
	b3d_wiggler.processed_models[target_name] = target_name

	if not b3d_wiggler.added_dynamic_media[target_name] then
		b3d_wiggler.added_dynamic_media[target_name] = true
		if core.dynamic_add_media then
			local out_path = nil
			if core.get_worldpath then
				local worldpath = core.get_worldpath()
				if worldpath and worldpath ~= "" then
					local media_dir = worldpath .. "/x_player_armor_cache"
					if core.mkdir then core.mkdir(media_dir) end
					local candidate_path = media_dir .. "/" .. target_name
					local out_file = io.open(candidate_path, "wb")
					if out_file then
						out_file:write(wiggled_data)
						out_file:close()
						out_path = candidate_path
					end
				end
			end

			local opts = {
				filename = target_name,
				ephemeral = false,
				client_cache = true,
			}
			if out_path then
				opts.filepath = out_path
			else
				opts.filedata = wiggled_data
			end
			if b3d_wiggler.is_runtime then
				local ok = pcall(core.dynamic_add_media, opts, function() end)
				if not ok then
					pcall(core.dynamic_add_media, opts)
				end
			else
				local ok = pcall(core.dynamic_add_media, opts)
				if not ok then
					pcall(core.dynamic_add_media, opts, function() end)
				end
			end
		end
	end

	alias_in_player_api(mesh_name, target_name)

	if core.log then
		core.log("action", string.format(
			"[x_player_armor] Wiggled B3D model '%s' -> '%s' (%d nodes, %d keys) to fix Irrlicht bone decomposition bug.",
			mesh_name, target_name, nodes_count, keys_count
		))
	end

	return target_name
end

---Scans all B3D models registered in player_api and pre-registers their wiggled media.
function b3d_wiggler.scan_and_wiggle_registered_b3d_models()
	if core.after then
		core.after(0, function()
			b3d_wiggler.is_runtime = true
		end)
	end

	if x_player_armor.compat_x_player_api and x_player_armor.compat_x_player_api.is_present() then
		return
	end

	b3d_wiggler.scan_and_wiggle_b3d_model("character.b3d")

	local p_api = x_player_armor.get_mod_api and x_player_armor.get_mod_api("player_api")
	if not p_api or type(p_api.registered_models) ~= "table" then
		return
	end

	local model_names = {}
	for model_name, def in pairs(p_api.registered_models) do
		if type(model_name) == "string" and model_name:match("%.b3d$") and not model_name:find("^_wiggled_") then
			table.insert(model_names, model_name)
		end
		if type(def) == "table" and type(def.mesh) == "string"
				and def.mesh:match("%.b3d$") and not def.mesh:find("^_wiggled_") then
			table.insert(model_names, def.mesh)
		end
	end

	for i = 1, #model_names do
		b3d_wiggler.scan_and_wiggle_b3d_model(model_names[i])
	end
end

---Ensures a player using a B3D model without x_player_api has the wiggled mesh applied.
---@param player ObjectRef
---@return string|nil active_mesh
function b3d_wiggler.ensure_player_wiggled_b3d(player)
	if not player or not player.is_player or not player:is_player() then
		return nil
	end
	if player.is_valid and not player:is_valid() then
		return nil
	end
	if x_player_armor.compat_x_player_api and x_player_armor.compat_x_player_api.is_present() then
		return nil
	end

	local props = player.get_properties and player:get_properties()
	local mesh = props and props.mesh
	if (not mesh or mesh == "") then
		local p_api = x_player_armor.get_mod_api and x_player_armor.get_mod_api("player_api")
		local anim = p_api and p_api.get_animation and p_api.get_animation(player)
		mesh = anim and anim.model
	end

	if not mesh or not mesh:match("%.b3d$") then
		return mesh
	end

	if mesh:find("^_wiggled_") then
		return mesh
	end

	local wiggled = b3d_wiggler.scan_and_wiggle_b3d_model(mesh)
	if wiggled and wiggled ~= mesh and player.set_properties then
		player:set_properties({mesh = wiggled})
		return wiggled
	end

	return mesh
end

-- Export internal helpers for unit testing
b3d_wiggler._test = {
	is_perfect_rotation = is_perfect_rotation,
	wiggle_quaternion = wiggle_quaternion,
	read_u32_le = read_u32_le,
	read_f32_le = read_f32_le,
	write_f32_le = write_f32_le,
}

x_player_armor.b3d_wiggler = b3d_wiggler
return b3d_wiggler
