// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>
//
// Validate security-review package provenance and retained local evidence.
// This checks internal consistency and bytes, not the truth of attestations.
//
// Derived from component://helium-te-poc/tests/lint-review-manifest.mjs at
// commit 9b3ff4e9441e5b4434a8ec37794dee1d941e11ef (helium-te-travel-fedora44).

import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptPath = fileURLToPath(import.meta.url)
const root = path.resolve(path.dirname(scriptPath), '..')
const schemaPath = path.join(root, 'contracts', 'review-manifest.schema.json')
const schema = readJson(schemaPath)
const safeIdPattern = /^[a-z0-9][a-z0-9._-]{0,127}$/
const packageIdPattern = /^SR-[0-9]{8}-[0-9]{3}-[a-z0-9][a-z0-9-]{0,40}$/
const approvalIdPattern = /^APPROVAL-[0-9]{3}$/
const componentLocatorPrefix = 'component://'
const commitPattern = /^(?!0{40}$)[0-9a-f]{40}$/
const sha256Pattern = /^(?!0{64}$)[0-9a-f]{64}$/
const signalPattern = /^SIG[A-Z0-9]+$/
const pathSegmentPattern = /^[A-Za-z0-9][A-Za-z0-9._-]*$/
const schemaPatternCache = new Map()
const supportedSchemaKeywords = new Set([
  '$defs',
  '$id',
  '$ref',
  '$schema',
  'additionalProperties',
  'allOf',
  'const',
  'description',
  'else',
  'enum',
  'if',
  'items',
  'maximum',
  'maxItems',
  'maxLength',
  'minimum',
  'minItems',
  'minLength',
  'oneOf',
  'pattern',
  'properties',
  'required',
  'then',
  'title',
  'type',
  'uniqueItems',
])
assertSupportedSchemaKeywords(schema)

/**
 * lintReviewManifest - validate one security-review package manifest.
 * @manifestPath: Path to the package's review-manifest.json.
 *
 * Return: The mechanically derived review classification.
 */
export function lintReviewManifest(manifestPath) {
  const absoluteManifest = path.resolve(manifestPath)

  if (path.basename(absoluteManifest) !== 'review-manifest.json') {
    throw new Error(`${manifestPath}: manifest filename must be review-manifest.json`)
  }
  const manifestStat = lstat(absoluteManifest, 'manifest')
  if (!manifestStat.isFile() || manifestStat.isSymbolicLink()) {
    throw new Error(`${manifestPath}: manifest must be a regular, non-symbolic-link file`)
  }

  const manifest = readJson(absoluteManifest)
  try {
    return validateManifest(manifest, absoluteManifest)
  } catch (error) {
    throw new Error(`${manifestPath}: ${error.message}`)
  }
}

function validateManifest(manifest, manifestPath) {
  assertMatchesSchema(manifest)

  validatePackage(manifest.package, path.dirname(manifestPath))
  validateSource(manifest.source)
  const classification = validateExecution(
    manifest.execution,
    path.dirname(manifestPath),
  )
  validateQualifications(manifest.qualifications)
  return classification
}

function assertMatchesSchema(value) {
  const error = findSchemaError(value, schema, '')

  if (error !== null) {
    throw new Error(`schema validation failed: ${error}`)
  }
}

/*
 * The checked-in contract uses a deliberately small JSON Schema subset.
 * Refuse unknown validation keywords so schema growth cannot silently weaken
 * the dependency-free linter.
 */
function assertSupportedSchemaKeywords(rule, location = '#') {
  if (typeof rule === 'boolean') {
    return
  }
  if (rule === null || typeof rule !== 'object' || Array.isArray(rule)) {
    throw new Error(`${schemaPath}: ${location} must be a schema object`)
  }

  for (const keyword of Object.keys(rule)) {
    if (!supportedSchemaKeywords.has(keyword) && !keyword.startsWith('x-')) {
      throw new Error(
        `${schemaPath}: ${location} uses unsupported keyword ${keyword}`,
      )
    }
  }

  for (const keyword of ['$defs', 'properties']) {
    for (const [name, child] of Object.entries(rule[keyword] ?? {})) {
      assertSupportedSchemaKeywords(
        child,
        `${location}/${keyword}/${escapeJsonPointer(name)}`,
      )
    }
  }
  for (const keyword of ['items', 'if', 'then', 'else']) {
    if (rule[keyword] !== undefined) {
      assertSupportedSchemaKeywords(rule[keyword], `${location}/${keyword}`)
    }
  }
  for (const keyword of ['allOf', 'oneOf']) {
    for (const [index, child] of (rule[keyword] ?? []).entries()) {
      assertSupportedSchemaKeywords(child, `${location}/${keyword}/${index}`)
    }
  }
}

