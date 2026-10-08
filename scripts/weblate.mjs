/**
 * Weblate API Integration for Modular Player Armor & Shield Defense (x_player_armor)
 * Copyright (C) 2026 SaKeL
 *
 * Interacts with Weblate REST API to query translation status
 * and trigger remote repository pull/push synchronizations.
 */

import fetch from 'node-fetch'
import dotenv from 'dotenv'
import yargs from 'yargs/yargs'
import { hideBin } from 'yargs/helpers'

const argv = yargs(hideBin(process.argv))
	.command('$0 [action]', 'Interact with Weblate API', (y) => {
		y.positional('action', {
			describe: 'Action to perform: status, refresh/pull, push/commit',
			type: 'string',
			default: 'status'
		})
	})
	.option('env', {
		alias: 'e',
		type: 'string',
		description: 'Path to custom .env file'
	})
	.option('url', {
		alias: 'u',
		type: 'string',
		description: 'Weblate instance base URL (env: WEBLATE_URL or WEBLATE_X_PLAYER_ARMOR_URL)'
	})
	.option('token', {
		alias: 't',
		type: 'string',
		description: 'Weblate API token (env: WEBLATE_TOKEN or WEBLATE_X_PLAYER_ARMOR_TOKEN)'
	})
	.option('project', {
		alias: 'p',
		type: 'string',
		description: 'Weblate project slug (env: WEBLATE_PROJECT or WEBLATE_X_PLAYER_ARMOR_PROJECT)'
	})
	.option('component', {
		alias: 'c',
		type: 'string',
		description: 'Weblate component slug (env: WEBLATE_COMPONENT or WEBLATE_X_PLAYER_ARMOR_COMPONENT)'
	})
	.help()
	.argv

// Load custom .env file if provided, otherwise default to .env in current or parent directory
if (argv.env) {
	dotenv.config({ path: argv.env })
} else {
	dotenv.config()
}

// Configurable via custom .env variables, generic .env variables, or CLI arguments
const WEBLATE_URL = argv.url || process.env.WEBLATE_X_PLAYER_ARMOR_URL || process.env.WEBLATE_URL || 'https://hosted.weblate.org'
const WEBLATE_TOKEN = argv.token || process.env.WEBLATE_X_PLAYER_ARMOR_TOKEN || process.env.WEBLATE_TOKEN
const WEBLATE_PROJECT = argv.project || process.env.WEBLATE_X_PLAYER_ARMOR_PROJECT || process.env.WEBLATE_PROJECT || 'x_player_armor'
const WEBLATE_COMPONENT = argv.component || process.env.WEBLATE_X_PLAYER_ARMOR_COMPONENT || process.env.WEBLATE_COMPONENT || 'x_player_armor'

const action = argv.action || argv._[0] || 'status'

async function callWeblate(endpoint, options = {}) {
	const headers = {
		'Accept': 'application/json',
		...options.headers
	}
	if (WEBLATE_TOKEN) {
		headers['Authorization'] = `Token ${WEBLATE_TOKEN}`
	}
	const url = `${WEBLATE_URL.replace(/\/+$/, '')}/api/${endpoint.replace(/^\/+/, '')}`
	return fetch(url, { ...options, headers })
}

async function getStatus() {
	console.log(`Checking Weblate status for ${WEBLATE_PROJECT}/${WEBLATE_COMPONENT} at ${WEBLATE_URL}...`)
	try {
		const res = await callWeblate(`components/${WEBLATE_PROJECT}/${WEBLATE_COMPONENT}/statistics/`)
		if (!res.ok) {
			console.error(`Weblate API error (${res.status}): ${await res.text()}`)
			return
		}
		const data = await res.json()
		const stats = data.results || data
		console.log('\n--- Weblate Translation Status ---')
		for (const item of (Array.isArray(stats) ? stats : [stats])) {
			const lang = item.code || item.language?.code || 'unknown'
			const total = item.total || 0
			const translated = item.translated || 0
			const percent = item.translated_percent !== undefined ? item.translated_percent : (total > 0 ? ((translated / total) * 100).toFixed(1) : 0)
			console.log(`[${lang}] ${translated}/${total} strings translated (${percent}%)`)
		}
	} catch (err) {
		console.error('Failed to connect to Weblate:', err.message)
	}
}

async function repoOperation(operation) {
	if (!WEBLATE_TOKEN) {
		console.error('Error: WEBLATE_TOKEN environment variable (or --token) is required to trigger repository operations.')
		process.exit(1)
	}
	console.log(`Triggering Weblate repository '${operation}' for ${WEBLATE_PROJECT}/${WEBLATE_COMPONENT}...`)
	try {
		const res = await callWeblate(`components/${WEBLATE_PROJECT}/${WEBLATE_COMPONENT}/repository/`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ operation })
		})
		const text = await res.text()
		if (!res.ok) {
			console.error(`Weblate operation failed (${res.status}): ${text}`)
			process.exit(1)
		}
		console.log(`Successfully triggered ${operation}:`, text)
	} catch (err) {
		console.error(`Error triggering ${operation}:`, err.message)
		process.exit(1)
	}
}

switch (action) {
	case 'status':
		await getStatus()
		break
	case 'refresh':
	case 'pull':
		await repoOperation('pull')
		break
	case 'push':
	case 'commit':
		await repoOperation('push')
		break
	default:
		console.log(`Unknown action '${action}'. Usage: node scripts/weblate.mjs [status|refresh|push]`)
		break
}
