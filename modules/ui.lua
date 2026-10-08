---@class XPlayerArmorUI
local ui = {
	open_players = {},
	sfinv_open_players = {},
	unified_inv_open_players = {},
	player_wield = {},
}

local S = core.get_translator("x_player_armor")

---Retrieves the current player character skin texture.
---@param player ObjectRef
---@return string skin_texture
local function get_player_skin(player)
	local p_api = x_player_armor.get_mod_api("player_api")
	if p_api then
		local textures = p_api.get_textures(player)
		if textures and textures[1] and textures[1] ~= "" then
			return textures[1]
		end
	end
	local props = player:get_properties()
	if props and props.textures and props.textures[1] and props.textures[1] ~= "" then
		return props.textures[1]
	end
	return "x_player_armor_character.png"
end

---Builds the composite overlay texture for all worn armor pieces (64x32 UV layout).
---@param player ObjectRef
---@return string armor_overlay
function ui.get_composite_armor_texture(player)
	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then
		return "blank.png"
	end

	local armor_list = inv:get_list("armor")
	if not armor_list then
		return "blank.png"
	end

	local textures = {}
	for idx = 1, 6 do
		local stack = armor_list[idx]
		if stack and not stack:is_empty() then
			local item_name = stack:get_name()
			local tex = x_player_armor.visuals.get_item_texture(item_name)
			if tex and tex ~= "" and tex ~= "blank.png" then
				table.insert(textures, tex)
			end
		end
	end

	if #textures > 0 then
		return table.concat(textures, "^")
	end
	return "blank.png"
end

---Resolves the texture string for an item stack in the 3D preview / stand wield mesh.
---Supports 2D wield/inventory images, overlays, color tinting, and cubic node tiles.
---@param stack ItemStack?
---@return string wield_texture
function ui.get_item_wield_texture(stack)
	if not stack or stack:is_empty() then
		return "blank.png"
	end
	local item_name = stack:get_name()
	if not item_name or item_name == "" then
		return "blank.png"
	end
	local def = stack:get_definition() or core.registered_items[item_name]
	if not def and core.registered_aliases and core.registered_aliases[item_name] then
		def = core.registered_items[core.registered_aliases[item_name]]
	end
	if not def then
		return "blank.png"
	end

	local tex = ""
	-- 1. Explicit wield image
	if def.wield_image and def.wield_image ~= "" then
		tex = def.wield_image
		if def.wield_overlay and def.wield_overlay ~= "" then
			tex = tex .. "^" .. def.wield_overlay
		end
	-- 2. Standard 2D inventory image
	elseif def.inventory_image and def.inventory_image ~= "" then
		tex = def.inventory_image
		if def.inventory_overlay and def.inventory_overlay ~= "" then
			tex = tex .. "^" .. def.inventory_overlay
		end
	-- 3. Solid cubic node tile fallback
	elseif def.type == "node" and def.tiles then
		local tiles = def.tiles
		if type(tiles) == "string" then
			tex = tiles
		elseif type(tiles) == "table" and #tiles > 0 then
			local t1 = tiles[1]
			if type(t1) == "string" then
				tex = t1
			elseif type(t1) == "table" and t1.name then
				tex = t1.name
			end
		end
	end

	if tex ~= "" and tex ~= "blank.png" then
		local meta = stack.get_meta and stack:get_meta()
		local meta_color = meta and meta.get_string and meta:get_string("color")
		local color = (meta_color and meta_color ~= "" and meta_color) or def.color
		if color and color ~= "" then
			tex = tex .. "^[colorize:" .. color .. ":alpha"
		end
		return tex
	end

	return "blank.png"
end

---Resolves the texture string for the player's active wielded item in the 3D preview.
---@param player ObjectRef
---@return string wield_texture
function ui.get_wield_texture(player)
	if not player or not player:is_player() then
		return "blank.png"
	end
	return ui.get_item_wield_texture(player:get_wielded_item())
end

