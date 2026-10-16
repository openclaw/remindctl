// Freeze release identity and require successful push CI on that exact source.
module.exports = async ({github, context, core}) => {
  const fs = require('node:fs');
  const cp = require('node:child_process');
  const assert = (ok, message) => { if (!ok) throw new Error(message); };
  const git = (...args) => cp.execFileSync('git', args, {encoding: 'utf8'}).trim();
  const repo = (await github.rest.repos.get(context.repo)).data;
  const branch = (await github.rest.repos.getBranch({...context.repo, branch: repo.default_branch})).data;
  assert(branch.protected, 'Default branch must be protected');
  const dry = process.env.DRY_RUN === 'true';
  const version = process.env.VERSION.replace(/^v/, '');
  assert(/^\d+\.\d+\.\d+$/.test(version), 'Expected stable vX.Y.Z version');
  const tag = `v${version}`;
  let tagObject = null;
  if (context.eventName === 'workflow_dispatch') {
    assert(dry, 'Live releases require a pushed signed annotated tag');
    assert(context.ref === `refs/heads/${repo.default_branch}` && context.sha === branch.commit.sha,
      'Dry run must use current protected default branch');
  } else {
    assert(context.eventName === 'push' && context.ref === `refs/tags/${tag}`, 'Expected version tag push');
    const ref = (await github.rest.git.getRef({...context.repo, ref: `tags/${tag}`})).data;
    assert(ref.object.type === 'tag', 'Lightweight tags are forbidden');
    tagObject = ref.object.sha;
    const object = (await github.rest.git.getTag({...context.repo, tag_sha: tagObject})).data;
    assert(object.object.type === 'commit' && object.object.sha === context.sha, 'Tag source mismatch');
    git('merge-base', '--is-ancestor', context.sha, `origin/${repo.default_branch}`);
    const release = await github.rest.repos.getReleaseByTag({...context.repo, tag}).catch(error => {
      if (error.status === 404) return null;
      throw error;
    });
    assert(!release, 'Version already has a release');
  }
  const actual = fs.readFileSync('version.env', 'utf8').match(/^MARKETING_VERSION=(.+)$/m)[1];
  assert(actual === version, 'Source version differs from requested release');
  assert(JSON.parse(fs.readFileSync('package.json')).version === version, 'package.json mismatch');
  assert(fs.readFileSync('Sources/remindctl/Version.swift', 'utf8').includes(`static let current = "${version}"`), 'Generated version mismatch');
  assert(fs.readFileSync('Sources/remindctl/Resources/Info.plist', 'utf8').includes(`<string>${version}</string>`), 'Embedded plist version mismatch');
  const text = fs.readFileSync('CHANGELOG.md', 'utf8');
  const heading = new RegExp(`^## ${version.replaceAll('.', '\\.')} - (\\d{4}-\\d{2}-\\d{2})$`, 'gm');
  const matches = [...text.matchAll(heading)];
  assert(matches.length === 1, 'Expected exactly one dated changelog section');
  const date = matches[0][1];
  assert(new Date(date).toISOString().slice(0, 10) === date, 'Invalid changelog date');
  const tail = text.slice(matches[0].index + matches[0][0].length);
  const notes = tail.split(/^## /m)[0].trim() + '\n';
  assert(/^[-*] /m.test(notes), 'Empty release notes');
  const runs = (await github.rest.actions.listWorkflowRuns({...context.repo, workflow_id: 'ci.yml',
    event: 'push', head_sha: context.sha, per_page: 100})).data.workflow_runs;
  assert(runs.some(run => run.head_sha === context.sha && run.head_branch === repo.default_branch &&
    run.status === 'completed' && run.conclusion === 'success'), 'Exact-source push CI must be green');
  fs.mkdirSync('release-proof');
  fs.writeFileSync('release-proof/RELEASE-NOTES.md', notes);
  fs.writeFileSync('release-proof/source-proof.json', JSON.stringify({repository: repo.full_name,
    defaultBranch: repo.default_branch, sourceCommit: context.sha, tag, version, tagObject,
    dryRun: dry}, null, 2) + '\n');
  core.setOutput('sha', context.sha);
  core.setOutput('tag', tag);
  core.setOutput('dry', String(dry));
};
