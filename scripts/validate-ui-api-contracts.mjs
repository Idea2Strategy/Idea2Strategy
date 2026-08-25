import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

async function filesBelow(root, extensions) {
  const result = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    if (['node_modules', 'build', 'dist', 'test', 'tests'].includes(entry.name)) continue;
    const target = path.join(root, entry.name);
    if (entry.isDirectory()) result.push(...await filesBelow(target, extensions));
    else if (extensions.some((extension) => entry.name.endsWith(extension)) && !/\.(?:test|spec)\./.test(entry.name)) result.push(target);
  }
  return result;
}

export function normalizeRoute(value) {
  const withoutQuery = value.split('?')[0]
    .replace(/\{\{([^{}]+)\}\}/g, '{$1}')
    .replace(/\$\{[^}]+\}/g, '{param}')
    .replace(/\{[^}/]+\}/g, '{param}')
    .replace(/\/+$/g, '');
  return withoutQuery || '/';
}

export function frontendRoutes(source) {
  const routes = new Set();
  const executable = source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');
  for (const match of executable.matchAll(/(?:`|'|")([^`'"]*(?:\/api\/v1|\/mcp\/v1)[^`'"]*)(?:`|'|")/g)) {
    const apiAt = Math.min(...['/api/v1', '/mcp/v1'].map((prefix) => {
      const index = match[1].indexOf(prefix);
      return index < 0 ? Number.POSITIVE_INFINITY : index;
    }));
    routes.add(normalizeRoute(match[1].slice(apiAt)));
  }
  return routes;
}

export function backendRoutes(source) {
  const routes = new Set();
  const classAt = source.search(/\b(?:class|record|interface)\s+\w+/);
  const header = classAt < 0 ? source : source.slice(0, classAt);
  const classMapping = [...header.matchAll(/@RequestMapping\s*\(\s*(?:(?:path|value)\s*=\s*)?(?:\{\s*)?"([^"]+)"/g)].at(-1)?.[1] ?? '';
  const body = classAt < 0 ? source : source.slice(classAt);
  for (const match of body.matchAll(/@(?:Get|Post|Put|Patch|Delete|Request)Mapping\s*(?:\(([\s\S]*?)\))?/g)) {
    const paths = [...(match[1] ?? '').matchAll(/"([^"]*)"/g)].map((quoted) => quoted[1]);
    for (const methodMapping of paths.length ? paths : ['']) {
      const combined = `${classMapping.replace(/\/$/, '')}/${methodMapping.replace(/^\//, '')}`.replace(/\/+$/, '');
      if (combined.startsWith('/api/v1') || combined.startsWith('/mcp/v1')) routes.add(normalizeRoute(combined));
    }
  }
  return routes;
}

export function pythonRoutes(source) {
  const routes = new Set();
  const constants = Object.fromEntries([...source.matchAll(/^([A-Z][A-Z0-9_]*)\s*=\s*["']([^"']+)["']/gm)].map((match) => [match[1], match[2]]));
  for (const match of source.matchAll(/@\w+\.(?:get|post|put|patch|delete)\(f?["']([^"']+)["']/g)) {
    let route = match[1].replace(/\{([A-Z][A-Z0-9_]*)\}/g, (_, name) => constants[name] ?? `{${name}}`);
    if (route.startsWith('/api/v1') || route.startsWith('/mcp/v1')) routes.add(normalizeRoute(route));
  }
  return routes;
}

export async function validateContracts({ uiRoot, backendRoot, backendRoots, pythonRoots = [], allowlist = new Set() }) {
  const frontend = new Map();
  for (const file of await filesBelow(uiRoot, ['.ts', '.tsx'])) {
    for (const route of frontendRoutes(await readFile(file, 'utf8'))) {
      if (!frontend.has(route)) frontend.set(route, []);
      frontend.get(route).push(file);
    }
  }
  const backend = new Set();
  for (const javaRoot of backendRoots ?? [backendRoot]) {
    for (const file of await filesBelow(javaRoot, ['.java'])) {
      for (const route of backendRoutes(await readFile(file, 'utf8'))) backend.add(route);
    }
  }
  for (const pythonRoot of pythonRoots) {
    for (const file of await filesBelow(pythonRoot, ['.py'])) {
      for (const route of pythonRoutes(await readFile(file, 'utf8'))) backend.add(route);
    }
  }
  const missing = [...frontend.keys()].filter((route) => !backend.has(route) && !allowlist.has(route)).sort();
  return { frontend, backend, missing };
}

async function main() {
  const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const result = await validateContracts({
    uiRoot: path.join(repositoryRoot, 'ui', 'src'),
    backendRoots: [
      path.join(repositoryRoot, 'backend', 'apps', 'backend-api', 'src', 'main', 'java'),
      path.join(repositoryRoot, 'backend', 'apps', 'admin-mcp', 'src', 'main', 'java'),
    ],
    pythonRoots: [path.join(repositoryRoot, 'backtest-engine', 'src')],
    allowlist: new Set([
      // The client deliberately dispatches one of five fixed resources through a shared helper;
      // each concrete route is covered by botTrading client contract tests.
      '/api/v1/bots/{param}/{param}{param}',
      // These two clients use a typed fixed suffix helper (leaderboard and leaderboard/my-bots).
      '/api/v1/competition/rooms/{param}/{param}',
      // This literal is an authentication retry guard checked with startsWith, not an HTTP call.
      '/api/v1/auth',
    ]),
  });
  if (result.missing.length) {
    process.stderr.write(`Frontend API routes without backend controller mappings:\n${result.missing.map((route) => `- ${route}`).join('\n')}\n`);
    process.exitCode = 1;
    return;
  }
  process.stdout.write(`Validated ${result.frontend.size} frontend API routes against ${result.backend.size} backend mappings.\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