---Builds the composite preview texture for the 3D formspec model.
---For 8-material meshes (e.g. x_player_armor_preview.glb): returns "skin,head,torso,legs,feet,shield_std,shield_tower,wield"
---@param player ObjectRef
---@param _preview_model? string Optional preview model override (unused, maintained for compatibility)
---@return string composite_texture
function ui.get_preview_texture(player, _preview_model)
	local skin = get_player_skin(player)

	local name, inv = x_player_armor.get_valid_player(player)
	local head_tex = "blank.png"
	local torso_tex = "blank.png"
	local legs_tex = "blank.png"
	local feet_tex = "blank.png"
	local shield_std_tex = "blank.png"
	local shield_tower_tex = "blank.png"
	local wield_tex = ui.get_wield_texture(player)

	if name and inv then
		local armor_list = inv:get_list("armor")
		if armor_list then
			-- Slot 1: Head
			if armor_list[1] and not armor_list[1]:is_empty() then
				local tex = x_player_armor.visuals.get_item_texture(armor_list[1]:get_name())
				if tex and tex ~= "" then
					head_tex = tex
				end
			end
			-- Slot 2: Torso
			if armor_list[2] and not armor_list[2]:is_empty() then
				local tex = x_player_armor.visuals.get_item_texture(armor_list[2]:get_name())
				if tex and tex ~= "" then
					torso_tex = tex
				end
			end
			-- Slot 3: Legs
			if armor_list[3] and not armor_list[3]:is_empty() then
				local tex = x_player_armor.visuals.get_item_texture(armor_list[3]:get_name())
				if tex and tex ~= "" then
					legs_tex = tex
				end
			end
			-- Slot 4: Feet
			if armor_list[4] and not armor_list[4]:is_empty() then
				local tex = x_player_armor.visuals.get_item_texture(armor_list[4]:get_name())
				if tex and tex ~= "" then
					feet_tex = tex
				end
			end
			-- Slot 5: Shield (Standard vs Tower)
			if armor_list[5] and not armor_list[5]:is_empty() then
				local shield_item = armor_list[5]:get_name()
				local tex = x_player_armor.visuals.get_item_texture(shield_item)
				if tex and tex ~= "" then
					local is_tower = core.get_item_group(shield_item, "armor_shield_tower") > 0
						or core.get_item_group(shield_item, "armor_tower_shield") > 0
					if not is_tower then
						local def = core.registered_items[shield_item]
						if def and (def.tower_shield or def.tower) then
							is_tower = true
						end
					end

					if is_tower then
						shield_tower_tex = tex
					else
						shield_std_tex = tex
					end
				end
			end
		end
	end

	return string.format("%s,%s,%s,%s,%s,%s,%s,%s", skin, head_tex, torso_tex, legs_tex, feet_tex, shield_std_tex, shield_tower_tex, wield_tex)
end

ui.registered_preview_models = {
	["character.glb"] = "x_player_armor_preview.glb",
	["character.b3d"] = "x_player_armor_preview.glb",
	["3d_armor_character.glb"] = "x_player_armor_preview.glb",
	["3d_armor_character.b3d"] = "x_player_armor_preview.glb",
	["skinsdb_3d_armor_character_5.b3d"] = "x_player_armor_preview.glb",
}

---Resolves the 3D preview model mesh for the player.
---The 3D preview is a dedicated preview of the armor and uses the production preview model.
---@param _player? ObjectRef Optional player reference (maintained for API compatibility)
---@return string model_name
function ui.get_preview_model(_player)
	return (x_player_armor.constants.MODELS and x_player_armor.constants.MODELS.preview) or "x_player_armor_preview.glb"
end

local SLOTS_LAYOUT = {
	{idx = 0, icon = "x_player_armor_stand_head.png", title = "Helmet Slot", desc = "Equip a helmet or headpiece here for defense."},
	{idx = 1, icon = "x_player_armor_stand_torso.png", title = "Chestplate Slot", desc = "Equip a chestplate or body armor here for core protection."},
	{idx = 4, icon = "x_player_armor_stand_shield.png", title = "Shield Slot", desc = "Equip a shield here for active frontal damage blocking."},
	{idx = 2, icon = "x_player_armor_stand_legs.png", title = "Leggings Slot", desc = "Equip leggings or greaves here for lower-body defense."},
	{idx = 3, icon = "x_player_armor_stand_feet.png", title = "Boots Slot", desc = "Equip boots here for foot protection and mobility."},
	{idx = 5, icon = "x_player_armor_icon.png", title = "Accessory Slot", desc = "Equip extra armor or an accessory here."},
}
ui.SLOTS_LAYOUT = SLOTS_LAYOUT

---Renders the 6 equipped armor slots with their blueprint silhouette icons and empty slot tooltips.
---@param target string Player name or inventory target string (e.g. "detached:name_armor" or "nodemeta:x,y,z")
---@param col_xs number[] Array of 3 X coordinates
---@param row_ys number[] Array of 2 Y coordinates
---@param slot_size number? Slot width/height (defaults to 1.0)
---@param inv_ref InvRef? Optional inventory reference for empty slot tooltip checks
---@param custom_slots table? Optional custom slot definitions
---@return string formspec
function ui.render_slots(target, col_xs, row_ys, slot_size, inv_ref, custom_slots)
	local size = slot_size or 1.0
	local fs = {}
	local list_target = target
	local inv = inv_ref
	if not target:find(":") then
		list_target = "detached:" .. target .. "_armor"
		if not inv then
			inv = core.get_inventory({type = "detached", name = target .. "_armor"})
		end
	end

	local slots = custom_slots or SLOTS_LAYOUT
	for i = 1, #slots do
		local s = slots[i]
		local col = ((i - 1) % 3) + 1
		local row = math.floor((i - 1) / 3) + 1
		local x = col_xs[col] or (col_xs[1] + (col - 1) * 1.2)
		local y = row_ys[row] or (row_ys[1] + (row - 1) * 1.3)
		table.insert(fs, string.format("image[%f,%f;%f,%f;%s^[opacity:75]", x, y, size, size, s.icon))
		table.insert(fs, string.format("list[%s;armor;%f,%f;1,1;%d]", list_target, x, y, s.idx))
		local stack = inv and inv:get_stack("armor", s.lua_idx or (s.idx + 1))
		if not stack or stack:is_empty() then
			local tip = core.colorize("#58a6ff", S(s.title)) .. "\n" .. core.colorize("#c9d1d9", S(s.desc))
			table.insert(fs, string.format("tooltip[%f,%f;%f,%f;%s;#10141cf0;#c9d1d9]", x, y, size, size, core.formspec_escape(tip)))
		end
	end
	return table.concat(fs, "")
