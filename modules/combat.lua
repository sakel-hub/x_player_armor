---@class XPlayerArmorCombat
local combat = {}

local S = core.get_translator("x_player_armor")
local constants = x_player_armor.constants
local utils = x_player_armor.utils

---Plays combat audio for a player.
---@param pos vector
---@param sound_name string
---@param gain number?
local function play_sound(pos, sound_name, gain)
	if not constants.ENABLE_SOUNDS or not pos then return end
	core.sound_play(sound_name, {
		pos = pos,
		gain = gain or 0.8,
		max_hear_distance = 20.0,
	})
end

---Plays appropriate destruction audio when an armor piece breaks.
---@param pos vector
---@param item_name string
---@param def table?
local function play_break_sound(pos, item_name, def)
	local custom_break = def and (def.sound_break or (def.sounds and (def.sounds.break_sound or def.sounds.destroy or def.sounds["break"])))
	if custom_break and custom_break ~= "" then
		play_sound(pos, custom_break, 1.0)
		return
	end
	if item_name:find("wood") or item_name:find("cactus") then
		play_sound(pos, constants.SOUNDS.break_wood, 1.0)
	elseif item_name:find("crystal") or item_name:find("diamond") then
		play_sound(pos, constants.SOUNDS.break_crystal, 1.0)
	else
		play_sound(pos, constants.SOUNDS.break_metal, 1.0)
	end
end

---Plays appropriate impact deflection audio when armor is struck.
---@param pos vector
---@param has_shield boolean
---@param dominant_material string?
---@param custom_hit_sound string?
local function play_impact_sound(pos, has_shield, dominant_material, custom_hit_sound)
	if custom_hit_sound and custom_hit_sound ~= "" then
		play_sound(pos, custom_hit_sound, 0.8)
		return
	end
	if has_shield and math.random(1, 2) == 1 then
		play_sound(pos, constants.SOUNDS.shield_block, 0.9)
	elseif dominant_material == "wood" or dominant_material == "cactus" then
		play_sound(pos, constants.SOUNDS.hit_wood, 0.8)
	elseif dominant_material == "crystal" or dominant_material == "diamond" then
		play_sound(pos, constants.SOUNDS.hit_crystal, 0.8)
	else
		play_sound(pos, constants.SOUNDS.hit_metal, 0.8)
	end
end

---- Delegate visual particle effects to dedicated VFX subsystem (SOLID architecture)
local vfx = x_player_armor.vfx

combat.spawn_particles = vfx.spawn_particles
combat.spawn_heal_particles = vfx.spawn_heal_particles
combat.spawn_shield_block_particles = vfx.spawn_shield_block_particles
combat.spawn_armor_break_particles = vfx.spawn_armor_break_particles
combat.spawn_impact_particles = vfx.spawn_impact_particles

---Applies durability wear to an armor item in the player's inventory using engine add_wear_by_uses.
---@param player ObjectRef
---@param index number
---@param stack ItemStack
---@param uses number
---@return boolean destroyed
function combat.damage_item(player, index, stack, uses)
	if stack:is_empty() or not uses or uses <= 0 then
		return false
	end

	local old_wear = stack:get_wear()
	local item_name = stack:get_name()

	-- Native Luanti engine wear calculation (distributes remainder evenly without rounding drift)
	-- Supports raw wear if uses > 65535 or uses passed as raw delta
	if uses > 65535 then
		stack:add_wear(uses)
	else
		stack:add_wear_by_uses(uses)
	end
	local is_broken = stack:is_empty()
	local new_wear = is_broken and 65535 or stack:get_wear()

	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then
		return false
	end

	local pos = player:get_pos()

	-- Low-durability warning
	if not is_broken and old_wear <= 60100 and new_wear > 60100 then
		local def = stack:get_definition()
		local desc = def and (def.short_description or def.description) or item_name
		core.chat_send_player(name, S("Warning: Your @1 is almost broken!", desc))
		if pos then
			play_sound(pos, constants.SOUNDS.warn, 0.7)
		end
	end

	if is_broken then
		-- Item broken
		if pos then
			local broken_def = core.registered_items[item_name] or (x_player_armor.registered_armors and x_player_armor.registered_armors[item_name])
			play_break_sound(pos, item_name, broken_def)
			combat.spawn_armor_break_particles(pos, item_name, player)
		end
		inv:set_stack("armor", index, ItemStack(""))
		x_player_armor.run_callbacks("on_destroy", player, index, stack)
		x_player_armor.set_player_armor(player)
		x_player_armor.update_player_visuals(player)
		x_player_armor.ui.refresh_player_formspec(player)
		x_player_armor.compat_hud.sync_player_hud_def(player, inv)
		x_player_armor.combat_hud.trigger(player)
		return true
	else
		inv:set_stack("armor", index, stack)
		x_player_armor.run_callbacks("on_damage", player, index, stack, uses)
		x_player_armor.compat_hud.sync_player_hud_def(player, inv)
		x_player_armor.combat_hud.trigger(player)
		return false
	end
