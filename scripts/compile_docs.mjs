#!/usr/bin/env node
/**
 * scripts/compile_docs.mjs
 *
 * Compiles comprehensive API.md documentation for x_player_armor
 * using emmylua_doc_cli and EmmyLua / LuaLS annotations.
 *
 * Copyright (C) 2026 SaKeL
 * License: LGPL-2.1-or-later
 */

import { execSync } from 'child_process'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const rootDir = path.resolve(__dirname, '..')

// Check if emmylua_doc_cli is available
function checkEmmyLuaDocCli() {
    try {
        execSync('which emmylua_doc_cli', { stdio: 'pipe' })
        return true
    } catch {
        return false
    }
}

// Format parameter list for signature
function formatParamSignature(params) {
    if (!params || params.length === 0) return ''
    return params.map(p => p.name).join(', ')
}

// Format parameter list with types
function formatTypedParams(params) {
    if (!params || params.length === 0) return ''
    return params.map(p => `${p.name}: ${p.typ || 'any'}`).join(', ')
}

// Format return types
function formatReturnSignature(returns) {
    if (!returns || returns.length === 0) return 'void'
    return returns.map(r => r.typ || 'any').join(', ')
}

// Clean and escape table markdown text
function escapeTableText(text) {
    if (!text) return ''
    return text.replace(/\|/g, '\\|').replace(/\r?\n/g, ' ')
}

// Format field type for markdown
function formatTypeDisplay(typ) {
    if (!typ) return 'any'
    return typ.replace(/\|/g, '\\|')
}

