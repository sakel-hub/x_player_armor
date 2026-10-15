---@class XPlayerArmorVisuals
local visuals = {
	player_entities = {},
	texture_cache = {},
	last_death_armor = {},
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
		backface_culling = false,
		shaded = true,
		glow = 0,
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	on_deactivate = function(self)
		if not self._intentional_removal and self._player_name then
			visuals.schedule_player_restore(self._player_name)
		end
	end,
	on_step = nil, -- Zero Lua tick overhead: engine scene graph handles bone tracking
})

---Determines the appropriate parent ObjectRef targets (handles x_player_api proxies if active).
---@param player ObjectRef
---@return table<{parent: ObjectRef, observers: table<string, boolean>?, format: string, is_skinsdb: boolean?}> targets
local function get_attachment_targets(player)
	local targets = {}
	local x_api = x_player_armor.get_mod_api("x_player_api")

	local model_name = (x_api and x_api.get_model_name and x_api.get_model_name(player))
	if not model_name and player and player.get_properties then
		local props = player:get_properties()
		model_name = props and props.mesh
	end

	local is_skinsdb = model_name and (
		model_name:find("skinsdb", 1, true) ~= nil or
		model_name:find("3d_armor", 1, true) ~= nil
	)

	if x_api and x_api.get_visual_proxies then
		if not (x_api.is_pure_native_b3d_active and x_api.is_pure_native_b3d_active(player)) then
			local proxies = x_api.get_visual_proxies(player)
			if proxies then
				local active_format = (x_api.get_model_format and x_api.get_model_format()) or "glb"
				local pdata = x_api.get_animation and x_api.get_animation(player)
				local m_name = (pdata and pdata.model) or model_name or (x_api.get_default_model and x_api.get_default_model())
				local model_def = m_name and x_api.get_model and x_api.get_model(m_name)
				local has_glb = (active_format ~= "b3d")
				if model_def then
					has_glb = (active_format ~= "b3d") and (model_def.mesh_glb ~= nil or (model_def.mesh and model_def.mesh:match("%.glb$") ~= nil))
				end

				-- Verify active proxies and non-zero visual size
				local glb_props = proxies.glb and proxies.glb:is_valid() and proxies.glb.get_properties and proxies.glb:get_properties()
				if glb_props and glb_props.visual_size and (glb_props.visual_size.x == 0 or glb_props.visual_size.y == 0) then
					has_glb = false
				end

				local b3d_props = proxies.b3d and proxies.b3d:is_valid() and proxies.b3d.get_properties and proxies.b3d:get_properties()
				local has_b3d = (proxies.b3d and proxies.b3d:is_valid()) and true or false
				if b3d_props and b3d_props.visual_size and (b3d_props.visual_size.x == 0 or b3d_props.visual_size.y == 0) then
					has_b3d = false
				end

				if active_format == "b3d" or not has_glb then
					if has_b3d then
						table.insert(targets, {
							parent = proxies.b3d,
							observers = nil,
							format = "b3d",
							is_skinsdb = is_skinsdb,
						})
					end
				elseif not has_b3d then
					if has_glb then
						table.insert(targets, {
							parent = proxies.glb,
							observers = nil,
							format = "glb",
							is_skinsdb = is_skinsdb,
						})
					end
				else
					-- Dual format mode: both proxies active
					if has_glb then
						table.insert(targets, {
							parent = proxies.glb,
							observers = nil,
							format = "glb",
							is_skinsdb = is_skinsdb,
						})
					end
					if has_b3d then
						table.insert(targets, {
							parent = proxies.b3d,
							observers = nil,
							format = "b3d",
							is_skinsdb = is_skinsdb,
						})
					end
				end
			end
		end
	end
	if #targets == 0 then
		local is_proxy_active = x_api and x_api.get_visual_proxies and not (x_api.is_pure_native_b3d_active and x_api.is_pure_native_b3d_active(player))
		if is_proxy_active then
			local pname = player and player:is_player() and player:get_player_name()
			if pname then
				visuals.schedule_player_restore(pname)
			end
			return targets
		end
		if x_player_armor.b3d_wiggler then
			x_player_armor.b3d_wiggler.ensure_player_wiggled_b3d(player)
		end
		table.insert(targets, {
			parent = player,
			observers = nil,
			format = "b3d",
			is_skinsdb = is_skinsdb,
		})
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

	local is_skinsdb = target.is_skinsdb
	if is_skinsdb == nil then
		local p_mesh = (parent.get_properties and parent:get_properties().mesh)
		if p_mesh then
			is_skinsdb = (p_mesh:find("skinsdb", 1, true) ~= nil) or (p_mesh:find("3d_armor", 1, true) ~= nil)
		elseif player_name then
			local p = core.get_player_by_name(player_name)
			if p and p:is_player() then
				local x_api = x_player_armor.get_mod_api("x_player_api")
				local mname = (x_api and x_api.get_model_name and x_api.get_model_name(p))
					or (p.get_properties and p:get_properties().mesh)
				is_skinsdb = mname and (
					(mname:find("skinsdb", 1, true) ~= nil) or
					(mname:find("3d_armor", 1, true) ~= nil)
				)
			end
		end
	end

	local rig_format = is_skinsdb and ("skinsdb_" .. format) or format
	local default_trans = (constants.ATTACH_TRANSFORMS[rig_format] and constants.ATTACH_TRANSFORMS[rig_format][piece_id])
		or (constants.ATTACH_TRANSFORMS[format] and constants.ATTACH_TRANSFORMS[format][piece_id])
	local custom_trans = item_def and item_def.transforms and (
		(item_def.transforms[rig_format] and item_def.transforms[rig_format][piece_id])
		or (item_def.transforms[format] and item_def.transforms[format][piece_id])
		or item_def.transforms[piece_id]
	)

	if not default_trans and not custom_trans then return nil end

	local bone = (custom_trans and custom_trans.bone) or (default_trans and default_trans.bone) or "Body"
	local pos = (custom_trans and custom_trans.pos) or (default_trans and default_trans.pos) or {x = 0, y = 0, z = 0}
	local rot = (custom_trans and custom_trans.rot) or (default_trans and default_trans.rot) or {x = 0, y = 0, z = 0}
	local scale = (custom_trans and custom_trans.scale)
		or (item_def and item_def.visual_size)
		or (default_trans and default_trans.scale)
		or {x = 1, y = 1, z = 1}

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
	local backface_culling = false
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
	-- 5th argument: true for standalone entities (corpses, stands) to guarantee rendering;
	-- false for living players to avoid first-person view frustum clipping
	local force_vis = (player_name == nil)
	obj:set_attach(parent, bone, pos, rot, force_vis)
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
	local def = x_player_armor.get_armor_def(item_name)
	local tex = def and (def.texture or (def._x_player_armor and def._x_player_armor.texture))
	if not tex then
		local resolved_name = core.registered_aliases[item_name] or item_name
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
				local idef = stack:get_definition() or x_player_armor.get_armor_def(item_name)
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
			local is_skinsdb_rig = (targets[1] and targets[1].is_skinsdb) or false
			if not current or current.item ~= target.item or (current.is_skinsdb ~= is_skinsdb_rig) or #current ~= expected_count then
				needs_spawn = true
			else
				local ds = rawget(_G, "deathstats")
				local is_dead_cam = (ds and type(ds.player_camera_data) == "table" and ds.player_camera_data[name] ~= nil)
					or (player.get_hp and player:get_hp() <= 0)
				-- Verify validity and attachment to an active target parent
				for i = 1, #current do
					local obj = current[i]
					if not obj or not obj:is_valid() then
						needs_spawn = true
						break
					end
					if not is_dead_cam and obj.get_properties then
						local oprops = obj:get_properties()
						if oprops and (oprops.is_visible == false
								or (oprops.visual_size and (oprops.visual_size.x == 0 or oprops.visual_size.y == 0))) then
							needs_spawn = true
							break
						end
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
				created.is_skinsdb = is_skinsdb_rig
				visuals.player_entities[name][element] = created
			end
		end
	end

	-- Reconcile shield wield item via x_player_api
	if has_x_api then
		local ds = rawget(_G, "deathstats")
		local is_dead_cam = (ds and type(ds.player_camera_data) == "table" and ds.player_camera_data[name] ~= nil)
		local target = worn_elements.shield
		local torso_item = (worn_elements.torso and worn_elements.torso.item) or ""
		local prev_torso_item = visuals.player_entities[name].shield_torso_item or ""
		if target then
			if not is_dead_cam then
				local stack_or_name = target.stack or target.item
				local target_name = (type(stack_or_name) == "userdata" and stack_or_name:get_name())
					or (type(stack_or_name) == "string" and stack_or_name:match("%S+"))
					or ""
				local current_left = x_player_armor.compat_x_player_api.get_left_wield_item(player)
				local x_api = x_player_armor.get_mod_api("x_player_api")
				local left_ent = x_api and x_api.get_left_wield_entity and x_api.get_left_wield_entity(player)
				if current_left ~= "" and current_left == target_name and prev_torso_item == torso_item and left_ent and left_ent:is_valid() then
					x_player_armor.compat_x_player_api.update_shield(player, stack_or_name)
				else
					x_player_armor.compat_x_player_api.attach_shield(player, stack_or_name)
				end
				visuals.player_entities[name].shield_torso_item = torso_item
			end
		else
			visuals.player_entities[name].shield_torso_item = nil
			x_player_armor.compat_x_player_api.remove_shield(player)
		end
	end

	-- Eagerly assemble and deliver dynamic 3D preview model if custom pieces are worn
	x_player_armor.gltf_assembler.update_player(player)
