// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>
//
// Exercise security-review manifest classification and fail-closed
// consistency. Fixtures are created under the system temporary directory and
// removed afterwards; nothing under reviews/ or any target is touched.
//
// Derived from component://helium-te-poc/tests/test-review-manifest.mjs at
// commit 9b3ff4e9441e5b4434a8ec37794dee1d941e11ef (helium-te-travel-fedora44).

import assert from 'node:assert/strict'
import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

import { lintReviewManifest } from '../scripts/lint-review-manifest.mjs'

const testPath = fileURLToPath(import.meta.url)
const root = path.resolve(path.dirname(testPath), '..')
const helperPath = path.join(root, 'scripts', 'lint-review-manifest.mjs')
const wrapperPath = path.join(root, 'scripts', 'lint-review-manifest.sh')
const schemaPath = path.join(root, 'contracts', 'review-manifest.schema.json')
const templatePath = path.join(
  root,
  'contracts',
  'review-manifest.template.json',
)
const schema = readJson(schemaPath)
const template = readJson(templatePath)
const packageIdPattern = /^SR-[0-9]{8}-[0-9]{3}-[a-z0-9][a-z0-9-]{0,40}$/
const fixturePrefix = 'SR-20000101-001-'
const fixtureComponent = 'helium-te-poc'
const fixtureLocator = `component://${fixtureComponent}`
const workspace = fs.mkdtempSync(
  path.join(os.tmpdir(), 'security-reviewer-manifest-'),
)
let checks = 0

