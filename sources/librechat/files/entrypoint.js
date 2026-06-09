#!/usr/bin/env node
// cspell:ignore convo Convo convos Convos meili Meili MEILI
'use strict'

const fs = require('fs')
const path = require('path')
const { execFileSync, spawn } = require('child_process')
const yaml = require('js-yaml')

require('module-alias')({ base: path.resolve(__dirname, 'api') })
require('dotenv').config({ path: path.resolve(__dirname, '.env') })
require('./config/helpers')

const connect = require('./config/connect')
const { batchResetMeiliFlags } = require('~/db/utils')
const mongoose = require('mongoose')

const THRESHOLD_PCT = parseFloat(process.env.MEILI_SYNC_THRESHOLD_PCT ?? '10')
const MEILI_HOST = process.env.MEILI_HOST
const MEILI_MASTER_KEY = process.env.MEILI_MASTER_KEY
const REMOTE_CONFIG_URL = process.env.REMOTE_CONFIG_URL
const CONFIG_PATH = process.env.CONFIG_PATH ?? path.resolve(__dirname, 'librechat.yaml')
const LOCAL_ENDPOINTS_PATH = path.resolve(__dirname, 'librechat.local.yaml')
const COPILOT_KEY = process.env.COPILOT_KEY
const COPILOT_MODELS_URL = 'https://niner.o6a.ru/v1/models'
const POLL_INTERVAL_MS = 2000

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

// Deep merge two plain objects. Arrays named "custom" are concatenated
// (local prepended to remote); all other arrays are replaced by local.
// Scalar values from local override remote.
function deepMerge(remote, local) {
  if (
    typeof remote !== 'object' || remote === null ||
    typeof local !== 'object' || local === null
  ) {
    return local
  }
  const result = { ...remote }
  for (const key of Object.keys(local)) {
    if (key === 'custom' && Array.isArray(local[key])) {
      result[key] = [...(local[key] ?? []), ...(remote[key] ?? [])]
    } else if (
      typeof local[key] === 'object' &&
      local[key] !== null &&
      !Array.isArray(local[key]) &&
      typeof remote[key] === 'object' &&
      remote[key] !== null &&
      !Array.isArray(remote[key])
    ) {
      result[key] = deepMerge(remote[key], local[key])
    } else {
      result[key] = local[key]
    }
  }
  return result
}

// Merge remote config with local config from librechat.local.yaml.
// Remote config is the base; local values override/extend it.
// endpoints.custom arrays are prepended (local before remote).
async function buildConfig() {
  if (!REMOTE_CONFIG_URL) {
    console.yellow('REMOTE_CONFIG_URL not set, using local config as-is')
    return
  }

  if (!fs.existsSync(LOCAL_ENDPOINTS_PATH)) {
    console.yellow(
      `${path.basename(LOCAL_ENDPOINTS_PATH)} not found, using remote config as-is`,
    )
  }

  console.cyan(`Fetching remote config from ${REMOTE_CONFIG_URL}...`)

  let remoteText
  try {
    const res = await fetch(REMOTE_CONFIG_URL)
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`)
    }
    remoteText = await res.text()
  } catch (err) {
    console.red(`Failed to fetch remote config: ${err.message}`)
    console.orange('Falling back to existing local config')
    return
  }

  const remoteConfig = yaml.load(remoteText)

  const [localConfig, copilotModels] = await Promise.all([
    fs.existsSync(LOCAL_ENDPOINTS_PATH)
      ? Promise.resolve(yaml.load(fs.readFileSync(LOCAL_ENDPOINTS_PATH, 'utf8')))
      : Promise.resolve(null),
    fetchCopilotModels(),
  ])

  remoteConfig.endpoints = remoteConfig.endpoints ?? {}
  remoteConfig.endpoints.custom = remoteConfig.endpoints.custom ?? []

  if (copilotModels) {
    const copilotEndpoint = {
      name: 'Niner',
      apiKey: 'user_provided',
      baseURL: 'https://niner.o6a.ru/v1',
      models: {
        default: copilotModels,
        fetch: false,
      },
      titleConvo: true,
      titleModel: copilotModels[0],
      summarize: false,
      summaryModel: copilotModels[0],
      modelDisplayLabel: 'Niner',
    }
    remoteConfig.endpoints.custom.unshift(copilotEndpoint)
    console.green('GitHub Copilot endpoint added')
  }

  let mergedConfig = remoteConfig
  if (localConfig) {
    mergedConfig = deepMerge(remoteConfig, localConfig)
    const localKeys = Object.keys(localConfig)
    console.green(`Merged local config keys: ${localKeys.join(', ')}`)
  }

  fs.writeFileSync(CONFIG_PATH, yaml.dump(mergedConfig, { lineWidth: -1 }))
  console.green(`Config written to ${CONFIG_PATH}`)
}

async function fetchCopilotModels() {
  if (!COPILOT_KEY) {
    console.yellow('COPILOT_KEY not set, skipping Copilot models fetch')
    return null
  }

  console.cyan(`Fetching Copilot models from ${COPILOT_MODELS_URL}...`)

  try {
    const res = await fetch(COPILOT_MODELS_URL, {
      headers: { Authorization: `Bearer ${COPILOT_KEY}` },
    })

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`)
    }

    const data = await res.json()
    const models = (data.data ?? data.models ?? data)
      .map((m) => m.id ?? m.name)
      .filter(Boolean)

    if (models.length === 0) {
      throw new Error('empty model list in response')
    }

    console.green(`Got ${models.length} Copilot model(s)`)
    return models
  } catch (err) {
    console.red(`Failed to fetch Copilot models: ${err.message}`)
    return null
  }
}