end

---Renders the 8x3 player inventory grid.
---@param x number
---@param y number
---@return string formspec
function ui.render_player_inventory(x, y)
	local sx = (x == math.floor(x)) and string.format("%.1f", x) or string.format("%g", x)
	local sy = (y == math.floor(y)) and string.format("%.1f", y) or string.format("%g", y)
	return string.format("list[current_player;main;%s,%s;8,3;8]", sx, sy)
end

---Renders the 8x1 player hotbar with consistent slot backgrounds.
---@param x number
---@param y number
---@param spacing number? Horizontal slot spacing (default 0.15)
---@return string formspec
function ui.render_player_hotbar(x, y, spacing)
	local sp = spacing or 0.15
	local step = 1.0 + sp
	local fs = {}
	for col = 0, 7 do
		local bx = x + col * step
		table.insert(fs, string.format("image[%.2f,%.2f;1.0,1.0;gui_hb_bg.png]", bx, y))
	end
	local sx = (x == math.floor(x)) and string.format("%.1f", x) or string.format("%g", x)
	local sy = (y == math.floor(y)) and string.format("%.1f", y) or string.format("%g", y)
	table.insert(fs, string.format("list[current_player;main;%s,%s;8,1;0]", sx, sy))
	return table.concat(fs, "")
end

---Builds the scrollable hypertext markup aggregating armor attributes and active perks.
---@param pdef table Player armor definition
---@param player ObjectRef? Optional player reference for contextual resolution
---@return string hypertext_markup
function ui.build_stats_hypertext(pdef, player)
	local level = pdef.level or 0
	local heal = pdef.heal or 0
	local has_set_bonus = pdef.set_bonus or false
	local speed = pdef.speed or 1.0
	local jump = pdef.jump or 1.0
	local gravity = pdef.gravity or 1.0
	local has_shield = pdef.has_shield
	local has_reciprocate = pdef.has_reciprocate

	-- Fallback resolution if pdef does not yet have shield properties cached
	if has_shield == nil and player and player:is_player() then
		local shield_stack = x_player_armor.combat.get_equipped_shield(player)
		has_shield = (shield_stack ~= nil)
	end
	has_shield = has_shield or false
	has_reciprocate = has_reciprocate or false

	local speed_diff = math.floor((speed - 1.0) * 100 + 0.5)
	local jump_diff = math.floor((jump - 1.0) * 100 + 0.5)
	local grav_diff = math.floor((gravity - 1.0) * 100 + 0.5)

	local lines = {
		"<global margin=4 size=14 color=#ffffff background=none valign=top>",
		"<style color=#58a6ff><b>" .. core.formspec_escape(S("ARMOR ATTRIBUTES")) .. "</b></style>",
		string.format(
			"<style color=#ffffff><b>%s: </b></style><style color=#58a6ff><b>%d%%</b></style>",
			core.formspec_escape(S("Damage Reduction")),
			level
		),
		string.format(
			"<style color=#c9d1d9 size=12>%s</style>",
			has_set_bonus
				and core.formspec_escape(S("Absorbs @1% incoming hit damage (+10% set bonus)", level))
				or core.formspec_escape(S("Absorbs @1% incoming hit damage", level))
		),
		string.format(
			"<style color=#ffffff><b>%s: </b></style><style color=%s><b>%d%%</b></style>",
			core.formspec_escape(S("Armor Healing")),
			heal > 0 and "#7ee787" or "#c9d1d9",
			heal
		),
		string.format(
			"<style color=#c9d1d9 size=12>%s</style>",
			heal > 0
				and core.formspec_escape(S("@1% chance on hit to nullify damage & heal", heal))
				or core.formspec_escape(S("0% - No regenerative healing ward"))
		),
	}

	if speed_diff ~= 0 or jump_diff ~= 0 or grav_diff ~= 0 then
		local mod_parts = {}
		if speed_diff ~= 0 then
			table.insert(mod_parts, string.format("Speed %+d%%", speed_diff))
		end
		if jump_diff ~= 0 then
			table.insert(mod_parts, string.format("Jump %+d%%", jump_diff))
		end
		if grav_diff ~= 0 then
			table.insert(mod_parts, string.format("Gravity %+d%%", grav_diff))
		end
		local mod_str = table.concat(mod_parts, ", ")
		local mod_color = (speed_diff >= 0 and jump_diff >= 0 and grav_diff <= 0) and "#7ee787" or "#ffa657"
		table.insert(lines, string.format(
			"<style color=#ffffff><b>%s: </b></style><style color=%s><b>%s</b></style>",
			core.formspec_escape(S("Mobility")),
			mod_color,
			core.formspec_escape(mod_str)
		))
	end

	if has_shield then
		table.insert(lines, string.format(
			"<style color=#ffffff><b>%s: </b></style><style color=#d2a8ff><b>%s</b></style>",
			core.formspec_escape(S("Shield Defense")),
			core.formspec_escape(S("Active"))
		))
		table.insert(lines, string.format(
			"<style color=#c9d1d9 size=12>%s</style>",
			core.formspec_escape(S("Blocks up to 80% damage in frontal arc (Hold RMB)"))
		))
	end

	table.insert(lines, "")
	table.insert(lines, "<style color=#58a6ff><b>" .. core.formspec_escape(S("ACTIVE PERKS")) .. "</b></style>")

	local perks = {}
	if has_set_bonus then
		table.insert(perks, {
			color = "#f1e05a",
			text = S("★ Set Bonus: +10% Defense"),
		})
	end
	if heal > 0 then
		table.insert(perks, {
			color = "#7ee787",
			text = S("Healing Ward: @1% Chance to Absorb & Heal", heal),
		})
	end
	if has_shield then
		table.insert(perks, {
			color = "#d2a8ff",
			text = S("Shield Guard: Frontal Block & Parry"),
		})
	end
	if has_reciprocate then
		table.insert(perks, {
			color = "#ff7b72",
			text = S("Thorns: Damages Attacker's Weapon"),
		})
	end
	if (pdef.feather or 0) > 0 then
		table.insert(perks, {
			color = "#79c0ff",
			text = S("Feather Fall: Dampened (-@1 HP)", pdef.feather * 4),
		})
	end
	if (pdef.fire or 0) > 0 then
		table.insert(perks, {
			color = "#ffa657",
			text = S("Fire Ward: Protected (Heat Immune)"),
		})
	end
	if (pdef.water or 0) > 0 then
		table.insert(perks, {
			color = "#58a6ff",
			text = S("Water Ward: Breathing (Infinite)"),
		})
	end
	if speed_diff > 5 then
		table.insert(perks, {
			color = "#79c0ff",
			text = S("Swiftness: +@1% Movement Speed", speed_diff),
		})
	elseif speed_diff < -5 then
		table.insert(perks, {
			color = "#f85149",
			text = S("Heavy Load: @1% Movement Speed", speed_diff),
		})
	end
	if jump_diff > 5 then
		table.insert(perks, {
			color = "#7ee787",
			text = S("High Jump: +@1% Jump Height", jump_diff),
		})
	end

	if #perks == 0 then
		table.insert(lines, string.format(
			"<style color=#c9d1d9>%s</style>",
			core.formspec_escape(S("No active enchantments"))
		))
		table.insert(lines, string.format(
			"<style color=#c9d1d9 size=12>%s</style>",
			core.formspec_escape(S("Equip 4 matching pieces for set bonus"))
		))
	else
		for _, perk in ipairs(perks) do
			table.insert(lines, string.format(
				"<style color=%s><b>%s</b></style>",
				perk.color,
				core.formspec_escape(perk.text)
			))
		end
	end

	return table.concat(lines, "\n")