try {
  assert.equal(
    schema['x-spdx-license-identifier'],
    'GPL-3.0-only',
    'schema must retain machine-readable licensing',
  )
  assert.equal(
    schema.$id,
    'urn:beryllium:security-review-manifest:1.0.0',
    'schema must carry the Beryllium identifier',
  )
  assert.equal(
    schema.properties.$schema.const,
    '../../contracts/review-manifest.schema.json',
    'manifests must reference the contracts/ schema from reviews/<package>/',
  )
  assert.deepEqual(
    schema.$defs.execution.properties.classification.enum,
    ['static-only', 'execution-backed'],
    'schema must expose both mechanical classifications',
  )
  assert.match(
    template.source.commit,
    /^REPLACE_/,
    'template must not masquerade as completed provenance',
  )
  assert.match(template.package.id, /^REPLACE_/)
  assert.match(template.source.component, /^REPLACE_/)
  assert.match(template.source.locator, /^component:\/\/REPLACE_/)
  checks += 1

  const staticPath = writeFixture(
    fixtureId('static-review'),
    staticManifest(fixtureId('static-review')),
  )
  expectAccepted(staticPath, 'static-only')

  const execution = executionManifest(fixtureId('executed-review'))
  const executionPath = writeFixture(
    fixtureId('executed-review'),
    execution.manifest,
    execution.files,
  )
  expectAccepted(executionPath, 'execution-backed')

  const subpathExecution = executionManifest(fixtureId('executed-subpath'))
  subpathExecution.manifest.execution.commands_attempted[0].working_directory =
    `${fixtureLocator}/tests`
  expectAccepted(
    writeFixture(
      fixtureId('executed-subpath'),
      subpathExecution.manifest,
      subpathExecution.files,
    ),
    'execution-backed',
  )

  const twoApprovals = executionManifest(fixtureId('executed-two'))
  addSecondCommand(twoApprovals, 'APPROVAL-002', 'approval-002')
  expectAccepted(
    writeFixture(
      fixtureId('executed-two'),
      twoApprovals.manifest,
      twoApprovals.files,
    ),
    'execution-backed',
  )

  const minimumId = `${fixturePrefix}m`
  const minimumStatic = minimumStaticManifest(minimumId)
  expectAccepted(writeFixture(minimumId, minimumStatic), 'static-only')

  const minimumExecutionId = `${fixturePrefix}e`
  const minimumExecution = minimumExecutionManifest(minimumExecutionId)
  expectAccepted(
    writeFixture(
      minimumExecutionId,
      minimumExecution.manifest,
      minimumExecution.files,
    ),
    'execution-backed',
  )

  const maximumPackageId = `${fixturePrefix}${'p'.repeat(41)}`
  const maximumExecution = maximumExecutionManifest(maximumPackageId)
  expectAccepted(
    writeFixture(
      maximumPackageId,
      maximumExecution.manifest,
      maximumExecution.files,
    ),
    'execution-backed',
  )

  const maximumStatic = staticManifest(fixtureId('static-reason-maximum'))
  maximumStatic.execution.static_only_reason = 'r'.repeat(4096)
  assert.equal(maximumStatic.execution.static_only_reason.length, 4096)
  expectAccepted(
    writeFixture(fixtureId('static-reason-maximum'), maximumStatic),
    'static-only',
  )

  const unicodeModel = staticManifest(fixtureId('unicode-model-boundary'))
  unicodeModel.package.model_id = '😀'.repeat(256)
  assert.equal([...unicodeModel.package.model_id].length, 256)
  expectAccepted(
    writeFixture(fixtureId('unicode-model-boundary'), unicodeModel),
    'static-only',
  )

  const maximumExit = executionManifest(fixtureId('exit-code-maximum'))
  maximumExit.manifest.execution.commands_attempted[0].exit_result.code = 255
  expectAccepted(
    writeFixture(
      fixtureId('exit-code-maximum'),
      maximumExit.manifest,
      maximumExit.files,
    ),
    'execution-backed',
  )

  const signaledId = `${fixturePrefix}s`
  const signaledExecution = minimumExecutionManifest(signaledId)
  signaledExecution.manifest.execution.commands_attempted[0].exit_result = {
    kind: 'signaled',
    signal: 'SIGA',
  }
  expectAccepted(
    writeFixture(
      signaledId,
      signaledExecution.manifest,
      signaledExecution.files,
    ),
    'execution-backed',
  )

  const detachedStatic = staticManifest(fixtureId('detached-review'))
  detachedStatic.source.detached = true
  detachedStatic.source.branch = null
  expectAccepted(
    writeFixture(fixtureId('detached-review'), detachedStatic),
    'static-only',
  )

  const cli = spawnSync(process.execPath, [helperPath, staticPath], {
    encoding: 'utf8',
  })
  assert.equal(cli.status, 0, cli.stderr)
  assert.match(cli.stdout, /PASS \(static-only\)/)
  checks += 1

  const wrapper = spawnSync('bash', [wrapperPath, executionPath], {
    encoding: 'utf8',
  })
  assert.equal(wrapper.status, 0, wrapper.stderr)
  assert.match(wrapper.stdout, /PASS \(execution-backed\)/)
  checks += 1

  const usage = spawnSync(process.execPath, [helperPath], { encoding: 'utf8' })
  assert.equal(usage.status, 2)
  assert.match(
    usage.stderr,
    /usage: node scripts\/lint-review-manifest\.mjs PACKAGE\/review-manifest\.json/,
  )
  checks += 1

  // The raw template must never lint as completed provenance, neither in
  // place (wrong filename) nor copied into a package directory.
  const templateCli = spawnSync(process.execPath, [helperPath, templatePath], {
    encoding: 'utf8',
  })
  assert.equal(templateCli.status, 1)
  assert.match(templateCli.stderr, /manifest filename must be review-manifest\.json/)
  const templateCopy = writeFixture(template.package.id, template)
  assert.throws(
    () => lintReviewManifest(templateCopy),
    /schema validation failed: \/package\/id must match pattern/,
  )
  checks += 1

  expectSchemaRejected(
    'package-id-pattern',
    staticFixture,
    (manifest) => {
      manifest.package.id = 'not-an-sr-package'
    },
    /package\/id must match pattern/,
  )
  expectSchemaRejected(
    'package-id-uppercase-name',
    staticFixture,
    (manifest) => {
      manifest.package.id = `${fixturePrefix}Upper`
    },
    /package\/id must match pattern/,
  )
  expectSchemaRejected(
    'missing-component',
    staticFixture,
    (manifest) => {
      delete manifest.source.component
    },
    /source is missing required property "component"/,
  )
  expectSchemaRejected(
    'missing-locator',
    staticFixture,
    (manifest) => {
      delete manifest.source.locator
    },
    /source is missing required property "locator"/,
  )
  expectSchemaRejected(
    'bad-component',
    staticFixture,
    (manifest) => {
      manifest.source.component = 'Helium'
    },
    /source\/component must match pattern/,
  )
  expectSchemaRejected(
    'bad-locator',
    staticFixture,
    (manifest) => {
      manifest.source.locator = 'workspace://helium-te-poc'
    },
    /source\/locator must match pattern/,
  )
  expectSchemaRejected(
    'bad-locator-subpath',
    staticFixture,
    (manifest) => {
      manifest.source.locator = `${fixtureLocator}/docs`
    },
    /source\/locator must match pattern/,
  )
  expectRejected(
    'locator-mismatch',
    staticFixture,
    (manifest) => {
      manifest.source.locator = 'component://other-component'
    },
    /source\/locator must equal component:\/\/helium-te-poc/,
  )
  expectSchemaRejected(
    'missing-approval',
    executionManifest,
    (manifest) => {
      delete manifest.execution.commands_attempted[0].approval_id
    },
    /commands_attempted\/0 is missing required property "approval_id"/,
  )
  expectSchemaRejected(
    'bad-approval-pattern',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].approval_id = 'APPROVAL-1'
    },
    /commands_attempted\/0\/approval_id must match pattern/,
  )
  expectSchemaRejected(
    'lowercase-approval',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].approval_id = 'approval-001'
    },
    /commands_attempted\/0\/approval_id must match pattern/,
  )
  expectRejected(
    'duplicate-approval',
    executionManifest,
    (manifest, fixture) => {
      addSecondCommand(fixture, 'APPROVAL-001', 'approval-002')
    },
    /commands_attempted\/1\/approval_id duplicates approval APPROVAL-001/,
  )
  expectRejected(
    'id-not-lowercase-approval',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].id = 'example-command'
      manifest.execution.retained_evidence[0].command_id = 'example-command'
    },
    /commands_attempted\/0\/id must equal approval-001/,
  )
  expectRejected(
    'evidence-outside-approval-dir',
    executionManifest,
    (manifest, fixture) => {
      const content = fixture.files['evidence/APPROVAL-001/example.log']
      delete fixture.files['evidence/APPROVAL-001/example.log']
      fixture.files['evidence/other/example.log'] = content
      manifest.execution.retained_evidence[0].path = 'evidence/other/example.log'
    },
    /retained_evidence\/0\/path must remain under evidence\/APPROVAL-001\/ for command approval-001/,
  )
  expectRejected(
    'evidence-in-wrong-approval-dir',
    executionManifest,
    (manifest, fixture) => {
      addSecondCommand(fixture, 'APPROVAL-002', 'approval-002')
      manifest.execution.retained_evidence[1].command_id = 'approval-001'
    },
    /retained_evidence\/1\/path must remain under evidence\/APPROVAL-001\//,
  )
  expectRejected(
    'evidence-directly-under-evidence',
    executionManifest,
    (manifest, fixture) => {
      const content = fixture.files['evidence/APPROVAL-001/example.log']
      delete fixture.files['evidence/APPROVAL-001/example.log']
      fixture.files['evidence/example.log'] = content
      manifest.execution.retained_evidence[0].path = 'evidence/example.log'
    },
    /retained_evidence\/0\/path must remain under evidence\/APPROVAL-001\//,
  )

  expectSchemaRejected(
    'classification-conflict',
    executionManifest,
    (manifest) => {
      manifest.execution.classification = 'static-only'
      manifest.execution.static_only_reason = 'Incorrectly declared static'
    },
    /commands_attempted must contain at most 0 items/,
  )
  expectSchemaRejected(
    'execution-without-commands',
    staticFixture,
    (manifest) => {
      manifest.execution.classification = 'execution-backed'
      manifest.execution.static_only_reason = null
    },
    /commands_attempted must contain at least 1 items/,
  )
  expectRejected(
    'unknown-tool',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].tool_id = 'missing-tool'
    },
    /references unknown tool/,
  )
  expectRejected(
    'unused-tool',
    executionManifest,
    (manifest) => {
      manifest.execution.tool_versions.push({ id: 'spare', version: '1' })
    },
    /tool_versions has unused tool spare/,
  )
  expectSchemaRejected(
    'invalid-exit',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].exit_result.code = 256
    },
    /exit_result must match exactly one schema alternative/,
  )
  expectSchemaRejected(
    'negative-exit',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].exit_result.code = -1
    },
    /exit_result must match exactly one schema alternative/,
  )
  expectRejected(
    'hash-mismatch',
    executionManifest,
    (manifest) => {
      manifest.execution.retained_evidence[0].sha256 =
        'a'.repeat(64)
    },
    /sha256 does not match/,
  )
  expectRejected(
    'missing-evidence-file',
    executionManifest,
    (manifest, fixture) => {
      delete fixture.files['evidence/APPROVAL-001/example.log']
    },
    /retained_evidence\/0\/path is not accessible/,
  )
  expectRejected(
    'symlink-evidence',
    executionManifest,
    (manifest, fixture) => {
      fixture.files['evidence/APPROVAL-001/real.log'] =
        fixture.files['evidence/APPROVAL-001/example.log']
      delete fixture.files['evidence/APPROVAL-001/example.log']
      fixture.symlinks = {
        'evidence/APPROVAL-001/example.log': 'real.log',
      }
    },
    /must name a regular, non-symbolic-link file/,
  )
  expectRejected(
    'duplicate-evidence-path',
    executionManifest,
    (manifest) => {
      manifest.execution.retained_evidence.push({
        ...manifest.execution.retained_evidence[0],
        sha256: 'b'.repeat(64),
      })
    },
    /retained_evidence\/1\/path duplicates evidence/,
  )
  expectRejected(
    'command-without-evidence',
    executionManifest,
    (manifest, fixture) => {
      addSecondCommand(fixture, 'APPROVAL-002', 'approval-002')
      manifest.execution.retained_evidence.pop()
    },
    /command approval-002 has no retained evidence/,
  )
  expectSchemaRejected(
    'path-traversal',
    executionManifest,
    (manifest) => {
      manifest.execution.retained_evidence[0].path = '../escaped.log'
    },
    /retained_evidence\/0\/path must match pattern/,
  )
  expectRejected(
    'path-traversal-inside',
    executionManifest,
    (manifest) => {
      manifest.execution.retained_evidence[0].path =
        'evidence/APPROVAL-001/../APPROVAL-001/example.log'
    },
    /retained_evidence\/0\/path must be a portable package-relative path/,
  )
  expectSchemaRejected(
    'branch-conflict',
    staticFixture,
    (manifest) => {
      manifest.source.detached = true
    },
    /source\/branch must be null/,
  )
  expectSchemaRejected(
    'dirty-conflict',
    staticFixture,
    (manifest) => {
      manifest.source.dirty_detail = 'Unexpected detail'
    },
    /source\/dirty_detail must be null/,
  )
  expectRejected(
    'branch-format',
    staticFixture,
    (manifest) => {
      manifest.source.branch = 'refs/heads/bad..branch'
    },
    /not a valid full branch ref/,
  )
  expectSchemaRejected(
    'workdir-format',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].working_directory = '/absolute'
    },
    /working_directory must match pattern/,
  )
  expectSchemaRejected(
    'workdir-relative',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].working_directory = '.'
    },
    /working_directory must match pattern/,
  )
  expectRejected(
    'workdir-traversal',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].working_directory =
        `${fixtureLocator}/a/../b`
    },
    /working_directory must be a portable package-relative path/,
  )
  expectRejected(
    'package-conflict',
    staticFixture,
    (manifest) => {
      manifest.package.id = fixtureId('different-package')
    },
    /must match package directory/,
  )
  expectSchemaRejected(
    'unexpected-metadata',
    staticFixture,
    (manifest) => {
      manifest.untracked_claim = true
    },
    /untracked_claim is not an allowed property/,
  )

  expectSchemaRejected(
    'missing-nested',
    executionManifest,
    (manifest) => {
      delete manifest.execution.tool_versions[0].version
    },
    /tool_versions\/0 is missing required property "version"/,
  )
  expectSchemaRejected(
    'extra-nested',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].untracked = true
    },
    /commands_attempted\/0\/untracked is not an allowed property/,
  )
  expectSchemaRejected(
    'wrong-array-type',
    staticFixture,
    (manifest) => {
      manifest.qualifications = {}
    },
    /qualifications must be an array/,
  )
  expectSchemaRejected(
    'wrong-schema-pointer',
    staticFixture,
    (manifest) => {
      manifest.$schema = '../review-manifest.schema.json'
    },
    /\$schema must equal "\.\.\/\.\.\/contracts\/review-manifest\.schema\.json"/,
  )
  expectSchemaRejected(
    'wrong-schema-version',
    staticFixture,
    (manifest) => {
      manifest.schema_version = '2.0.0'
    },
    /schema_version must equal "1.0.0"/,
  )
  expectSchemaRejected(
    'wrong-boolean-type',
    staticFixture,
    (manifest) => {
      manifest.source.detached = 'false'
    },
    /source\/detached must be a boolean/,
  )
  expectSchemaRejected(
    'wrong-enum',
    staticFixture,
    (manifest) => {
      manifest.execution.classification = 'unknown'
    },
    /classification must be one of/,
  )
  expectSchemaRejected(
    'wrong-commit-pattern',
    staticFixture,
    (manifest) => {
      manifest.source.commit = 'A'.repeat(40)
    },
    /source\/commit must match pattern/,
  )
  expectSchemaRejected(
    'zero-commit',
    staticFixture,
    (manifest) => {
      manifest.source.commit = '0'.repeat(40)
    },
    /source\/commit must match pattern/,
  )
  expectSchemaRejected(
    'wrong-signal-pattern',
    executionManifest,
    (manifest) => {
      manifest.execution.commands_attempted[0].exit_result = {
        kind: 'signaled',
        signal: 'KILL',
      }
    },
    /exit_result must match exactly one schema alternative/,
  )
  expectSchemaRejected(
    'duplicate-qualification',
    staticFixture,
    (manifest) => {
      const qualification = {
        field: '/source/dirty',
        reason: 'The source state needs explanation.',
      }
      manifest.qualifications = [qualification, structuredClone(qualification)]
    },
    /qualifications must contain unique items/,
  )

  for (const testCase of schemaLengthFailures()) {
    expectSchemaRejected(
      testCase.label,
      testCase.fixtureFactory,
      testCase.mutate,
      testCase.expected,
    )
  }

  console.log(`security-reviewer review manifest tests: PASS (${checks} checks)`)
} finally {
  fs.rmSync(workspace, { recursive: true, force: true })
}