// Main compilation routine
async function main() {
    console.log('Compiling x_player_armor API documentation using emmylua_doc_cli...')

    if (!checkEmmyLuaDocCli()) {
        console.error('Error: emmylua_doc_cli was not found in PATH.')
        console.error('Install via Homebrew: brew install emmylua_ls')
        console.error('Or via Cargo: cargo install emmylua_doc_cli')
        process.exit(1)
    }

    const docBuildDir = path.join(rootDir, 'doc_build')
    const jsonPath = path.join(docBuildDir, 'doc.json')

    try {
        if (!fs.existsSync(docBuildDir)) {
            fs.mkdirSync(docBuildDir, { recursive: true })
        }

        // Run emmylua_doc_cli to generate JSON AST
        execSync(`emmylua_doc_cli "${rootDir}" -f json -o "${jsonPath}"`, {
            cwd: rootDir,
            stdio: 'inherit'
        })

        if (!fs.existsSync(jsonPath)) {
            throw new Error(`Failed to generate ${jsonPath}`)
        }

        const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'))
        const types = data.types || []
        const modules = data.modules || []
        const globals = data.globals || []

        // Extract primary API module and subsystems
        const apiModule = modules.find(m => m.name === 'api') || {}
        const apiMembers = apiModule.members || []

        // Group types
        const classTypes = types.filter(t => t.name.startsWith('XPlayerArmor') || t.name.endsWith('Compat'))
        const aliasTypes = types.filter(t => t.type === 'alias' && !t.name.startsWith('XPlayerArmor'))

        // Subsystems map
        const subsystemTypes = {
            inventory: types.find(t => t.name === 'XPlayerArmorInventory'),
            combat: types.find(t => t.name === 'XPlayerArmorCombat'),
            visuals: types.find(t => t.name === 'XPlayerArmorVisuals'),
            effects: types.find(t => t.name === 'XPlayerArmorEffects'),
            stand: types.find(t => t.name === 'XPlayerArmorStand'),
            items: types.find(t => t.name === 'XPlayerArmorItems'),
            crafting: types.find(t => t.name === 'XPlayerArmorCrafting'),
            skins: types.find(t => t.name === 'XPlayerArmorSkins'),
            ui: types.find(t => t.name === 'XPlayerArmorUI'),
            shield_hud: types.find(t => t.name === 'XPlayerArmorShieldHUD'),
            combat_hud: types.find(t => t.name === 'XPlayerArmorCombatHUD'),
            vfx: types.find(t => t.name === 'XPlayerArmorVFX'),
            utils: types.find(t => t.name === 'XPlayerArmorUtils'),
            compat: types.find(t => t.name === 'XPlayerArmorCompat'),
            compat_x_player_api: types.find(t => t.name === 'XPlayerArmorCompatXPlayerAPI'),
            compat_armor: types.find(t => t.name === 'ArmorCompat'),
            compat_shields: types.find(t => t.name === 'ShieldsCompat'),
            compat_stand: types.find(t => t.name === 'ArmorStandCompat'),
        }

        const lines = []
        function emit(str = '') {
            lines.push(str)
        }

        // Header
        emit('# x_player_armor API Reference')
        emit()
        emit('High-performance modular player armor, shield defense, durability, and damage mitigation system for Luanti.')
        emit()

        // Table of Contents
        emit('## Table of Contents')
        emit()
        emit('- [Core Data Structures & Types](#core-data-structures--types)')
        emit('  - [XPlayerArmorItemDef](#xplayerarmoritemdef)')
        emit('  - [XPlayerArmorTransform](#xplayerarmortransform)')
        emit('  - [XPlayerArmorConstants](#xplayerarmorconstants)')
        emit('  - [XPlayerArmorPunchCallback](#xplayerarmorpunchcallback)')
        emit('  - [XPlayerArmorSounds](#xplayerarmorsounds)')
        emit('- [Public API Methods](#public-api-methods)')
        emit('- [Inventory Subsystem](#inventory-subsystem)')
        emit('- [Combat & Deflection Subsystem](#combat--deflection-subsystem)')
        emit('- [Visuals & Bones Subsystem](#visuals--bones-subsystem)')
        emit('- [Effects & Physics Subsystem](#effects--physics-subsystem)')
        emit('- [Armor Stand Subsystem](#armor-stand-subsystem)')
        emit('- [Items & Registration Subsystem](#items--registration-subsystem)')
        emit('- [Crafting Recipes Subsystem](#crafting-recipes-subsystem)')
        emit('- [Skins & Textures Subsystem](#skins--textures-subsystem)')
        emit('- [UI & Formspecs Subsystem](#ui--formspecs-subsystem)')
        emit('- [HUD Subsystems](#hud-subsystems)')
        emit('  - [Combat HUD Overlay](#combat-hud-overlay)')
        emit('  - [Shield Blocking Indicator HUD](#shield-blocking-indicator-hud)')
        emit('- [Compatibility Adapters](#compatibility-adapters)')
        emit('  - [3d_armor Compatibility Layer](#3d_armor-compatibility-layer)')
        emit('  - [shields Compatibility Layer](#shields-compatibility-layer)')
        emit('  - [3d_armor_stand Compatibility Layer](#3d_armor_stand-compatibility-layer)')
        emit('  - [x_player_api Integration Adapter](#x_player_api-integration-adapter)')
        emit('- [Visual Particle Effects (VFX)](#visual-particle-effects-vfx)')
        emit('- [Utility Methods](#utility-methods)')
        emit()
        emit('---')
        emit()

        // Core Data Structures & Types
        emit('## Core Data Structures & Types')
        emit()

        const primaryTypes = [
            'XPlayerArmorItemDef',
            'XPlayerArmorTransform',
            'XPlayerArmorConstants',
            'XPlayerArmorPunchCallback',
            'XPlayerArmorSounds'
        ]

        for (const typeName of primaryTypes) {
            const typ = types.find(t => t.name === typeName)
            if (!typ) continue

            emit(`### \`${typ.name}\``)
            emit()
            if (typ.description) {
                emit(typ.description)
                emit()
            }

            const fields = (typ.members || []).filter(m => m.type === 'field')
            if (fields.length > 0) {
                emit('| Field | Type | Description |')
                emit('| :--- | :--- | :--- |')
                for (const field of fields) {
                    const fDesc = escapeTableText(field.description || '')
                    const fType = formatTypeDisplay(field.typ || 'any')
                    emit(`| \`${field.name}\` | \`${fType}\` | ${fDesc} |`)
                }
                emit()
            }
        }

        // Helper to format functions
        function renderFunctionsSection(fns, prefix = 'x_player_armor') {
            if (!fns || fns.length === 0) {
                emit('*No exported public functions in this section.*')
                emit()
                return
            }

            for (const fn of fns) {
                const paramSig = formatParamSignature(fn.params)
                const typedParams = formatTypedParams(fn.params)
                const retSig = formatReturnSignature(fn.returns)

                emit(`### \`${prefix}.${fn.name}(${paramSig})\``)
                emit()
                if (fn.description) {
                    emit(fn.description)
                    emit()
                }

                emit('```lua')
                emit(`${prefix}.${fn.name}(${typedParams}) -> ${retSig}`)
                emit('```')
                emit()

                if (fn.params && fn.params.length > 0) {
                    emit('**Parameters:**')
                    for (const p of fn.params) {
                        const pDesc = p.desc ? ` — ${p.desc}` : ''
                        emit(`- \`${p.name}\` (\`${p.typ || 'any'}\`)${pDesc}`)
                    }
                    emit()
                }

                if (fn.returns && fn.returns.length > 0) {
                    emit('**Returns:**')
                    for (const r of fn.returns) {
                        const rName = r.name ? `\`${r.name}\` ` : ''
                        const rDesc = r.desc ? ` — ${r.desc}` : ''
                        emit(`- ${rName}(\`${r.typ || 'any'}\`)${rDesc}`)
                    }
                    emit()
                }

                emit('---')
                emit()
            }
        }

        // Public API Methods
        emit('## Public API Methods')
        emit()
        emit('Methods exposed directly on the root `x_player_armor` namespace.')
        emit()
        const coreFns = apiMembers.filter(m => m.type === 'fn')
        renderFunctionsSection(coreFns, 'x_player_armor')

        // Subsystems
        const subsystemsToRender = [
            { key: 'inventory', title: 'Inventory Subsystem', prefix: 'x_player_armor.inventory', desc: 'Detached inventory management, equipment persistence, and slot serialization.' },
            { key: 'combat', title: 'Combat & Deflection Subsystem', prefix: 'x_player_armor.combat', desc: 'Punch damage calculations, active shield blocking cone evaluation, recoil physics, and arrow deflection.' },
            { key: 'visuals', title: 'Visuals & Bones Subsystem', prefix: 'x_player_armor.visuals', desc: 'Direct bone attachment visual entities, skeletal transformation reconciliation, and multi-format support.' },
            { key: 'effects', title: 'Effects & Physics Subsystem', prefix: 'x_player_armor.effects', desc: 'Periodic environmental protection (fire, drown, heal, feather fall) and player physics monoid integration.' },
            { key: 'stand', title: 'Armor Stand Subsystem', prefix: 'x_player_armor.stand', desc: 'Interactive armor stand node, 3D entity preview, shift-click wardrobe swap, and management UI.' },
            { key: 'items', title: 'Items & Registration Subsystem', prefix: 'x_player_armor.items', desc: 'Armor item registration, tier generation, textures, and craft recipe orchestration.' },
            { key: 'crafting', title: 'Crafting Recipes Subsystem', prefix: 'x_player_armor.crafting', desc: 'Crafting recipe definitions and ingredient queries for armor equipment.' },
            { key: 'skins', title: 'Skins & Textures Subsystem', prefix: 'x_player_armor.skins', desc: 'Player skin resolution, 1.0 vs 1.8 format detection, and clothing layer compositing.' },
            { key: 'ui', title: 'UI & Formspecs Subsystem', prefix: 'x_player_armor.ui', desc: 'Modern responsive formspecs, sfinv tab integration, unified_inventory, and i3 adapters.' },
            { key: 'combat_hud', title: 'Combat HUD Overlay', prefix: 'x_player_armor.combat_hud', desc: 'Screen overlay displaying equipment durability and active loadout during combat.' },
            { key: 'shield_hud', title: 'Shield Blocking Indicator HUD', prefix: 'x_player_armor.shield_hud', desc: '1st-person perspective dynamic shield blocking guard and cooldown crosshair HUD indicator.' },
            { key: 'vfx', title: 'Visual Particle Effects (VFX)', prefix: 'x_player_armor.vfx', desc: 'Hit particle bursts, durability break sparks, shield deflection visual particles, and sound effects.' },
            { key: 'utils', title: 'Utility Methods', prefix: 'x_player_armor.utils', desc: 'Shared mathematical, spatial, and vector helpers.' },
            { key: 'compat_x_player_api', title: 'x_player_api Integration Adapter', prefix: 'x_player_armor.compat.x_player_api', desc: 'Biomechanical off-hand shield attachment, multi-track animation synchronization, and hurt triggers.' },
            { key: 'compat_armor', title: '3d_armor Compatibility Layer', prefix: 'armor', desc: 'Full backward-compatible drop-in shim providing legacy 3d_armor API functions.' },
            { key: 'compat_shields', title: 'shields Compatibility Layer', prefix: 'shields', desc: 'Full backward-compatible drop-in shim providing legacy shields API functions.' },
            { key: 'compat_stand', title: '3d_armor_stand Compatibility Layer', prefix: 'armor_stand', desc: 'Compatibility shim for legacy 3d_armor_stand registrations and nodes.' }
        ]

        for (const sub of subsystemsToRender) {
            emit(`## ${sub.title}`)
            emit()
            if (sub.desc) {
                emit(sub.desc)
                emit()
            }
            const typeObj = subsystemTypes[sub.key]
            if (typeObj && typeObj.members) {
                const fns = typeObj.members.filter(m => m.type === 'fn')
                renderFunctionsSection(fns, sub.prefix)
            } else {
                emit('*No explicit methods exported.*')
                emit()
            }
        }

        // Write output API.md
        const outputPath = path.join(rootDir, 'API.md')
        const content = lines.join('\n')
        fs.writeFileSync(outputPath, content, 'utf8')

        const totalFns = lines.filter(l => l.startsWith('### `')).length
        console.log(`Successfully compiled API.md (${content.length} bytes, ${totalFns} documented symbols)`)
    } finally {
        // Cleanup doc_build directory
        if (fs.existsSync(docBuildDir)) {
            fs.rmSync(docBuildDir, { recursive: true, force: true })
        }
    }
}

main().catch(err => {
    console.error('Doc compilation error:', err)
    process.exit(1)
})