end

---Generates the modern Formspec Version 7 UI for armor and equipment.
---@param player ObjectRef
---@return string formspec
function ui.get_formspec(player)
	local name = player:get_player_name()
	local pdef = x_player_armor.get_player_def(player)
	local preview_model = ui.get_preview_model(player)
	local preview_texture = ui.get_preview_texture(player, preview_model)

	local fs = {
		"formspec_version[7]",
		"size[11.6,12.0]",
		"style_type[box;border=false]",
		"style_type[label;font=bold]",
		"style_type[list;size=1.0,1.0;spacing=0.15]",
		"listcolors[#00000069;#5A5A5A;#141318;#10141cf0;#c9d1d9]",
		"box[0,0;11.6,12.0;#0d1117]",

		-- Top Header
		"box[0.6,0.4;10.4,0.7;#161b22]",
		"label[0.9,0.78;" .. S("ARMOR & EQUIPMENT") .. "]",
		"style[btn_close;bgcolor=#21262d;textcolor=#8b949e;font=bold;border=true;borderwidth=1;bordercolor=#30363d]",
		"style[btn_close:hover;bgcolor=#da3633;textcolor=#ffffff;bordercolor=#f85149]",
		"style[btn_close:pressed;bgcolor=#b62324;textcolor=#ffffff;bordercolor=#da3633]",
		"button_exit[10.42,0.48;0.52,0.54;btn_close;X]",
		"tooltip[btn_close;" .. core.formspec_escape(S("Close")) .. ";#10141cf0;#c9d1d9]",

		-- 1st Column: 3D Player Model Preview Card (spans 2 rows: y = 1.3 .. 6.6, h = 5.3)
		"box[0.6,1.3;4.4,5.3;#161b22]",
		string.format(
			"model[0.8,1.4;4.0,4.7;armor_3d_preview;%s;%s;0,-150;false;true;0,0;0]",
			preview_model,
			preview_texture
		),
		"label[1.2,6.35;" .. core.colorize("#c9d1d9", core.formspec_escape(S("Drag to rotate 3D view"))) .. "]",

		-- 2nd Column 1st Row: Equipped Armor Slots (smaller row: 2 rows / 3 items, y = 1.3 .. 3.95, h = 2.65)
		"box[5.3,1.3;5.7,2.65;#161b22]",
		"label[5.6,1.55;" .. S("Equipped Armor Slots") .. "]",
	}

	-- 6 Slots arranged in 3 columns x 2 rows
	table.insert(fs, ui.render_slots(name, {6.35, 7.65, 8.95}, {1.75, 2.85}))

	-- 2nd Column 2nd Row: Aggregated armor attributes and active perks in scrollable hypertext (y = 4.15 .. 6.60, h = 2.45)
	table.insert(fs, "box[5.3,4.15;5.7,2.45;#161b22]")
	local stats_text = ui.build_stats_hypertext(pdef, player)
	table.insert(fs, string.format("hypertext[5.50,4.25;5.30,2.25;armor_stats;%s]", stats_text))

	-- Player Main Inventory Card (All 32 slots: 24 main + 8 hotbar)
	table.insert(fs, "box[0.6,6.8;10.4,4.9;#161b22]")
	table.insert(fs, "label[0.9,7.1;" .. core.colorize("#58a6ff", core.formspec_escape(S("PLAYER INVENTORY"))) .. "]")
	table.insert(fs, ui.render_player_inventory(1.4, 7.4))
	table.insert(fs, "label[0.9,10.65;" .. core.colorize("#58a6ff", core.formspec_escape(S("HOTBAR"))) .. "]")
	table.insert(fs, ui.render_player_hotbar(1.4, 11.0, 0.15))

	-- Shift-click circular listring loop
	table.insert(fs, "listring[detached:" .. name .. "_armor;armor]")
	table.insert(fs, "listring[current_player;main]")
	table.insert(fs, "listring[detached:" .. name .. "_armor;armor]")

	return table.concat(fs, "")