function fixtureId(label) {
  const packageId = `${fixturePrefix}${label}`
  assert.match(packageId, packageIdPattern, `fixture id ${packageId}`)
  return packageId
}

function minimumStaticManifest(packageId) {
  const manifest = staticManifest(packageId)
  manifest.package.model_id = 'm'
  manifest.package.run_id = 'r'
  manifest.source.component = 'h'
  manifest.source.locator = 'component://h'
  manifest.source.branch = 'refs/heads/a'
  manifest.execution.static_only_reason = 'r'
  manifest.qualifications = [
    {
      field: '/package',
      reason: 'r',
    },
  ]

  assert.equal(manifest.package.id.length, fixturePrefix.length + 1)
  assert.equal(manifest.package.model_id.length, 1)
  assert.equal(manifest.package.run_id.length, 1)
  assert.equal(manifest.source.component.length, 1)
  assert.equal(manifest.source.locator.length, 13)
  assert.equal(manifest.source.branch.length, 12)
  assert.equal(manifest.execution.static_only_reason.length, 1)
  assert.equal(manifest.qualifications[0].field.length, 8)
  assert.equal(manifest.qualifications[0].reason.length, 1)
  return manifest
}

function minimumExecutionManifest(packageId) {
  const content = 'x'
  const manifest = minimumStaticManifest(packageId)
  manifest.source.dirty = true
  manifest.source.dirty_detail = 'd'
  manifest.execution = {
    classification: 'execution-backed',
    static_only_reason: null,
    commands_attempted: [
      {
        id: 'approval-001',
        approval_id: 'APPROVAL-001',
        command: 'x',
        working_directory: 'component://h',
        tool_id: 't',
        exit_result: {
          kind: 'not-started',
          reason: 'r',
        },
      },
    ],
    tool_versions: [
      {
        id: 't',
        version: 'v',
      },
    ],
    retained_evidence: [
      {
        path: 'evidence/APPROVAL-001/a',
        sha256: sha256(content),
        command_id: 'approval-001',
      },
    ],
  }

  assert.equal(manifest.source.dirty_detail.length, 1)
  assert.equal(manifest.execution.commands_attempted[0].command.length, 1)
  assert.equal(
    manifest.execution.commands_attempted[0].working_directory.length,
    13,
  )
  assert.equal(manifest.execution.commands_attempted[0].tool_id.length, 1)
  assert.equal(
    manifest.execution.commands_attempted[0].exit_result.reason.length,
    1,
  )
  assert.equal(manifest.execution.tool_versions[0].id.length, 1)
  assert.equal(manifest.execution.tool_versions[0].version.length, 1)
  assert.equal(manifest.execution.retained_evidence[0].path.length, 23)
  return {
    manifest,
    files: {
      'evidence/APPROVAL-001/a': content,
    },
  }
}