end

combat.last_punch_dirs = {}
combat.was_blocked = {}

---Resolves the equipped shield ItemStack, slot index, and material key for a player.
---Shields must be equipped in the armor inventory (slot 5 or auxiliary slot 6) and
---wielded in the left hand (queried via x_player_api when available).
---Holding a shield in the main (right) hand from hotbar does not count.
---@param player ObjectRef
---@return ItemStack? shield_stack, number? slot_idx, string? mat_key
function combat.get_equipped_shield(player)
	if not player or not player:is_player() then return nil, nil, nil end

	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then return nil, nil, nil end

	-- When x_player_api is present, query the left-hand wield item
	local left_item = nil
	if x_player_armor.compat_x_player_api.is_present() then
		local left_wield = x_player_armor.compat_x_player_api.get_left_wield_item(player)
		if left_wield and left_wield ~= "" then
			local is_shield = (core.get_item_group(left_wield, "armor_shield") > 0)
				or (core.get_item_group(left_wield, "shield") > 0)
			if not is_shield then
				-- Left hand is holding a non-shield item (e.g. torch, tool)
				return nil, nil, nil
			end
			left_item = left_wield
		end
	end

	-- Check primary shield slot (slot 5) and auxiliary slot (slot 6) in armor inventory
	for _, slot_idx in ipairs({5, 6}) do
		local stack = inv:get_stack("armor", slot_idx)
		if stack and not stack:is_empty() then
			local stack_name = stack:get_name()
			local sdef = stack:get_definition()
			if sdef and sdef.groups and ((sdef.groups.armor_shield or 0) > 0 or (sdef.groups.shield or 0) > 0) then
				-- If left-hand item is specifically tracked, ensure it matches this shield stack
				if not left_item or left_item == stack_name then
					local mat = utils.get_item_material(stack_name) or "wood"
					return stack, slot_idx, mat
				end
			end
		end
	end
	return nil, nil, nil
end

---Evaluates whether a player is capable of blocking with an equipped shield.
---Delegates to x_player_api.evaluate_can_block when available to respect two-handed weapons,
---bow drawing, and item classification, with a robust standalone fallback.
---@nodiscard
---@param player ObjectRef Target player
---@return boolean can_block
function combat.can_block(player)
	if not player or not player:is_player() then
		return false
	end

	local x_api = x_player_armor.compat_x_player_api.get_api()
	if x_api and x_api.evaluate_can_block then
		return x_api.evaluate_can_block(player)
	end

	-- Standalone fallback when x_player_api is absent or evaluate_can_block is not provided
	local shield_stack = combat.get_equipped_shield(player)
	if not shield_stack then
		return false
	end

	local wielded = player:get_wielded_item()
	local wname = wielded and wielded:get_name() or ""
	if wname ~= "" then
		local wdef = wielded:get_definition()
		local wgroups = wdef and wdef.groups
		if wgroups and (wgroups.bow or wgroups.bow_charged or wgroups.crossbow or wgroups.two_handed) then
			return false
		end
	end

	return true
end

