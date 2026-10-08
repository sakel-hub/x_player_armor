-- X Player Armor - Backwards Compatibility Orchestrator (modules/compat.lua)
-- Orchestrates modular compatibility shims adhering to SOLID principles.
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class XPlayerArmorCompat
---@field hud XPlayerArmorCompatHUD HUD statbar synchronizer (hbarmor support)
---@field x_player_api XPlayerArmorCompatXPlayerAPI Advanced x_player_api adapter
---@field armor ArmorCompat 3d_armor API compatibility shim
---@field shields ShieldsCompat Shields API compatibility shim
---@field stand ArmorStandCompat 3d_armor_stand compatibility shim
local compat = {}

local modpath = core.get_modpath("x_player_armor")

-- 1. HUD Statbar Synchronizer (hbarmor support)
compat.hud = dofile(modpath .. "/modules/compat/hud.lua")

-- 2. Advanced x_player_api Adapter (Optional, zero x_player_bridge dependency)
compat.x_player_api = dofile(modpath .. "/modules/compat/x_player_api.lua")

-- 3. 3D Armor API Compatibility Shim
compat.armor = dofile(modpath .. "/modules/compat/armor.lua")

-- 4. Shields API Compatibility Shim
compat.shields = dofile(modpath .. "/modules/compat/shields.lua")

-- 5. 3D Armor Stand Compatibility Shim
compat.stand = dofile(modpath .. "/modules/compat/stand.lua")

-- Maintain both namespaced and top-level references for 100% backwards compatibility
x_player_armor.compat = compat
x_player_armor.compat_hud = compat.hud
x_player_armor.compat_x_player_api = compat.x_player_api
x_player_armor.compat_armor = compat.armor
x_player_armor.compat_shields = compat.shields
x_player_armor.compat_stand = compat.stand

return compat