function findSchemaError(value, rule, location, depth = 0) {
  if (depth > 64) {
    throw new Error(`${schemaPath}: schema evaluation exceeded depth limit`)
  }
  if (rule === true) {
    return null
  }
  if (rule === false) {
    return `${displayJsonPointer(location)} is forbidden`
  }

  if (rule.$ref !== undefined) {
    return findSchemaError(
      value,
      resolveSchemaReference(rule.$ref),
      location,
      depth + 1,
    )
  }

  if (rule.oneOf !== undefined) {
    const alternatives = rule.oneOf.map((alternative) =>
      findSchemaError(value, alternative, location, depth + 1),
    )
    if (alternatives.filter((error) => error === null).length !== 1) {
      return `${displayJsonPointer(location)} must match exactly one schema alternative`
    }
  }

  if (rule.type !== undefined && !matchesSchemaType(value, rule.type)) {
    return `${displayJsonPointer(location)} must be ${schemaTypeName(rule.type)}`
  }
  if (
    rule.const !== undefined &&
    canonicalJson(value) !== canonicalJson(rule.const)
  ) {
    return `${displayJsonPointer(location)} must equal ${JSON.stringify(rule.const)}`
  }
  if (
    rule.enum !== undefined &&
    !rule.enum.some((candidate) =>
      canonicalJson(candidate) === canonicalJson(value)
    )
  ) {
    return `${displayJsonPointer(location)} must be one of ${JSON.stringify(rule.enum)}`
  }

  if (isJsonObject(value)) {
    for (const property of rule.required ?? []) {
      if (!Object.hasOwn(value, property)) {
        return `${displayJsonPointer(location)} is missing required property ${JSON.stringify(property)}`
      }
    }

    for (const [property, propertyRule] of Object.entries(
      rule.properties ?? {},
    )) {
      if (!Object.hasOwn(value, property)) {
        continue
      }
      const error = findSchemaError(
        value[property],
        propertyRule,
        appendJsonPointer(location, property),
        depth + 1,
      )
      if (error !== null) {
        return error
      }
    }

    if (rule.additionalProperties === false) {
      const declaredProperties = new Set(Object.keys(rule.properties ?? {}))
      const additionalProperty = Object.keys(value).find(
        (property) => !declaredProperties.has(property),
      )
      if (additionalProperty !== undefined) {
        return `${appendJsonPointer(location, additionalProperty)} is not an allowed property`
      }
    }
  }

  if (typeof value === 'string') {
    const length = [...value].length

    if (rule.minLength !== undefined && length < rule.minLength) {
      return `${displayJsonPointer(location)} must contain at least ${rule.minLength} Unicode characters`
    }
    if (rule.maxLength !== undefined && length > rule.maxLength) {
      return `${displayJsonPointer(location)} must contain at most ${rule.maxLength} Unicode characters`
    }
    if (
      rule.pattern !== undefined &&
      !compileSchemaPattern(rule.pattern).test(value)
    ) {
      return `${displayJsonPointer(location)} must match pattern ${JSON.stringify(rule.pattern)}`
    }
  }

  if (typeof value === 'number') {
    if (rule.minimum !== undefined && value < rule.minimum) {
      return `${displayJsonPointer(location)} must be at least ${rule.minimum}`
    }
    if (rule.maximum !== undefined && value > rule.maximum) {
      return `${displayJsonPointer(location)} must be at most ${rule.maximum}`
    }
  }

  if (Array.isArray(value)) {
    if (rule.minItems !== undefined && value.length < rule.minItems) {
      return `${displayJsonPointer(location)} must contain at least ${rule.minItems} items`
    }
    if (rule.maxItems !== undefined && value.length > rule.maxItems) {
      return `${displayJsonPointer(location)} must contain at most ${rule.maxItems} items`
    }
    if (rule.items !== undefined) {
      for (const [index, item] of value.entries()) {
        const error = findSchemaError(
          item,
          rule.items,
          appendJsonPointer(location, index),
          depth + 1,
        )
        if (error !== null) {
          return error
        }
      }
    }
    if (rule.uniqueItems === true) {
      const canonicalItems = value.map(canonicalJson)
      if (new Set(canonicalItems).size !== canonicalItems.length) {
        return `${displayJsonPointer(location)} must contain unique items`
      }
    }
  }

  for (const child of rule.allOf ?? []) {
    const error = findSchemaError(value, child, location, depth + 1)
    if (error !== null) {
      return error
    }
  }

  if (rule.if !== undefined) {
    const conditionMatches =
      findSchemaError(value, rule.if, location, depth + 1) === null
    const conditionalRule = conditionMatches ? rule.then : rule.else

    if (conditionalRule !== undefined) {
      const error = findSchemaError(
        value,
        conditionalRule,
        location,
        depth + 1,
      )
      if (error !== null) {
        return error
      }
    }
  }

  return null
}

