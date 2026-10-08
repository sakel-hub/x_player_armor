--[[
	X Player Armor - 1st-Person Shield Blocking HUD Indicator (modules/shield_hud.lua)
	Displays active equipped shield's inventory image in bottom-left corner of the screen
	cropped to the top 33% (defensive rim & boss) when guarding.

	Author: SaKeL
	License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0
]]

---@class XPlayerArmorShieldHUD
local shield_hud = {}

---Per-player active HUD element IDs
---@type table<string, number>
shield_hud.active_huds = {}

---Per-player pending display timer jobs
---@type table<string, any>
shield_hud.pending_timers = {}

---Per-player request sequence counter to invalidate stale async timer callbacks
---@type table<string, number>
shield_hud.request_seq = {}

---Memoized cropped texture strings keyed by item name
---@type table<string, string>
shield_hud.texture_cache = {}

---Extrusion depth in texels on reference canvas (scaled to wielditem plate thickness, ~20% of previous)
local EXTRUDE_DEPTH = 12
---Base canvas dimension for high-resolution sub-texel layer stacking
local BASE_CANVAS_DIM = 512
---Total reference canvas size (512px base + 12px extrusion)
local REFERENCE_SIZE = BASE_CANVAS_DIM + EXTRUDE_DEPTH

---Builds precomputed 4-connected depth coordinates and progressive ambient occlusion shades.
---Stepping strictly 1 canvas pixel (either dx=1, dy=0 or dx=0, dy=1) per layer eliminates
---all diagonal jumps and produces a seamless, continuous solid extruded edge.
---@return table<{x: number, y: number, shade: string}> depth_layers, number front_x, number front_y
local function generate_extrusion_layers()
	local layers = {}
	local cx, cy = EXTRUDE_DEPTH, 0
	local coords = {{x = cx, y = cy}}
	while cx > 0 or cy < EXTRUDE_DEPTH do
		if cx > 0 and (cy == EXTRUDE_DEPTH or (cx - 0) >= (EXTRUDE_DEPTH - cy)) then
			cx = cx - 1
		else
			cy = cy + 1
		end
		coords[#coords + 1] = {x = cx, y = cy}
	end

	local num_depth = #coords - 1
	local min_b = 0.45 -- 45% brightness: ambient shadow / inner backing
	local max_b = 0.85 -- 85% brightness: beveled rim transition
	for i = 1, num_depth do
		local t = (i - 1) / (num_depth - 1)
		local b = min_b + (max_b - min_b) * t
		local val = math.floor(b * 255 + 0.5)
		local shade = string.format("#%02x%02x%02x", val, val, val)
		layers[i] = {
			x = coords[i].x,
			y = coords[i].y,
			shade = shade,
		}
	end
	local front = coords[#coords]
	return layers, front.x, front.y
end

local DEPTH_LAYERS, FRONT_X, FRONT_Y = generate_extrusion_layers()

---Escapes special characters in texture strings for safe nesting inside [combine.
---@param text string
---@return string
local function escape_texture(text)
	local escaped = text:gsub("\\", "\\\\"):gsub("%^", "\\^"):gsub(":", "\\:")
	return escaped
end

---Constructs a 2.5D extruded composite texture using Luanti [combine modifier.
---Overlays 24 4-connected depth layers offset by single-texel increments behind
---the front face, simulating realistic wielditem plate thickness (~20% of previous)
---with progressive ambient occlusion shading and zero staggered edges.
---@param base_img string Base inventory image filename or modifier string
---@return string composite_texture
local function build_extruded_texture(base_img)
	local base_scaled
	if base_img:find("%^") then
		base_scaled = "(" .. base_img .. ")^[resize:" .. BASE_CANVAS_DIM .. "x" .. BASE_CANVAS_DIM
	else
		base_scaled = base_img .. "^[resize:" .. BASE_CANVAS_DIM .. "x" .. BASE_CANVAS_DIM
	end

	local parts = {}

	-- Render 24 depth layers from back (ambient shadow) to front (rim bevel)
	for i = 1, #DEPTH_LAYERS do
		local layer = DEPTH_LAYERS[i]
		local layer_tex = "(" .. base_scaled .. "^[multiply:" .. layer.shade .. ")"
		parts[#parts + 1] = string.format("%d,%d=%s", layer.x, layer.y, escape_texture(layer_tex))
	end

	-- Render unshaded front face at (FRONT_X, FRONT_Y) wrapped in parentheses
	local front_tex = "(" .. base_scaled .. ")"
	parts[#parts + 1] = string.format("%d,%d=%s", FRONT_X, FRONT_Y, escape_texture(front_tex))

	return string.format("[combine:%dx%d:%s", REFERENCE_SIZE, REFERENCE_SIZE, table.concat(parts, ":"))
end
shield_hud.build_extruded_texture = build_extruded_texture

---Calculates dynamic scale and offset for a real-sized shield held in 1st person.
---Targets ~45% of viewport width, clamped to 45% of screen height and width,
---with natural spacing from the left screen frame and 2.5D extruded rim thickness.
---The bottom portion exceeding 45% screen height is submerged below the bottom screen edge,
---grounding it flush with the lower screen border with zero detachment gap.
---@param player ObjectRef
---@return {x: number, y: number} scale, {x: number, y: number} offset
local function get_proportional_geometry(player)
	local win = core.get_player_window_information(player:get_player_name())
	if win and win.size and win.size.y and win.size.y > 0 then
		local win_h = win.size.y
		local win_w = (win.size.x and win.size.x > 0) and win.size.x or (win_h * 16 / 9)

		-- Natural spacing from the left screen frame (doubled: 48px on 1080p, 32px on 720p)
		local offset_x = math.max(24, math.floor(48 * (win_w / 1920) + 0.5))

		-- Target and clamp width to 45% of viewport width
		local max_w = win_w * 0.45
		local crosshair_limit = (win_w * 0.50) - 32 - offset_x
		if crosshair_limit > 96 and max_w > crosshair_limit then
			max_w = crosshair_limit
		end

		local total_w = max_w
		local s = math.max(0.5, math.floor((total_w / REFERENCE_SIZE) * 1000 + 0.5) / 1000)
		local total_h = s * REFERENCE_SIZE

		-- Clamp visible height to at most 45% of screen height
		local max_visible_h = win_h * 0.45
		local visible_h = math.min(total_h, max_visible_h)
		local submerged_y = math.max(0, math.floor(total_h - visible_h + 0.5))

		return {x = s, y = s}, {x = offset_x, y = submerged_y}
	end

	-- Baseline fallback for standard 1080p (45% width = 864px, scale = 1.649, submerged = 378px, left offset = 48px):
	local fallback_s = math.floor((864 / REFERENCE_SIZE) * 1000 + 0.5) / 1000
	local fallback_submerged = math.max(0, math.floor(fallback_s * REFERENCE_SIZE - (1080 * 0.45) + 0.5))
	return {x = fallback_s, y = fallback_s}, {x = 48, y = fallback_submerged}
end
shield_hud.get_proportional_geometry = get_proportional_geometry

---Resolves the equipped or wielded shield item and returns the memoized extruded texture string.
---Uses build_extruded_texture with ambient occlusion depth layers and reference canvas dimensions.
---@nodiscard
---@param player ObjectRef Target player
---@return string? texture_string Extruded composite texture string or nil
function shield_hud.get_shield_texture(player)
	if not player or not player:is_player() then
		return nil
	end

	local shield_stack = nil

	-- Detached armor inventory (primary slot 5, then auxiliary slot 6, then scan all slots)
	local _, inv = x_player_armor.get_valid_player(player)
	if not inv then
		local pname = player:get_player_name()
		inv = core.get_inventory({type = "detached", name = pname .. "_armor"})
	end

	if inv then
		local s5 = inv:get_stack("armor", 5)
		if s5 and not s5:is_empty() then
			shield_stack = s5
		else
			local s6 = inv:get_stack("armor", 6)
			if s6 and not s6:is_empty() then
				shield_stack = s6
			else
				local list = inv:get_list("armor")
				if list then
					for i = 1, #list do
						local st = list[i]
						if st and not st:is_empty() then
							local iname = st:get_name()
							if core.get_item_group(iname, "armor_shield") > 0
									or core.get_item_group(iname, "shield") > 0 then
								shield_stack = st
								break
							end
						end
					end
				end
			end
		end
	end

	-- Fallback: check main inventory for unit tests or legacy inventory mods
	if not shield_stack or shield_stack:is_empty() then
		local pinv = player:get_inventory()
		if pinv and pinv:get_list("armor") then
			local s5 = pinv:get_stack("armor", 5)
			if s5 and not s5:is_empty() then
				shield_stack = s5
			else
				local s6 = pinv:get_stack("armor", 6)
				if s6 and not s6:is_empty() then
					shield_stack = s6
				end
			end
		end
	end

	-- Fallback: check left-hand wield item via x_player_api
	if not shield_stack or shield_stack:is_empty() then
		local x_api = x_player_armor.get_mod_api("x_player_api")
		if x_api then
			local left_item = x_api.get_left_wield_item(player)
			if left_item and left_item ~= "" then
				shield_stack = ItemStack(left_item)
			end
		end
	end

	if not shield_stack or shield_stack:is_empty() then
		return nil
	end

	local item_name = shield_stack:get_name()
	if shield_hud.texture_cache[item_name] then
		return shield_hud.texture_cache[item_name]
	end

	local def = core.registered_tools[item_name] or core.registered_items[item_name] or shield_stack:get_definition()
	if not def then
		return nil
	end

	local is_shield = (def.groups and ((def.groups.shield or 0) > 0 or (def.groups.armor_shield or 0) > 0))
		or (core.get_item_group(item_name, "armor_shield") > 0)
		or (core.get_item_group(item_name, "shield") > 0)
	if not is_shield then
		return nil
	end

	local base_img = def.hud_image or def.first_person_image or def.inventory_image
	if not base_img or base_img == "" then
		base_img = def.preview or def.texture
	end
	if not base_img or base_img == "" then
		base_img = item_name:gsub(":", "_") .. ".png"
	end

	local full_tex
	if def.hud_image or def.first_person_image then
		if base_img:find("%^") then
			full_tex = "(" .. base_img .. ")^[resize:" .. REFERENCE_SIZE .. "x" .. REFERENCE_SIZE
		else
			full_tex = base_img .. "^[resize:" .. REFERENCE_SIZE .. "x" .. REFERENCE_SIZE
		end
	else
		full_tex = build_extruded_texture(base_img)
	end
	shield_hud.texture_cache[item_name] = full_tex
	return full_tex
end

---Displays or updates the 2D shield block HUD indicator on the target player.
---When the HUD is not yet visible, debounces presentation by SHIELD_HUD_DELAY (default 0.35s)
---to prevent flashing the overlay on right-click taps for block placement or node interaction.
---@param player ObjectRef Target player
---@param immediate? boolean|number If true or 0, renders immediately without debounce delay
---@return number? hud_id Active HUD element ID if shown immediately, or nil if debounced
function shield_hud.show(player, immediate)
	if not player or not player:is_player() then
		return nil
	end

	local enabled = not x_player_armor.constants or (x_player_armor.constants.SHIELD_HUD_ENABLE ~= false)
	if not enabled then
		return nil
	end

	local pname = player:get_player_name()

	-- If HUD is already displayed on screen, update immediately in-place
	local existing_id = shield_hud.active_huds[pname]
	if existing_id then
		local tex = shield_hud.get_shield_texture(player)
		if not tex then
			shield_hud.hide(player)
			return nil
		end

		local scale, offset = get_proportional_geometry(player)
		player:hud_change(existing_id, "text", tex)
		player:hud_change(existing_id, "scale", scale)
		player:hud_change(existing_id, "offset", offset)
		return existing_id
	end

	-- Resolve configured debounce delay
	local delay = (x_player_armor.constants and x_player_armor.constants.SHIELD_HUD_DELAY) or 0.35
	local is_immediate = (immediate == true) or (immediate == 0) or (delay <= 0)

	if not is_immediate then
		-- If a debounce timer is already pending for this player, let it complete
		if shield_hud.pending_timers[pname] then
			return nil
		end

		local seq = (shield_hud.request_seq[pname] or 0) + 1
		shield_hud.request_seq[pname] = seq

		local job = core.after(delay, function()
			shield_hud.pending_timers[pname] = nil
			if shield_hud.request_seq[pname] ~= seq then
				return
			end

			local p = core.get_player_by_name(pname) or player
			if not p or not p:is_player() then
				return
			end
			if p.is_valid and not p:is_valid() then
				return
			end

			shield_hud.show(p, true)
		end)

		shield_hud.pending_timers[pname] = job
		return shield_hud.active_huds[pname]
	end

	-- Immediate render: cancel any lingering timer
	local pending_job = shield_hud.pending_timers[pname]
	if pending_job then
		if (type(pending_job) == "table" or type(pending_job) == "userdata") and pending_job.cancel then
			pending_job:cancel()
		end
		shield_hud.pending_timers[pname] = nil
	end

	local tex = shield_hud.get_shield_texture(player)
	if not tex then
		shield_hud.hide(player)
		return nil
	end

	local scale, offset = get_proportional_geometry(player)
	local hud_id = player:hud_add({
		type = "image",
		hud_elem_type = "image",
		position = {x = 0, y = 1},
		alignment = {x = 1, y = -1},
		offset = offset,
		scale = scale,
		text = tex,
		z_index = -1,
	})

	if hud_id then
		shield_hud.active_huds[pname] = hud_id
	end
	return hud_id
end

---Removes the 2D shield block HUD indicator from the target player and cancels any pending show timer.
---@param player ObjectRef Target player
function shield_hud.hide(player)
	if not player or not player:is_player() then
		return
	end

	local pname = player:get_player_name()

	-- Invalidate and cancel any pending debounced display timer
	shield_hud.request_seq[pname] = (shield_hud.request_seq[pname] or 0) + 1
	local job = shield_hud.pending_timers[pname]
	if job then
		if (type(job) == "table" or type(job) == "userdata") and job.cancel then
			job:cancel()
		end
		shield_hud.pending_timers[pname] = nil
	end

	local hud_id = shield_hud.active_huds[pname]
	if hud_id then
		player:hud_remove(hud_id)
		shield_hud.active_huds[pname] = nil
	end
end

local last_bits = {}
local last_block_states = {}

---Cleans up player HUD tracking and pending timers on disconnect or death.
---@param player_name string Technical name of player
function shield_hud.cleanup(player_name)
	shield_hud.request_seq[player_name] = (shield_hud.request_seq[player_name] or 0) + 1
	local job = shield_hud.pending_timers[player_name]
	if job then
		if (type(job) == "table" or type(job) == "userdata") and job.cancel then
			job:cancel()
		end
		shield_hud.pending_timers[player_name] = nil
	end
	shield_hud.active_huds[player_name] = nil
	last_bits[player_name] = nil
	last_block_states[player_name] = nil
end

---Initializes lifecycle hooks and standalone input fallback.
function shield_hud.init()
	core.register_on_leaveplayer(function(player)
		shield_hud.cleanup(player:get_player_name())
	end)

	core.register_on_dieplayer(function(player)
		shield_hud.hide(player)
	end)

	-- Standalone fallback for environments without x_player_api:
	-- Only register globalstep if x_player_api is NOT present after all mods have loaded.
	core.register_on_mods_loaded(function()
		if x_player_armor.compat_x_player_api.is_present() then
			-- With x_player_api, HUD is 100% event-driven via register_on_state_change (zero globalsteps)
			return
		end

		core.register_globalstep(function()
			local players = core.get_connected_players()
			if #players == 0 then
				return
			end

			for i = 1, #players do
				local player = players[i]
				local pname = player:get_player_name()

				-- Fast bitmask check: avoids allocating get_player_control() table every tick
				local bits = (player.get_player_control_bits and player:get_player_control_bits())
				if bits then
					local prev_bits = last_bits[pname]
					if bits ~= prev_bits then
						last_bits[pname] = bits
						local is_blocking = x_player_armor.is_blocking(player)
						if is_blocking ~= last_block_states[pname] then
							last_block_states[pname] = is_blocking
							if is_blocking then
								shield_hud.show(player)
							else
								shield_hud.hide(player)
							end
						end
					end
				else
					-- Engine fallback when get_player_control_bits is unavailable
					local is_blocking = x_player_armor.is_blocking(player)
					local prev_blocking = last_block_states[pname] or false
					if is_blocking ~= prev_blocking then
						last_block_states[pname] = is_blocking
						if is_blocking then
							shield_hud.show(player)
						else
							shield_hud.hide(player)
						end
					end
				end
			end
		end)
	end)
end

shield_hud.init()
x_player_armor.shield_hud = shield_hud
return shield_hud
