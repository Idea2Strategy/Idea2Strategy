import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('./ensure-local-test-account.ps1', import.meta.url));

const runPowerShell = (args) => new Promise((resolve) => {
  const child = spawn('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, ...args]);
  let stdout = '';
  let stderr = '';
  child.stdout.on('data', (chunk) => { stdout += chunk; });
  child.stderr.on('data', (chunk) => { stderr += chunk; });
  child.on('close', (code) => resolve({ code, stdout, stderr }));
});

test('creates the fixed local account through signup and proves it can log in', async () => {
  const requests = [];
  let accountCreated = false;
  const server = createServer((request, response) => {
    let body = '';
    request.on('data', (chunk) => { body += chunk; });
    request.on('end', () => {
      requests.push({ path: request.url, body: JSON.parse(body) });
      response.setHeader('content-type', 'application/json');
      if (request.url === '/api/v1/auth/login' && !accountCreated) {
        response.writeHead(401).end('{"code":"AUTHENTICATION_REJECTED"}');
      } else if (request.url === '/api/v1/auth/signup') {
        accountCreated = true;
        response.writeHead(202).end('{"accountId":"00000000-0000-4000-8000-000000000001","verificationRequired":false,"verificationExpiresAt":null}');
      } else if (request.url === '/api/v1/auth/login') {
        response.writeHead(200).end('{"accountId":"00000000-0000-4000-8000-000000000001"}');
      } else {
        response.writeHead(404).end('{}');
      }
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));

  try {
    const { port } = server.address();
    const result = await runPowerShell([
      '-BackendBaseUrl', `http://127.0.0.1:${port}`,
      '-Email', 'developer@idea2strategy.local',
      '-Password', 'TestUser!2026',
    ]);

    assert.equal(result.code, 0, result.stderr || result.stdout);
    assert.deepEqual(requests.map(({ path }) => path), [
      '/api/v1/auth/login',
      '/api/v1/auth/signup',
      '/api/v1/auth/login',
    ]);
    assert.deepEqual(requests[1].body, {
      email: 'developer@idea2strategy.local',
      password: 'TestUser!2026',
    });
    assert.match(result.stdout, /developer@idea2strategy\.local/);
    assert.match(result.stdout, /TestUser!2026/);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