end

---Removes all visual armor entities for a player.
---@param player_name string|ObjectRef Target player name or ObjectRef
function visuals.clear_all(player_name)
	local name = x_player_armor.utils.get_player_name(player_name)
	if not name then return end

	local player_data = visuals.player_entities[name]
	if player_data then
		for _, list in pairs(player_data) do
			if type(list) == "table" then
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
	local name = player and player.get_player_name and player:get_player_name()
	if name and visuals.last_death_armor then
		visuals.last_death_armor[name] = nil
	end
	core.after(0.05, function()
		if player and player:is_player() then
			visuals.update_player_visuals(player)
		end
	end)
	core.after(0.2, function()
		if player and player:is_player() then
			visuals.verify_player_visuals(player)
		end
	end)
end)

---Verifies that all worn armor and shield pieces for a player have valid, attached visual entities.
---Performs an on-demand reconciliation if any worn piece is missing, detached, or on an unready proxy.
---@param player ObjectRef Target player
---@return boolean needs_repair True if visuals required and executed repair, false if already healthy
function visuals.verify_player_visuals(player)
	if not player or not player:is_player() or (player.is_valid and not player:is_valid()) then
		return false
	end

	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then return false end

	local ds = rawget(_G, "deathstats")
	if (ds and type(ds.player_camera_data) == "table" and ds.player_camera_data[name] ~= nil)
			or (player.get_hp and player:get_hp() <= 0) then
		return false
	end

	local armor_list = inv:get_list("armor")
	if not armor_list then return false end

	local has_any_armor = false
	for slot = 1, 5 do
		local stack = armor_list[slot]
		if stack and not stack:is_empty() then
			has_any_armor = true
			break
		end
	end

	if not has_any_armor then return false end

	local ents = visuals.player_entities[name]
	local needs_repair = not ents

	if not needs_repair then
		for slot = 1, 4 do
			local el = constants.SLOT_ELEMENTS[slot]
			local stack = armor_list[slot]
			if stack and not stack:is_empty() then
				local el_ents = ents[el]
				if not el_ents or #el_ents == 0 then
					needs_repair = true
					break
				else
					for e = 1, #el_ents do
						local obj = el_ents[e]
						if not obj or not obj:is_valid() then
							needs_repair = true
							break
						end
						if obj.get_properties then
							local oprops = obj:get_properties()
							if oprops and (oprops.is_visible == false
									or (oprops.visual_size and (oprops.visual_size.x == 0 or oprops.visual_size.y == 0))) then
								needs_repair = true
								break
							end
						end
						local p = obj:get_attach()
						if not p or (p.is_valid and not p:is_valid()) then
							needs_repair = true
							break
						end
						local pprops = p.get_properties and p:get_properties()
						if pprops and pprops.visual_size and (pprops.visual_size.x == 0 or pprops.visual_size.y == 0) then
							needs_repair = true
							break
						end
					end
				end
			end
			if needs_repair then break end
		end

		-- Check shield (slot 5)
		if not needs_repair then
			local shield_stack = armor_list[5]
			if shield_stack and not shield_stack:is_empty() then
				if x_player_armor.compat_x_player_api.is_present() then
					local cur_item = x_player_armor.compat_x_player_api.get_left_wield_item(player)
					local x_api = x_player_armor.get_mod_api("x_player_api")
					local left_ent = x_api and x_api.get_left_wield_entity and x_api.get_left_wield_entity(player)
					if cur_item == "" or not left_ent or not left_ent:is_valid() then
						needs_repair = true
					end
				end
			end
		end
	end

	if x_player_armor.b3d_wiggler then
		x_player_armor.b3d_wiggler.ensure_player_wiggled_b3d(player)
	end

	if needs_repair then
		visuals.update_player_visuals(player)
		return true
	end
	return false
