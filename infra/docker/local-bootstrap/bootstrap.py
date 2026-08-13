#!/usr/bin/env python3
"""Single Compose gate for immutable baseline restore, conversion, and verification."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path
from urllib.parse import quote_plus

import boto3
import psycopg
from botocore.exceptions import ClientError
from psycopg import sql


BACKUP = Path("/backup").resolve()
STATE = Path("/state").resolve()
SCRIPTS = Path("/app/scripts")
PIN = json.loads(Path("/app/config/fixed-market-data-baseline.json").read_text(encoding="utf-8"))


def required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"required environment variable is missing: {name}")
    return value


PG_HOST = required("POSTGRES_HOST")
PG_PORT = int(required("POSTGRES_PORT"))
PG_DATABASE = required("POSTGRES_DB")
PG_USER = required("POSTGRES_USER")
PG_PASSWORD = required("POSTGRES_PASSWORD")
APP_USER = required("APP_POSTGRES_USER")
APP_PASSWORD = required("APP_POSTGRES_PASSWORD")
MINIO_ENDPOINT = required("MINIO_ENDPOINT")
MINIO_ROOT_USER = required("MINIO_ROOT_USER")
MINIO_ROOT_PASSWORD = required("MINIO_ROOT_PASSWORD")
APP_S3_ACCESS_KEY = required("APP_S3_ACCESS_KEY")
APP_S3_SECRET_KEY = required("APP_S3_SECRET_KEY")
MARKET_BUCKET = required("S3_MARKET_DATA_BUCKET")
RESULTS_BUCKET = required("S3_RESULTS_BUCKET")


def database_url(database: str, *, user: str = PG_USER, password: str = PG_PASSWORD) -> str:
    return f"postgresql+psycopg://{quote_plus(user)}:{quote_plus(password)}@{PG_HOST}:{PG_PORT}/{database}"


def psycopg_url(database: str, *, user: str = PG_USER, password: str = PG_PASSWORD) -> str:
    return f"postgresql://{quote_plus(user)}:{quote_plus(password)}@{PG_HOST}:{PG_PORT}/{database}"


def run(arguments: list[str]) -> None:
    completed = subprocess.run(arguments, check=False)
    if completed.returncode != 0:
        raise RuntimeError(f"bootstrap command failed with exit code {completed.returncode}: {arguments[0]}")


def wait_postgres() -> None:
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        try:
            with psycopg.connect(psycopg_url("postgres"), connect_timeout=3):
                return
        except psycopg.Error:
            time.sleep(2)
    raise RuntimeError("PostgreSQL did not become ready")


def load_and_pin_manifest() -> tuple[dict[str, object], str]:
    manifest_path = BACKUP / "backup-manifest.json"
    if not manifest_path.is_file():
        raise RuntimeError("BACKUP_PATH does not contain backup-manifest.json")
    payload = manifest_path.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    if digest != PIN["manifest_sha256"]:
        raise RuntimeError(f"backup manifest SHA-256 is not the team baseline: {digest}")
    manifest = json.loads(payload.decode("utf-8-sig"))
    if manifest["database"]["sha256"] != PIN["database_dump_sha256"]:
        raise RuntimeError("database dump SHA-256 pin differs from the manifest")
    expected = {
        "s3_versions": int(manifest["s3"]["current_versions"]) + int(manifest["s3"]["noncurrent_versions"]),
        "delete_markers": int(manifest["s3"]["delete_markers"]),
        "storage_objects": int(manifest["database"]["row_counts"]["storage_objects"]),
        "dataset_manifests": int(manifest["database"]["row_counts"]["dataset_manifests"]),
        "dataset_objects": int(manifest["database"]["row_counts"]["dataset_objects"]),
        "dataset_lineage": int(manifest["database"]["row_counts"]["dataset_lineage"]),
    }
    for key, value in expected.items():
        if value != int(PIN[key]):
            raise RuntimeError(f"backup manifest {key} differs from the team pin")
    return manifest, digest


def ensure_legacy_database(name: str, manifest: dict[str, object]) -> None:
    dump_path = BACKUP / "database.dump"
    if not dump_path.is_file():
        raise RuntimeError("BACKUP_PATH does not contain database.dump")
    dump_sha256 = hashlib.sha256(dump_path.read_bytes()).hexdigest()
    if dump_sha256 != PIN["database_dump_sha256"]:
        raise RuntimeError(f"RDS dump SHA-256 is not the team baseline: {dump_sha256}")

    with psycopg.connect(psycopg_url("postgres"), autocommit=True) as connection:
        connection.execute(sql.SQL("DROP DATABASE IF EXISTS {} WITH (FORCE)").format(sql.Identifier(name)))
        connection.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
    env = {**os.environ, "PGPASSWORD": PG_PASSWORD}
    completed = subprocess.run(
        [
            "pg_restore", "--no-owner", "--no-privileges",
            "--host", PG_HOST, "--port", str(PG_PORT), "--username", PG_USER,
            "--dbname", name, str(dump_path),
        ],
        env=env,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.stdout:
        print(completed.stdout, end="")
    if completed.stderr:
        print(completed.stderr, file=sys.stderr, end="")
    if completed.returncode != 0:
        error_lines = [line for line in completed.stderr.splitlines() if "error:" in line.lower()]
        known_pg17_to_pg16_warning = (
            len(error_lines) == 1
            and "unrecognized configuration parameter" in error_lines[0]
            and "transaction_timeout" in completed.stderr
            and "SET transaction_timeout = 0" in completed.stderr
        )
        if not known_pg17_to_pg16_warning:
            raise RuntimeError("full RDS dump restore into the isolated legacy DB failed")
        print("Accepted the single known PostgreSQL 17 -> 16 transaction_timeout restore warning.")
    counts = manifest["database"]["row_counts"]
    with psycopg.connect(psycopg_url(name)) as connection:
        history = connection.execute(
            "SELECT version, script FROM public.flyway_schema_history WHERE success ORDER BY installed_rank"
        ).fetchall()
        if history != [("001", "V001__market_data_initial_schema.sql")]:
            raise RuntimeError(f"legacy DB does not have the exact retired V001 history: {history!r}")
        checks = {
            "storage_objects": "SELECT count(*) FROM storage.objects",
            "dataset_manifests": "SELECT count(*) FROM market_data.dataset_manifests",
            "dataset_objects": "SELECT count(*) FROM market_data.dataset_objects",
            "dataset_lineage": "SELECT count(*) FROM market_data.dataset_lineage",
        }
        for key, statement in checks.items():
            observed = int(connection.execute(statement).fetchone()[0])
            if observed != int(counts[key]):
                raise RuntimeError(f"legacy DB {key} count differs: {observed}")


def configure_database_access() -> None:
    with psycopg.connect(psycopg_url(PG_DATABASE), autocommit=True) as connection:
        if connection.execute("SELECT 1 FROM pg_roles WHERE rolname=%s", (APP_USER,)).fetchone():
            connection.execute(
                sql.SQL("ALTER ROLE {} LOGIN PASSWORD {}").format(sql.Identifier(APP_USER), sql.Literal(APP_PASSWORD))
            )
        else:
            connection.execute(
                sql.SQL("CREATE ROLE {} LOGIN PASSWORD {}").format(sql.Identifier(APP_USER), sql.Literal(APP_PASSWORD))
            )
        schemas = [
            row[0]
            for row in connection.execute(
                "SELECT nspname FROM pg_namespace WHERE nspname NOT LIKE 'pg_%' AND nspname <> 'information_schema'"
            )
        ]
        for schema in schemas:
            schema_id = sql.Identifier(schema)
            role_id = sql.Identifier(APP_USER)
            connection.execute(sql.SQL("GRANT USAGE ON SCHEMA {} TO {}").format(schema_id, role_id))
            connection.execute(
                sql.SQL("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA {} TO {}").format(schema_id, role_id)
            )
            connection.execute(
                sql.SQL("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA {} TO {}").format(schema_id, role_id)
            )
        for schema in ("market_data", "storage"):
            connection.execute(
                sql.SQL(
                    "REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA {} FROM {}"
                ).format(sql.Identifier(schema), sql.Identifier(APP_USER))
            )
        for schema in ("local_dev", "local_results"):
            connection.execute(
                sql.SQL("CREATE SCHEMA IF NOT EXISTS {} AUTHORIZATION {}").format(
                    sql.Identifier(schema), sql.Identifier(APP_USER)
                )
            )
            connection.execute(
                sql.SQL("GRANT ALL ON SCHEMA {} TO {}").format(sql.Identifier(schema), sql.Identifier(APP_USER))
            )

    try:
        with psycopg.connect(psycopg_url(PG_DATABASE, user=APP_USER, password=APP_PASSWORD)) as application:
            application.execute("INSERT INTO market_data.providers DEFAULT VALUES")
        raise RuntimeError("application role unexpectedly wrote to fixed market_data")
    except psycopg.errors.InsufficientPrivilege:
        pass
    with psycopg.connect(psycopg_url(PG_DATABASE, user=APP_USER, password=APP_PASSWORD)) as application:
        application.execute("CREATE TABLE local_results.bootstrap_write_probe(id integer)")
        application.execute("INSERT INTO local_results.bootstrap_write_probe VALUES (1)")
        application.rollback()


def minio_client(access: str, secret: str):
    return boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=access,
        aws_secret_access_key=secret,
        region_name="ap-northeast-2",
    )


def count_minio_events() -> int:
    count = 0
    client = minio_client(MINIO_ROOT_USER, MINIO_ROOT_PASSWORD)
    for page in client.get_paginator("list_object_versions").paginate(Bucket=MARKET_BUCKET):
        count += len(page.get("Versions", [])) + len(page.get("DeleteMarkers", []))
    return count


def verify_minio_access() -> None:
    client = minio_client(APP_S3_ACCESS_KEY, APP_S3_SECRET_KEY)
    try:
        client.put_object(Bucket=MARKET_BUCKET, Key="__bootstrap_write_probe__", Body=b"blocked")
        raise RuntimeError("application MinIO account unexpectedly wrote to fixed market bucket")
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") not in {"AccessDenied", "XMinioAdminNoSuchUser"}:
            raise
    key = f"bootstrap-write-probe/{uuid.uuid4()}.txt"
    response = client.put_object(Bucket=RESULTS_BUCKET, Key=key, Body=b"writable")
    if not response.get("VersionId"):
        raise RuntimeError("results bucket did not return a VersionId")
    client.get_object(Bucket=RESULTS_BUCKET, Key=key, VersionId=response["VersionId"])["Body"].read()
    client.delete_object(Bucket=RESULTS_BUCKET, Key=key)


def quick_completed_check(marker: Path, manifest_digest: str, legacy_database: str) -> bool:
    if not marker.is_file():
        return False
    state = json.loads(marker.read_text(encoding="utf-8"))
    if state.get("manifest_sha256") != manifest_digest:
        raise RuntimeError("bootstrap completion marker belongs to another manifest")
    with psycopg.connect(psycopg_url(PG_DATABASE)) as connection:
        counts = connection.execute(
            "SELECT (SELECT count(*) FROM storage.objects), "
            "(SELECT count(*) FROM market_data.dataset_manifests), "
            "(SELECT count(*) FROM market_data.dataset_objects), "
            "(SELECT count(*) FROM market_data.dataset_lineage)"
        ).fetchone()
    if tuple(map(int, counts)) != (768, 96, 768, 72):
        raise RuntimeError("completed canonical DB counts drifted")
    if count_minio_events() != int(PIN["minio_mapping_events"]):
        raise RuntimeError("completed MinIO version mapping count drifted")
    print(json.dumps({"status": "ALREADY_BOOTSTRAPPED", "manifest_sha256": manifest_digest, "legacy_database": legacy_database}))
    return True


def main() -> int:
    wait_postgres()
    manifest, digest = load_and_pin_manifest()
    version_state = STATE / digest
    version_state.mkdir(parents=True, exist_ok=True)
    marker = version_state / "complete.json"
    receipt = version_state / "minio-restore-receipt.json"
    legacy_database = f"idea2strategy_legacy_{digest[:12]}"
    if quick_completed_check(marker, digest, legacy_database):
        return 0

    ensure_legacy_database(legacy_database, manifest)
    os.environ.update({
        "LEGACY_DATABASE_URL": database_url(legacy_database),
        "CANONICAL_DATABASE_URL": database_url(PG_DATABASE),
        "MINIO_ACCESS_KEY": MINIO_ROOT_USER,
        "MINIO_SECRET_KEY": MINIO_ROOT_PASSWORD,
    })
    run([
        sys.executable, str(SCRIPTS / "restore-raw-market-data.py"),
        "--backup", str(BACKUP), "--receipt", str(receipt),
        "--bucket", MARKET_BUCKET,
    ])
    run([
        sys.executable, str(SCRIPTS / "migrate-legacy-market-data.py"),
        "--backup", str(BACKUP),
        "--source-bucket", str(manifest["source_bucket"]), "--target-bucket", MARKET_BUCKET,
        "--minio-receipt", str(receipt), "--expected-object-count", str(PIN["storage_objects"]),
        "--expected-manifest-count", str(PIN["dataset_manifests"]), "--execute",
    ])
    configure_database_access()
    verify_minio_access()
    run([
        sys.executable, str(SCRIPTS / "verify-fixed-market-data.py"),
        "--backup", str(BACKUP),
        "--minio-receipt", str(receipt),
    ])
    temporary = marker.with_suffix(".tmp")
    temporary.write_text(
        json.dumps({"manifest_sha256": digest, "status": "VERIFIED", "legacy_database": legacy_database}, indent=2),
        encoding="utf-8",
    )
    temporary.replace(marker)
    print(json.dumps({"status": "BOOTSTRAPPED_AND_VERIFIED", "manifest_sha256": digest}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