function maximumExecutionManifest(packageId) {
  const content = 'maximum boundary evidence\n'
  const evidencePath = portablePathOfLength(1024, 'evidence/APPROVAL-001/')
  const component = 'c'.repeat(128)
  const toolId = 't'.repeat(128)
  const manifest = staticManifest(packageId)

  manifest.package.model_id = 'm'.repeat(256)
  manifest.package.run_id = 'r'.repeat(256)
  manifest.source.component = component
  manifest.source.locator = `component://${component}`
  manifest.source.branch = `refs/heads/${'b'.repeat(501)}`
  manifest.source.dirty = true
  manifest.source.dirty_detail = 'd'.repeat(4096)
  manifest.execution = {
    classification: 'execution-backed',
    static_only_reason: null,
    commands_attempted: [
      {
        id: 'approval-001',
        approval_id: 'APPROVAL-001',
        command: 'c'.repeat(16384),
        working_directory: portablePathOfLength(
          1024,
          `component://${component}/`,
        ),
        tool_id: toolId,
        exit_result: {
          kind: 'not-started',
          reason: 'n'.repeat(4096),
        },
      },
    ],
    tool_versions: [
      {
        id: toolId,
        version: 'v'.repeat(4096),
      },
    ],
    retained_evidence: [
      {
        path: evidencePath,
        sha256: sha256(content),
        command_id: 'approval-001',
      },
    ],
  }
  manifest.qualifications = [
    {
      field: `/package/${'q'.repeat(1015)}`,
      reason: 'q'.repeat(4096),
    },
  ]

  assert.equal(manifest.package.id.length, fixturePrefix.length + 41)
  assert.equal(manifest.package.model_id.length, 256)
  assert.equal(manifest.package.run_id.length, 256)
  assert.equal(manifest.source.component.length, 128)
  assert.equal(manifest.source.branch.length, 512)
  assert.equal(manifest.source.dirty_detail.length, 4096)
  assert.equal(manifest.execution.commands_attempted[0].command.length, 16384)
  assert.equal(
    manifest.execution.commands_attempted[0].working_directory.length,
    1024,
  )
  assert.equal(manifest.execution.commands_attempted[0].tool_id.length, 128)
  assert.equal(
    manifest.execution.commands_attempted[0].exit_result.reason.length,
    4096,
  )
  assert.equal(manifest.execution.tool_versions[0].id.length, 128)
  assert.equal(manifest.execution.tool_versions[0].version.length, 4096)
  assert.equal(manifest.execution.retained_evidence[0].path.length, 1024)
  assert.equal(manifest.qualifications[0].field.length, 1024)
  assert.equal(manifest.qualifications[0].reason.length, 4096)
  return {
    manifest,
    files: {
      [evidencePath]: content,
    },
  }
}

