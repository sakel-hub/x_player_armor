---@class XPlayerArmorVisuals
local visuals = {
	player_entities = {},
	texture_cache = {},
}

local constants = x_player_armor.constants

-- Performance Blueprint: Ephemeral entity with zero tick overhead
core.register_entity("x_player_armor:visual", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		visual = "mesh",
		mesh = "",
		textures = {"blank.png"},
		visual_size = {x = 1, y = 1, z = 1},
		backface_culling = true,
		shaded = true,
		glow = 0,
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	on_deactivate = function(self, removal)
		if removal and not self._intentional_removal and self._player_name then
			visuals.schedule_player_restore(self._player_name)
		end
	end,
	on_step = nil, -- Zero Lua tick overhead: engine scene graph handles bone tracking
})

---Determines the appropriate parent ObjectRef targets (handles x_player_api proxies if active).
---@param player ObjectRef
---@return table<{parent: ObjectRef, observers: table<string, boolean>?, format: string}> targets
local function get_attachment_targets(player)
	local targets = {}
	local x_api = x_player_armor.get_mod_api("x_player_api")
	if x_api and x_api.get_visual_proxies then
		if not (x_api.is_pure_native_b3d_active and x_api.is_pure_native_b3d_active(player)) then
			local proxies = x_api.get_visual_proxies(player)
			if proxies then
				if proxies.glb and proxies.glb:is_valid() then
					local observers = x_api.get_modern_observers and x_api.get_modern_observers()
					table.insert(targets, {parent = proxies.glb, observers = observers, format = "glb"})
				end
				if proxies.b3d and proxies.b3d:is_valid() then
					local observers = x_api.get_legacy_observers and x_api.get_legacy_observers()
					table.insert(targets, {parent = proxies.b3d, observers = observers, format = "b3d"})
				end
			end
		end
	end
	if #targets == 0 then
		table.insert(targets, {parent = player, observers = nil, format = "b3d"})
	end
	return targets
end