end

---Checks if the player's active wielded item or hotbar slot changed, and refreshes UI if needed.
---@param player ObjectRef
---@param skip_refresh? boolean If true, synchronizes internal tracked state without triggering refresh_player_formspec
---@return boolean changed
function ui.check_wield_change(player, skip_refresh)
	if not player or not player:is_player() then
		return false
	end
	local name = player:get_player_name()
	local last_state = ui.player_wield[name]
	local current_idx = player:get_wield_index() or 1
	local current_stack = player:get_wielded_item()
	local current_item = (current_stack and not current_stack:is_empty() and current_stack:get_name()) or ""
	local current_wear = (current_stack and not current_stack:is_empty() and current_stack:get_wear()) or 0

	if not last_state then
		ui.player_wield[name] = {
			index = current_idx,
			item = current_item,
			wear = current_wear,
		}
		if not skip_refresh and (current_item ~= "" or current_wear ~= 0) then
			ui.refresh_player_formspec(player)
			if x_player_armor.combat_hud.active_players[name] then
				x_player_armor.combat_hud.trigger(player)
			end
			return true
		end
		return false
	end

	if last_state.index ~= current_idx or last_state.item ~= current_item or last_state.wear ~= current_wear then
		last_state.index = current_idx
		last_state.item = current_item
		last_state.wear = current_wear
		if not skip_refresh then
			ui.refresh_player_formspec(player)
		end
		-- Reusable hook: Update combat armor HUD in-place if player is actively in combat
		if x_player_armor.combat_hud.active_players[name] then
			x_player_armor.combat_hud.trigger(player)
		end
		return true
	end

	return false
end

---Refreshes open formspecs for a player across active inventory engines.
---@param player ObjectRef
function ui.refresh_player_formspec(player)
	if not player or not player:is_player() then return end
	local name = player:get_player_name()

	-- Keep tracked wield state in sync without re-triggering recursive refresh
	ui.check_wield_change(player, true)

	-- 1. If custom standalone formspec is open
	if ui.open_players[name] then
		core.show_formspec(name, "x_player_armor:armor", ui.get_formspec(player))
	end

	-- 2. i3 refresh
	local i3_api = x_player_armor.get_mod_api("i3")
	if i3_api then
		i3_api.set_fs(player)
	end

	-- 3. sfinv refresh
	local sfinv_api = x_player_armor.get_mod_api("sfinv")
	if sfinv_api and sfinv_api.enabled ~= false then
		if sfinv_api.get_page(player) == "x_player_armor:armor" then
			sfinv_api.set_player_inventory_formspec(player)
		end
	end

	-- 4. Unified Inventory refresh
	local ui_api = x_player_armor.get_mod_api("unified_inventory")
	if ui_api and ui_api.current_page and ui_api.current_page[name] == "armor" then
		ui_api.set_inventory_formspec(player, "armor")
	end
end

---Checks whether a specific player is currently viewing an armor equipment interface.
---@param player ObjectRef
---@return boolean is_open
function ui.is_armor_ui_open(player)
	if not player or not player:is_player() then return false end
	local name = player:get_player_name()
	if ui.open_players[name] then
		return true
	end
	if ui.sfinv_open_players[name] then
		local sfinv_api = x_player_armor.get_mod_api("sfinv")
		if sfinv_api and sfinv_api.enabled ~= false then
			return sfinv_api.get_page(player) == "x_player_armor:armor"
		end
		return false
	end
	if ui.unified_inv_open_players[name] then
		local ui_api = x_player_armor.get_mod_api("unified_inventory")
		if ui_api and ui_api.current_page then
			return ui_api.current_page[name] == "armor"
		end
		return true
	end
	return false
end
x_player_armor.is_armor_ui_open = ui.is_armor_ui_open

---Checks whether any connected player has an active armor inventory interface open.
---Optimizes multiplayer performance by idle-skipping background updates when no UI is open.
---@return boolean has_any
function ui.has_any_open_armor_ui()
	return (next(ui.open_players) ~= nil)
		or (next(ui.sfinv_open_players) ~= nil)
		or (next(ui.unified_inv_open_players) ~= nil)