function schemaLengthFailures() {
  return [
    {
      label: 'package-id-over-max',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.package.id = `${fixturePrefix}${'p'.repeat(42)}`
      },
      expected: /package\/id must match pattern/,
    },
    {
      label: 'component-over-max',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.source.component = 'c'.repeat(129)
        manifest.source.locator = `component://${'c'.repeat(129)}`
      },
      expected: /source\/component must match pattern/,
    },
    {
      label: 'model-empty',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.package.model_id = ''
      },
      expected: /package\/model_id must contain at least 1 Unicode characters/,
    },
    {
      label: 'model-over-max',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.package.model_id = 'm'.repeat(257)
      },
      expected: /package\/model_id must contain at most 256 Unicode characters/,
    },
    {
      label: 'run-empty',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.package.run_id = ''
      },
      expected: /package\/run_id must contain at least 1 Unicode characters/,
    },
    {
      label: 'run-over-max',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.package.run_id = 'r'.repeat(257)
      },
      expected: /package\/run_id must contain at most 256 Unicode characters/,
    },
    {
      label: 'branch-under-min',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.source.branch = 'refs/heads/'
      },
      expected: /source\/branch must match exactly one schema alternative/,
    },
    {
      label: 'branch-over-max',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.source.branch = `refs/heads/${'b'.repeat(502)}`
      },
      expected: /source\/branch must match exactly one schema alternative/,
    },
    {
      label: 'dirty-detail-empty',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.source.dirty = true
        manifest.source.dirty_detail = ''
      },
      expected: /source\/dirty_detail must match exactly one schema alternative/,
    },
    {
      label: 'dirty-detail-over-max',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.source.dirty = true
        manifest.source.dirty_detail = 'd'.repeat(4097)
      },
      expected: /source\/dirty_detail must match exactly one schema alternative/,
    },
    {
      label: 'static-reason-empty',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.execution.static_only_reason = ''
      },
      expected: /static_only_reason must match exactly one schema alternative/,
    },
    {
      label: 'static-reason-over-max',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.execution.static_only_reason = 'r'.repeat(4097)
      },
      expected: /static_only_reason must match exactly one schema alternative/,
    },
    {
      label: 'command-id-over-max',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        const commandId = 'c'.repeat(129)
        manifest.execution.commands_attempted[0].id = commandId
        manifest.execution.retained_evidence[0].command_id = commandId
      },
      expected: /commands_attempted\/0\/id must match pattern/,
    },
    {
      label: 'command-empty',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.commands_attempted[0].command = ''
      },
      expected: /commands_attempted\/0\/command must contain at least 1 Unicode characters/,
    },
    {
      label: 'command-over-max',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.commands_attempted[0].command = 'c'.repeat(16385)
      },
      expected: /commands_attempted\/0\/command must contain at most 16384 Unicode characters/,
    },
    {
      label: 'workdir-empty',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.commands_attempted[0].working_directory = ''
      },
      expected: /working_directory must contain at least 1 Unicode characters/,
    },
    {
      label: 'workdir-over-max',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.commands_attempted[0].working_directory =
          portablePathOfLength(1025, `${fixtureLocator}/`)
      },
      expected: /working_directory must contain at most 1024 Unicode characters/,
    },
    {
      label: 'tool-id-over-max',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.tool_versions[0].id = 't'.repeat(129)
      },
      expected: /tool_versions\/0\/id must match pattern/,
    },
    {
      label: 'version-empty',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.tool_versions[0].version = ''
      },
      expected: /tool_versions\/0\/version must contain at least 1 Unicode characters/,
    },
    {
      label: 'version-over-max',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.tool_versions[0].version = 'v'.repeat(4097)
      },
      expected: /tool_versions\/0\/version must contain at most 4096 Unicode characters/,
    },
    {
      label: 'exit-reason-empty',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.commands_attempted[0].exit_result = {
          kind: 'not-started',
          reason: '',
        }
      },
      expected: /exit_result must match exactly one schema alternative/,
    },
    {
      label: 'exit-reason-over-max',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.commands_attempted[0].exit_result = {
          kind: 'not-started',
          reason: 'r'.repeat(4097),
        }
      },
      expected: /exit_result must match exactly one schema alternative/,
    },
    {
      label: 'evidence-path-under-min',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.retained_evidence[0].path = 'evidence/'
      },
      expected: /retained_evidence\/0\/path must match pattern/,
    },
    {
      label: 'evidence-path-over-max',
      fixtureFactory: executionManifest,
      mutate: (manifest) => {
        manifest.execution.retained_evidence[0].path =
          portablePathOfLength(1025, 'evidence/APPROVAL-001/')
      },
      expected: /retained_evidence\/0\/path must contain at most 1024 Unicode characters/,
    },
    {
      label: 'qualification-field-pattern',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.qualifications = [
          {
            field: '/other',
            reason: 'r',
          },
        ]
      },
      expected: /qualifications\/0\/field must match pattern/,
    },
    {
      label: 'qualification-field-over-max',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.qualifications = [
          {
            field: `/package/${'q'.repeat(1016)}`,
            reason: 'r',
          },
        ]
      },
      expected: /qualifications\/0\/field must contain at most 1024 Unicode characters/,
    },
    {
      label: 'qualification-reason-empty',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.qualifications = [
          {
            field: '/source',
            reason: '',
          },
        ]
      },
      expected: /qualifications\/0\/reason must contain at least 1 Unicode characters/,
    },
    {
      label: 'qualification-reason-over-max',
      fixtureFactory: staticFixture,
      mutate: (manifest) => {
        manifest.qualifications = [
          {
            field: '/source',
            reason: 'q'.repeat(4097),
          },
        ]
      },
      expected: /qualifications\/0\/reason must contain at most 4096 Unicode characters/,
    },
  ]
}

