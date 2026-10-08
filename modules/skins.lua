-- X Player Armor - Skin Subsystem & Texture Resolution (modules/skins.lua)
-- Resolves player skin formats (1.0 vs 1.8), integrates third-party skin mods
-- (skinsdb, simple_skins, wardrobe, clothing), and routes textures to canonical
-- preview model slots following Single Responsibility and DRY principles.
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class SkinResolution
---@field body10 string Texture specifier for 64x32 Slot 0 ("blank.png" if 1.8)
---@field body18 string Texture specifier for 64x64 Slot 1 ("blank.png" if 1.0)
---@field format string "1.0" | "1.8"
---@field raw_texture string Base skin texture filename
---@field composite_texture string Skin texture with clothing overlays

---@class XPlayerArmorSkins
local skins = {
	format_cache = {},
}

local BLANK = "blank.png"
local DEFAULT_SKIN = "x_player_armor_character.png"

---Detects whether a skin texture represents a 1.8 (64x64) or 1.0 (64x32) layout.
---Inspects naming conventions, skinsdb metadata, and cached dimensions.
---@param texture_name string Texture filename or modifier string
---@return string format Format identifier ("1.0" or "1.8")
function skins.detect_texture_format(texture_name)
	if not texture_name or texture_name == "" or texture_name == BLANK then
		return "1.0"
	end

	local cached = skins.format_cache[texture_name]
	if cached then
		return cached
	end

	-- Check explicit format naming conventions in filename
	if texture_name:find("_18", 1, true) or texture_name:find("1.8", 1, true) then
		skins.format_cache[texture_name] = "1.8"
		return "1.8"
	end

	-- Check skinsdb skin metadata
	local skins_mod = x_player_armor.get_mod_api("skins")
	if skins_mod and skins_mod.get then
		local key = texture_name:gsub("%.png$", "")
		local skin_obj = skins_mod.get(key)
		if skin_obj and skin_obj.get_meta then
			local ver = skin_obj:get_meta("format")
			if ver == "1.8" or ver == "1.0" then
				skins.format_cache[texture_name] = ver
				return ver
			end
		end
	end

	-- Standard fallback to 1.0 format
	skins.format_cache[texture_name] = "1.0"
	return "1.0"
end

---Resolves active clothing overlays for a player if the clothing mod is installed.
---@param player_name string Technical player name
---@return string? overlay_string Combined clothing overlay texture string or nil
function skins.get_clothing_overlay(player_name)
	local clothing_mod = x_player_armor.get_mod_api("clothing")
	if not clothing_mod or not clothing_mod.player_textures then
		return nil
	end

	local c_data = clothing_mod.player_textures[player_name]
	if not c_data then
		return nil
	end

	local layers = {}
	for k, v in pairs(c_data) do
		if k ~= "skin" and k ~= "cape" and v and v ~= "" and v ~= BLANK then
			table.insert(layers, v)
		end
	end

	if #layers > 0 then
		return table.concat(layers, "^")
	end
	return nil
end

---Resolves the player's active skin and produces the canonical dual-slot texture pair.
---@param player ObjectRef Target player
---@return SkinResolution resolution Resolved skin data with body10 and body18 textures
function skins.resolve_player_skin(player)
	local player_name = player:get_player_name()
	local raw_skin = nil
	local format = nil

	-- Query skinsdb player skin object if available
	local skins_mod = x_player_armor.get_mod_api("skins")
	if skins_mod and skins_mod.get_player_skin then
		local skin_obj = skins_mod.get_player_skin(player)
		if skin_obj then
			if skin_obj.get_texture then
				local tex = skin_obj:get_texture()
				if tex and tex ~= "" and tex ~= BLANK then
					raw_skin = tex
				end
			end
			if skin_obj.get_meta then
				local ver = skin_obj:get_meta("format")
				if ver == "1.8" or ver == "1.0" then
					format = ver
				end
			end
		end
	end

	-- Inspect player_api or engine properties if raw_skin is not yet resolved
	local p_api = x_player_armor.get_mod_api("player_api")
	local textures = p_api and p_api.get_textures(player)
	if not textures then
		local props = player:get_properties()
		textures = props and props.textures
	end

	if textures and #textures > 0 then
		-- Detect skinsdb 4-slot layout: Slot 1 is 1.0, Slot 2 is 1.8
		if #textures >= 2 and textures[2] and textures[2] ~= "" and textures[2] ~= BLANK then
			if not raw_skin then
				raw_skin = textures[2]
			end
			if not format then
				format = "1.8"
			end
		elseif textures[1] and textures[1] ~= "" and textures[1] ~= BLANK then
			if not raw_skin then
				raw_skin = textures[1]
			end
		end
	end

	if not raw_skin or raw_skin == "" or raw_skin == BLANK then
		raw_skin = DEFAULT_SKIN
		format = "1.0"
	end

	if not format then
		format = skins.detect_texture_format(raw_skin)
	end

	-- Composite clothing overlays if present
	local composite_skin = raw_skin
	local clothing_overlay = skins.get_clothing_overlay(player_name)
	if clothing_overlay then
		composite_skin = raw_skin .. "^" .. clothing_overlay
	end

	-- Route to canonical dual-format preview slots
	local body10_tex = BLANK
	local body18_tex = BLANK

	if format == "1.8" then
		body18_tex = composite_skin
	else
		body10_tex = composite_skin
	end

	return {
		body10 = body10_tex,
		body18 = body18_tex,
		format = format,
		raw_texture = raw_skin,
		composite_texture = composite_skin,
	}
end

---Convenience accessor for skin info.
---@param player ObjectRef Target player
---@return SkinResolution resolution Resolved skin data
function skins.get_skin_info(player)
	return skins.resolve_player_skin(player)
end

x_player_armor.skins = skins
return skins
