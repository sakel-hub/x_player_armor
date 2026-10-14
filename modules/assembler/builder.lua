--[[
	X Player Armor - glTF 2.0 In-Memory Dynamic Model Assembler: Binary Builder Subsystem
	Author: SaKeL
	License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

	Slices, transforms, and combines modular 3D armor pieces into a single-mesh
	glTF 2.0 / GLB binary in RAM with zero disk I/O and zero child entity overhead.
]]

local math_mod = x_player_armor.gltf_assembler.math
local loader_mod = x_player_armor.gltf_assembler.loader

---@class XPlayerArmorAssemblerBuilder
local builder = {
	math = math_mod,
	loader = loader_mod,
}

---Resolves the texture names for a single piece model.
---@param piece table Piece definition table
---@param p_json? table Parsed glTF JSON of the piece
---@return string[] textures List of texture filenames
function builder.get_piece_textures(piece, p_json)
	local piece_tex = x_player_armor.visuals.get_item_texture(piece.item_name)
		or (piece.item_def and piece.item_def.texture)
		or "blank.png"
	local piece_tex_list = {}
	if piece.item_def and piece.item_def.textures and #piece.item_def.textures > 0 then
		for _, tname in ipairs(piece.item_def.textures) do
			table.insert(piece_tex_list, tname)
		end
	else
		table.insert(piece_tex_list, piece_tex)
	end

	local p_tex_count = (p_json and p_json.textures and #p_json.textures) or #piece_tex_list
	if p_tex_count == 0 then p_tex_count = 1 end

	local result = {}
	for t_idx = 1, p_tex_count do
		local assigned_tex = piece_tex_list[t_idx] or piece_tex_list[1] or piece_tex
		table.insert(result, assigned_tex)
	end
	return result
end

---Builds a spec-compliant .glb binary string combining base preview model and custom pieces in RAM.
---Modular piece vertices and normals are transformed into world space and attached to the scene root
---so that Irrlicht computes the exact same bounding box (H = 18.01, dist = 38.90) as the base model.
---@param pieces_to_attach table[] Array of piece descriptor tables
---@return string? glb_binary, string[] material_textures
function builder.assemble_glb(pieces_to_attach)
	local base_json_raw, base_bin_raw = loader_mod.get_base_model()
	if not base_json_raw or not base_bin_raw then
		return nil, {}
	end

	-- Deep copy base JSON structure
	local comb_json = table.copy(base_json_raw)
	local comb_bin = math_mod.pad_4bytes(base_bin_raw, "\0")
	local material_textures = {}

	-- Resolve Armature root node index in base model
	local armature_node_idx = 8
	for idx, node in ipairs(comb_json.nodes or {}) do
		if node.name == "Armature" then
			armature_node_idx = idx
			break
		end
	end

	-- Precompute bone world matrices and bone name lookup for attaching prop items (e.g. shields)
	local base_world_mats = math_mod.compute_node_world_matrices(comb_json.nodes)
	local bone_node_map = {}
	for idx, node in ipairs(comb_json.nodes or {}) do
		if node.name then
			bone_node_map[node.name] = idx
		end
	end

	local read_f32 = math_mod.read_float32
	local write_f32 = math_mod.write_float32
	local math_sqrt = math.sqrt

	for _, piece in ipairs(pieces_to_attach) do
		local p_json, p_bin = loader_mod.get_piece_model(piece.model_file, piece.mod_hint)
		if p_json and p_bin and p_json.meshes and #p_json.meshes > 0 then
			local idef = piece.item_def or (piece.item_name and x_player_armor.get_armor_def(piece.item_name))
			local custom_trans = idef and (
				(idef.transforms and (
					(idef.transforms.glb and idef.transforms.glb[piece.piece_id])
					or idef.transforms[piece.piece_id]
				))
				or (piece.element == "shield" and (
					(idef.shield_offset and idef.shield_offset.glb)
					or idef.shield_offset
				))
			)

			-- Detect native unified master character model export (Blender File -> Export -> glTF 2.0 with "Selected Objects")
			local p_node = nil
			for _, node in ipairs(p_json.nodes or {}) do
				if node.mesh ~= nil then
					p_node = node
					break
				end
			end
			if not p_node and p_json.nodes then
				p_node = p_json.nodes[1]
			end

			-- Unified character model: extract node scene transform directly from glTF node
			local node_pos = p_node and p_node.translation
			local node_quat = p_node and p_node.rotation
			local node_scale = p_node and p_node.scale

			local node_mat = math_mod.trs_to_mat4(node_pos, node_quat, node_scale)

			local world_mat
			if custom_trans then
				local c_pos = custom_trans.pos or {x = 0, y = 0, z = 0}
				local c_rot = custom_trans.rot or {x = 0, y = 0, z = 0}
				local c_scale = custom_trans.scale or {x = 1, y = 1, z = 1}
				local c_quat = math_mod.euler_to_quat(c_rot)
				local custom_mat = math_mod.trs_to_mat4(c_pos, c_quat, c_scale)
				if custom_trans.bone_local or (idef and idef.bone_local) then
					local bone_name = custom_trans.bone or "Arm_Left"
					local bone_idx = bone_node_map[bone_name]
					local bone_mat = (bone_idx and base_world_mats[bone_idx]) or math_mod.trs_to_mat4()
					local bone_attach_mat = math_mod.mat4_mul(bone_mat, custom_mat)
					world_mat = math_mod.mat4_mul(bone_attach_mat, node_mat)
				else
					world_mat = math_mod.mat4_mul(custom_mat, node_mat)
				end
			else
				world_mat = node_mat
			end

			-- Pre-extract matrix registers for high-performance JIT execution
			local m11, m12, m13, m14 = world_mat[1][1], world_mat[1][2], world_mat[1][3], world_mat[1][4]
			local m21, m22, m23, m24 = world_mat[2][1], world_mat[2][2], world_mat[2][3], world_mat[2][4]
			local m31, m32, m33, m34 = world_mat[3][1], world_mat[3][2], world_mat[3][3], world_mat[3][4]

			-- Deep copy piece JSON structure and transform vertex attributes into character world coordinates
			local p_json_copy = table.copy(p_json)
			local replacements = {}
			local processed_pos_accessors = {}
			local processed_norm_accessors = {}

			for _, mesh in ipairs(p_json_copy.meshes or {}) do
				for _, prim in ipairs(mesh.primitives or {}) do
					if prim.attributes then
						local pos_acc_idx = prim.attributes.POSITION
						if pos_acc_idx ~= nil and not processed_pos_accessors[pos_acc_idx] then
							processed_pos_accessors[pos_acc_idx] = true
							local acc = p_json_copy.accessors[pos_acc_idx + 1]
							if acc and acc.bufferView ~= nil then
								local bv = p_json_copy.bufferViews[acc.bufferView + 1]
								if bv then
									local start_offset = (bv.byteOffset or 0) + (acc.byteOffset or 0) + 1
									local count = acc.count or 0
									local min_x, min_y, min_z = math.huge, math.huge, math.huge
									local max_x, max_y, max_z = -math.huge, -math.huge, -math.huge
									local chunks = {}
									local c = 0

									for i = 0, count - 1 do
										local v_offset = start_offset + i * 12
										local vx = read_f32(p_bin, v_offset)
										local vy = read_f32(p_bin, v_offset + 4)
										local vz = read_f32(p_bin, v_offset + 8)

										local wx = m11 * vx + m12 * vy + m13 * vz + m14
										local wy = m21 * vx + m22 * vy + m23 * vz + m24
										local wz = m31 * vx + m32 * vy + m33 * vz + m34

										if wx < min_x then min_x = wx end
										if wx > max_x then max_x = wx end
										if wy < min_y then min_y = wy end
										if wy > max_y then max_y = wy end
										if wz < min_z then min_z = wz end
										if wz > max_z then max_z = wz end

										chunks[c + 1] = write_f32(wx)
										chunks[c + 2] = write_f32(wy)
										chunks[c + 3] = write_f32(wz)
										c = c + 3
									end

									acc.min = {min_x, min_y, min_z}
									acc.max = {max_x, max_y, max_z}
									table.insert(replacements, {
										start = start_offset,
										len = count * 12,
										data = table.concat(chunks),
									})
								end
							end
						end

						local norm_acc_idx = prim.attributes.NORMAL
						if norm_acc_idx ~= nil and not processed_norm_accessors[norm_acc_idx] then
							processed_norm_accessors[norm_acc_idx] = true
							local acc = p_json_copy.accessors[norm_acc_idx + 1]
							if acc and acc.bufferView ~= nil then
								local bv = p_json_copy.bufferViews[acc.bufferView + 1]
								if bv then
									local start_offset = (bv.byteOffset or 0) + (acc.byteOffset or 0) + 1
									local count = acc.count or 0
									local chunks = {}
									local c = 0

									for i = 0, count - 1 do
										local v_offset = start_offset + i * 12
										local nx = read_f32(p_bin, v_offset)
										local ny = read_f32(p_bin, v_offset + 4)
										local nz = read_f32(p_bin, v_offset + 8)

										local wnx = m11 * nx + m12 * ny + m13 * nz
										local wny = m21 * nx + m22 * ny + m23 * nz
										local wnz = m31 * nx + m32 * ny + m33 * nz

										local len = math_sqrt(wnx * wnx + wny * wny + wnz * wnz)
										if len > 0 then
											wnx, wny, wnz = wnx / len, wny / len, wnz / len
										end

										chunks[c + 1] = write_f32(wnx)
										chunks[c + 2] = write_f32(wny)
										chunks[c + 3] = write_f32(wnz)
										c = c + 3
									end

									table.insert(replacements, {
										start = start_offset,
										len = count * 12,
										data = table.concat(chunks),
									})
								end
							end
						end
					end
				end
			end

			-- Splice transformed vertex buffers into piece binary
			table.sort(replacements, function(a, b) return a.start < b.start end)
			local bin_parts = {}
			local cur = 1
			for _, rep in ipairs(replacements) do
				if rep.start > cur then
					table.insert(bin_parts, string.sub(p_bin, cur, rep.start - 1))
				end
				table.insert(bin_parts, rep.data)
				cur = rep.start + rep.len
			end
			if cur <= #p_bin then
				table.insert(bin_parts, string.sub(p_bin, cur))
			end
			local transformed_p_bin = table.concat(bin_parts)

			local bin_offset = #comb_bin
			local p_bin_padded = math_mod.pad_4bytes(transformed_p_bin, "\0")
			comb_bin = comb_bin .. p_bin_padded

			-- 1. Map BufferViews
			local bv_offset = #comb_json.bufferViews
			for _, bv in ipairs(p_json_copy.bufferViews or {}) do
				local new_bv = table.copy(bv)
				new_bv.buffer = 0
				new_bv.byteOffset = (new_bv.byteOffset or 0) + bin_offset
				table.insert(comb_json.bufferViews, new_bv)
			end

			-- 2. Map Accessors
			local acc_offset = #comb_json.accessors
			for _, acc in ipairs(p_json_copy.accessors or {}) do
				local new_acc = table.copy(acc)
				if new_acc.bufferView ~= nil then
					new_acc.bufferView = new_acc.bufferView + bv_offset
				end
				table.insert(comb_json.accessors, new_acc)
			end

			-- 3. Map Textures, Materials & Resolve Texture
			comb_json.textures = comb_json.textures or {}
			local tex_offset = #comb_json.textures
			local mat_offset = #comb_json.materials

			local p_texs = builder.get_piece_textures(piece, p_json_copy)
			for _, assigned_tex in ipairs(p_texs) do
				table.insert(comb_json.textures, {sampler = 0})
				table.insert(material_textures, assigned_tex)
			end

			if p_json_copy.materials and #p_json_copy.materials > 0 then
				for _, mat in ipairs(p_json_copy.materials) do
					local new_mat = table.copy(mat)
					new_mat.pbrMetallicRoughness = new_mat.pbrMetallicRoughness or {}
					local pbr = new_mat.pbrMetallicRoughness
					if pbr.baseColorTexture and pbr.baseColorTexture.index ~= nil then
						pbr.baseColorTexture.index = pbr.baseColorTexture.index + tex_offset
					else
						pbr.baseColorTexture = {index = tex_offset}
					end
					new_mat.alphaMode = "MASK"
					new_mat.alphaCutoff = 0.5
					new_mat.doubleSided = true
					table.insert(comb_json.materials, new_mat)
				end
			else
				table.insert(comb_json.materials, {
					name = piece.piece_id,
					alphaMode = "MASK",
					alphaCutoff = 0.5,
					doubleSided = true,
					pbrMetallicRoughness = {
						baseColorTexture = {index = tex_offset}
					}
				})
			end

			-- 4. Map Meshes & Primitives
			local mesh_offset = #comb_json.meshes
			for _, mesh in ipairs(p_json_copy.meshes) do
				local new_mesh = table.copy(mesh)
				for _, prim in ipairs(new_mesh.primitives or {}) do
					if prim.indices ~= nil then
						prim.indices = prim.indices + acc_offset
					end
					if prim.attributes then
						for attr_name, attr_idx in pairs(prim.attributes) do
							prim.attributes[attr_name] = attr_idx + acc_offset
						end
					end
					if prim.material ~= nil then
						prim.material = prim.material + mat_offset
					else
						prim.material = mat_offset
					end
				end
				table.insert(comb_json.meshes, new_mesh)
			end

			-- 5. Attach Transformed Node Directly Under Scene Root (Armature)
			local new_node_idx = #comb_json.nodes -- 0-indexed in glTF
			local new_node = {
				name = "Custom_" .. piece.piece_id,
				mesh = mesh_offset,
			}
			table.insert(comb_json.nodes, new_node)

			local armature_node = comb_json.nodes[armature_node_idx]
			if armature_node then
				armature_node.children = armature_node.children or {}
				table.insert(armature_node.children, new_node_idx)
			end
		end
	end

	-- Update total buffer length
	comb_json.buffers[1].byteLength = #comb_bin

	-- Serialize JSON chunk
	local json_str = core.write_json(comb_json)
	local json_padded = math_mod.pad_4bytes(json_str, " ")

	-- Construct 12-byte header + Chunk 0 + Chunk 1
	local total_len = 12 + 8 + #json_padded + 8 + #comb_bin
	local out = math_mod.write_uint32(0x46546C67) .. math_mod.write_uint32(2) .. math_mod.write_uint32(total_len)
		.. math_mod.write_uint32(#json_padded) .. math_mod.write_uint32(0x4E4F534A) .. json_padded
		.. math_mod.write_uint32(#comb_bin) .. math_mod.write_uint32(0x004E4942) .. comb_bin

	return out, material_textures
end

return builder