---Checks whether a player is actively holding a shield block stance.
---@param player ObjectRef
---@return boolean is_blocking, ItemStack? shield_stack, number? slot_idx, string? mat_key
function combat.is_blocking(player)
	if not player or not player:is_player() then
		return false, nil, nil, nil
	end

	local shield_stack, slot_idx, mat_key = combat.get_equipped_shield(player)
	if not shield_stack then
		return false, nil, nil, nil
	end

	-- Verify blocking capability (suppressed by bows, two-handed weapons, or left-hand items)
	if not combat.can_block(player) then
		return false, nil, nil, nil
	end

	-- Query x_player_api high-level semantic state if available
	if x_player_armor.compat_x_player_api.is_present() then
		local x_api = x_player_armor.compat_x_player_api.get_api()
		if x_api and x_api.get_player_state then
			local pstate = x_api.get_player_state(player)
			if pstate and (pstate.action == "block" or (pstate.blocking == true and not pstate.aiming_bow and not pstate.shooting_bow)) then
				return true, shield_stack, slot_idx, mat_key
			end
			return false, nil, nil, nil
		end
	end

	-- Standalone fallback: evaluate player controls (RMB / place)
	local ctrl = player:get_player_control()
	local rmb = ctrl and (ctrl.RMB or ctrl.place) or false
	if rmb then
		return true, shield_stack, slot_idx, mat_key
	end

	return false, nil, nil, nil
end

---Calculates the 3D world origin position of the shield contact surface (Tier 1 deflection origin).
---Biased to the lower-left viewport where the off-hand shield is actively held in guard stance.
---@param player ObjectRef
---@return vector shield_pos 3D world coordinate of shield surface
function combat.get_shield_contact_pos(player)
	local ppos = player:get_pos()
	if not ppos then
		return {x = 0, y = 0, z = 0}
	end

	local props = player:get_properties()
	local eye_height = (props and props.eye_height) or 1.47
	local eye_x = ppos.x
	local eye_y = ppos.y + eye_height
	local eye_z = ppos.z

	local look_dir = player:get_look_dir() or {x = 0, y = 0, z = 1}
	local f_len = math.sqrt(look_dir.x * look_dir.x + look_dir.y * look_dir.y + look_dir.z * look_dir.z)
	local fx, fy, fz
	if f_len > 0.0001 then
		fx, fy, fz = look_dir.x / f_len, look_dir.y / f_len, look_dir.z / f_len
	else
		fx, fy, fz = 0, 0, 1
	end

	-- Horizontal perpendicular right vector
	local h_len = math.sqrt(fx * fx + fz * fz)
	local rx, ry, rz
	if h_len > 0.0001 then
		rx, ry, rz = fz / h_len, 0, -fx / h_len
	else
		rx, ry, rz = 1, 0, 0
	end

	-- True up vector (F x R cross product)
	local ux = fy * rz - fz * ry
	local uy = fz * rx - fx * rz
	local uz = fx * ry - fy * rx

	-- Offsets: 0.65m forward, -0.40m left (off-hand side), -0.35m down (chest/shield level)
	local d_fwd = 0.65
	local d_right = -0.40
	local d_up = -0.35

	return {
		x = eye_x + fx * d_fwd + rx * d_right + ux * d_up,
		y = eye_y + fy * d_fwd + ry * d_right + uy * d_up,
		z = eye_z + fz * d_fwd + rz * d_right + uz * d_up,
	}
end

