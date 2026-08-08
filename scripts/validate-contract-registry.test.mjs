// 계약 레지스트리를 전수로 검증한다.
//
// 기존 validator 들(validate-com-a-canonical, validate-case-response-deadline-canonical,
// validate-com-a21-batch-operator-canonical, validate-corporate-action-approval-canonical)은
// 각각 손으로 고른 3~4개 계약만 본다. 그래서 새 계약이 등록되어도 아무 검사에 걸리지 않고,
// 등록되지 않은 계약 파일은 어떤 검사도 보지 않는다. INT01 은 "provider·consumer 버전·fixture
// 전수" 를 요구하므로 목록을 손으로 유지하지 않는 검사가 하나 필요하다.
//
// YAML 파서를 쓰지 않는다. 저장소에 yaml 의존성이 없고, 손으로 만든 YAML 파서는 이 저장소에서
// 한 번 조용히 틀렸다. 대신 이 파일이 하는 일은 레지스트리 원문에서 고정된 들여쓰기의 필드를
// 뽑는 것뿐이며, 뽑기에 실패하면 통과가 아니라 실패한다. 항목 수를 독립적으로 두 번 세어
// 쪼개기가 무언가를 삼키지 않았음도 확인한다.

import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import test from 'node:test';

const contractsDir = fileURLToPath(new URL('../contracts/', import.meta.url));
const registryPath = path.join(contractsDir, 'registry.yaml');
const registryText = await readFile(registryPath, 'utf8');

// workspace 목록을 여기에 적지 않는다. .gitmodules 의 서브모듈 경로에서 유도하면 목록이
// 저장소 구조와 어긋날 수 없다 — 손으로 적었던 첫 판은 실제 이름(`workspace.trading-engine`)
// 대신 짧은 이름(`workspace.trading`)을 넣어, 올바른 레지스트리를 결함으로 신고했다.
const gitmodules = await readFile(fileURLToPath(new URL('../.gitmodules', import.meta.url)), 'utf8');
const submodulePaths = [...gitmodules.matchAll(/^\s*path\s*=\s*(.+?)\s*$/gm)].map((m) => m[1]);
const KNOWN_WORKSPACES = new Set(['workspace.root', ...submodulePaths.map((p) => `workspace.${p}`)]);

const KNOWN_KINDS = new Set(['product', 'business', 'behavior', 'interface', 'data']);
const KNOWN_COMPATIBILITY = new Set(['additive', 'breaking', 'none']);

/** 한 줄 스칼라 필드. 없으면 null 을 돌려주고, 부르는 쪽이 그것을 실패로 만든다. */
function scalar(block, name) {
  const match = block.match(new RegExp(`^\\s{4}${name}:\\s*(.+?)\\s*$`, 'm'));
  return match ? match[1] : null;
}

/** `[a, b]` 한 줄 목록. 빈 목록은 `[]` 로 적혀 있다. */
function inlineList(block, name) {
  const raw = scalar(block, name);
  if (raw === null) return null;
  const inner = raw.match(/^\[(.*)\]$/);
  if (!inner) return null;
  return inner[1].split(',').map((item) => item.trim()).filter((item) => item.length > 0);
}

function parseEntries(text) {
  // 항목은 정확히 두 칸 들여쓴 `- id:` 로 시작한다. 그 경계로만 쪼갠다.
  const parts = text.split(/\n(?=  - id: )/);
  const entries = [];
  for (const part of parts) {
    if (!/^\s*- id: /m.test(part)) continue;
    const id = part.match(/^\s*- id:\s*(\S+)\s*$/m)?.[1];
    if (!id) continue;
    entries.push({ id, block: part });
  }
  return entries;
}

const entries = parseEntries(registryText);

test('레지스트리 항목을 하나도 삼키지 않고 읽는다', () => {
  const declaredCount = (registryText.match(/^ {2}- id: /gm) ?? []).length;
  assert.ok(declaredCount > 0, '레지스트리에 계약 항목이 없다.');
  assert.equal(
    entries.length,
    declaredCount,
    `항목 쪼개기가 어긋났다: ${declaredCount} 개가 선언되었는데 ${entries.length} 개를 읽었다.`,
  );
  const ids = entries.map((entry) => entry.id);
  assert.equal(new Set(ids).size, ids.length, `계약 id 가 중복된다: ${ids.join(', ')}`);
});

test('모든 계약의 지문이 원본 파일과 일치한다', async () => {
  const stale = [];
  const missing = [];
  for (const { id, block } of entries) {
    const source = scalar(block, 'source');
    const fingerprint = scalar(block, 'fingerprint');
    assert.ok(source, `${id}: source 가 없다.`);
    assert.ok(fingerprint, `${id}: fingerprint 가 없다.`);
    assert.match(fingerprint, /^sha256:[0-9a-f]{64}$/, `${id}: 지문 형식이 sha256:<64hex> 가 아니다.`);

    let content;
    try {
      content = await readFile(path.join(contractsDir, source), 'utf8');
    } catch {
      missing.push(`${id} -> ${source}`);
      continue;
    }
    const actual = `sha256:${createHash('sha256').update(content).digest('hex')}`;
    if (actual !== fingerprint) stale.push(`${id}: 레지스트리 ${fingerprint} / 실제 ${actual}`);
  }
  assert.deepEqual(missing, [], `원본 파일이 없는 계약이 있다:\n  ${missing.join('\n  ')}`);
  // 지문이 어긋나면 그 계약을 소비한다고 선언한 모든 workspace 가 낡은 것을 보고 있다는 뜻이다.
  assert.deepEqual(stale, [], `지문이 낡았다 — 원본을 고치고 레지스트리를 갱신하지 않았다:\n  ${stale.join('\n  ')}`);
});

