#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { SOURCE_FILES, organizeContext, readEnvFile } from './lib/report-context.mjs';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(scriptDir, '..');
const localDir = path.join(rootDir, '.local/report-context');
const sourceDir = path.join(localDir, 'source');
const organizedDir = path.join(localDir, 'organized');
const repository = process.env.REPORT_CONTEXT_REPOSITORY ?? 'kareo-engineering/worklist';
const ref = process.env.REPORT_CONTEXT_REF ?? 'codex/restore-analytics-internal-token';
const sourcePath = process.env.REPORT_CONTEXT_PATH
  ?? 'orchestration/orchestration-server/src/main/resources/analytics/context';
const baseUrl = (process.env.LIBRECHAT_URL ?? 'http://127.0.0.1:3080').replace(/\/$/, '');
const agentName = process.env.REPORT_RAG_AGENT_NAME ?? 'ClickHouse Reports';
const managedPrefix = 'report-context--';
const browserUa = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/140 Safari/537.36';
const args = new Set(process.argv.slice(2));

function ghApi(endpoint, fields = []) {
  return execFileSync('gh', ['api', endpoint, ...fields], { encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 });
}

async function fetchSource() {
  execFileSync('gh', ['auth', 'status'], { stdio: 'ignore' });
  const commit = JSON.parse(ghApi(`repos/${repository}/commits/${encodeURIComponent(ref)}`)).sha;
  await fs.mkdir(sourceDir, { recursive: true });
  for (const filename of SOURCE_FILES) {
    const response = JSON.parse(ghApi(`repos/${repository}/contents/${sourcePath}/${filename}?ref=${encodeURIComponent(ref)}`));
    if (response.encoding !== 'base64') throw new Error(`Unexpected GitHub encoding for ${filename}`);
    await fs.writeFile(path.join(sourceDir, filename), Buffer.from(response.content, 'base64'));
  }
  const manifest = await organizeContext({
    sourceDir,
    outputDir: organizedDir,
    source: { repository, ref, commit, path: sourcePath },
  });
  console.log(`Prepared ${manifest.documents.length} retrieval documents from ${repository}@${commit.slice(0, 12)}.`);
}

async function request(token, pathname, options = {}) {
  const headers = { 'user-agent': browserUa, ...(options.headers ?? {}) };
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(`${baseUrl}${pathname}`, { ...options, headers });
  const text = await response.text();
  let body = text;
  try { body = text ? JSON.parse(text) : null; } catch { /* preserve response text */ }
  if (!response.ok) throw new Error(`${options.method ?? 'GET'} ${pathname} failed (${response.status}): ${text.slice(0, 500)}`);
  return body;
}

async function login() {
  const env = await readEnvFile(path.join(rootDir, '.env'));
  const email = process.env.LIBRECHAT_USER_EMAIL ?? env.LIBRECHAT_USER_EMAIL;
  const password = process.env.LIBRECHAT_USER_PASSWORD ?? env.LIBRECHAT_USER_PASSWORD;
  if (!email || !password) throw new Error('LIBRECHAT_USER_EMAIL and LIBRECHAT_USER_PASSWORD are required.');
  const result = await request(null, '/api/auth/login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!result?.token) throw new Error('LibreChat login did not return a token.');
  return result.token;
}

async function upsertAgent(token) {
  const instructions = await fs.readFile(path.join(organizedDir, 'always-on-instructions.md'), 'utf8');
  const listed = await request(token, '/api/agents?limit=100');
  let agent = listed.data?.find((candidate) => candidate.name === agentName);
  const payload = {
    name: agentName,
    description: 'Answers ClickHouse report questions with retrieved Worklist definitions and live read-only data.',
    provider: 'openAI',
    model: 'gpt-5.6-sol',
    instructions,
    model_parameters: { useResponsesApi: true, reasoning_effort: 'none' },
    tools: [
      'file_search',
      'list_databases_mcp_ClickHouse-Local',
      'list_tables_mcp_ClickHouse-Local',
      'run_select_query_mcp_ClickHouse-Local',
    ],
    conversation_starters: [
      'Explain how the Outstanding A/R report is calculated.',
      'Show the current patient balance and explain the metric definition.',
      'Which report should I use for appointment analysis?',
    ],
  };
  if (agent) {
    agent = await request(token, `/api/agents/${agent.id}`, {
      method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload),
    });
  } else {
    agent = await request(token, '/api/agents', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload),
    });
  }
  return agent;
}

async function uploadFile(token, agentId, absolutePath, remoteName) {
  const form = new FormData();
  form.append('endpoint', 'openAI');
  form.append('endpointType', 'openAI');
  form.append('file_id', crypto.randomUUID());
  form.append('agent_id', agentId);
  form.append('tool_resource', 'file_search');
  form.append('file', new Blob([await fs.readFile(absolutePath)], { type: 'text/markdown' }), remoteName);
  return request(token, '/api/files', { method: 'POST', body: form });
}

async function deleteManagedFile(token, agentId, file) {
  return request(token, '/api/files', {
    method: 'DELETE',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ agent_id: agentId, tool_resource: 'file_search', files: [file] }),
  });
}

async function bootstrap() {
  const token = await login();
  const agent = await upsertAgent(token);
  const manifest = JSON.parse(await fs.readFile(path.join(organizedDir, 'manifest.json'), 'utf8'));
  const existing = await request(token, `/api/files/agent/${agent.id}`);
  const currentFiles = Array.isArray(existing) ? existing : existing?.files ?? [];
  const expected = new Map();

  for (const document of manifest.documents) {
    const remoteName = `${managedPrefix}${path.basename(document.path, '.md')}.md`;
    expected.set(remoteName, document);
  }

  let uploaded = 0;
  let removed = 0;
  const currentNames = new Set(currentFiles.map((file) => decodeURIComponent(file.filename ?? file.name ?? '')));
  for (const [remoteName, document] of expected) {
    if (currentNames.has(remoteName)) continue;
    await uploadFile(token, agent.id, path.join(organizedDir, document.path), remoteName);
    uploaded += 1;
  }
  for (const file of currentFiles) {
    const filename = decodeURIComponent(file.filename ?? file.name ?? '');
    if (!filename.startsWith(managedPrefix) || expected.has(filename)) continue;
    await deleteManagedFile(token, agent.id, file);
    removed += 1;
  }
  console.log(`Agent "${agentName}" (${agent.id}) is ready: ${expected.size} indexed documents, ${uploaded} uploaded, ${removed} stale removed.`);
}

try {
  if (!args.has('--bootstrap-only')) await fetchSource();
  if (!args.has('--sync-only')) await bootstrap();
} catch (error) {
  console.error(`Report RAG sync failed: ${error.message}`);
  process.exitCode = 1;
}