function resolveSchemaReference(reference) {
  if (typeof reference !== 'string' || !reference.startsWith('#/')) {
    throw new Error(`${schemaPath}: unsupported schema reference ${reference}`)
  }

  let value = schema
  for (const encodedComponent of reference.slice(2).split('/')) {
    const component = encodedComponent
      .replaceAll('~1', '/')
      .replaceAll('~0', '~')
    if (!isJsonObject(value) || !Object.hasOwn(value, component)) {
      throw new Error(`${schemaPath}: unresolved schema reference ${reference}`)
    }
    value = value[component]
  }
  return value
}

function matchesSchemaType(value, type) {
  switch (type) {
    case 'array':
      return Array.isArray(value)
    case 'boolean':
      return typeof value === 'boolean'
    case 'integer':
      return Number.isInteger(value)
    case 'null':
      return value === null
    case 'number':
      return typeof value === 'number'
    case 'object':
      return isJsonObject(value)
    case 'string':
      return typeof value === 'string'
    default:
      throw new Error(`${schemaPath}: unsupported schema type ${type}`)
  }
}

function schemaTypeName(type) {
  if (type === 'null') {
    return 'null'
  }
  if (type === 'integer') {
    return 'an integer'
  }
  if (type === 'object') {
    return 'an object'
  }
  if (type === 'array') {
    return 'an array'
  }
  return `a ${type}`
}

