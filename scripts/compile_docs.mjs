#!/usr/bin/env node
/**
 * scripts/compile_docs.mjs
 *
 * Compiles comprehensive API.md documentation for x_player_armor
 * using emmylua_doc_cli and EmmyLua / LuaLS annotations.
 * Strictly documents only public-facing APIs following SOLID architecture.
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
    console.log('Compiling x_player_armor public API documentation using emmylua_doc_cli...')

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

        // Extract primary API module
        const apiModule = modules.find(m => m.name === 'api') || {}
        const apiMembers = apiModule.members || []

        // Index functions on x_player_armor by name (taking most complete definition)
        const fnsByName = new Map()
        for (const m of apiMembers) {
            if (m.type === 'fn') {
                const existing = fnsByName.get(m.name)
                if (!existing || (!existing.description && m.description) || ((existing.params || []).length < (m.params || []).length)) {
                    fnsByName.set(m.name, m)
                }
            }
        }

        const lines = []
        function emit(str = '') {
            lines.push(str)
        }

        // Document Header
        emit('# x_player_armor API Reference')
        emit()
        emit('High-performance modular player armor, shield defense, durability, and damage mitigation system for Luanti.')
        emit()
        emit('- **Author**: SaKeL')
        emit('- **License**: LGPL-2.1-or-later (code), CC-BY-4.0 / CC0-1.0 (assets)')
        emit('- **Target Engine**: Luanti 5.10.0+')
        emit()

        // Table of Contents
        emit('## Table of Contents')
        emit()
        emit('- [Core Data Structures & Types](#core-data-structures--types)')
        emit('  - [XPlayerArmorItemDef](#xplayerarmoritemdef)')
        emit('  - [XPlayerArmorTransforms](#xplayerarmortransforms)')
        emit('  - [XPlayerArmorFormatTransforms](#xplayerarmorformattransforms)')
        emit('  - [XPlayerArmorTransform](#xplayerarmortransform)')
        emit('  - [XPlayerArmorBoneOffset](#xplayerarmorboneoffset)')
        emit('  - [XPlayerArmorShieldOffset](#xplayerarmorshieldoffset)')
        emit('  - [XPlayerArmorShieldVisualOpts](#xplayerarmorshieldvisualopts)')
        emit('  - [XPlayerArmorProjectileData](#xplayerarmorprojectiledata)')
        emit('  - [XPlayerArmorWearColor](#xplayerarmorwearcolor)')
        emit('  - [XPlayerArmorParticleOpts](#xplayerarmorparticleopts)')
        emit('  - [XPlayerArmorConstants](#xplayerarmorconstants)')
        emit('  - [XPlayerArmorShieldTierProps](#xplayerarmorshieldtierprops)')
        emit('  - [XPlayerArmorElementDef](#xplayerarmorelementdef)')
        emit('  - [XPlayerArmorMaterialDef](#xplayerarmormaterialdef)')
        emit('  - [XPlayerArmorPlayerDef](#xplayerarmorplayerdef)')
        emit('  - [XPlayerArmorPunchCallback](#xplayerarmorpunchcallback)')
        emit('  - [XPlayerArmorSounds](#xplayerarmorsounds)')
        emit('  - [SkinResolution](#skinresolution)')
        emit('- [Public API Reference](#public-api-reference)')
        emit('  - [Registration & Definitions](#registration--definitions)')
        emit('  - [Lifecycle & Event Callbacks](#lifecycle--event-callbacks)')
        emit('  - [Equipment & Inventory State](#equipment--inventory-state)')
        emit('  - [Combat, Defense & Shield Mechanics](#combat-defense--shield-mechanics)')
        emit('  - [Visuals & 3D Attachments](#visuals--3d-attachments)')
        emit('  - [User Interface & Formspecs](#user-interface--formspecs)')
        emit('  - [HUD Overlays](#hud-overlays)')
        emit('  - [Mod Integration & Utilities](#mod-integration--utilities)')
        emit('- [Backward Compatibility Layer](#backward-compatibility-layer)')
        emit('  - [3d_armor Compatibility](#3d_armor-compatibility)')
        emit('  - [shields Compatibility](#shields-compatibility)')
        emit('  - [3d_armor_stand Compatibility](#3d_armor_stand-compatibility)')
        emit()
        emit('---')
        emit()

        // Core Data Structures & Types
        emit('## Core Data Structures & Types')
        emit()
        emit('Fundamental tables, callback signatures, and configuration structures utilized by `x_player_armor`.')
        emit()

        const primaryTypes = [
            'XPlayerArmorItemDef',
            'XPlayerArmorTransforms',
            'XPlayerArmorFormatTransforms',
            'XPlayerArmorTransform',
            'XPlayerArmorBoneOffset',
            'XPlayerArmorShieldOffset',
            'XPlayerArmorShieldVisualOpts',
            'XPlayerArmorProjectileData',
            'XPlayerArmorWearColor',
            'XPlayerArmorParticleOpts',
            'XPlayerArmorConstants',
            'XPlayerArmorShieldTierProps',
            'XPlayerArmorElementDef',
            'XPlayerArmorMaterialDef',
            'XPlayerArmorPlayerDef',
            'XPlayerArmorPunchCallback',
            'XPlayerArmorSounds',
            'SkinResolution'
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

            if (typ.type === 'alias' && typ.typ) {
                emit('```lua')
                emit(`type ${typ.name} = ${typ.typ}`)
                emit('```')
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

        emit('---')
        emit()

        // Public API Sections
        emit('## Public API Reference')
        emit()
        emit('All public functions are exposed under the canonical `x_player_armor.*` namespace.')
        emit('Internal implementation modules (e.g. `visuals`, `combat`, `inventory`, `compat`) are decoupled behind this unified facade following SOLID architecture.')
        emit()

        const apiSections = [
            {
                title: 'Registration & Definitions',
                desc: 'Methods for registering custom armor items, slot elements, materials, defense groups, and resolving technical item names.',
                fns: [
                    'register_armor',
                    'register_element',
                    'register_material',
                    'register_armor_group',
                    'get_armor_def',
                    'get_legacy_replacement'
                ]
            },
            {
                title: 'Lifecycle & Event Callbacks',
                desc: 'Global callback registration hooks invoked during armor equipment changes, combat strikes, item destruction, state updates, and shield blocks.',
                fns: [
                    'register_on_equip',
                    'register_on_unequip',
                    'register_on_damage',
                    'register_on_destroy',
                    'register_on_update',
                    'register_on_block',
                    'run_callbacks'
                ]
            },
            {
                title: 'Equipment & Inventory State',
                desc: 'Methods for equipping and unequipping items, querying worn armor elements, inspecting player state definitions, and checking environmental protection rules.',
                fns: [
                    'equip',
                    'unequip',
                    'remove_all',
                    'get_worn_elements',
                    'get_valid_player',
                    'get_player_def',
                    'get_elements',
                    'get_attributes',
                    'get_fire_nodes',
                    'is_reciprocate_damage_enabled'
                ]
            },
            {
                title: 'Combat, Defense & Shield Mechanics',
                desc: 'Methods for evaluating punch damage mitigation, shield blocking state, frontal defense cones, projectile deflection physics, and shield transforms.',
                fns: [
                    'damage',
                    'punch',
                    'can_block',
                    'is_blocking',
                    'is_facing_attack',
                    'try_deflect_projectile',
                    'get_equipped_shield',
                    'get_shield_contact_pos',
                    'get_shield_offset',
                    'set_shield_offset'
                ]
            },
            {
                title: 'Visuals & 3D Attachments',
                desc: 'Methods for managing 3D skeletal bone attachments, off-hand shield positioning, skin resolution, visual entity restoration, and third-party entity attachments.',
                fns: [
                    'set_player_armor',
                    'update_player_visuals',
                    'clear_player_visuals',
                    'restore_all_player_visuals',
                    'schedule_player_visual_restore',
                    'attach_armor_to_entity',
                    'attach_shield',
                    'attach_shield_to_entity',
                    'update_shield',
                    'remove_shield',
                    'set_shield_first_person',
                    'get_shield_first_person',
                    'cleanup_orphaned_visuals',
                    'resolve_player_skin',
                    'get_skin_info'
                ]
            },
            {
                title: 'User Interface & Formspecs',
                desc: 'Methods for displaying and refreshing player armor equipment dialogs across standard, sfinv, unified_inventory, and i3 interfaces.',
                fns: [
                    'show_armor_formspec',
                    'refresh_player_formspec',
                    'is_armor_ui_open',
                    'has_any_open_armor_ui',
                    'get_player_preview_texture'
                ]
            },
            {
                title: 'HUD Overlays',
                desc: 'Methods for triggering and controlling the combat durability HUD overlay and the 1st-person shield blocking reticle indicator.',
                fns: [
                    'show_shield_block_hud',
                    'hide_shield_block_hud',
                    'get_shield_block_hud',
                    'trigger_combat_hud',
                    'hide_combat_hud',
                    'get_combat_hud_id'
                ]
            },
            {
                title: 'Mod Integration & Utilities',
                desc: 'Integration helpers for optional mod environments.',
                fns: [
                    'get_mod_api'
                ]
            }
        ]

        for (const section of apiSections) {
            emit(`### ${section.title}`)
            emit()
            if (section.desc) {
                emit(section.desc)
                emit()
            }

            for (const fnName of section.fns) {
                const fn = fnsByName.get(fnName)
                if (!fn) continue

                const paramSig = formatParamSignature(fn.params)
                const typedParams = formatTypedParams(fn.params)
                const retSig = formatReturnSignature(fn.returns)

                emit(`#### \`x_player_armor.${fn.name}(${paramSig})\``)
                emit()
                if (fn.description) {
                    emit(fn.description)
                    emit()
                }

                emit('```lua')
                emit(`x_player_armor.${fn.name}(${typedParams}) -> ${retSig}`)
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

        // Backward Compatibility Layer
        emit('## Backward Compatibility Layer')
        emit()
        emit('`x_player_armor` provides full, transparent, drop-in backward compatibility for legacy mods designed around `3d_armor`, `shields`, and `3d_armor_stand`. External mods requiring these APIs continue to function seamlessly without modification.')
        emit()
        emit('### 3d_armor Compatibility')
        emit('- **Global Table**: The global `armor` table is virtualized and registered with standard methods (`armor:register_armor`, `armor:equip`, `armor:damage`, `armor:punch`, `armor:update_player_visuals`, `armor:get_valid_player`, etc.).')
        emit('- **Legacy Item Mapping**: Legacy items prefixed with `3d_armor:*` are automatically redirected, aliased, and migrated to modern `x_player_armor:*` equivalents.')
        emit('- **Inventory Format**: Detached inventories and metadata structures are automatically migrated to modern `x_player_armor` format.')
        emit()
        emit('### shields Compatibility')
        emit('- **Global Table**: The global `shields` table is provided with complete support for shield registration (`shields:register_shield`), punch mitigation, and blocking logic.')
        emit('- **Legacy Item Mapping**: Legacy shields prefixed with `shields:shield_*` and `shields:shield_enhanced_*` are mapped to modern tiered shield equivalents.')
        emit()
        emit('### 3d_armor_stand Compatibility')
        emit('- **Registered Nodes & Entities**: Compatible node definitions and entity handlers for `3d_armor_stand:armor_stand` and locked variants are maintained.')
        emit('- **Wardrobe Swap**: Shift+click and formspec interaction remain fully functional with legacy and modern armor pieces.')
        emit()
        emit('> [!NOTE]')
        emit('> New mods developed for Luanti should directly target the canonical `x_player_armor.*` API namespace documented above for optimal performance, strict typing, and full feature access.')
        emit()

        // Write output API.md
        const outputPath = path.join(rootDir, 'API.md')
        const content = lines.join('\n')
        fs.writeFileSync(outputPath, content, 'utf8')

        const totalFns = lines.filter(l => l.startsWith('#### `')).length
        console.log(`Successfully compiled API.md (${content.length} bytes, ${totalFns} documented public methods)`)
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