async function waitForMeiliSearch() {
  console.cyan('Waiting for MeiliSearch...')

  const url = `${MEILI_HOST}/health`
  const headers = MEILI_MASTER_KEY
    ? { Authorization: `Bearer ${MEILI_MASTER_KEY}` }
    : {}

  for (;;) {
    try {
      const res = await fetch(url, { headers })
      if (res.ok) {
        break
      }
    } catch (_) {
      // not ready yet
    }
    await sleep(POLL_INTERVAL_MS)
  }

  console.green('MeiliSearch is up')
}

async function getMeiliCount(indexName) {
  const url = `${MEILI_HOST}/indexes/${indexName}/stats`
  const headers = MEILI_MASTER_KEY
    ? { Authorization: `Bearer ${MEILI_MASTER_KEY}` }
    : {}

  const res = await fetch(url, { headers })
  if (!res.ok) {
    console.yellow(`MeiliSearch index "${indexName}" returned HTTP ${res.status}`)
    return 0
  }

  const data = await res.json()
  return data.numberOfDocuments ?? 0
}

async function getMongoCount(collectionName) {
  return mongoose.connection.db
    .collection(collectionName)
    .countDocuments({ expiredAt: null })
}

function isStaleDivergence(mongoCount, meiliCount) {
  if (mongoCount === 0 && meiliCount === 0) {
    return false
  }
  if (mongoCount > 0 && meiliCount === 0) {
    return true
  }
  const diffPct = (Math.abs(mongoCount - meiliCount) / mongoCount) * 100
  return diffPct > THRESHOLD_PCT
}

async function checkAndResetSync() {
  const [
    mongoMessages,
    mongoConvos,
    meiliMessages,
    meiliConvos,
  ] = await Promise.all([
    getMongoCount('messages'),
    getMongoCount('conversations'),
    getMeiliCount('messages'),
    getMeiliCount('convos'),
  ])

  console.cyan(
    `MongoDB      — messages: ${mongoMessages}, conversations: ${mongoConvos}`,
  )
  console.cyan(
    `MeiliSearch  — messages: ${meiliMessages}, convos: ${meiliConvos}`,
  )

  const stale =
    isStaleDivergence(mongoMessages, meiliMessages) ||
    isStaleDivergence(mongoConvos, meiliConvos)

  if (!stale) {
    console.green('Indexes are in sync, skipping reset')
    return
  }

  const msgDiff = mongoMessages - meiliMessages
  const convoDiff = mongoConvos - meiliConvos
  console.orange(
    `Indexes are stale — messages diff: ${msgDiff}, convos diff: ${convoDiff}` +
    ` (threshold: ${THRESHOLD_PCT}%)`,
  )

  console.cyan('Resetting message sync flags...')
  const msgCount = await batchResetMeiliFlags(
    mongoose.connection.db.collection('messages'),
  )
  process.stdout.write('\n')
  console.green(`Reset ${msgCount} message sync flags`)

  console.cyan('Resetting conversation sync flags...')
  const convoCount = await batchResetMeiliFlags(
    mongoose.connection.db.collection('conversations'),
  )
  process.stdout.write('\n')
  console.green(`Reset ${convoCount} conversation sync flags`)
}

function startBackend() {
  console.cyan('Starting backend...')

  let npm
  try {
    npm = execFileSync('which', ['npm'], { encoding: 'utf8' }).trim()
  } catch (_) {
    npm = 'npm'
  }

  const child = spawn(npm, ['run', 'backend'], {
    stdio: 'inherit',
    env: process.env,
    cwd: __dirname,
  })

  const signals = [
    'SIGTERM', 'SIGINT', 'SIGHUP', 'SIGQUIT', 'SIGUSR1', 'SIGUSR2',
    'SIGPIPE', 'SIGALRM', 'SIGCONT', 'SIGWINCH',
  ]
  for (const sig of signals) {
    process.on(sig, () => child.kill(sig))
  }

  child.on('exit', (code, signal) => {
    process.exitCode = code ?? 1
    if (signal) {
      process.kill(process.pid, signal)
    }
  })
}

(async () => {
  await buildConfig()

  if (!MEILI_HOST) {
    console.red('MEILI_HOST is not set, skipping MeiliSearch checks')
    startBackend()
    return
  }

  await waitForMeiliSearch()
  await connect()

  try {
    await checkAndResetSync()
  } catch (err) {
    console.red('Sync check failed, skipping reset:')
    console.error(err)
  }

  await mongoose.disconnect()

  startBackend()
})()