function staticFixture(packageId) {
  return {
    manifest: staticManifest(packageId),
    files: {},
  }
}

function staticManifest(packageId) {
  const manifest = structuredClone(template)
  manifest.package = {
    id: packageId,
    model_id: 'example-provider/example-model',
    run_id: `run-${packageId}`,
  }
  manifest.source = {
    component: fixtureComponent,
    locator: fixtureLocator,
    commit: '0123456789abcdef0123456789abcdef01234567',
    branch: 'refs/heads/for-review',
    detached: false,
    dirty: false,
    dirty_detail: null,
  }
  manifest.execution.static_only_reason =
    'The review used source-reading APIs and attempted no target command.'
  return manifest
}

function executionManifest(packageId) {
  const content = 'example command output\n'
  const manifest = staticManifest(packageId)
  manifest.execution = {
    classification: 'execution-backed',
    static_only_reason: null,
    commands_attempted: [
      {
        id: 'approval-001',
        approval_id: 'APPROVAL-001',
        command: 'node --version',
        working_directory: fixtureLocator,
        tool_id: 'node',
        exit_result: {
          kind: 'exited',
          code: 0,
        },
      },
    ],
    tool_versions: [
      {
        id: 'node',
        version: 'v18.0.0',
      },
    ],
    retained_evidence: [
      {
        path: 'evidence/APPROVAL-001/example.log',
        sha256: sha256(content),
        command_id: 'approval-001',
      },
    ],
  }
  return {
    manifest,
    files: {
      'evidence/APPROVAL-001/example.log': content,
    },
  }
}

