--[[
	X Player Armor - glTF 2.0 In-Memory Dynamic Model Assembler: Math & Binary Subsystem
	Author: SaKeL
	License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

	Provides linear algebra, matrix transforms, quaternions, and high-performance
	little-endian binary IEEE-754 float / uint32 packing and unpacking.
]]

---@class XPlayerArmorAssemblerMath
local math_mod = {}

local deg2rad = math.pi / 180
local str_pack = rawget(string, "pack")
local str_unpack = rawget(string, "unpack")
local has_string_pack = (type(str_pack) == "function" and type(str_unpack) == "function")

---Reads a 32-bit unsigned integer (little-endian) from a binary string.
---@param str string Binary string
---@param offset number 1-indexed byte offset
---@return number val Unsigned 32-bit integer
function math_mod.read_uint32(str, offset)
	if has_string_pack then
		local ok, val = pcall(str_unpack, "<I4", str, offset)
		if ok then return val end
	end
	local b1, b2, b3, b4 = string.byte(str, offset, offset + 3)
	if not b1 or not b2 or not b3 or not b4 then return 0 end
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

---Packs a 32-bit unsigned integer (little-endian) into a 4-byte string.
---@param val number Unsigned 32-bit integer
---@return string packed 4-byte binary string
function math_mod.write_uint32(val)
	if has_string_pack then
		local ok, packed = pcall(str_pack, "<I4", math.floor(val))
		if ok then return packed end
	end
	val = math.floor(val)
	local b1 = val % 256
	local b2 = math.floor(val / 256) % 256
	local b3 = math.floor(val / 65536) % 256
	local b4 = math.floor(val / 16777216) % 256
	return string.char(b1, b2, b3, b4)
end

---Pads a binary string to a 4-byte boundary using the specified padding character.
---@param str string Binary string to pad
---@param pad_char string Single character used for alignment ("\0" or " ")
---@return string padded 4-byte aligned string
function math_mod.pad_4bytes(str, pad_char)
	local rem = #str % 4
	if rem ~= 0 then
		return str .. string.rep(pad_char, 4 - rem)
	end
	return str
end

---Converts Euler rotation angles in degrees {x, y, z} to a glTF unit quaternion [qx, qy, qz, qw].
---@param rot table<string, number> Euler angles in degrees
---@return number[] quat Normalized unit quaternion [qx, qy, qz, qw]
function math_mod.euler_to_quat(rot)
	local rx = ((rot.x or 0) * deg2rad) * 0.5
	local ry = ((rot.y or 0) * deg2rad) * 0.5
	local rz = ((rot.z or 0) * deg2rad) * 0.5

	local sx, cx = math.sin(rx), math.cos(rx)
	local sy, cy = math.sin(ry), math.cos(ry)
	local sz, cz = math.sin(rz), math.cos(rz)

	local qx = sx * cy * cz - cx * sy * sz
	local qy = cx * sy * cz + sx * cy * sz
	local qz = cx * cy * sz - sx * sy * cz
	local qw = cx * cy * cz + sx * sy * sz

	return {qx, qy, qz, qw}
end

---Reads a 32-bit little-endian IEEE-754 float from a binary string.
---@param str string Binary string
---@param offset number 1-indexed byte offset
---@return number val Floating-point value
function math_mod.read_float32(str, offset)
	if has_string_pack then
		local ok, val = pcall(str_unpack, "<f", str, offset)
		if ok then return val end
	end
	local b1, b2, b3, b4 = string.byte(str, offset, offset + 3)
	if not b1 or not b2 or not b3 or not b4 then return 0 end
	local sign = (b4 >= 128) and -1 or 1
	local expo = (b4 % 128) * 2 + math.floor(b3 / 128)
	local mant = ((b3 % 128) * 256 + b2) * 256 + b1
	if expo == 255 then
		return (mant == 0) and (sign * math.huge) or 0 / 0
	elseif expo == 0 then
		if mant == 0 then return sign * 0 end
		return sign * math.ldexp(mant / 8388608, -126)
	end
	return sign * math.ldexp(1 + mant / 8388608, expo - 127)
end