---Validates whether an incoming attack or projectile vector falls within the player's blocking cone.
---Incorporates Tier 2 asymmetric guard cone bias rotating the cone axis ~22 degrees counter-clockwise
---towards the player's left side (where the shield is physically held in the off-hand).
---Attacks outside this cone (on the exposed right weapon side or from the rear) penetrate.
---@param player ObjectRef
---@param attack_dir vector Direction pointing from the attacker/projectile towards the player
---@param max_arc_deg number? Maximum blocking arc in degrees (default constants.BLOCK_CONE_ANGLE or 52)
---@param bias_deg number? Custom lateral bias angle in degrees (default constants.BLOCK_ASYMMETRIC_BIAS or 22)
---@return boolean is_facing
function combat.is_facing_attack(player, attack_dir, max_arc_deg, bias_deg)
	if not player or not attack_dir then return false end
	local look_dir = player:get_look_dir()
	if not look_dir then return false end

	-- Horizontal look vector normalized
	local h_look_len = math.sqrt(look_dir.x * look_dir.x + look_dir.z * look_dir.z)
	local h_look_x, h_look_z
	if h_look_len > 0.0001 then
		h_look_x = look_dir.x / h_look_len
		h_look_z = look_dir.z / h_look_len
	else
		h_look_x, h_look_z = 0, 1
	end

	-- Apply Tier 2 asymmetric guard cone bias towards left off-hand shield
	local bias = bias_deg
	if bias == nil then
		bias = constants.BLOCK_ASYMMETRIC_BIAS or 22
	end
	if bias ~= 0 then
		local bias_rad = math.rad(bias)
		local cos_b = math.cos(bias_rad)
		local sin_b = math.sin(bias_rad)
		local bx = h_look_x * cos_b - h_look_z * sin_b
		local bz = h_look_x * sin_b + h_look_z * cos_b
		h_look_x, h_look_z = bx, bz
	end

	-- Vector pointing from player towards the threat (-attack_dir)
	local threat_x = -attack_dir.x
	local threat_z = -attack_dir.z
	local t_len = math.sqrt(threat_x * threat_x + threat_z * threat_z)
	if t_len <= 0.0001 then
		return false
	end
	threat_x = threat_x / t_len
	threat_z = threat_z / t_len

	local dot = h_look_x * threat_x + h_look_z * threat_z
	local arc = max_arc_deg or constants.BLOCK_CONE_ANGLE or 52
	local min_dot = math.cos(math.rad(arc * 0.5))
	return dot >= min_dot
end

---Resolves the attack direction pointing from attacker towards the player.
---@param player ObjectRef
---@param reason table
---@return vector? attack_dir
function combat.get_attack_direction(player, reason)
	local name = player:get_player_name()
	local cached_dir = combat.last_punch_dirs[name]
	if cached_dir then
		combat.last_punch_dirs[name] = nil
		return cached_dir
	end

	if reason.object and reason.object.is_valid and reason.object:is_valid() then
		local opos = reason.object:get_pos()
		local ppos = player:get_pos()
		if opos and ppos then
			local dir = vector.direction(opos, ppos)
			if dir and (dir.x ~= 0 or dir.y ~= 0 or dir.z ~= 0) then
				return dir
			end
		end
	end

	return nil
end