end

-- Event-driven visual self-healing registration.
-- Hooks proxy activation and lifecycle events without continuous globalstep polling.
local watchdog_registered = false
function visuals.register_watchdog()
	if watchdog_registered then return end
	watchdog_registered = true

	if x_player_armor.b3d_wiggler then
		x_player_armor.b3d_wiggler.scan_and_wiggle_registered_b3d_models()
	end
	if x_player_armor.override and x_player_armor.override.hook_visual_triggers then
		x_player_armor.override.hook_visual_triggers()
	end

	-- luacheck: push
	-- luacheck: ignore 122
	local function hook_proxy_entity(entity_name)
		local edef = core.registered_entities[entity_name]
		if edef and not edef._x_pa_proxy_wrapped then
			edef._x_pa_proxy_wrapped = true
			local orig_activate = edef.on_activate
			edef.on_activate = function(self, staticdata, dtime_s)
				if orig_activate then
					orig_activate(self, staticdata, dtime_s)
				end
				core.after(0.05, function()
					if self.object and self.object:is_valid() then
						local parent = self.object:get_attach()
						if parent and parent:is_player() then
							visuals.schedule_player_restore(parent:get_player_name())
						end
					end
				end)
			end
		end
	end
	hook_proxy_entity("x_player_api:visual_glb")
	hook_proxy_entity("x_player_api:visual_b3d")
	-- luacheck: pop
