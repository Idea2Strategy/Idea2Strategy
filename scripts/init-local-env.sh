#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
force=0
if [ "${1:-}" = "--force" ]; then
  force=1
  shift
fi
backup_path=${1:-./.local-data/baseline-2026-08-13}
if [ ! -f "$backup_path/backup-manifest.json" ]; then
  echo "Backup path has no backup-manifest.json: $backup_path" >&2
  exit 1
fi
if [ -e .env ] && [ "$force" -ne 1 ]; then
  echo '.env already exists. Use --force only when intentionally rotating all local credentials.' >&2
  exit 1
fi
command -v openssl >/dev/null 2>&1 || { echo 'openssl is required.' >&2; exit 1; }

secret() {
  openssl rand -base64 32 | tr -d '\n=' | tr '+/' 'AB'
}

umask 077
temporary=".env.tmp.$$"
trap 'rm -f "$temporary"' EXIT HUP INT TERM
{
  printf 'DBDIAGRAM_TOKEN=\n'
  printf 'BACKUP_PATH=%s\n' "$backup_path"
  printf 'POSTGRES_PASSWORD=%s\n' "$(secret)"
  printf 'APP_POSTGRES_PASSWORD=%s\n' "$(secret)"
  printf 'MINIO_ROOT_PASSWORD=%s\n' "$(secret)"
  printf 'APP_S3_SECRET_KEY=%s\n' "$(secret)"
  printf 'IDENTITY_CRYPTO_EMAIL_ENCRYPTION_KEY=%s\n' "$(secret)"
  printf 'IDENTITY_CRYPTO_LOOKUP_HMAC_KEY=%s\n' "$(secret)"
  printf 'IDENTITY_CRYPTO_VERIFICATION_HMAC_KEY=%s\n' "$(secret)"
  printf 'IDENTITY_CRYPTO_REFRESH_TOKEN_HMAC_KEY=%s\n' "$(secret)"
  printf 'IDENTITY_CRYPTO_CUSTOMER_JWT_SIGNING_KEY=%s\n' "$(secret)"
  printf 'BACKTEST_RESULT_INGEST_TOKEN=%s\n' "$(secret)"
} > "$temporary"
chmod 600 "$temporary"
mv -f "$temporary" .env
trap - EXIT HUP INT TERM
echo 'Created ignored .env with new local-only credentials.'
