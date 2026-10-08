-- X Player Armor - Backwards Compatibility Orchestrator (modules/compat.lua)
-- Orchestrates modular compatibility shims adhering to SOLID principles.
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class XPlayerArmorCompat
---@field override XPlayerArmorOverride Legacy 3d_armor runtime override and takeover
---@field hud XPlayerArmorCompatHUD HUD statbar synchronizer (hbarmor support)
---@field x_player_api XPlayerArmorCompatXPlayerAPI Advanced x_player_api adapter
---@field armor ArmorCompat 3d_armor API compatibility shim
---@field shields ShieldsCompat Shields API compatibility shim
---@field stand ArmorStandCompat 3d_armor_stand compatibility shim
local compat = {}

local modpath = core.get_modpath("x_player_armor")

-- Legacy 3D Armor override and neutralizer (neutralize legacy callbacks before registering shims)
compat.override = dofile(modpath .. "/modules/compat/override.lua")
compat.override.takeover_legacy_armor()
core.register_on_mods_loaded(compat.override.takeover_legacy_armor)

-- HUD statbar synchronizer (hbarmor support)
compat.hud = dofile(modpath .. "/modules/compat/hud.lua")

-- Advanced x_player_api adapter (optional, zero x_player_bridge dependency)
compat.x_player_api = dofile(modpath .. "/modules/compat/x_player_api.lua")

-- 3D Armor API compatibility shim
compat.armor = dofile(modpath .. "/modules/compat/armor.lua")

-- Shields API compatibility shim
compat.shields = dofile(modpath .. "/modules/compat/shields.lua")

-- 3D Armor Stand compatibility shim
compat.stand = dofile(modpath .. "/modules/compat/stand.lua")

-- Maintain both namespaced and top-level references for complete backwards compatibility
x_player_armor.compat = compat
x_player_armor.compat_override = compat.override
x_player_armor.compat_hud = compat.hud
x_player_armor.compat_x_player_api = compat.x_player_api
x_player_armor.compat_armor = compat.armor
x_player_armor.compat_shields = compat.shields
x_player_armor.compat_stand = compat.stand

return compat