function compileSchemaPattern(pattern) {
  if (!schemaPatternCache.has(pattern)) {
    schemaPatternCache.set(pattern, new RegExp(pattern, 'u'))
  }
  return schemaPatternCache.get(pattern)
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(',')}]`
  }
  if (isJsonObject(value)) {
    return `{${Object.keys(value)
      .sort()
      .map(
        (key) =>
          `${JSON.stringify(key)}:${canonicalJson(value[key])}`,
      )
      .join(',')}}`
  }
  return JSON.stringify(value)
}

function isJsonObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function appendJsonPointer(location, component) {
  return `${location}/${escapeJsonPointer(String(component))}`
}

function escapeJsonPointer(value) {
  return value.replaceAll('~', '~0').replaceAll('/', '~1')
}

function displayJsonPointer(location) {
  return location === '' ? '/' : location
}

function validatePackage(value, packageDirectory) {
  requireExactKeys(value, ['id', 'model_id', 'run_id'], '/package')
  requirePackageId(value.id, '/package/id')
  requireDeclaredId(value.model_id, '/package/model_id')
  requireDeclaredId(value.run_id, '/package/run_id')

  const directoryName = path.basename(packageDirectory)
  if (value.id !== directoryName) {
    throw new Error(
      `/package/id must match package directory ${JSON.stringify(directoryName)}`,
    )
  }
}

function validateSource(value) {
  requireExactKeys(
    value,
    [
      'component',
      'locator',
      'commit',
      'branch',
      'detached',
      'dirty',
      'dirty_detail',
    ],
    '/source',
  )
  requireSafeId(value.component, '/source/component')
  requireText(value.locator, '/source/locator')
  const expectedLocator = `${componentLocatorPrefix}${value.component}`
  if (value.locator !== expectedLocator) {
    throw new Error(`/source/locator must equal ${expectedLocator}`)
  }
  if (typeof value.commit !== 'string' || !commitPattern.test(value.commit)) {
    throw new Error('/source/commit must be a nonzero lowercase 40-hex commit')
  }
  requireBoolean(value.detached, '/source/detached')
  if (value.detached) {
    if (value.branch !== null) {
      throw new Error('/source/branch must be null when HEAD is detached')
    }
  } else {
    validateBranch(value.branch)
  }

  requireBoolean(value.dirty, '/source/dirty')
  if (value.dirty) {
    requireText(value.dirty_detail, '/source/dirty_detail')
  } else if (value.dirty_detail !== null) {
    throw new Error('/source/dirty_detail must be null for a clean checkout')
  }
}

function validateBranch(value) {
  requireText(value, '/source/branch')
  if (!value.startsWith('refs/heads/')) {
    throw new Error('/source/branch must be a full refs/heads/... ref')
  }
  const branch = value.slice('refs/heads/'.length)
  const invalidCharacter = [...branch].some((character) => {
    const code = character.charCodeAt(0)
    return (
      code <= 0x20 ||
      code === 0x7f ||
      '~^:?*[\\'.includes(character)
    )
  })
  const invalidComponent = branch
    .split('/')
    .some(
      (component) =>
        component.length === 0 ||
        component.startsWith('.') ||
        component.endsWith('.') ||
        component.endsWith('.lock'),
    )

  if (
    branch === '@' ||
    branch.includes('..') ||
    branch.includes('@{') ||
    invalidCharacter ||
    invalidComponent
  ) {
    throw new Error('/source/branch is not a valid full branch ref')
  }
}

function validateExecution(value, packageDirectory) {
  requireExactKeys(
    value,
    [
      'classification',
      'static_only_reason',
      'commands_attempted',
      'tool_versions',
      'retained_evidence',
    ],
    '/execution',
  )
  requireArray(value.commands_attempted, '/execution/commands_attempted')
  requireArray(value.tool_versions, '/execution/tool_versions')
  requireArray(value.retained_evidence, '/execution/retained_evidence')

  const derivedClassification =
    value.commands_attempted.length === 0
      ? 'static-only'
      : 'execution-backed'
  if (value.classification !== derivedClassification) {
    throw new Error(
      `/execution/classification must be ${derivedClassification} for the recorded commands`,
    )
  }

  if (derivedClassification === 'static-only') {
    requireText(value.static_only_reason, '/execution/static_only_reason')
    if (
      value.tool_versions.length !== 0 ||
      value.retained_evidence.length !== 0
    ) {
      throw new Error(
        '/execution static-only packages must have empty tool and evidence arrays',
      )
    }
    return derivedClassification
  }

  if (value.static_only_reason !== null) {
    throw new Error(
      '/execution/static_only_reason must be null for execution-backed packages',
    )
  }
  if (
    value.tool_versions.length === 0 ||
    value.retained_evidence.length === 0
  ) {
    throw new Error(
      '/execution execution-backed packages require tools and retained evidence',
    )
  }

  const tools = validateTools(value.tool_versions)
  const commands = validateCommands(value.commands_attempted, tools)
  validateEvidence(value.retained_evidence, commands, packageDirectory)

  for (const toolId of tools) {
    if (![...commands.values()].some((command) => command.tool_id === toolId)) {
      throw new Error(`/execution/tool_versions has unused tool ${toolId}`)
    }
  }
  return derivedClassification
}

function validateTools(values) {
  const tools = new Set()
  for (const [index, value] of values.entries()) {
    const location = `/execution/tool_versions/${index}`
    requireExactKeys(value, ['id', 'version'], location)
    requireSafeId(value.id, `${location}/id`)
    requireText(value.version, `${location}/version`)
    if (tools.has(value.id)) {
      throw new Error(`${location}/id duplicates tool ${value.id}`)
    }
    tools.add(value.id)
  }
  return tools
}

function validateCommands(values, tools) {
  const commands = new Map()
  const approvals = new Set()
  for (const [index, value] of values.entries()) {
    const location = `/execution/commands_attempted/${index}`
    requireExactKeys(
      value,
      [
        'id',
        'approval_id',
        'command',
        'working_directory',
        'tool_id',
        'exit_result',
      ],
      location,
    )
    requireSafeId(value.id, `${location}/id`)
    requireApprovalId(value.approval_id, `${location}/approval_id`)
    if (approvals.has(value.approval_id)) {
      throw new Error(
        `${location}/approval_id duplicates approval ${value.approval_id}`,
      )
    }
    approvals.add(value.approval_id)
    const expectedId = value.approval_id.toLowerCase()
    if (value.id !== expectedId) {
      throw new Error(
        `${location}/id must equal ${expectedId} (lowercase form of ${value.approval_id})`,
      )
    }
    requireText(value.command, `${location}/command`)
    validateComponentLocator(
      value.working_directory,
      `${location}/working_directory`,
    )
    requireSafeId(value.tool_id, `${location}/tool_id`)
    if (!tools.has(value.tool_id)) {
      throw new Error(`${location}/tool_id references unknown tool ${value.tool_id}`)
    }
    validateExitResult(value.exit_result, `${location}/exit_result`)
    if (commands.has(value.id)) {
      throw new Error(`${location}/id duplicates command ${value.id}`)
    }
    commands.set(value.id, value)
  }
  return commands
}

function validateExitResult(value, location) {
  requireObject(value, location)
  switch (value.kind) {
    case 'exited':
      requireExactKeys(value, ['kind', 'code'], location)
      if (
        !Number.isInteger(value.code) ||
        value.code < 0 ||
        value.code > 255
      ) {
        throw new Error(`${location}/code must be an integer from 0 through 255`)
      }
      break
    case 'signaled':
      requireExactKeys(value, ['kind', 'signal'], location)
      if (
        typeof value.signal !== 'string' ||
        !signalPattern.test(value.signal)
      ) {
        throw new Error(`${location}/signal must use the SIG... form`)
      }
      break
    case 'not-started':
      requireExactKeys(value, ['kind', 'reason'], location)
      requireText(value.reason, `${location}/reason`)
      break
    default:
      throw new Error(`${location}/kind is not a supported exit result`)
  }
}

function validateEvidence(values, commands, packageDirectory) {
  const paths = new Set()
  const commandEvidence = new Map([...commands.keys()].map((id) => [id, 0]))
  const realPackageDirectory = fs.realpathSync(packageDirectory)

  for (const [index, value] of values.entries()) {
    const location = `/execution/retained_evidence/${index}`
    requireExactKeys(value, ['path', 'sha256', 'command_id'], location)
    validateRelativePath(value.path, `${location}/path`, false)
    if (!value.path.startsWith('evidence/')) {
      throw new Error(`${location}/path must remain under evidence/`)
    }
    if (
      typeof value.sha256 !== 'string' ||
      !sha256Pattern.test(value.sha256)
    ) {
      throw new Error(`${location}/sha256 must be a nonzero lowercase SHA-256`)
    }
    requireSafeId(value.command_id, `${location}/command_id`)
    if (!commands.has(value.command_id)) {
      throw new Error(
        `${location}/command_id references unknown command ${value.command_id}`,
      )
    }
    const approvalDirectory = `evidence/${commands.get(value.command_id).approval_id}/`
    if (!value.path.startsWith(approvalDirectory)) {
      throw new Error(
        `${location}/path must remain under ${approvalDirectory} for command ${value.command_id}`,
      )
    }
    if (paths.has(value.path)) {
      throw new Error(`${location}/path duplicates evidence ${value.path}`)
    }
    paths.add(value.path)
    commandEvidence.set(
      value.command_id,
      commandEvidence.get(value.command_id) + 1,
    )

    const evidencePath = path.resolve(packageDirectory, ...value.path.split('/'))
    const evidenceStat = lstat(evidencePath, `${location}/path`)
    if (!evidenceStat.isFile() || evidenceStat.isSymbolicLink()) {
      throw new Error(`${location}/path must name a regular, non-symbolic-link file`)
    }
    const realEvidencePath = fs.realpathSync(evidencePath)
    if (!realEvidencePath.startsWith(`${realPackageDirectory}${path.sep}`)) {
      throw new Error(`${location}/path resolves outside the package`)
    }
    const actualHash = crypto
      .createHash('sha256')
      .update(fs.readFileSync(evidencePath))
      .digest('hex')
    if (actualHash !== value.sha256) {
      throw new Error(`${location}/sha256 does not match ${value.path}`)
    }
  }

  for (const [commandId, count] of commandEvidence) {
    if (count === 0) {
      throw new Error(`command ${commandId} has no retained evidence`)
    }
  }
}

function validateQualifications(values) {
  requireArray(values, '/qualifications')
  const qualifications = new Set()
  for (const [index, value] of values.entries()) {
    const location = `/qualifications/${index}`
    requireExactKeys(value, ['field', 'reason'], location)
    requireText(value.field, `${location}/field`)
    if (!/^\/(package|source|execution)(\/.*)?$/.test(value.field)) {
      throw new Error(`${location}/field must identify package provenance`)
    }
    requireText(value.reason, `${location}/reason`)
    const key = `${value.field}\u0000${value.reason}`
    if (qualifications.has(key)) {
      throw new Error(`${location} duplicates a qualification`)
    }
    qualifications.add(key)
  }
}

/*
 * A working directory is the logical locator of the registered component the
 * command ran in (component://<name>), optionally followed by a portable
 * relative subpath. Registration itself is checked by the validator.
 */
function validateComponentLocator(value, location) {
  requireText(value, location)
  if (!value.startsWith(componentLocatorPrefix)) {
    throw new Error(`${location} must be a component://<name>[/<subpath>] locator`)
  }
  const remainder = value.slice(componentLocatorPrefix.length)
  const separator = remainder.indexOf('/')
  const component = separator === -1 ? remainder : remainder.slice(0, separator)
  if (!safeIdPattern.test(component)) {
    throw new Error(`${location} must name a lowercase portable component`)
  }
  if (separator !== -1) {
    validateRelativePath(
      remainder.slice(separator + 1),
      location,
      false,
    )
  }
}