---Attempts to deflect an incoming projectile with the player's active shield.
---Simulates realistic reflection physics, energy restitution, glancing drag, and orientation.
---Enforces Tier 2 asymmetric guard cone bias and spatial hit position filtering (only deflecting
---projectiles striking the forward off-hand shield quadrant; rear hits and right flank hits penetrate).
---@param player ObjectRef Defending player
---@param proj_obj ObjectRef Incoming projectile entity
---@param hit_pos vector? Impact position
---@param flight_dir vector? Incoming normalized flight direction
---@param _proj_data? XPlayerArmorProjectileData Optional projectile combat metadata
---@return boolean deflected, vector? bounce_velocity
function combat.try_deflect_projectile(player, proj_obj, hit_pos, flight_dir, _proj_data)
	if not constants.BLOCK_DEFLECT_PROJECTILES then
		return false
	end
	local is_blocking, shield_stack, slot_idx, mat_key = x_player_armor.is_blocking(player)
	if not is_blocking then
		return false
	end

	-- Spatial hit position check: if impact point is known, verify projectile physically
	-- struck the front-left shield zone (cannot deflect rear hits or exposed right-side hits)
	if hit_pos and type(hit_pos) == "table" and hit_pos.x and hit_pos.z then
		local ppos = player:get_pos()
		local look_dir = player:get_look_dir()
		if ppos and look_dir then
			local h_len = math.sqrt(look_dir.x * look_dir.x + look_dir.z * look_dir.z)
			if h_len > 0.0001 then
				local lx = look_dir.x / h_len
				local lz = look_dir.z / h_len
				local dx = hit_pos.x - ppos.x
				local dz = hit_pos.z - ppos.z
				local fwd_dist = dx * lx + dz * lz
				local right_dist = dx * lz - dz * lx
				-- Projectile physically struck player's back (rear of bounding box)
				if fwd_dist < -0.05 then
					return false
				end
				-- Projectile physically struck player's exposed right side (weapon arm / right torso)
				if right_dist > 0.12 then
					return false
				end
			end
		end
	end

	-- Incoming flight direction verification
	if not flight_dir or (flight_dir.x == 0 and flight_dir.y == 0 and flight_dir.z == 0) then
		if proj_obj and proj_obj:is_valid() then
			local vel = proj_obj.get_velocity and proj_obj:get_velocity()
			if vel and (vel.x ~= 0 or vel.y ~= 0 or vel.z ~= 0) then
				flight_dir = vector.normalize(vel)
			end
		end
		if not flight_dir and hit_pos and player then
			local ppos = player:get_pos()
			if ppos and not vector.equals(hit_pos, ppos) then
				flight_dir = vector.direction(hit_pos, ppos)
			end
		end
	end

	-- If flight direction cannot be established, do not assume frontal deflection
	if not flight_dir or (flight_dir.x == 0 and flight_dir.y == 0 and flight_dir.z == 0) then
		return false
	end

	-- Tier 2 Asymmetric Guard Cone Bias check
	local shield_props = constants.SHIELD_TIER_PROPERTIES[mat_key] or {}
	local arc = shield_props.arc or constants.BLOCK_CONE_ANGLE or 52
	local bias = shield_props.bias or constants.BLOCK_ASYMMETRIC_BIAS or 22
	if not combat.is_facing_attack(player, flight_dir, arc, bias) then
		return false
	end

	-- Shield surface normal with subtle natural ergonomic cant/curvature
	local look_dir = player:get_look_dir() or {x = 0, y = 0, z = 1}
	local jitter_x = (math.random() - 0.5) * 0.12
	local jitter_y = (math.random() - 0.5) * 0.08
	local jitter_z = (math.random() - 0.5) * 0.12
	local normal = vector.normalize({
		x = look_dir.x + jitter_x,
		y = look_dir.y + jitter_y,
		z = look_dir.z + jitter_z,
	})

	local in_vel = (proj_obj and proj_obj:is_valid() and proj_obj:get_velocity())
		or vector.multiply(flight_dir, 20.0)
	local in_speed = vector.length(in_vel)
	if in_speed < 0.1 then in_speed = 15.0 end

	-- Natural vector reflection: v_out = f * v_in - (f + e) * (v_in . n) * n
	local restitution = shield_props.restitution or constants.BLOCK_RESTITUTION or 0.50
	local friction = 0.85
	local dot_vn = vector.dot(in_vel, normal)

	local bounce_vel = {
		x = friction * in_vel.x - (friction + restitution) * dot_vn * normal.x,
		y = math.max(1.5, friction * in_vel.y - (friction + restitution) * dot_vn * normal.y + 1.2),
		z = friction * in_vel.z - (friction + restitution) * dot_vn * normal.z,
	}

	-- Tier 1: Visual & Physical Deflection Origin Point (lower-left viewport shield contact surface)
	local shield_pos = combat.get_shield_contact_pos(player)

	-- Update in-world projectile object trajectory, origin position, and model orientation
	if proj_obj and proj_obj:is_valid() then
		if proj_obj.set_pos then
			proj_obj:set_pos(shield_pos)
		end
		proj_obj:set_velocity(bounce_vel)
		proj_obj:set_acceleration({x = 0, y = -9.81, z = 0})
		local horiz_len = math.sqrt(bounce_vel.x * bounce_vel.x + bounce_vel.z * bounce_vel.z)
		local atan2 = math.atan2 or math.atan
		local pitch = atan2(bounce_vel.y, horiz_len)
		local yaw = core.dir_to_yaw(bounce_vel)
		proj_obj:set_rotation({x = pitch, y = yaw, z = 0})
	end

	-- Apply physical recoil impulse to player in direction of the projectile flight
	local recoil_base = constants.BLOCK_RECOIL_IMPULSE or 5.5
	local recoil_mult = shield_props.recoil_mult or 1.0
	local speed_factor = math.min(1.4, math.max(0.7, in_speed / 16.0))
	local recoil_speed = recoil_base * recoil_mult * speed_factor
	local vert_lift = recoil_mult > 0 and math.min(2.5, math.max(1.6, 1.8 * math.sqrt(recoil_mult))) or 0
	local h_len = math.sqrt(flight_dir.x * flight_dir.x + flight_dir.z * flight_dir.z)
	local h_x, h_z
	if h_len > 0.001 then
		h_x, h_z = flight_dir.x / h_len, flight_dir.z / h_len
	else
		local look = player:get_look_dir() or {x = 0, y = 0, z = 1}
		h_x, h_z = -look.x, -look.z
	end
	player:add_velocity({
		x = h_x * recoil_speed,
		y = vert_lift,
		z = h_z * recoil_speed,
	})

	-- Audio parry feedback and metallic sparks at exact shield contact position
	local shield_def = shield_stack and shield_stack:get_definition()
	local block_snd = (shield_def and (shield_def.sound_block or (shield_def.sounds and shield_def.sounds.block))) or constants.SOUNDS.shield_block
	play_sound(shield_pos, block_snd, 0.9)
	combat.spawn_shield_block_particles(shield_pos, player)
	if shield_def and shield_def.on_block then
		shield_def.on_block(player, proj_obj, 0, shield_stack)
	end
	x_player_armor.run_callbacks("on_block", player, proj_obj, 0, shield_stack)

	-- Shield durability wear
	if shield_stack and slot_idx and slot_idx > 0 then
		local sdef = shield_stack:get_definition()
		local uses = (sdef and sdef.groups and sdef.groups.armor_uses) or 200
		combat.damage_item(player, slot_idx, shield_stack, uses)
	end

	return true, bounce_vel
