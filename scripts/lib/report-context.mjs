import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

export const SOURCE_FILES = [
  'answer-guidelines.md',
  'business-glossary.md',
  'detail-report-definitions.md',
  'metric-definitions.md',
  'raw-query-metrics.md',
  'schema-guide.md',
];

export function slugify(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 72) || 'context';
}

export function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function splitMarkdown(filename, content) {
  const lines = content.replace(/\r\n/g, '\n').split('\n');
  const title = lines.find((line) => /^#\s+/.test(line))?.replace(/^#\s+/, '').trim()
    ?? filename.replace(/\.md$/, '');
  const sections = [];
  let heading = title;
  let buffer = [];

  const flush = () => {
    const body = buffer.join('\n').trim();
    if (body) sections.push({ title: heading, body });
    buffer = [];
  };

  for (const line of lines) {
    if (/^##\s+/.test(line)) {
      flush();
      heading = line.replace(/^##\s+/, '').trim();
    } else {
      buffer.push(line);
    }
  }
  flush();
  return sections;
}

function kindFor(filename) {
  if (filename === 'raw-query-metrics.md') return 'query';
  if (filename === 'schema-guide.md') return 'schema';
  if (filename.includes('definition')) return 'report';
  return 'core';
}

export async function organizeContext({ sourceDir, outputDir, source }) {
  await fs.rm(outputDir, { recursive: true, force: true });
  await fs.mkdir(outputDir, { recursive: true });
  const manifest = { version: 1, generatedAt: new Date().toISOString(), source, documents: [] };
  const alwaysOn = [];

  for (const filename of SOURCE_FILES) {
    const content = await fs.readFile(path.join(sourceDir, filename), 'utf8');
    const sourceHash = sha256(content);
    const kind = kindFor(filename);
    const sections = splitMarkdown(filename, content);

    if (filename === 'answer-guidelines.md' || filename === 'business-glossary.md') {
      alwaysOn.push(content.trim());
    }

    for (const [index, section] of sections.entries()) {
      const metadata = {
        context_type: kind,
        title: section.title,
        source_file: filename,
        source_repository: source.repository,
        source_ref: source.ref,
        source_commit: source.commit,
        source_sha256: sourceHash,
      };
      const body = [
        '---',
        ...Object.entries(metadata).map(([key, value]) => `${key}: ${JSON.stringify(value)}`),
        '---',
        '',
        `# ${section.title}`,
        '',
        section.body,
        '',
      ].join('\n');
      const hash = sha256(body).slice(0, 12);
      const relativePath = path.join(kind, `${slugify(section.title)}-${index + 1}-${hash}.md`);
      await fs.mkdir(path.dirname(path.join(outputDir, relativePath)), { recursive: true });
      await fs.writeFile(path.join(outputDir, relativePath), body);
      manifest.documents.push({ path: relativePath, hash, ...metadata });
    }
  }

  const instructions = [
    '# ClickHouse report assistant instructions',
    '',
    'Use file search before answering questions about report meaning, metric definitions, joins, filters, or approved SQL patterns. Treat retrieved documentation as semantic guidance, not as current data.',
    'Use the ClickHouse MCP tools only when the user asks for current values or the answer requires inspecting live schemas/data. Run read-only SELECT queries. Never invent a table, column, metric definition, or result.',
    'Clearly distinguish documented definitions from live query results. If retrieval is ambiguous or conflicting, say so and ask a focused clarification. Cite the retrieved source filename and section in the answer.',
    '',
    ...alwaysOn,
    '',
  ].join('\n');
  await fs.writeFile(path.join(outputDir, 'always-on-instructions.md'), instructions);
  await fs.writeFile(path.join(outputDir, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  return manifest;
}

export async function readEnvFile(filename) {
  const result = {};
  const text = await fs.readFile(filename, 'utf8');
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const index = line.indexOf('=');
    if (index < 1) continue;
    let value = line.slice(index + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    result[line.slice(0, index)] = value;
  }
  return result;
}