test('provider 와 consumer 가 아는 workspace 다', () => {
  const problems = [];
  for (const { id, block } of entries) {
    const providers = inlineList(block, 'providers');
    const consumers = inlineList(block, 'consumers');
    if (providers === null) { problems.push(`${id}: providers 를 읽지 못했다.`); continue; }
    if (consumers === null) { problems.push(`${id}: consumers 를 읽지 못했다.`); continue; }
    if (providers.length === 0) problems.push(`${id}: provider 가 없다 — 아무도 이 계약을 지키지 않는다.`);
    for (const workspace of [...providers, ...consumers]) {
      if (!KNOWN_WORKSPACES.has(workspace)) problems.push(`${id}: 모르는 workspace '${workspace}'`);
    }
    // 같은 workspace 가 provider 이면서 consumer 인 경우는 실패로 보지 않는다. 처음에는
    // "경계를 정하지 않는다" 며 막았는데, 그런 규칙은 어느 승인된 문서에도 없고 실제로
    // backend 가 양쪽인 계약이 둘 있다 — outbox 를 쓰는 쪽과 결과를 되받는 쪽이 같은
    // workspace 인 것은 정상이다. 근거 없는 규칙으로 올바른 등록을 결함으로 만들 수는 없다.
  }
  assert.deepEqual(problems, [], `provider/consumer 선언에 문제가 있다:\n  ${problems.join('\n  ')}`);
});

test('kind, status, compatibility, revision 이 알려진 값이다', () => {
  const problems = [];
  for (const { id, block } of entries) {
    const kind = scalar(block, 'kind');
    const status = scalar(block, 'status');
    const compatibility = scalar(block, 'compatibility');
    const revision = scalar(block, 'revision');
    if (!KNOWN_KINDS.has(kind)) problems.push(`${id}: 모르는 kind '${kind}'`);
    if (status !== 'approved') problems.push(`${id}: status 가 '${status}' 다 — 등록된 계약은 approved 여야 한다.`);
    if (!KNOWN_COMPATIBILITY.has(compatibility)) problems.push(`${id}: 모르는 compatibility '${compatibility}'`);
    if (!/^\d+$/.test(revision ?? '')) problems.push(`${id}: revision 이 정수가 아니다 ('${revision}')`);
  }
  assert.deepEqual(problems, [], `계약 메타데이터에 문제가 있다:\n  ${problems.join('\n  ')}`);
});

test('id 의 버전 접미사가 원본 파일 이름과 일치한다', () => {
  const problems = [];
  for (const { id, block } of entries) {
    const source = scalar(block, 'source');
    if (!source) continue;
    const idVersion = id.match(/\.(v\d+)$/)?.[1];
    const fileVersion = source.match(/\.(v\d+)\.md$/)?.[1];
    if (!idVersion) { problems.push(`${id}: id 에 버전 접미사가 없다.`); continue; }
    if (!fileVersion) { problems.push(`${id}: 원본 파일 이름에 버전이 없다 (${source}).`); continue; }
    // 버전이 갈리면 소비자가 어느 개정을 구현했는지 판별할 수 없다.
    if (idVersion !== fileVersion) problems.push(`${id}: id 는 ${idVersion} 인데 파일은 ${fileVersion} (${source})`);
  }
  assert.deepEqual(problems, [], `계약 버전이 어긋난다:\n  ${problems.join('\n  ')}`);
});

test('등록되지 않은 계약 파일이 없다', async () => {
  // 이 검사가 기존 validator 들이 하지 못하는 방향이다. 그쪽은 레지스트리에서 파일로 가므로,
  // 레지스트리에 없는 계약 파일은 아무 검사도 보지 않는다. 등록되지 않은 계약은 provider 도
  // consumer 도 선언하지 않으므로, 누가 그것을 지켜야 하는지 아무도 모른다.
  const registered = new Set(
    entries.map(({ block }) => scalar(block, 'source')).filter(Boolean).map((s) => s.replace(/\\/g, '/')),
  );
  const found = [];
  for (const kind of await readdir(contractsDir, { withFileTypes: true })) {
    if (!kind.isDirectory()) continue;
    for (const file of await readdir(path.join(contractsDir, kind.name))) {
      if (!file.endsWith('.md') || file === 'index.md') continue;
      found.push(`${kind.name}/${file}`);
    }
  }
  const unregistered = found.filter((relative) => !registered.has(relative));
  assert.deepEqual(
    unregistered,
    [],
    `contracts/ 에 있으나 registry.yaml 에 없는 계약이 있다:\n  ${unregistered.join('\n  ')}`,
  );
});

test('레지스트리가 없는 원본을 가리키지 않는다', () => {
  // 위 검사의 반대 방향은 지문 검사가 이미 잡는다(파일을 열 수 없으면 실패). 여기서는
  // 경로 모양만 확인해, 레지스트리가 contracts/ 밖을 가리키지 않게 한다.
  const problems = [];
  for (const { id, block } of entries) {
    const source = scalar(block, 'source');
    if (!source) continue;
    if (source.startsWith('/') || source.includes('..')) problems.push(`${id}: source 가 contracts/ 밖을 가리킨다 (${source})`);
    if (!source.endsWith('.md')) problems.push(`${id}: source 가 .md 가 아니다 (${source})`);
  }
  assert.deepEqual(problems, [], `source 경로에 문제가 있다:\n  ${problems.join('\n  ')}`);
});