end

---Attaches modular 3D armor visuals to a target parent entity (such as a corpse).
---@param parent ObjectRef The entity to attach armor to
---@param player_or_name ObjectRef|string|(string|ItemStack)[] Player object, player name, or explicit armor item list
---@param format string? Model format ("glb" or "b3d")
---@return ObjectRef[] entities List of spawned armor visual entities
function visuals.attach_armor_to_entity(parent, player_or_name, format)
	if not parent or (parent.is_valid and not parent:is_valid()) then
		return {}
	end

	local parent_lua = parent.get_luaentity and parent:get_luaentity()
	if parent_lua then
		parent_lua._x_pa_torso_item = nil
	end

	local fmt = format
	if not fmt or fmt == "" then
		local p_mesh = (parent.get_properties and parent:get_properties().mesh) or ""
		fmt = (p_mesh:find("%.glb$") or p_mesh:find("%.gltf$")) and "glb" or "b3d"
	end

	local armor_stacks = {}
	if type(player_or_name) == "table" and not (player_or_name.is_player and player_or_name:is_player()) then
		-- Explicit list of items (ItemStacks, item name strings, or serialized table definitions)
		for _, item in ipairs(player_or_name) do
			if type(item) == "string" and item ~= "" then
				table.insert(armor_stacks, ItemStack(item))
			elseif (type(item) == "userdata" or (type(item) == "table" and item.get_name)) and not item:is_empty() then
				table.insert(armor_stacks, item)
			elseif type(item) == "table" and (item.name or item.item) then
				table.insert(armor_stacks, ItemStack(item.name or item.item))
			end
		end
	elseif player_or_name then
		local pname = nil
		local player_obj = nil
		if type(player_or_name) == "string" then
			pname = player_or_name
			player_obj = core.get_player_by_name(pname)
		elseif type(player_or_name) == "userdata" or (type(player_or_name) == "table" and player_or_name.is_player and player_or_name:is_player()) then
			player_obj = player_or_name
			pname = player_obj.get_player_name and player_obj:get_player_name()
		end

		local has_live_inv = false
		if player_obj and player_obj.is_player and player_obj:is_player() then
			local _, inv = x_player_armor.get_valid_player(player_obj)
			if inv then
				local list = inv:get_list("armor")
				if list then
					has_live_inv = true
					for _, st in ipairs(list) do
						if st and not st:is_empty() then
							table.insert(armor_stacks, st)
						end
					end
				end
			end
		end

		-- If inventory was already cleared on death (or unavailable), consult last_death_armor snapshot
		if #armor_stacks == 0 and (not has_live_inv or constants.DROP_ON_DEATH or constants.DESTROY_ON_DEATH) and pname and visuals.last_death_armor[pname] then
			for _, st in ipairs(visuals.last_death_armor[pname]) do
				if st and not st:is_empty() then
					table.insert(armor_stacks, st)
				end
			end
		end
	end

	if #armor_stacks == 0 then
		return {}
	end

	local p_mesh = (parent.get_properties and parent:get_properties().mesh) or ""
	local is_skinsdb = (p_mesh:find("skinsdb", 1, true) ~= nil) or (p_mesh:find("3d_armor", 1, true) ~= nil)
	local target = { parent = parent, format = fmt, is_skinsdb = is_skinsdb }
	local created = {}

	for _, stack in ipairs(armor_stacks) do
		local iname = stack:get_name()
		if iname and iname ~= "" then
			local tex = visuals.get_item_texture(iname)
			if tex then
				local idef = stack:get_definition() or x_player_armor.get_armor_def(iname)
				local element = idef and idef.element
				if not element then
					for _, el in ipairs({"head", "torso", "legs", "feet"}) do
						if core.get_item_group(iname, "armor_" .. el) > 0 then
							element = el
							break
						end
					end
				end

				if element and element ~= "shield" then
					if element == "torso" and parent_lua then
						parent_lua._x_pa_torso_item = iname
					end
					local piece_ids = (idef and idef.pieces) or constants.ELEMENT_PIECES[element]
					if piece_ids then
						for _, piece_id in ipairs(piece_ids) do
							local obj = spawn_piece(target, piece_id, tex, idef and idef.glow, nil, idef)
							if obj then
								local ent = obj:get_luaentity()
								if ent then
									ent._is_corpse = true
									ent._intentional_removal = true
								end
								table.insert(created, obj)
							end
						end
					end
				end
			end
		end
	end

	return created
