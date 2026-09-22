import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { organizeContext, slugify, splitMarkdown, SOURCE_FILES } from './report-context.mjs';

test('splitMarkdown creates retrieval units at H2 boundaries', () => {
  const sections = splitMarkdown('reports.md', '# Reports\nIntro\n## Revenue Dashboard\nDefinition\n## Patient Base\nDetails');
  assert.deepEqual(sections.map(({ title }) => title), ['Reports', 'Revenue Dashboard', 'Patient Base']);
});

test('slugify creates bounded portable names', () => {
  assert.equal(slugify('Outstanding A/R & Aging'), 'outstanding-a-r-aging');
});

test('organizeContext emits metadata, hashes, and always-on instructions', async () => {
  const temp = await fs.mkdtemp(path.join(os.tmpdir(), 'report-context-test-'));
  const sourceDir = path.join(temp, 'source');
  const outputDir = path.join(temp, 'output');
  await fs.mkdir(sourceDir);
  for (const filename of SOURCE_FILES) {
    await fs.writeFile(path.join(sourceDir, filename), `# ${filename}\n\n## Definition\n\nContent for ${filename}.\n`);
  }
  const manifest = await organizeContext({
    sourceDir, outputDir, source: { repository: 'owner/repo', ref: 'branch', commit: 'abc123', path: 'context' },
  });
  assert.equal(manifest.documents.length, SOURCE_FILES.length * 2);
  assert.match(await fs.readFile(path.join(outputDir, 'always-on-instructions.md'), 'utf8'), /Use file search/);
  const document = await fs.readFile(path.join(outputDir, manifest.documents[0].path), 'utf8');
  assert.match(document, /source_repository: "owner\/repo"/);
});