function addSecondCommand(fixture, approvalId, commandId) {
  const content = `second command output for ${approvalId}\n`
  const evidencePath = `evidence/${approvalId}/second.log`
  fixture.manifest.execution.commands_attempted.push({
    id: commandId,
    approval_id: approvalId,
    command: 'node --help',
    working_directory: fixtureLocator,
    tool_id: 'node',
    exit_result: {
      kind: 'exited',
      code: 1,
    },
  })
  fixture.manifest.execution.retained_evidence.push({
    path: evidencePath,
    sha256: sha256(content),
    command_id: commandId,
  })
  fixture.files[evidencePath] = content
}

function expectAccepted(manifestPath, classification) {
  assert.equal(lintReviewManifest(manifestPath), classification)
  checks += 1
}

function expectRejected(label, fixtureFactory, mutate, expected) {
  const packageId = fixtureId(`reject-${label}`)
  const fixture = fixtureFactory(packageId)
  mutate(fixture.manifest, fixture)
  const manifestPath = writeFixture(
    packageId,
    fixture.manifest,
    fixture.files,
    fixture.symlinks,
  )
  assert.throws(() => lintReviewManifest(manifestPath), expected)

  const cli = spawnSync(process.execPath, [helperPath, manifestPath], {
    encoding: 'utf8',
  })
  assert.equal(cli.status, 1, `${label}: CLI unexpectedly accepted fixture`)
  checks += 1
}