end

---Resolves the composite attachment options, mesh, textures, and calibrated transforms for a shield item.
---Single source of truth used for both standalone entity attachment and x_player_api left-wield integration.
---@param item_or_stack string|ItemStack Shield item name or stack
---@param custom_opts? XPlayerArmorShieldVisualOpts Optional overrides
---@return XPlayerArmorResolvedShieldOpts opts Resolved options table
function visuals.resolve_shield_visual_opts(item_or_stack, custom_opts)
	local item_name = (type(item_or_stack) == "userdata" and item_or_stack:get_name())
		or (type(item_or_stack) == "table" and item_or_stack.get_name and item_or_stack:get_name())
		or (type(item_or_stack) == "table" and (item_or_stack.name or item_or_stack.item))
		or (type(item_or_stack) == "string" and item_or_stack:match("%S+"))
		or ""
	local item_def = core.registered_items[item_name]
		or x_player_armor.get_armor_def(item_name)
	local shield_trans = constants.SHIELD_OFFSET or {}
	local glb_trans = shield_trans.glb or {}
	local b3d_trans = shield_trans.b3d or {}
	local item_offset = item_def and (item_def.shield_offset or item_def.shield_transform)

	local custom_mesh = (custom_opts and custom_opts.mesh)
		or (item_def and (item_def.mesh or item_def.model))

	local item_tex = (item_name ~= "" and visuals.get_item_texture(item_name))
		or (item_def and (item_def.texture or item_def.inventory_image))

	local custom_textures = (custom_opts and custom_opts.textures)
		or (item_def and (item_def.textures or (item_def.texture and {item_def.texture})))
		or (item_tex and {item_tex})

	local visual_type = (custom_opts and custom_opts.visual) or (custom_mesh and "mesh") or "wielditem"

	local is_bone_local = (custom_opts and custom_opts.bone_local)
		or (item_def and item_def.bone_local)

	local pos_glb
	local rot_glb
	local pos_b3d
	local rot_b3d
	local scale

	if is_bone_local and not item_offset and not (custom_opts and (custom_opts.pos or custom_opts.pos_glb)) then
		pos_glb = {x = 0, y = 0, z = 0}
		rot_glb = {x = 0, y = 0, z = 0}
		pos_b3d = {x = 0, y = 0, z = 0}
		rot_b3d = {x = 0, y = 180, z = 0}
		scale = (custom_opts and (custom_opts.scale_glb or custom_opts.scale)) or {x = 1, y = 1, z = 1}
	else
		pos_glb = (custom_opts and custom_opts.pos_glb)
			or (item_offset and item_offset.glb and item_offset.glb.pos)
			or (item_offset and item_offset.pos)
			or (custom_opts and custom_opts.pos)
			or glb_trans.pos
			or {x = -0.95, y = 4.44, z = -1.48}
		rot_glb = (custom_opts and custom_opts.rot_glb)
			or (item_offset and item_offset.glb and item_offset.glb.rot)
			or (item_offset and item_offset.rot)
			or (custom_opts and custom_opts.rot)
			or glb_trans.rot
			or {x = -171.4, y = 70.5, z = -1.7}

		pos_b3d = (custom_opts and custom_opts.pos_b3d)
			or (item_offset and item_offset.b3d and item_offset.b3d.pos)
			or (item_offset and item_offset.pos)
			or (custom_opts and custom_opts.pos)
			or b3d_trans.pos
			or {x = 0.95, y = 4.44, z = 1.48}
		rot_b3d = (custom_opts and custom_opts.rot_b3d)
			or (item_offset and item_offset.b3d and item_offset.b3d.rot)
			or (item_offset and item_offset.rot)
			or (custom_opts and custom_opts.rot)
			or b3d_trans.rot
			or {x = -171.4, y = -109.5, z = -1.7}

		scale = (custom_opts and (custom_opts.scale_glb or custom_opts.scale))
			or (item_offset and item_offset.glb and item_offset.glb.scale)
			or (item_offset and item_offset.scale)
			or glb_trans.scale
			or (item_def and item_def.visual_size)
			or {x = 1, y = 1, z = 1}
	end

	-- Apply torso-driven shield_clearance offset if a bulky torso is worn (and no explicit custom pos override)
	if not (custom_opts and (custom_opts.pos or custom_opts.pos_glb or custom_opts.pos_b3d)) then
		local clearance = custom_opts and custom_opts.shield_clearance
		if not clearance and custom_opts and custom_opts.torso_item then
			local t_item = custom_opts.torso_item
			local t_name = (type(t_item) == "userdata" and t_item:get_name())
				or (type(t_item) == "table" and t_item.get_name and t_item:get_name())
				or (type(t_item) == "table" and (t_item.name or t_item.item))
				or (type(t_item) == "string" and t_item:match("%S+"))
				or ""
			if t_name ~= "" then
				local t_def = x_player_armor.get_armor_def(t_name) or core.registered_items[t_name]
				clearance = t_def and t_def.shield_clearance
			end
		end
		if clearance then
			local c_glb = (clearance.glb and clearance.glb.pos) or clearance.pos
			if c_glb then
				pos_glb = {
					x = (pos_glb.x or 0) + (c_glb.x or 0),
					y = (pos_glb.y or 0) + (c_glb.y or 0),
					z = (pos_glb.z or 0) + (c_glb.z or 0),
				}
			end
			local c_b3d = (clearance.b3d and clearance.b3d.pos)
				or (clearance.pos and {
					x = -(clearance.pos.x or 0),
					y = clearance.pos.y or 0,
					z = -(clearance.pos.z or 0),
				})
			if c_b3d then
				local dx = c_b3d.x or 0
				if c_glb and (c_glb.x or 0) < 0 and dx < 0 then
					dx = -dx
				end
				pos_b3d = {
					x = (pos_b3d.x or 0) + dx,
					y = (pos_b3d.y or 0) + (c_b3d.y or 0),
					z = (pos_b3d.z or 0) + (c_b3d.z or 0),
				}
			end
		end
	end

	local opts = {
		visual = visual_type,
		mesh = custom_mesh,
		textures = custom_textures,
		override_transform = true,
		pos_glb = pos_glb,
		rot_glb = rot_glb,
		pos_b3d = pos_b3d,
		rot_b3d = rot_b3d,
		scale = scale,
		visual_size = scale,
		bone_local = is_bone_local,
		item_def = item_def,
		item_name = item_name,
	}

	if custom_opts then
		for k, v in pairs(custom_opts) do
			if opts[k] == nil then
				opts[k] = v
			end
		end
	end

	return opts