end
x_player_armor.has_any_open_armor_ui = ui.has_any_open_armor_ui

---Opens the armor and equipment inventory for a player.
---@param player ObjectRef
function ui.show_armor_formspec(player)
	if not player or not player:is_player() then return end
	local name = player:get_player_name()
	ui.open_players[name] = true
	ui.check_wield_change(player, true)
	core.show_formspec(name, "x_player_armor:armor", ui.get_formspec(player))
end

-- Register standalone /armor chat command
core.register_chatcommand("armor", {
	description = S("Open armor and equipment inventory"),
	func = function(name)
		local player = core.get_player_by_name(name)
		if player then
			ui.show_armor_formspec(player)
		end
		return true
	end,
})

core.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if formname == "x_player_armor:armor" then
		if fields.quit then
			ui.open_players[name] = nil
		end
		ui.check_wield_change(player)
	elseif formname == "" then
		-- sfinv / unified_inventory / main inventory interaction
		if fields.quit then
			ui.sfinv_open_players[name] = nil
			ui.unified_inv_open_players[name] = nil
		else
			local sfinv_api = x_player_armor.get_mod_api("sfinv")
			if sfinv_api and sfinv_api.enabled ~= false then
				if sfinv_api.get_page(player) == "x_player_armor:armor" then
					ui.sfinv_open_players[name] = true
				else
					ui.sfinv_open_players[name] = nil
				end
			end
			local ui_api = x_player_armor.get_mod_api("unified_inventory")
			if ui_api then
				for _, btn in ipairs(ui_api.buttons or {}) do
					if btn.name ~= "armor" and fields[btn.name] then
						ui.unified_inv_open_players[name] = nil
						break
					end
				end
				if ui_api.current_page then
					if ui_api.current_page[name] == "armor" then
						ui.unified_inv_open_players[name] = true
					elseif ui_api.current_page[name] ~= nil then
						ui.unified_inv_open_players[name] = nil
					end
				end
			end
		end
		ui.check_wield_change(player)
	end
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local stack = player:get_wielded_item()
	local current_idx = player:get_wield_index() or 1
	ui.player_wield[name] = {
		index = current_idx,
		item = (stack and not stack:is_empty() and stack:get_name()) or "",
		wear = (stack and not stack:is_empty() and stack:get_wear()) or 0,
	}
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	ui.player_wield[name] = nil
	ui.open_players[name] = nil
	ui.sfinv_open_players[name] = nil
	ui.unified_inv_open_players[name] = nil
end)

core.register_on_mods_loaded(function()
	if x_player_armor.compat_x_player_api.is_present() then
		local x_api = x_player_armor.compat_x_player_api.get_api()
		if x_api and x_api.register_on_wield_change then
			-- Event-driven slot syncing is handled via x_player_api.register_on_wield_change in modules/compat/x_player_api.lua (zero globalstep polling)
			return
		end
	end

	-- Fallback: Throttled 0.2s globalstep with idle-skipping when x_player_api is absent
	local wield_check_timer = 0
	local WIELD_CHECK_INTERVAL = 0.2

	core.register_globalstep(function(dtime)
		local has_open_ui = ui.has_any_open_armor_ui()
		local has_combat = x_player_armor.combat_hud and next(x_player_armor.combat_hud.active_players) ~= nil
		if not has_open_ui and not has_combat then
			return
		end

		wield_check_timer = wield_check_timer + dtime
		if wield_check_timer < WIELD_CHECK_INTERVAL then
			return
		end
		wield_check_timer = 0

		local players = core.get_connected_players()
		local count = #players
		if count == 0 then
			return
		end

		for i = 1, count do
			local p = players[i]
			local pname = p:get_player_name()
			local is_combat = x_player_armor.combat_hud and x_player_armor.combat_hud.active_players[pname]
			if ui.is_armor_ui_open(p) or is_combat then
				ui.check_wield_change(p)
			end
		end
	end)
end)