function expectSchemaRejected(label, fixtureFactory, mutate, expected) {
  const packageId = fixtureId(`reject-${label}`)
  const fixture = fixtureFactory(packageId)
  mutate(fixture.manifest, fixture)
  const manifestPath = writeFixture(
    packageId,
    fixture.manifest,
    fixture.files,
    fixture.symlinks,
  )
  assert.throws(
    () => lintReviewManifest(manifestPath),
    (error) => {
      assert.match(error.message, /schema validation failed:/)
      assert.match(error.message, expected)
      return true
    },
  )

  const cli = spawnSync(process.execPath, [helperPath, manifestPath], {
    encoding: 'utf8',
  })
  assert.equal(cli.status, 1, `${label}: CLI unexpectedly accepted fixture`)
  assert.match(cli.stderr, /schema validation failed:/)
  checks += 1
}

function writeFixture(packageId, manifest, files = {}, symlinks = {}) {
  const directory = path.join(workspace, packageId)
  fs.mkdirSync(directory, { recursive: false })
  for (const [relativePath, content] of Object.entries(files)) {
    const filePath = path.join(directory, ...relativePath.split('/'))
    fs.mkdirSync(path.dirname(filePath), { recursive: true })
    fs.writeFileSync(filePath, content)
  }
  for (const [relativePath, target] of Object.entries(symlinks ?? {})) {
    const linkPath = path.join(directory, ...relativePath.split('/'))
    fs.mkdirSync(path.dirname(linkPath), { recursive: true })
    fs.symlinkSync(target, linkPath)
  }
  const manifestPath = path.join(directory, 'review-manifest.json')
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`)
  return manifestPath
}

function portablePathOfLength(length, prefix = '') {
  let remaining = length - prefix.length
  const segments = []

  assert(remaining > 0, 'portable path length must exceed its prefix')
  while (remaining > 120) {
    segments.push('a'.repeat(120))
    remaining -= 121
  }
  assert(remaining > 0, 'portable path must end in a nonempty segment')
  segments.push('a'.repeat(remaining))
  return `${prefix}${segments.join('/')}`
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex')
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'))
}