end

---Attaches a shield visual entity to a target parent entity (such as a corpse or mob) with proper forearm transforms.
---@param parent ObjectRef The entity to attach the shield to
---@param item_or_stack string|ItemStack Shield item name or stack
---@param format string? Model format ("glb" or "b3d")
---@param custom_opts? XPlayerArmorShieldVisualOpts Optional custom overrides
---@return ObjectRef? entity The attached shield entity or nil
function visuals.attach_shield_to_entity(parent, item_or_stack, format, custom_opts)
	if not parent or (parent.is_valid and not parent:is_valid()) then
		return nil
	end

	local resolve_opts = custom_opts
	if not custom_opts or (custom_opts.torso_item == nil and custom_opts.shield_clearance == nil) then
		local parent_lua = parent.get_luaentity and parent:get_luaentity()
		if parent_lua and parent_lua._x_pa_torso_item then
			resolve_opts = custom_opts and table.copy(custom_opts) or {}
			resolve_opts.torso_item = parent_lua._x_pa_torso_item
		end
	end

	local opts = visuals.resolve_shield_visual_opts(item_or_stack, resolve_opts)
	local item_name = opts.item_name
	if not item_name or item_name == "" then
		return nil
	end

	local fmt = format
	if not fmt or fmt == "" then
		local p_mesh = (parent.get_properties and parent:get_properties().mesh) or ""
		fmt = (p_mesh:find("%.glb$") or p_mesh:find("%.gltf$")) and "glb" or "b3d"
	end

	local bone = (custom_opts and custom_opts.bone) or "Arm_Left"
	local ent_name = (custom_opts and custom_opts.entity_name)
		or (core.registered_entities["deathstats:corpse_wielditem"] and "deathstats:corpse_wielditem")
		or "x_player_armor:visual"

	local x_api = x_player_armor.get_mod_api("x_player_api")
	local ent = nil

	if x_api and type(x_api.attach_wield_item_to_entity) == "function" and (x_api.enable_wield_item ~= false) then
		ent = x_api.attach_wield_item_to_entity(parent, item_or_stack, fmt, bone, ent_name, true, opts)
	end

	if not ent then
		local pos = parent:get_pos()
		if not pos then return nil end
		local obj = core.add_entity(pos, ent_name)
		if obj and obj:is_valid() then
			local v_size = (opts.visual == "wielditem") and {x = 0.25, y = 0.25, z = 0.25}
				or (custom_opts and (custom_opts.visual_size or custom_opts.scale))
				or opts.scale or (opts.item_def and opts.item_def.visual_size) or {x = 1, y = 1, z = 1}
			local glow = (custom_opts and custom_opts.glow) or (opts.item_def and opts.item_def.glow) or 0
			obj:set_properties({
				visual = opts.visual,
				mesh = opts.mesh,
				textures = opts.textures or {item_name},
				wield_item = item_name,
				visual_size = v_size,
				pointable = false,
				glow = glow,
			})
			local att_pos = (fmt == "glb") and opts.pos_glb or opts.pos_b3d
			local att_rot = (fmt == "glb") and opts.rot_glb or opts.rot_b3d
			obj:set_attach(parent, bone, att_pos, att_rot, true)
			ent = obj
		end
	end

	if ent then
		local luaent = ent:get_luaentity()
		if luaent then
			luaent._is_corpse = true
			luaent._intentional_removal = true
		end
	end

	return ent