-- sfinv tab integration
local sfinv_api = x_player_armor.get_mod_api("sfinv")
if sfinv_api then
	sfinv_api.register_page("x_player_armor:armor", {
		title = S("Armor"),
		on_enter = function(_self, player, _context)
			local name = player:get_player_name()
			ui.sfinv_open_players[name] = true
			ui.check_wield_change(player, true)
		end,
		on_leave = function(_self, player, _context)
			local name = player:get_player_name()
			ui.sfinv_open_players[name] = nil
		end,
		get = function(_self, player, context)
			local name = player:get_player_name()
			ui.check_wield_change(player, true)
			local preview_model = ui.get_preview_model(player)
			local preview_texture = ui.get_preview_texture(player, preview_model)
			local pdef = x_player_armor.get_player_def(player)

			local fs = {
				"style_type[box;border=false]",
				"style_type[label;font=bold]",
				"style_type[list;size=1.0,1.0;spacing=0.25]",
				"listcolors[#00000069;#5A5A5A;#141318;#10141cf0;#c9d1d9]",

				-- COLUMN 1: 3D Interactive Model Preview Card (Spans 2 rows: y = 0.25 .. 6.55, h = 6.30)
				"box[0.375,0.25;4.40,6.30;#161b22ee]",
				string.format(
					"model[0.475,0.40;4.20,5.55;armor_sfinv_preview;%s;%s;0,-150;false;true;0,0;0]",
					preview_model,
					preview_texture
				),
				string.format(
					"label[1.20,6.18;%s]",
					core.colorize("#c9d1d9", core.formspec_escape(S("Drag to rotate 3D view")))
				),

				-- COLUMN 2 ROW 1: Equipped Armor Slots Panel (Smaller row: y = 0.25 .. 3.05, h = 2.80)
				"box[5.025,0.25;5.10,2.80;#161b22ee]",
				string.format(
					"label[5.30,0.50;%s]",
					core.colorize("#58a6ff", core.formspec_escape(S("EQUIPPED ARMOR")))
				),
			}

			-- 6 Slots arranged in 3 columns x 2 rows
			table.insert(fs, ui.render_slots(name, {5.725, 7.075, 8.425}, {0.75, 1.90}))

			-- COLUMN 2 ROW 2: Aggregated Armor Attributes & Active Perks in Scrollable Hypertext (y = 3.30 .. 6.55, h = 3.25)
			table.insert(fs, "box[5.025,3.30;5.10,3.25;#161b22ee]")
			local stats_text = ui.build_stats_hypertext(pdef, player)
			table.insert(fs, string.format("hypertext[5.25,3.45;4.65,2.95;armor_stats;%s]", stats_text))

			-- ROW 3: Player Hotbar and Main Inventory
			-- Hotbar: 8 slots at y = 6.875, Main Inventory: 8x3 slots at y = 8.3125
			for col = 0, 7 do
				local bx = 0.375 + col * 1.25
				table.insert(fs, string.format("image[%f,6.875;1.0,1.0;gui_hb_bg.png]", bx))
			end
			table.insert(fs, "list[current_player;main;0.375,6.875;8,1;0]")
			table.insert(fs, "list[current_player;main;0.375,8.3125;8,3;8]")

			-- Shift-click circular listring loop
			table.insert(fs, "listring[detached:" .. name .. "_armor;armor]")
			table.insert(fs, "listring[current_player;main]")
			table.insert(fs, "listring[detached:" .. name .. "_armor;armor]")

			-- Parameter 4 = false: we provide modern real coordinate inventory layout!
			-- Parameter 5 = formspec_version[7]size[10.5,12.25]: consistent 0.4375 padding below inventory!
			return sfinv_api.make_formspec(player, context, table.concat(fs, ""), false, "formspec_version[7]size[10.5,12.25]")
		end,
	})
end

---Generates the formspec content table for Unified Inventory's armor page.
---Reuses the 3D player preview, 6 equipped armor slots, and aggregated stats hypertext.
---@param player ObjectRef
---@param perplayer_formspec? table Optional style definition from Unified Inventory
---@return table page_data Table with formspec, draw_inventory, and draw_item_list
function ui.get_unified_inventory_formspec(player, perplayer_formspec)
	local name = player:get_player_name()
	ui.check_wield_change(player, true)

	local style = perplayer_formspec
	local ui_api = x_player_armor.get_mod_api("unified_inventory")
	if not style and ui_api then
		style = ui_api.get_per_player_formspec(name)
	end
	style = style or (ui_api and ui_api.style_full) or {
		form_header_x = 0.4,
		form_header_y = 0.4,
		is_lite_mode = false,
		standard_inv_bg = "",
	}

	local is_lite = style.is_lite_mode == true
	local preview_model = ui.get_preview_model(player)
	local preview_texture = ui.get_preview_texture(player, preview_model)
	local pdef = x_player_armor.get_player_def(player)
	local stats_text = ui.build_stats_hypertext(pdef, player)

	local fs = {
		style.standard_inv_bg or "",
		"listcolors[#00000000;#00000000;#30363d;#10141cf0;#c9d1d9]",
		string.format(
			"label[%f,%f;%s]",
			style.form_header_x or 0.4,
			style.form_header_y or 0.4,
			core.formspec_escape(S("Armor & Equipment"))
		),
	}

	if is_lite then
		-- LITE MODE LAYOUT (height budget ~3.95 above standard_inv at y = 4.60)
		-- Column 1: 3D Player Preview Card
		table.insert(fs, "box[0.10,0.50;3.80,3.95;#161b22ee]")
		table.insert(fs, string.format(
			"model[0.15,0.55;3.70,3.45;armor_unified_preview;%s;%s;0,-150;false;true;0,0;0]",
			preview_model,
			preview_texture
		))
		table.insert(fs, string.format(
			"label[0.55,4.22;%s]",
			core.colorize("#c9d1d9", core.formspec_escape(S("Drag to rotate 3D view")))
		))

		-- Column 2 Top: Equipped Armor Slots Panel
		table.insert(fs, "box[4.10,0.50;6.20,2.30;#161b22ee]")
		table.insert(fs, string.format(
			"label[4.30,0.68;%s]",
			core.colorize("#58a6ff", core.formspec_escape(S("EQUIPPED ARMOR")))
		))
		table.insert(fs, ui.render_slots(name, {4.85, 6.55, 8.25}, {0.75, 1.75}))

		-- Column 2 Bottom: Aggregated Armor Attributes & Active Perks Hypertext
		table.insert(fs, "box[4.10,2.85;6.20,1.60;#161b22ee]")
		table.insert(fs, string.format("hypertext[4.25,2.95;5.90,1.40;armor_stats;%s]", stats_text))
	else
		-- FULL MODE LAYOUT (height budget ~4.90 above standard_inv at y = 5.75)
		-- Column 1: 3D Player Preview Card
		table.insert(fs, "box[0.30,0.70;4.30,4.90;#161b22ee]")
		table.insert(fs, string.format(
			"model[0.40,0.80;4.10,4.35;armor_unified_preview;%s;%s;0,-150;false;true;0,0;0]",
			preview_model,
			preview_texture
		))
		table.insert(fs, string.format(
			"label[0.90,5.32;%s]",
			core.colorize("#c9d1d9", core.formspec_escape(S("Drag to rotate 3D view")))
		))

		-- Column 2 Top: Equipped Armor Slots Panel
		table.insert(fs, "box[4.80,0.70;5.65,2.50;#161b22ee]")
		table.insert(fs, string.format(
			"label[5.00,0.90;%s]",
			core.colorize("#58a6ff", core.formspec_escape(S("EQUIPPED ARMOR")))
		))
		table.insert(fs, ui.render_slots(name, {5.45, 7.10, 8.75}, {1.05, 2.10}))

		-- Column 2 Bottom: Aggregated Armor Attributes & Active Perks Hypertext
		table.insert(fs, "box[4.80,3.30;5.65,2.30;#161b22ee]")
		table.insert(fs, string.format("hypertext[4.95,3.40;5.35,2.10;armor_stats;%s]", stats_text))
	end

	-- Shift-click circular listring loop
	table.insert(fs, "listring[detached:" .. name .. "_armor;armor]")
	table.insert(fs, "listring[current_player;main]")
	table.insert(fs, "listring[detached:" .. name .. "_armor;armor]")

	return {
		formspec = table.concat(fs, ""),
		draw_inventory = true,
		draw_item_list = true,
	}