---Creates and attaches a visual entity to a bone with format-specific transforms.
---@param target table
---@param piece_id string
---@param default_texture string
---@param glow number?
---@param player_name string?
---@param item_def table?
---@return ObjectRef? entity
local function spawn_piece(target, piece_id, default_texture, glow, player_name, item_def)
	local parent = target.parent
	local format = target.format or "b3d"
	local default_trans = constants.ATTACH_TRANSFORMS[format] and constants.ATTACH_TRANSFORMS[format][piece_id]
	local custom_trans = item_def and item_def.transforms and (
		(item_def.transforms[format] and item_def.transforms[format][piece_id])
		or item_def.transforms[piece_id]
	)

	if not default_trans and not custom_trans then return nil end

	local bone = (custom_trans and custom_trans.bone) or (default_trans and default_trans.bone) or "Body"
	local pos = (custom_trans and custom_trans.pos) or (default_trans and default_trans.pos) or {x = 0, y = 0, z = 0}
	local rot = (custom_trans and custom_trans.rot) or (default_trans and default_trans.rot) or {x = 0, y = 0, z = 0}
	local scale = (custom_trans and custom_trans.scale) or (item_def and item_def.visual_size) or {x = 1, y = 1, z = 1}

	local model = nil
	if item_def then
		if item_def.models and item_def.models[piece_id] then
			model = item_def.models[piece_id]
		elseif item_def.meshes and item_def.meshes[piece_id] then
			model = item_def.meshes[piece_id]
		elseif (piece_id == item_def.element or (constants.ELEMENT_PIECES[item_def.element] and #constants.ELEMENT_PIECES[item_def.element] == 1))
				and (item_def.model or item_def.mesh) then
			model = item_def.model or item_def.mesh
		end
	end
	if not model or model == "" then
		model = (custom_trans and custom_trans.model) or (default_trans and default_trans.model)
	end
	if not model or model == "" then return nil end

	local ppos = parent:get_pos()
	if not ppos then return nil end
	local obj = core.add_entity(ppos, "x_player_armor:visual")
	if not obj or not obj:is_valid() then return nil end

	local luaent = obj:get_luaentity()
	if luaent then
		luaent._player_name = player_name
		luaent._piece_id = piece_id
		luaent._intentional_removal = false
	end

	local textures
	if item_def and item_def.textures and type(item_def.textures) == "table" and #item_def.textures > 0 then
		textures = item_def.textures
	else
		textures = {default_texture}
	end

	local item_glow = (item_def and item_def.glow) or glow or 0
	local backface_culling = true
	if item_def and item_def.backface_culling ~= nil then
		backface_culling = item_def.backface_culling
	end
	local shaded = true
	if item_def and item_def.shaded ~= nil then
		shaded = item_def.shaded
	end

	obj:set_properties({
		mesh = model,
		textures = textures,
		glow = item_glow,
		visual_size = scale,
		backface_culling = backface_culling,
		shaded = shaded,
	})
	-- 5th argument 'false' disables forced_visible, avoiding first-person view frustum clipping
	obj:set_attach(parent, bone, pos, rot, false)
	if target.observers and obj.set_observers then
		obj:set_observers(target.observers)
	end
	return obj
end

---Spawns all modular armor mesh parts for an element across target parent proxies.
---@param targets table<{parent: ObjectRef, observers: table<string, boolean>?, format: string}>
---@param element string
---@param worn_target table|string Worn target info table or legacy texture string
---@param player_name string?
---@return table<number, ObjectRef> entities
local function spawn_element_pieces(targets, element, worn_target, player_name)
	local created = {}
	local item_def = type(worn_target) == "table" and worn_target.def
	local tex = (type(worn_target) == "table" and worn_target.texture) or worn_target
	local piece_ids = (item_def and item_def.pieces) or constants.ELEMENT_PIECES[element]
	if not piece_ids then return created end

	for _, target in ipairs(targets) do
		for _, piece_id in ipairs(piece_ids) do
			local obj = spawn_piece(target, piece_id, tex, item_def and item_def.glow, player_name, item_def)
			if obj then
				table.insert(created, obj)
			end
		end
	end
	return created
end

---Removes visual entities for a specific element slot of a player.
---@param player_name string
---@param element string
local function clear_element_visuals(player_name, element)
	local player_data = visuals.player_entities[player_name]
	if not player_data or not player_data[element] then return end

	local list = player_data[element]
	for i = 1, #list do
		local obj = list[i]
		if obj and obj:is_valid() then
			local ent = obj:get_luaentity()
			if ent then
				ent._intentional_removal = true
			end
			obj:set_detach()
			obj:remove()
		end
	end
	player_data[element] = nil
end

---Retrieves or resolves the texture for an armor item stack.
---@param item_name string
---@return string? texture
function visuals.get_item_texture(item_name)
	if not item_name or item_name == "" then return nil end
	if visuals.texture_cache[item_name] then
		return visuals.texture_cache[item_name]
	end
	local resolved_name = core.registered_aliases[item_name] or item_name
	local def = core.registered_tools[resolved_name] or core.registered_items[resolved_name]
	local tex = nil
	if def then
		tex = def.texture
		if not tex and def._x_player_armor and def._x_player_armor.texture then
			tex = def._x_player_armor.texture
		end
	end
	if not tex then
		tex = resolved_name:gsub(":", "_") .. ".png"
	end
	if tex then
		visuals.texture_cache[item_name] = tex
	end
	return tex
end

---Updates all modular bone attachments for a player based on worn armor items.
---@param player ObjectRef
function visuals.update_player_visuals(player)
	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then return end

	if not visuals.player_entities[name] then
		visuals.player_entities[name] = {}
	end

	local targets = get_attachment_targets(player)
	if #targets == 0 then return end

	local armor_list = inv:get_list("armor")
	if not armor_list then return end

	local worn_elements = {}
	for idx = 1, 5 do
		local stack = armor_list[idx]
		local element = constants.SLOT_ELEMENTS[idx]
		if stack and not stack:is_empty() and element then
			local item_name = stack:get_name()
			local tex = visuals.get_item_texture(item_name)
			if tex then
				local idef = stack:get_definition() or (x_player_armor.registered_armors and x_player_armor.registered_armors[item_name])
				worn_elements[element] = {
					item = item_name,
					texture = tex,
					stack = stack,
					def = idef,
				}
			end
		end
	end

	local has_x_api = x_player_armor.compat_x_player_api.is_present()

	-- Reconcile modular armor mesh elements (head, torso, legs, feet)
	for _, element in ipairs({"head", "torso", "legs", "feet"}) do
		local current = visuals.player_entities[name][element]
		local target = worn_elements[element]

		if not target then
			if current then
				clear_element_visuals(name, element)
			end
		else
			local needs_spawn = false
			local target_pieces = (target.def and target.def.pieces) or (constants.ELEMENT_PIECES[element] or {})
			local expected_count = #targets * #target_pieces
			if not current or current.item ~= target.item or #current ~= expected_count then
				needs_spawn = true
			else
				-- Verify validity and attachment to an active target parent
				for i = 1, #current do
					local obj = current[i]
					if not obj or not obj:is_valid() then
						needs_spawn = true
						break
					end
					local attach_parent = obj:get_attach()
					if not attach_parent or (attach_parent.is_valid and not attach_parent:is_valid()) then
						needs_spawn = true
						break
					end
					local is_target_parent = false
					for t = 1, #targets do
						if attach_parent == targets[t].parent then
							is_target_parent = true
							break
						end
					end
					if not is_target_parent then
						needs_spawn = true
						break
					end
				end
			end

			if needs_spawn then
				clear_element_visuals(name, element)
				local created = spawn_element_pieces(targets, element, target, name)
				created.item = target.item
				visuals.player_entities[name][element] = created
			end
		end
	end

	-- Reconcile shield wield item via x_player_api
	if has_x_api then
		local target = worn_elements.shield
		if target then
			local stack_or_name = target.stack or target.item
			local target_name = (type(stack_or_name) == "userdata" and stack_or_name:get_name())
				or (type(stack_or_name) == "string" and stack_or_name:match("%S+"))
				or ""
			local current_left = x_player_armor.compat_x_player_api.get_left_wield_item(player)
			if current_left ~= "" and current_left == target_name then
				x_player_armor.compat_x_player_api.update_shield(player, stack_or_name)
			else
				x_player_armor.compat_x_player_api.attach_shield(player, stack_or_name)
			end
		else
			x_player_armor.compat_x_player_api.remove_shield(player)
		end
	end
end

---Removes all visual armor entities for a player.
---@param player_name string|ObjectRef Target player name or ObjectRef
function visuals.clear_all(player_name)
	local name = x_player_armor.utils.get_player_name(player_name)
	if not name then return end

	local player_data = visuals.player_entities[name]
	if player_data then
		for _, list in pairs(player_data) do
			for i = 1, #list do
				local obj = list[i]
				if obj and obj:is_valid() then
					local ent = obj:get_luaentity()
					if ent then
						ent._intentional_removal = true
					end
					obj:set_detach()
					obj:remove()
				end
			end
		end
		visuals.player_entities[name] = nil
	end

	if x_player_armor.compat_x_player_api.is_present() then
		local player = core.get_player_by_name(name)
		x_player_armor.compat_x_player_api.remove_shield(player or name)
	end
end

---Cleans up any orphaned or detached x_player_armor:visual entities near connected players
---@return number count Cleaned up entities count
function visuals.cleanup_orphaned_visuals()
	local cleaned = 0
	local players = core.get_connected_players()
	for _, player in ipairs(players) do
		local pos = player:get_pos()
		if pos then
			local objs = core.get_objects_inside_radius(pos, 64)
			for _, obj in ipairs(objs) do
				local luaent = obj:get_luaentity()
				if luaent and luaent.name == "x_player_armor:visual" then
					local parent = obj:get_attach()
					if not parent or (parent.is_valid and not parent:is_valid()) then
						luaent._intentional_removal = true
						obj:set_detach()
						obj:remove()
						cleaned = cleaned + 1
					end
				end
			end
		end
	end
	return cleaned
end

local pending_restorations = {}

---Schedules debounced visual restoration for a player.
---Avoids multi-spawn thrashing when multiple armor pieces or entities are cleared simultaneously.
---@param player_name string Target player name
function visuals.schedule_player_restore(player_name)
	if not player_name or player_name == "" or pending_restorations[player_name] then
		return
	end
	pending_restorations[player_name] = true
	core.after(0.05, function()
		pending_restorations[player_name] = nil
		local player = core.get_player_by_name(player_name)
		if player and player:is_player() and (not player.is_valid or player:is_valid()) then
			visuals.update_player_visuals(player)
		end
	end)
end

---Restores armor visuals for all currently connected players.
function visuals.restore_all_players()
	local players = core.get_connected_players()
	for i = 1, #players do
		local player = players[i]
		if player and player:is_player() and (not player.is_valid or player:is_valid()) then
			visuals.update_player_visuals(player)
		end
	end
end

core.register_on_leaveplayer(function(player)
	visuals.clear_all(player)
end)

core.register_on_shutdown(function()
	for name in pairs(visuals.player_entities) do
		visuals.clear_all(name)
	end
end)

core.register_on_respawnplayer(function(player)
	core.after(0.1, function()
		if player and player:is_player() then
			visuals.update_player_visuals(player)
		end
	end)
end)

core.register_chatcommand("clean_armor_visuals", {
	params = "",
	description = "Clean up orphaned or disconnected armor visual entities",
	privs = {server = true},
	func = function()
		local count = visuals.cleanup_orphaned_visuals()
		return true, "Cleaned up " .. count .. " orphaned armor visual entities."
	end,
})

core.register_chatcommand("restore_armor_visuals", {
	params = "[<player_name>]",
	description = "Restore modular armor visual entities for a player or all connected players",
	privs = {server = true},
	func = function(_name, param)
		if param ~= "" then
			local player = core.get_player_by_name(param)
			if not player then
				return false, "Player '" .. param .. "' is not connected."
			end
			visuals.update_player_visuals(player)
			return true, "Restored armor visuals for player '" .. param .. "'."
		else
			visuals.restore_all_players()
			return true, "Restored armor visuals for all connected players."
		end
	end,
})

x_player_armor.visuals = visuals
return visuals