end

---Attaches a wield item visual entity to a target parent entity (such as an armor stand or corpse) on the right arm.
---@param parent ObjectRef The entity to attach the wield item to
---@param item_or_stack string|ItemStack Held item name or stack
---@param format string? Model format ("glb" or "b3d")
---@param custom_opts? table Optional custom overrides
---@return ObjectRef? entity The attached visual entity or nil
function visuals.attach_wield_item_to_entity(parent, item_or_stack, format, custom_opts)
	if not parent or (parent.is_valid and not parent:is_valid()) then
		return nil
	end

	local item_name = (type(item_or_stack) == "userdata" and item_or_stack:get_name())
		or (type(item_or_stack) == "table" and item_or_stack.get_name and item_or_stack:get_name())
		or (type(item_or_stack) == "table" and (item_or_stack.name or item_or_stack.item))
		or (type(item_or_stack) == "string" and item_or_stack:match("%S+"))
		or ""
	if item_name == "" then
		return nil
	end

	local fmt = format
	if not fmt or fmt == "" then
		local p_mesh = (parent.get_properties and parent:get_properties().mesh) or ""
		fmt = (p_mesh:find("%.glb$") or p_mesh:find("%.gltf$")) and "glb" or "b3d"
	end

	local bone = (custom_opts and custom_opts.bone) or "Arm_Right"
	local ent_name = (custom_opts and custom_opts.entity_name)
		or "x_player_armor:visual"

	local x_api = x_player_armor.get_mod_api("x_player_api")
	local ent = nil

	if x_api and type(x_api.attach_wield_item_to_entity) == "function" and (x_api.enable_wield_item ~= false) then
		ent = x_api.attach_wield_item_to_entity(parent, item_or_stack, fmt, bone, ent_name, true, custom_opts)
	end

	if not ent then
		local pos = parent:get_pos()
		if not pos then return nil end
		local obj = core.add_entity(pos, ent_name)
		if obj and obj:is_valid() then
			local v_size = (custom_opts and (custom_opts.visual_size or custom_opts.scale))
				or {x = 0.275, y = 0.275, z = 0.275}
			local glow = (custom_opts and custom_opts.glow) or 0
			obj:set_properties({
				visual = "wielditem",
				wield_item = item_name,
				visual_size = v_size,
				pointable = false,
				glow = glow,
			})
			local att_pos = (fmt == "glb") and {x = 0, y = 5.2, z = -3.5} or {x = 0, y = 5.2, z = 3.5}
			local att_rot = (fmt == "glb") and {x = -90, y = 45, z = -90} or {x = -90, y = 225, z = 90}
			if custom_opts then
				att_pos = (fmt == "glb" and (custom_opts.pos_glb or custom_opts.pos))
					or custom_opts.pos_b3d or custom_opts.pos or att_pos
				att_rot = (fmt == "glb" and (custom_opts.rot_glb or custom_opts.rot))
					or custom_opts.rot_b3d or custom_opts.rot or att_rot
			end
			obj:set_attach(parent, bone, att_pos, att_rot, true)
			ent = obj
		end
	end

	if ent then
		local luaent = ent:get_luaentity()
		if luaent then
			luaent._intentional_removal = true
		end
	end

	return ent
end


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