end

-- Unified Inventory integration
local ui_api = x_player_armor.get_mod_api("unified_inventory")
if ui_api then
	-- Apply x_player_armor modern dark theme tooltip colors to Unified Inventory background
	if ui_api.standard_background and not ui_api.standard_background:find("listcolors") then
		ui_api.standard_background = ui_api.standard_background .. "listcolors[#00000000;#00000000;#30363d;#10141cf0;#c9d1d9]"
	end

	-- Hook Unified Inventory formspec generator to theme tooltips across all pages
	if type(ui_api.get_formspec) == "function" and not ui_api._x_player_armor_themed then
		ui_api._x_player_armor_themed = true
		local orig_ui_get_formspec = ui_api.get_formspec
		ui_api.get_formspec = function(player, page)
			local uifs = orig_ui_get_formspec(player, page)
			if type(uifs) == "string" and uifs ~= "" then
				-- Replace un-themed inventory listcolors resets with our dark theme tooltip colors
				uifs = uifs:gsub("listcolors%[#00000000;#00000000%]", "listcolors[#00000000;#00000000;#30363d;#10141cf0;#c9d1d9]")
				-- Ensure trailing item browser tooltips inherit the theme colors
				if not uifs:find("listcolors%[#00000000;#00000000;#30363d;#10141cf0;#c9d1d9%]$") then
					uifs = uifs .. "listcolors[#00000000;#00000000;#30363d;#10141cf0;#c9d1d9]"
				end
			end
			return uifs
		end
	end

	ui_api.register_page("armor", {
		get_formspec = function(player, perplayer_formspec)
			local name = player:get_player_name()
			ui.unified_inv_open_players[name] = true
			return ui.get_unified_inventory_formspec(player, perplayer_formspec)
		end,
	})

	local btn_def = {
		type = "image",
		image = "x_player_armor_icon.png",
		tooltip = S("Armor & Equipment"),
		action = function(player)
			ui.check_wield_change(player, true)
			local name = player:get_player_name()
			ui.unified_inv_open_players[name] = true
			ui_api.set_inventory_formspec(player, "armor")
		end,
	}

	-- Deduplicate button if already registered
	local already_registered = false
	if ui_api.buttons then
		for _, btn in ipairs(ui_api.buttons) do
			if btn.name == "armor" then
				already_registered = true
				break
			end
		end
	end
	if not already_registered then
		ui_api.register_button("armor", btn_def)
	end
end

---Returns a 2D composite preview texture overlay string for legacy formspecs.
---@param player ObjectRef
---@return string preview_2d
function ui.get_2d_preview_texture(player)
	local base = "character_preview.png"
	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then
		return base
	end
	local list = inv:get_list("armor")
	if not list then
		return base
	end

	local layers = {base}
	for i = 1, #list do
		local stack = list[i]
		if stack and not stack:is_empty() then
			local def = stack:get_definition()
			if def and def.preview and def.preview ~= "" and def.preview ~= "blank.png" then
				table.insert(layers, def.preview)
			end
		end
	end
	return table.concat(layers, "^")
end

---Returns legacy formspec for player name/player.
---@param player ObjectRef|string
---@param _page? number
---@return string
function ui.get_legacy_formspec(player, _page)
	local pref = type(player) == "string" and core.get_player_by_name(player) or player
	if pref and pref:is_player() then
		return ui.get_formspec(pref)
	end
	return ""
end

x_player_armor.ui = ui
return ui