end

---Handles on_punchplayer event and wear calculations.
---@param player ObjectRef
---@param hitter ObjectRef?
---@param time_from_last_punch number?
---@param tool_capabilities table? Tool capabilities table of the punch (see Luanti doc/lua_api.md: Tool Capabilities)
---@param dir vector?
---@param damage number?
function combat.handle_punch(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	if not player or not player:is_player() then return end
	if player:get_hp() <= 0 then return end
	if core.settings:get_bool("enable_damage") == false then return end

	local pos = player:get_pos()
	if hitter and hitter:is_player() then
		if hitter == player then return end
		if core.settings:get_bool("enable_pvp") == false then return end
		if pos and core.is_protected(pos, "") then return end
	end

	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then return end

	-- Trigger combat HUD on defending player receiving punch (incoming only)
	x_player_armor.combat_hud.trigger(player)

	local armor_list = inv:get_list("armor")
	if not armor_list then return end

	local has_shield = false
	local armor_count = 0
	local material_counts = {}
	local dominant_material = "steel"
	local max_mat_count = 0
	local has_reciprocate_armor = false

	local custom_hit_sound = nil
	for idx = 1, 6 do
		local stack = armor_list[idx]
		if stack and not stack:is_empty() then
			local def = stack:get_definition()
			if def and def.groups then
				armor_count = armor_count + 1
				if (def.groups.armor_shield or 0) > 0 then
					has_shield = true
				end
				if def.reciprocate_damage == true or def.thorns == true or (type(def.thorns) == "number" and def.thorns > 0) then
					has_reciprocate_armor = true
				end
				if not custom_hit_sound then
					custom_hit_sound = def.sound_hit or (def.sounds and def.sounds.hit)
				end
				local mat = utils.get_item_material(stack:get_name())
				if mat then
					material_counts[mat] = (material_counts[mat] or 0) + 1
					if material_counts[mat] > max_mat_count then
						max_mat_count = material_counts[mat]
						dominant_material = mat
					end
				end

				-- Dispatch item-level def.on_punch / on_punched callback if defined
				if def.on_punch then
					def.on_punch(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
				elseif def.on_punched then
					def.on_punched(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
				end
			end
		end
	end

	-- Skip if the player is not wearing any armor pieces
	if armor_count == 0 then return end

	-- Check whether the attack is being blocked by a shield
	local is_blocking, shield_stack, shield_slot, shield_mat = x_player_armor.is_blocking(player)
	local shield_def = shield_stack and shield_stack:get_definition()
	local is_blocked = false
	if is_blocking and dir then
		local shield_props = constants.SHIELD_TIER_PROPERTIES[shield_mat] or {}
		local arc = shield_props.arc or constants.BLOCK_CONE_ANGLE or 52
		local bias = shield_props.bias or constants.BLOCK_ASYMMETRIC_BIAS or 22
		if combat.is_facing_attack(player, dir, arc, bias) then
			is_blocked = true
			combat.was_blocked[name] = true
		end
	end

	-- Apply wear damage to equipped armor items
	if is_blocked and shield_slot and shield_slot > 0 then
		-- Shield absorbed the frontal impact; only wear the shield
		local stack = inv:get_stack("armor", shield_slot)
		if not stack:is_empty() then
			local def = stack:get_definition()
			local uses = (def and def.groups and def.groups.armor_uses) or 200
			combat.damage_item(player, shield_slot, stack, uses)
		end
	else
		-- Standard armor wear across all equipped pieces
		for idx = 1, 6 do
			local stack = inv:get_stack("armor", idx)
			if not stack:is_empty() then
				local def = stack:get_definition()
				if def and def.groups then
					-- Slot 6 is auxiliary; only damage items designated as armor or possessing armor_uses
					if idx <= 5 or def.groups.armor_uses or def.groups.armor_element or def.armor_groups or (def.groups.armor_use or 0) > 0 then
						local uses = def.groups.armor_uses or 200
						combat.damage_item(player, idx, stack, uses)
					end
				end
			end
		end
	end

	-- Play audio and display particle feedback for absorbed/deflected damage
	if pos then
		if is_blocked then
			local shield_pos = combat.get_shield_contact_pos(player)
			local block_snd = (shield_def and (shield_def.sound_block or (shield_def.sounds and shield_def.sounds.block))) or constants.SOUNDS.shield_block
			play_sound(shield_pos, block_snd, 0.9)
			combat.spawn_shield_block_particles(shield_pos, player)
			if shield_def and shield_def.on_block then
				shield_def.on_block(player, hitter, damage or 0, shield_stack)
			end
			x_player_armor.run_callbacks("on_block", player, hitter, damage or 0, shield_stack)
		else
			play_impact_sound(pos, has_shield, dominant_material, custom_hit_sound)
			if has_shield then
				local shield_pos = combat.get_shield_contact_pos(player)
				combat.spawn_shield_block_particles(shield_pos, player)
			else
				combat.spawn_impact_particles(pos, dominant_material)
			end
		end
	end

	-- Trigger hurt reaction only if attack was NOT cleanly blocked
	if not is_blocked then
		x_player_armor.compat_x_player_api.trigger_hurt(player)
	end

	-- Reciprocate wear to attacker weapon if applicable (item-defined or legacy config)
	local should_reciprocate = has_reciprocate_armor or x_player_armor.is_reciprocate_damage_enabled()

	if should_reciprocate and hitter and hitter:is_player() then
		local wielded = hitter:get_wielded_item()
		if wielded and not wielded:is_empty() then
			local wdef = wielded:get_definition()
			if wdef and wdef.tool_capabilities then
				wielded:add_wear(100)
				hitter:set_wielded_item(wielded)
			end
		end
	end
end

core.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	if player and player:is_player() and dir then
		combat.last_punch_dirs[player:get_player_name()] = vector.new(dir)
	end
	combat.handle_punch(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
end)

core.register_on_player_hpchange(function(player, hp_change, reason)
	if not player or not player:is_player() or hp_change >= 0 then
		return hp_change
	end

	-- Trigger combat HUD on incoming negative HP change (damage from any source)
	x_player_armor.combat_hud.trigger(player)

	-- Active shield blocking damage mitigation (e.g. 10% - 25% reduction based on shield tier)
	if reason.type == "punch" and hp_change < 0 then
		local is_blocking, _, _, mat_key = x_player_armor.is_blocking(player)
		if is_blocking then
			local attack_dir = combat.get_attack_direction(player, reason)
			if attack_dir then
				local shield_props = constants.SHIELD_TIER_PROPERTIES[mat_key] or {}
				local arc = shield_props.arc or constants.BLOCK_CONE_ANGLE or 52
				local bias = shield_props.bias or constants.BLOCK_ASYMMETRIC_BIAS or 22
				if combat.is_facing_attack(player, attack_dir, arc, bias) then
					local reduction = shield_props.reduction or constants.BLOCK_DEFAULT_REDUCTION or 0.20
					local blocked_amount = math.floor(-hp_change * reduction)
					if blocked_amount > 0 then
						hp_change = hp_change + blocked_amount

						-- Apply recoil push-back impulse to defending player
						local recoil_base = constants.BLOCK_RECOIL_IMPULSE or 5.5
						local recoil_mult = shield_props.recoil_mult or 1.0
						local recoil_speed = recoil_base * recoil_mult
						local vert_lift = recoil_mult > 0 and math.min(2.5, math.max(1.6, 1.8 * math.sqrt(recoil_mult))) or 0
						local h_len = math.sqrt(attack_dir.x * attack_dir.x + attack_dir.z * attack_dir.z)
						local h_x, h_z
						if h_len > 0.001 then
							h_x, h_z = attack_dir.x / h_len, attack_dir.z / h_len
						else
							local look = player:get_look_dir() or {x = 0, y = 0, z = 1}
							h_x, h_z = -look.x, -look.z
						end
						player:add_velocity({
							x = h_x * recoil_speed,
							y = vert_lift,
							z = h_z * recoil_speed,
						})

						-- Play shield block audio and sparks if not already played in handle_punch
						local name = player:get_player_name()
						if not combat.was_blocked[name] then
							local shield_pos = combat.get_shield_contact_pos(player)
							play_sound(shield_pos, constants.SOUNDS.shield_block, 0.9)
							combat.spawn_shield_block_particles(shield_pos, player)
						end
						combat.was_blocked[name] = nil
					end
				end
			end
		end
	end

	local pdef = x_player_armor.get_player_def(player)

	-- Fall damage mitigation (feather falling)
	if reason.type == "fall" and constants.FEATHER_FALL and (pdef.feather or 0) > 0 then
		local reduction = pdef.feather * 4
		local new_change = hp_change + reduction
		if new_change >= 0 then
			return 0
		end
		return new_change
	end

	-- Tiered environmental fire & lava damage mitigation
	if reason.type == "node_damage" and constants.FIRE_PROTECT and (pdef.fire or 0) > 0 then
		local node_name = reason.node
		local fire_nodes = x_player_armor.get_fire_nodes()
		local fire_prot = node_name and fire_nodes and fire_nodes[node_name]

		if not fire_prot and node_name and type(fire_nodes) == "table" then
			for k, v in pairs(fire_nodes) do
				if (type(k) == "number" and v == node_name) or (k == node_name) then
					fire_prot = type(v) == "number" and v or 3
					break
				end
			end
		end

		-- Dynamic group fallback for custom mod lavas, igniters, and flames
		if not fire_prot and node_name then
			if core.get_item_group(node_name, "lava") > 0 then
				fire_prot = 5
			elseif core.get_item_group(node_name, "igniter") > 0 or core.get_item_group(node_name, "fire") > 0 then
				fire_prot = 3
			end
		end

		if fire_prot then
			local player_fire = pdef.fire or 0
			if player_fire >= fire_prot then
				return 0
			elseif player_fire > 0 then
				-- Proportional damage mitigation for partial protection against higher-tier heat
				local reduction = player_fire / fire_prot
				return math.min(-1, math.floor(hp_change * (1 - reduction)))
			end
		elseif not node_name then
			-- Backwards-compatibility for engine callbacks where reason.node is nil
			return 0
		end
	end

	-- Drowning mitigation (water breathing)
	if reason.type == "drown" and constants.WATER_PROTECT and (pdef.water or 0) > 0 then
		return 0
	end

	-- Regenerative heal ward chance
	if (pdef.heal or 0) > 0 and math.random(1, 100) <= pdef.heal then
		local pos = player:get_pos()
		if pos then
			combat.spawn_heal_particles(pos, player)
		end
		return 0
	end

	return hp_change
end, true)

-- Optional torch heat damage override matching 3d_armor
if constants.FIRE_PROTECT_TORCH then
	core.register_on_mods_loaded(function()
		for _, torch_name in ipairs({"default:torch", "default:torch_wall", "default:torch_ceiling"}) do
			if core.registered_nodes[torch_name] then
				core.override_item(torch_name, {damage_per_second = 1})
			end
		end
	end)
end

core.register_on_leaveplayer(function(player)
	if not player or not player:is_player() then return end
	local name = player:get_player_name()
	combat.last_punch_dirs[name] = nil
	combat.was_blocked[name] = nil
end)

x_player_armor.combat = combat
return combat
