--[[
	X Player Armor - Combat Armor HUD Overlay (modules/combat_hud.lua)
	Displays an armor blueprint paperdoll with equipped items, active wielded item,
	and 5-stage transitional durability gauges when receiving incoming combat damage.
	Features 100% procedural [fill texture composition with zero static file overhead,
	responsive screen-size scaling, in-place updates, and multiplayer packet suppression.

	Author: SaKeL
	License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0
]]

---@class XPlayerArmorCombatHUD
local combat_hud = {}

---Active combat player state cache keyed by player name
---@type table<string, {hud_id: number, expire_time: number, last_texture: string}>
combat_hud.active_players = {}

---Predefined screen anchor configurations with offset direction multipliers
local POSITIONS = {
	bottom_right = {
		position = {x = 1, y = 1},
		alignment = {x = -1, y = -1},
		offset_mult = {x = -1, y = -1},
	},
	bottom_left = {
		position = {x = 0, y = 1},
		alignment = {x = 1, y = -1},
		offset_mult = {x = 1, y = -1},
	},
	top_right = {
		position = {x = 1, y = 0},
		alignment = {x = -1, y = 1},
		offset_mult = {x = -1, y = 1},
	},
	middle_right = {
		position = {x = 1, y = 0.5},
		alignment = {x = -1, y = 0},
		offset_mult = {x = -1, y = 0},
	},
}

---Slot layout specifications on the 96x128 canvas
local SLOTS = {
	{idx = 1, x = 36, y = 8,  blueprint = "x_player_armor_stand_head.png"},   -- Helmet
	{idx = 5, x = 8,  y = 38, blueprint = "x_player_armor_stand_shield.png"}, -- Shield (Off-Hand)
	{idx = 2, x = 36, y = 38, blueprint = "x_player_armor_stand_torso.png"},  -- Torso (Chestplate)
	{idx = 6, x = 64, y = 38, blueprint = "x_player_armor_icon.png"},         -- Main Hand / Wielded Item
	{idx = 3, x = 36, y = 68, blueprint = "x_player_armor_stand_legs.png"},   -- Leggings
	{idx = 4, x = 36, y = 98, blueprint = "x_player_armor_stand_feet.png"},   -- Boots
}

---5 Transitional durability colors based on wear ratio:
---Tier 5 (80% - 100%): Emerald Green
---Tier 4 (60% - 79%): Lime Green
---Tier 3 (40% - 59%): Amber Yellow
---Tier 2 (20% - 39%): Vivid Orange
---Tier 1 (0% - 19%): Crimson Red
---@param wear number Engine wear integer (0 to 65535)
---@return string hex_color
function combat_hud.get_durability_color(wear)
	local health_ratio = 1.0 - (wear / 65535.0)
	if health_ratio >= 0.80 then
		return "#2ea043" -- Pristine Emerald Green
	elseif health_ratio >= 0.60 then
		return "#7ee787" -- Light Wear Lime Green
	elseif health_ratio >= 0.40 then
		return "#e3b341" -- Moderate Wear Amber Yellow
	elseif health_ratio >= 0.20 then
		return "#f97316" -- Heavy Wear Vivid Orange
	else
		return "#f85149" -- Critical Crimson Red
	end
end

---Escapes special characters in texture strings for safe nesting inside [combine.
---@param text string
---@return string
local function escape_texture(text)
	return (text:gsub("\\", "\\\\"):gsub(":", "\\:"):gsub("%^", "\\^"))
end

---Generates a coordinate-anchored programmatic fill rectangle for [combine.
---Escapes colons so the [combine parser does not split the fill specification.
---@param x number
---@param y number
---@param w number
---@param h number
---@param color string
---@return string
local function combine_fill(x, y, w, h, color)
	local fill_spec = string.format("[fill:%dx%d:%s", w, h, color)
	return string.format("%d,%d=%s", x, y, escape_texture(fill_spec))
end

---Pre-computed static background and slot-well frame parts (eliminates 35 string allocations per combat tick)
local STATIC_FRAME_PARTS = {
	combine_fill(0, 0, 96, 128, "#0d1117dd"),
	combine_fill(0, 0, 96, 1, "#38444dee"),
	combine_fill(0, 127, 96, 1, "#38444dee"),
	combine_fill(0, 0, 1, 128, "#38444dee"),
	combine_fill(95, 0, 1, 128, "#38444dee"),
}
for s = 1, #SLOTS do
	local slot_def = SLOTS[s]
	local sx = slot_def.x
	local sy = slot_def.y
	STATIC_FRAME_PARTS[#STATIC_FRAME_PARTS + 1] = combine_fill(sx, sy, 24, 24, "#161b22ee")
	STATIC_FRAME_PARTS[#STATIC_FRAME_PARTS + 1] = combine_fill(sx, sy, 24, 1, "#30363dff")
	STATIC_FRAME_PARTS[#STATIC_FRAME_PARTS + 1] = combine_fill(sx, sy + 23, 24, 1, "#30363dff")
	STATIC_FRAME_PARTS[#STATIC_FRAME_PARTS + 1] = combine_fill(sx, sy, 1, 24, "#30363dff")
	STATIC_FRAME_PARTS[#STATIC_FRAME_PARTS + 1] = combine_fill(sx + 23, sy, 1, 24, "#30363dff")
end
local STATIC_FRAME_PREFIX = table.concat(STATIC_FRAME_PARTS, ":")

---Memoized cache mapping item technical names to their resolved 2D HUD icon texture string
combat_hud.icon_cache = {}

---Resolves the 2D inventory texture for an armor or tool ItemStack.
---Uses memoized cache to avoid repeated definition table lookups during high-frequency combat ticks.
---@param stack ItemStack
---@return string texture
local function get_item_icon(stack)
	if not stack or stack:is_empty() then
		return "x_player_armor_icon.png"
	end
	local item_name = stack:get_name()
	if not item_name or item_name == "" then
		return "x_player_armor_icon.png"
	end
	local cached = combat_hud.icon_cache[item_name]
	if cached then
		return cached
	end

	local def = stack:get_definition() or core.registered_items[item_name]
	if not def then
		combat_hud.icon_cache[item_name] = "x_player_armor_icon.png"
		return "x_player_armor_icon.png"
	end

	local tex = def.inventory_image
	if not tex or tex == "" then
		tex = def.wield_image or def.preview or def.texture
	end
	if not tex or tex == "" then
		if def.tiles and type(def.tiles) == "table" and #def.tiles > 0 then
			local t1 = def.tiles[1]
			tex = type(t1) == "string" and t1 or (type(t1) == "table" and t1.name)
		elseif type(def.tiles) == "string" then
			tex = def.tiles
		end
	end
	if not tex or tex == "" then
		tex = "x_player_armor_icon.png"
	end
	combat_hud.icon_cache[item_name] = tex
	return tex
end

---Calculates dynamic scale and offset for the combat HUD overlay based on player viewport size.
---Ensures clear legibility and tactical scaling on 1080p, 1440p (2K), 4K, and ultra-wide screens.
---@param player ObjectRef
---@return {x: number, y: number} scale, {x: number, y: number} offset, {x: number, y: number} position, {x: number, y: number} alignment
function combat_hud.get_proportional_geometry(player)
	local win = core.get_player_window_information(player:get_player_name())
	local win_h = (win and win.size and win.size.y and win.size.y > 0) and win.size.y or 1080
	local win_w = (win and win.size and win.size.x and win.size.x > 0) and win.size.x or (win_h * 16 / 9)

	-- Calibrated reference baseline: 1.6 scale on 1080p yields ~205px panel height
	local user_scale = x_player_armor.constants.COMBAT_HUD_SCALE or 1.0
	local res_factor = math.max(0.75, win_h / 1080.0)
	local final_scale = math.floor((1.6 * res_factor * user_scale) * 100 + 0.5) / 100

	-- Dynamic edge margins scaled with resolution
	local ox = math.max(16, math.floor(24 * (win_w / 1920.0) + 0.5))
	local oy = math.max(16, math.floor(24 * res_factor + 0.5))

	local pos_name = x_player_armor.constants.COMBAT_HUD_POSITION or "bottom_right"
	local pos_def = POSITIONS[pos_name] or POSITIONS.bottom_right
	local offset = {x = pos_def.offset_mult.x * ox, y = pos_def.offset_mult.y * oy}

	return {x = final_scale, y = final_scale}, offset, pos_def.position, pos_def.alignment
end

---Constructs the single 96x128 composite texture representation of the combat HUD.
---Generated 100% programmatically via native [fill and [combine modifiers (zero static file overhead).
---@param player ObjectRef
---@return string composite_texture
function combat_hud.build_overlay_texture(player)
	local _, inv = x_player_armor.get_valid_player(player)
	local armor_list = inv and inv:get_list("armor")
	local wield_stack = player:get_wielded_item()

	local parts = { STATIC_FRAME_PREFIX }

	for s = 1, #SLOTS do
		local slot_def = SLOTS[s]
		local idx = slot_def.idx
		local sx = slot_def.x
		local sy = slot_def.y

		-- Resolve item stack: Slot 6 represents actual active wielded item in the main hand
		local is_wield_slot = (idx == 6)
		local stack
		if is_wield_slot and wield_stack and not wield_stack:is_empty() then
			stack = wield_stack
		else
			stack = armor_list and armor_list[idx]
		end

		if stack and not stack:is_empty() then
			-- Equipped / Wielded Item: 16x16 icon centered in 24x24 well at (sx + 4, sy + 1)
			local item_icon
			if is_wield_slot then
				item_icon = x_player_armor.ui.get_wield_texture(player)
				if not item_icon or item_icon == "" or item_icon == "blank.png" then
					item_icon = get_item_icon(stack)
				end
			else
				item_icon = get_item_icon(stack)
			end

			if not item_icon or item_icon == "" or item_icon == "blank.png" then
				item_icon = "x_player_armor_icon.png"
			end

			local icon_tex = item_icon .. "^[resize:16x16"
			parts[#parts + 1] = string.format("%d,%d=%s", sx + 4, sy + 1, escape_texture(icon_tex))

			-- Durability Bar: Rendered if item has wear or possesses durability (tool/armor)
			local wear = stack:get_wear()
			local def = stack:get_definition()
			local has_durability = (wear > 0)
				or (def and def.tool_capabilities ~= nil)
				or (def and def.groups and (def.groups.armor_uses ~= nil or def.groups.uses ~= nil))

			if has_durability then
				-- Dark charcoal background track (#161b22)
				parts[#parts + 1] = combine_fill(sx + 2, sy + 19, 20, 3, "#161b22ff")

				-- Five-tier colored fill bar
				local fill_ratio = math.max(0.0, math.min(1.0, 1.0 - (wear / 65535.0)))
				local fill_w = math.max(1, math.floor(20 * fill_ratio + 0.5))
				local color = combat_hud.get_durability_color(wear)
				parts[#parts + 1] = combine_fill(sx + 2, sy + 19, fill_w, 3, color)
			end
		else
			-- Empty Slot: Ghostly blueprint silhouette scaled to 16x16 centered at (sx + 4, sy + 4)
			local blueprint_tex = slot_def.blueprint .. "^[resize:16x16^[colorize:#58a6ff:40"
			parts[#parts + 1] = string.format("%d,%d=%s", sx + 4, sy + 4, escape_texture(blueprint_tex))
		end
	end

	return string.format("[combine:96x128:%s", table.concat(parts, ":"))
end

---Displays or updates the combat armor HUD overlay on the target player.
---Resets timeout on subsequent calls and updates existing HUD in-place with dirty checking.
---@param player ObjectRef
---@return number? hud_id
function combat_hud.trigger(player)
	if not x_player_armor.constants.COMBAT_HUD_ENABLE then
		return nil
	end
	if not player or not player:is_player() then
		return nil
	end
	if player.is_valid and not player:is_valid() then
		return nil
	end

	local pname = player:get_player_name()
	local now = core.get_gametime()
	local timeout = x_player_armor.constants.COMBAT_HUD_TIMEOUT or 5.0

	-- Ensure player wield tracking is initialized for combat HUD listener
	if not x_player_armor.ui.player_wield[pname] then
		local stack = player:get_wielded_item()
		x_player_armor.ui.player_wield[pname] = {
			index = (player.get_wield_index and player:get_wield_index()) or 1,
			item = (stack and not stack:is_empty() and stack:get_name()) or "",
			wear = (stack and not stack:is_empty() and stack:get_wear()) or 0,
		}
	end

	local new_texture = combat_hud.build_overlay_texture(player)
	local scale, offset, pos, align = combat_hud.get_proportional_geometry(player)

	local existing = combat_hud.active_players[pname]
	if existing and existing.hud_id then
		-- Reset combat hide timer
		existing.expire_time = now + timeout

		-- Reconcile responsive scale and offset in-place if changed
		if not existing.last_scale or existing.last_scale.x ~= scale.x or existing.last_scale.y ~= scale.y then
			player:hud_change(existing.hud_id, "scale", scale)
			existing.last_scale = scale
		end
		if not existing.last_offset or existing.last_offset.x ~= offset.x or existing.last_offset.y ~= offset.y then
			player:hud_change(existing.hud_id, "offset", offset)
			existing.last_offset = offset
		end

		-- Dirty-state network optimization: only transmit hud_change packet if visual state changed
		if new_texture ~= existing.last_texture then
			player:hud_change(existing.hud_id, "text", new_texture)
			existing.last_texture = new_texture
		end
		return existing.hud_id
	end

	-- Create single composite HUD element with responsive geometry
	local hud_id = player:hud_add({
		type = "image",
		position = pos,
		alignment = align,
		offset = offset,
		scale = scale,
		text = new_texture,
		z_index = 5,
	})

	if hud_id then
		combat_hud.active_players[pname] = {
			hud_id = hud_id,
			expire_time = now + timeout,
			last_texture = new_texture,
			last_scale = scale,
			last_offset = offset,
		}
	end

	return hud_id
end

---Hides and removes the combat armor HUD element from the target player.
---@param player_or_name ObjectRef|string
function combat_hud.hide(player_or_name)
	local pname = type(player_or_name) == "string" and player_or_name
		or (player_or_name and player_or_name.get_player_name and player_or_name:get_player_name())
	if not pname then
		return
	end

	local state = combat_hud.active_players[pname]
	if not state then
		return
	end

	local player = type(player_or_name) == "userdata" and player_or_name or core.get_player_by_name(pname)
	if player and player:is_player() and (not player.is_valid or player:is_valid()) and state.hud_id then
		player:hud_remove(state.hud_id)
	end

	combat_hud.active_players[pname] = nil
end

---Cleans up player HUD tracking on disconnect or death without stale pointer assumptions.
---@param player_name string
function combat_hud.cleanup(player_name)
	combat_hud.active_players[player_name] = nil
end

---Gracefully cleans up all active combat HUD elements on server shutdown.
function combat_hud.shutdown()
	for pname, state in pairs(combat_hud.active_players) do
		local player = core.get_player_by_name(pname)
		if player and player:is_player() and (not player.is_valid or player:is_valid()) and state.hud_id then
			player:hud_remove(state.hud_id)
		end
	end
	combat_hud.active_players = {}
end

---Initializes engine lifecycle hooks and throttled timer.
function combat_hud.init()
	core.register_on_leaveplayer(function(player)
		combat_hud.cleanup(player:get_player_name())
	end)

	core.register_on_dieplayer(function(player)
		combat_hud.hide(player)
	end)

	core.register_on_respawnplayer(function(player)
		combat_hud.hide(player)
	end)

	core.register_on_joinplayer(function(player)
		combat_hud.cleanup(player:get_player_name())
	end)

	core.register_on_shutdown(function()
		combat_hud.shutdown()
	end)

	-- Update in-place if armor equipment state changes while player is actively in combat
	x_player_armor.register_on_update(function(player)
		if not player or not player:is_player() then
			return
		end
		local pname = player:get_player_name()
		if combat_hud.active_players[pname] then
			combat_hud.trigger(player)
		end
	end)

	core.register_on_mods_loaded(function()
		-- Throttled globalstep timer (4 ticks per second with zero-overhead idle skipping)
		local step_accum = 0
		core.register_globalstep(function(dtime)
			if next(combat_hud.active_players) == nil then
				return
			end

			step_accum = step_accum + dtime
			if step_accum < 0.25 then
				return
			end
			step_accum = 0

			local now = core.get_gametime()
			for pname, state in pairs(combat_hud.active_players) do
				if now >= state.expire_time then
					combat_hud.hide(pname)
				end
			end
		end)
	end)
end

combat_hud.init()
x_player_armor.combat_hud = combat_hud
return combat_hud