---Packs a 32-bit little-endian IEEE-754 float into a 4-byte string.
---@param val number Floating-point value
---@return string packed 4-byte binary string
function math_mod.write_float32(val)
	if has_string_pack then
		local ok, packed = pcall(str_pack, "<f", val)
		if ok then return packed end
	end
	if val == 0 then return "\0\0\0\0" end
	local sign = 0
	if val < 0 then
		sign = 128
		val = -val
	end
	local mant, expo = math.frexp(val)
	expo = expo + 126
	if expo >= 255 then
		return string.char(0, 0, 128, sign + 127)
	elseif expo <= 0 then
		mant = math.floor(mant * math.ldexp(1, 24 + expo) + 0.5)
		return string.char(mant % 256, math.floor(mant / 256) % 256, math.floor(mant / 65536) % 128, sign)
	end
	mant = math.floor((mant * 2 - 1) * 8388608 + 0.5)
	local b1 = mant % 256
	local b2 = math.floor(mant / 256) % 256
	local b3 = (math.floor(mant / 65536) % 128) + (expo % 2) * 128
	local b4 = math.floor(expo / 2) + sign
	return string.char(b1, b2, b3, b4)
end

---Multiplies two 4x4 transformation matrices A and B.
---@param a number[][] 4x4 Left matrix
---@param b number[][] 4x4 Right matrix
---@return number[][] result 4x4 Result matrix
function math_mod.mat4_mul(a, b)
	local c = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}
	for i = 1, 4 do
		local ai = a[i]
		local ci = c[i]
		for j = 1, 4 do
			local sum = 0
			for k = 1, 4 do
				sum = sum + ai[k] * b[k][j]
			end
			ci[j] = sum
		end
	end
	return c
end

---Builds a 4x4 matrix from translation vector, quaternion [qx, qy, qz, qw], and scale vector.
---@param t? table<string, number>|number[] Translation vector {x, y, z} or [tx, ty, tz]
---@param q? number[] Unit quaternion [qx, qy, qz, qw]
---@param s? table<string, number>|number[] Scale vector {x, y, z} or [sx, sy, sz]
---@return number[][] mat4 4x4 Transformation matrix
function math_mod.trs_to_mat4(t, q, s)
	q = q or {0, 0, 0, 1}
	local qx, qy, qz, qw = q[1] or 0, q[2] or 0, q[3] or 0, q[4] or 1
	local n = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
	if n > 0 then
		qx, qy, qz, qw = qx / n, qy / n, qz / n, qw / n
	end
	local sx = (type(s) == "table" and (s.x or s[1])) or 1
	local sy = (type(s) == "table" and (s.y or s[2])) or 1
	local sz = (type(s) == "table" and (s.z or s[3])) or 1

	local tx = (type(t) == "table" and (t.x or t[1])) or 0
	local ty = (type(t) == "table" and (t.y or t[2])) or 0
	local tz = (type(t) == "table" and (t.z or t[3])) or 0

	return {
		{(1 - 2 * (qy * qy + qz * qz)) * sx, (2 * (qx * qy - qz * qw)) * sy,     (2 * (qx * qz + qy * qw)) * sz,     tx},
		{(2 * (qx * qy + qz * qw)) * sx,     (1 - 2 * (qx * qx + qz * qz)) * sy, (2 * (qy * qz - qx * qw)) * sz,     ty},
		{(2 * (qx * qz - qy * qw)) * sx,     (2 * (qy * qz + qx * qw)) * sy,     (1 - 2 * (qx * qx + qy * qy)) * sz, tz},
		{0,                                  0,                                  0,                                  1},
	}
end

---Computes world transform matrices for all nodes in the glTF node hierarchy.
---@param nodes table[] Array of glTF node definition tables
---@return table<number, number[][]> node_world_matrices Map of 1-indexed node indices to 4x4 world matrices
function math_mod.compute_node_world_matrices(nodes)
	local world_matrices = {}
	local parent_map = {}

	for parent_idx, node in ipairs(nodes) do
		if node.children then
			for _, child_idx in ipairs(node.children) do
				parent_map[child_idx + 1] = parent_idx
			end
		end
	end

	local function get_world_matrix(idx)
		if world_matrices[idx] then
			return world_matrices[idx]
		end
		local node = nodes[idx]
		local local_mat = math_mod.trs_to_mat4(node.translation, node.rotation, node.scale)
		local p_idx = parent_map[idx]
		if p_idx then
			local p_mat = get_world_matrix(p_idx)
			world_matrices[idx] = math_mod.mat4_mul(p_mat, local_mat)
		else
			world_matrices[idx] = local_mat
		end
		return world_matrices[idx]
	end

	for idx = 1, #nodes do
		get_world_matrix(idx)
	end

	return world_matrices
end

return math_mod
