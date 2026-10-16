const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const validate = require('./release-source.cjs');
const original = process.cwd();
const sha = '1'.repeat(40);

async function scenario(change = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'release-source-test-'));
  fs.mkdirSync(path.join(root, 'Sources/remindctl/Resources'), {recursive: true});
  fs.writeFileSync(path.join(root, 'Sources/remindctl/Version.swift'), 'static let current = "1.2.3"');
  fs.writeFileSync(path.join(root, 'version.env'), 'MARKETING_VERSION=1.2.3\n');
  fs.writeFileSync(path.join(root, 'package.json'), '{"version":"1.2.3"}');
  fs.writeFileSync(path.join(root, 'Sources/remindctl/Resources/Info.plist'), '<string>1.2.3</string>');
  fs.writeFileSync(path.join(root, 'CHANGELOG.md'), change.notes || '## 1.2.3 - 2026-10-16\n\n- A release.\n');
  const outputs = {};
  process.env.VERSION = change.version || '1.2.3';
  process.env.DRY_RUN = change.dry === false ? 'false' : 'true';
  process.chdir(root);
  try {
    await validate({
      context: {repo: {owner: 'example', repo: 'cli'}, eventName: 'workflow_dispatch', ref: 'refs/heads/main', sha, ...change.context},
      core: {setOutput: (key, value) => outputs[key] = value},
      github: {rest: {
        repos: {
          get: async () => ({data: {default_branch: 'main', full_name: 'example/cli'}}),
          getBranch: async () => ({data: {protected: change.protected !== false, commit: {sha: change.branchSha || sha}}})
        },
        actions: {listWorkflowRuns: async () => ({data: {workflow_runs: change.runs || [{head_sha: sha, head_branch: 'main', status: 'completed', conclusion: 'success'}]}})}
      }}
    });
    return {outputs, proof: JSON.parse(fs.readFileSync('release-proof/source-proof.json')), notes: fs.readFileSync('release-proof/RELEASE-NOTES.md', 'utf8')};
  } finally {
    process.chdir(original);
    fs.rmSync(root, {recursive: true, force: true});
  }
}

test('dry run freezes main without reading or creating a tag', async () => {
  const result = await scenario();
  assert.deepEqual(result.outputs, {sha, tag: 'v1.2.3', dry: 'true'});
  assert.equal(result.proof.tagObject, null);
  assert.equal(result.proof.dryRun, true);
  assert.equal(result.notes, '- A release.\n');
});
for (const [label, change, error] of [
  ['unprotected main', {protected: false}, /protected/],
  ['stale main', {branchSha: '2'.repeat(40)}, /current protected/],
  ['feature dispatch', {context: {ref: 'refs/heads/feature'}}, /current protected/],
  ['live dispatch', {dry: false}, /pushed signed/],
  ['mismatched version', {version: '1.2.4'}, /Source version/],
  ['missing notes', {notes: '## Unreleased\n- future\n'}, /dated changelog/],
  ['duplicate notes', {notes: '## 1.2.3 - 2026-10-16\n- A\n## 1.2.3 - 2026-10-15\n- B\n'}, /dated changelog/],
  ['invalid calendar date', {notes: '## 1.2.3 - 2026-02-30\n- A\n'}, /Invalid changelog date/],
  ['no exact CI', {runs: []}, /push CI/],
  ['CI on another commit', {runs: [{head_sha: '2'.repeat(40), head_branch: 'main', status: 'completed', conclusion: 'success'}]}, /push CI/],
  ['failed CI', {runs: [{head_sha: sha, head_branch: 'main', status: 'completed', conclusion: 'failure'}]}, /push CI/],
]) test(`reject ${label}`, async () => assert.rejects(scenario(change), error));
