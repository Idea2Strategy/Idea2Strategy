import { createHash, randomBytes } from "node:crypto";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const mode = process.argv[2];

function execute(program, args, options = {}) {
  const result = spawnSync(program, args, {
    cwd: options.cwd ?? root,
    encoding: "utf8",
    windowsHide: true,
    env: process.env,
  });
  if (result.error) throw result.error;
  if (!options.allowFailure && result.status !== 0) {
    throw new Error(
      `${program} exited with ${result.status}: ${(result.stderr || result.stdout).trim()}`,
    );
  }
  return result;
}

function output(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

function githubCli() {
  const probe = execute(process.platform === "win32" ? "where.exe" : "which", ["gh"], {
    allowFailure: true,
  });
  if (probe.status === 0) return probe.stdout.trim().split(/\r?\n/)[0];
  const fallback = "C:\\Program Files\\GitHub CLI\\gh.exe";
  if (process.platform === "win32" && existsSync(fallback)) return fallback;
  throw new Error("GitHub CLI is required to verify exact develop CI results.");
}

function verifyCi() {
  const gh = githubCli();
  execute(gh, ["auth", "status"]);
  const targets = [
    ["Idea2Strategy/Idea2Strategy", root],
    ["Idea2Strategy/Idea2Strategy-backend", join(root, "backend")],
    ["Idea2Strategy/Idea2Strategy-trading-engine", join(root, "trading-engine")],
    ["Idea2Strategy/Idea2Strategy-backtest-engine", join(root, "backtest-engine")],
    ["Idea2Strategy/Idea2Strategy-data-pipeline", join(root, "data-pipeline")],
    ["Idea2Strategy/Idea2Strategy-ui", join(root, "ui")],
  ];
  const verified = targets.map(([repository, workspace]) => {
    const commit = execute("git", ["-C", workspace, "rev-parse", "HEAD"]).stdout.trim();
    if (!/^[0-9a-f]{40}$/.test(commit)) throw new Error(`Invalid commit for ${repository}.`);
    const runs = JSON.parse(
      execute(gh, [
        "run", "list", "--repo", repository, "--commit", commit, "--workflow", "CI",
        "--limit", "10", "--json", "status,conclusion,event,headSha,url",
      ]).stdout,
    );
    const success = runs.find(
      (run) => run.headSha === commit && run.event === "push" &&
        run.status === "completed" && run.conclusion === "success",
    );
    if (!success) throw new Error(`No successful develop push CI matches ${repository}@${commit}.`);
    return { repository, commit, run: success.url };
  });
  output({ status: "passed", verified });
}

function verifyCompose() {
  const requiredFiles = [
    "compose.front.yml", "compose.back.yml", ".env.docker.example", ".dockerignore",
    "infra/docker/frontend/Dockerfile", "infra/docker/backend/Dockerfile.spring",
    "backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql",
  ];
  for (const path of requiredFiles) {
    if (!existsSync(join(root, path))) throw new Error(`Missing Docker development file: ${path}`);
  }
  const config = JSON.parse(
    execute("docker", [
      "compose", "--env-file", join(root, ".env.docker.example"),
      "-f", join(root, "compose.back.yml"), "-f", join(root, "compose.front.yml"),
      "-p", "idea2strategy-evidence", "--profile", "apps", "config", "--format", "json",
    ]).stdout,
  );
  const requiredServices = [
    "postgres", "redis", "minio", "minio-init", "localstack", "frontend", "flyway",
    "backend-api", "backend-batch", "backend-worker", "admin-mcp", "market-gateway",
    "trading-worker", "backtest-api", "backtest-worker",
  ];
  for (const service of requiredServices) {
    if (!config.services?.[service]) throw new Error(`Compose service is missing: ${service}`);
  }
  for (const service of ["postgres", "redis", "minio", "localstack", "frontend", "backend-api", "admin-mcp", "backtest-api"]) {
    for (const port of config.services[service].ports ?? []) {
      if (port.host_ip !== "127.0.0.1") throw new Error(`${service} publishes outside localhost.`);
    }
  }
  for (const service of ["backend-batch", "backend-worker", "market-gateway", "trading-worker", "backtest-worker"]) {
    if ((config.services[service].ports ?? []).length > 0) throw new Error(`${service} publishes a host port.`);
  }
  const migration = readFileSync(
    join(root, "backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql"),
    "utf8",
  );
  const tableCount = (migration.match(/^CREATE TABLE /gim) ?? []).length;
  if (tableCount !== 137) throw new Error(`Expected 137 CREATE TABLE statements; found ${tableCount}.`);
  if (/^INSERT INTO /im.test(migration)) throw new Error("Initial migration contains review-only seed data.");
  output({ status: "passed", services: requiredServices.length, application_tables: tableCount });
}

function verifyPolicy() {
  const policyRelative = "docs/collaboration-policy.md";
  const policyPath = join(root, policyRelative);
  const ownerPath = join(root, ".harness/local/project/policy/owner.yaml");
  const integrityPath = join(root, ".harness/local/project/policy/integrity.json");
  if (!existsSync(policyPath) || !existsSync(ownerPath) || !existsSync(integrityPath)) {
    throw new Error("Collaboration policy or initialized local authority metadata is missing.");
  }
  const ignored = execute("git", ["-C", root, "check-ignore", "-q", "--", ".harness/local/project/policy/integrity.json"], { allowFailure: true });
  if (ignored.status !== 0) throw new Error("Operational local harness content is not ignored by Git.");
  const tracked = execute("git", ["-C", root, "ls-files", "--", ".harness/local"]).stdout
    .split(/\r?\n/).filter(Boolean);
  for (const path of tracked) {
    if (path !== ".harness/local/README.md" && !path.endsWith("/.gitkeep")) {
      throw new Error(`Unexpected tracked local-harness content: ${path}`);
    }
  }
  const authorityRegistry = readFileSync(join(root, ".harness/product-authorities.yaml"), "utf8");
  for (const value of [
    "repository: Idea2Strategy/Idea2Strategy",
    "authority_ids: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:hjcud]",
    "before_v1: explicit-authority-instruction-recorded-in-change",
    "from_v1: pull-request-review-by-authority",
  ]) {
    if (!authorityRegistry.includes(value)) throw new Error(`Authority-registry requirement is missing: ${value}`);
  }
  const owner = readFileSync(ownerPath, "utf8");
  for (const value of ["product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:hjcud]", "contact_email_is_authority: false"]) {
    if (!owner.includes(value)) throw new Error(`Local authority requirement is missing: ${value}`);
  }
  const policy = readFileSync(policyPath, "utf8");
  const actual = createHash("sha256").update(policy).digest("hex");
  const integrity = JSON.parse(readFileSync(integrityPath, "utf8").replace(/^\uFEFF/, ""));
  if (integrity.sha256 !== actual) throw new Error("Collaboration policy differs from the local integrity baseline.");
  const clean = execute("git", ["-C", root, "diff", "--quiet", "HEAD", "--", policyRelative], { allowFailure: true });
  if (clean.status !== 0) throw new Error("Collaboration policy has an uncommitted change.");
  output({ status: "passed", policy: policyRelative, sha256: actual, product_authorities: ["user:kcrmin", "user:pjy008008", "user:Juwon-Na", "user:hjcud"] });
}

function sleep(milliseconds) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

function verifyMigration() {
  const suffix = randomBytes(6).toString("hex");
  const container = `idea2strategy-migration-${suffix}`;
  const database = "idea2strategy";
  const user = "idea2strategy";
  const password = `migration-${suffix}`;
  const migrationPath = join(root, "backend/db-migration/src/main/resources/db/migration");
  try {
    execute("docker", [
      "run", "-d", "--name", container,
      "--health-cmd", `pg_isready -U ${user} -d ${database}`,
      "--health-interval", "2s", "--health-timeout", "2s", "--health-retries", "30",
      "-e", `POSTGRES_DB=${database}`, "-e", `POSTGRES_USER=${user}`,
      "-e", `POSTGRES_PASSWORD=${password}`, "postgres:16-alpine",
    ]);
    let healthy = false;
    for (let attempt = 0; attempt < 45; attempt += 1) {
      const inspect = execute("docker", ["inspect", "--format", "{{.State.Health.Status}}", container], { allowFailure: true });
      const health = inspect.stdout.trim();
      if (health === "healthy") { healthy = true; break; }
      if (health === "unhealthy") throw new Error("Temporary PostgreSQL became unhealthy.");
      sleep(2000);
    }
    if (!healthy) throw new Error("Timed out waiting for temporary PostgreSQL.");
    execute("docker", [
      "run", "--rm", "--network", `container:${container}`,
      "-v", `${migrationPath}:/flyway/sql:ro`, "redgate/flyway:11-alpine",
      `-url=jdbc:postgresql://localhost:5432/${database}`, `-user=${user}`,
      `-password=${password}`, "-connectRetries=30", "migrate",
    ]);
    const schemas = "'identity','strategy','bot','storage','market_data','trading','backtest','performance','competition','operations'";
    const tableCount = execute("docker", [
      "exec", "-e", `PGPASSWORD=${password}`, container, "psql", "-U", user, "-d", database,
      "-Atc", `SELECT count(*) FROM information_schema.tables WHERE table_schema IN (${schemas}) AND table_type = 'BASE TABLE';`,
    ]).stdout.trim();
    const historyCount = execute("docker", [
      "exec", "-e", `PGPASSWORD=${password}`, container, "psql", "-U", user, "-d", database,
      "-Atc", "SELECT count(*) FROM flyway_schema_history WHERE success;",
    ]).stdout.trim();
    if (tableCount !== "138" || Number(historyCount) < 1) {
      throw new Error(`Unexpected migration result: tables=${tableCount}, history=${historyCount}.`);
    }
    output({ status: "passed", application_tables: 138, successful_migrations: Number(historyCount) });
  } finally {
    execute("docker", ["rm", "-f", container], { allowFailure: true });
  }
}

const verifiers = { ci: verifyCi, compose: verifyCompose, policy: verifyPolicy, migration: verifyMigration };
if (!verifiers[mode]) throw new Error(`Unknown evidence mode: ${mode ?? "<missing>"}`);
verifiers[mode]();