function validateRelativePath(value, location, allowDot) {
  requireText(value, location)
  if (allowDot && value === '.') {
    return
  }
  if (
    value.startsWith('/') ||
    value.includes('\\') ||
    value.split('/').some(
      (segment) =>
        segment === '' ||
        segment === '.' ||
        segment === '..' ||
        !pathSegmentPattern.test(segment),
    )
  ) {
    throw new Error(`${location} must be a portable package-relative path`)
  }
}

function requireExactKeys(value, expected, location) {
  requireObject(value, location)
  const actual = Object.keys(value).sort()
  const wanted = [...expected].sort()
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    throw new Error(`${location} has unexpected object keys`)
  }
}

function requireObject(value, location) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${location} must be an object`)
  }
}

function requireArray(value, location) {
  if (!Array.isArray(value)) {
    throw new Error(`${location} must be an array`)
  }
}

function requireBoolean(value, location) {
  if (typeof value !== 'boolean') {
    throw new Error(`${location} must be a boolean`)
  }
}

function requireText(value, location) {
  if (
    typeof value !== 'string' ||
    value.trim().length === 0 ||
    value.includes('\u0000')
  ) {
    throw new Error(`${location} must be nonempty text`)
  }
}

function requireDeclaredId(value, location) {
  requireText(value, location)
  if (
    value !== value.trim() ||
    /[\u0000-\u001f\u007f]/.test(value)
  ) {
    throw new Error(`${location} is not an exact portable declared identifier`)
  }
}

function requireSafeId(value, location) {
  if (typeof value !== 'string' || !safeIdPattern.test(value)) {
    throw new Error(`${location} must be a lowercase portable identifier`)
  }
}

function requirePackageId(value, location) {
  if (typeof value !== 'string' || !packageIdPattern.test(value)) {
    throw new Error(
      `${location} must be an SR-YYYYMMDD-NNN-<short-name> package identifier`,
    )
  }
}

function requireApprovalId(value, location) {
  if (typeof value !== 'string' || !approvalIdPattern.test(value)) {
    throw new Error(`${location} must be an APPROVAL-NNN identifier`)
  }
}

function lstat(filePath, label) {
  try {
    return fs.lstatSync(filePath)
  } catch (error) {
    throw new Error(`${label} is not accessible: ${error.message}`)
  }
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'))
  } catch (error) {
    throw new Error(`${filePath}: invalid JSON: ${error.message}`)
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === scriptPath) {
  if (process.argv.length !== 3) {
    console.error(
      'usage: node scripts/lint-review-manifest.mjs PACKAGE/review-manifest.json',
    )
    process.exit(2)
  }
  try {
    const classification = lintReviewManifest(process.argv[2])
    console.log(`security-reviewer review manifest: PASS (${classification})`)
  } catch (error) {
    console.error(error.message)
    process.exit(1)
  }
}
