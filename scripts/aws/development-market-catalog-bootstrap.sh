#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

AWS_CLI_IMAGE='amazon/aws-cli@sha256:310813a7eae8fd88da1cc9c37970e3500b0ff3984479e1012f0a6fd44e453f63'

phase=''
pipeline_image=''
pipeline_source_commit=''
source_secret_arn=''
target_secret_arn=''
bucket=''
region=''
root_sha=''
expected_object_count=''
expected_manifest_count=''
expected_source_digest=''
work_directory=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase) phase="$2"; shift 2 ;;
    --pipeline-image) pipeline_image="$2"; shift 2 ;;
    --pipeline-source-commit) pipeline_source_commit="$2"; shift 2 ;;
    --source-secret-arn) source_secret_arn="$2"; shift 2 ;;
    --target-secret-arn) target_secret_arn="$2"; shift 2 ;;
    --bucket) bucket="$2"; shift 2 ;;
    --region) region="$2"; shift 2 ;;
    --root-sha) root_sha="$2"; shift 2 ;;
    --expected-object-count) expected_object_count="$2"; shift 2 ;;
    --expected-manifest-count) expected_manifest_count="$2"; shift 2 ;;
    --expected-source-digest) expected_source_digest="$2"; shift 2 ;;
    --work-directory) work_directory="$2"; shift 2 ;;
    *) echo 'Unsupported bootstrap argument.' >&2; exit 2 ;;
  esac
done

[[ "$phase" == dry-run || "$phase" == apply ]]
[[ "$pipeline_image" =~ ^[0-9]+\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-zA-Z0-9_./-]+@sha256:[0-9a-f]{64}$ ]]
[[ "$pipeline_source_commit" =~ ^[0-9a-f]{40}$ ]]
[[ "$source_secret_arn" == arn:aws:secretsmanager:* ]]
[[ "$target_secret_arn" == arn:aws:secretsmanager:* ]]
[[ "$bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]
[[ "$region" == ap-northeast-2 ]]
[[ "$root_sha" =~ ^[0-9a-f]{40}$ ]]
[[ "$expected_object_count" =~ ^[1-9][0-9]*$ ]]
[[ "$expected_manifest_count" =~ ^[1-9][0-9]*$ ]]
[[ -n "$work_directory" ]]
if [[ "$phase" == apply ]]; then
  [[ "$expected_source_digest" =~ ^[0-9a-f]{64}$ ]]
fi

install -d -m 0700 "$work_directory"
install -d -o 10001 -g 10001 -m 0700 "$work_directory/evidence"
source_secret="$work_directory/legacy-secret.json"
target_secret="$work_directory/canonical-secret.json"
credentials_env="$work_directory/database.env"
dry_report="$work_directory/dry-run.json"
apply_report="$work_directory/apply.json"
replay_report="$work_directory/replay.json"
error_log="$work_directory/command-error.log"

cleanup() {
  rm -f -- "$credentials_env" "$source_secret" "$target_secret" "$error_log"
  docker logout "${pipeline_image%%/*}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

aws_cli() {
  docker run --rm --network host \
    --env AWS_REGION="$region" --env AWS_DEFAULT_REGION="$region" \
    --volume "$work_directory:$work_directory" \
    "$AWS_CLI_IMAGE" "$@"
}

aws_cli secretsmanager get-secret-value --secret-id "$source_secret_arn" \
  --query SecretString --output text >"$source_secret"
aws_cli secretsmanager get-secret-value --secret-id "$target_secret_arn" \
  --query SecretString --output text >"$target_secret"
chmod 0600 "$source_secret" "$target_secret"

# Secret values are read from owner-only files and written to Docker's env-file.
# Neither a database URL nor a password is ever placed in argv or stdout.
python3 - "$source_secret" "$target_secret" >"$credentials_env" <<'PY'
import json
import sys
from pathlib import Path
from urllib.parse import quote

def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def url(document, preferred):
    direct = document.get(preferred) or document.get("DATABASE_URL")
    if direct:
        value = str(direct)
    else:
        required = ("host", "port", "dbname", "username", "password")
        if any(not str(document.get(field, "")) for field in required):
            raise SystemExit("database secret is missing required fields")
        value = "postgresql+psycopg://%s:%s@%s:%s/%s?sslmode=require" % (
            quote(str(document["username"]), safe=""),
            quote(str(document["password"]), safe=""),
            document["host"], document["port"],
            quote(str(document["dbname"]), safe=""),
        )
    if "\n" in value or "\r" in value:
        raise SystemExit("database URL contains a newline")
    return value

legacy = url(load(sys.argv[1]), "LEGACY_DATABASE_URL")
target = url(load(sys.argv[2]), "PIPELINE_WORKER_DATABASE_URL")
if legacy == target:
    raise SystemExit("legacy and canonical database URLs must differ")
print("LEGACY_DATABASE_URL=" + legacy)
print("DATABASE_URL=" + target)
PY
chmod 0600 "$credentials_env"
rm -f -- "$source_secret" "$target_secret"

registry="${pipeline_image%%/*}"
aws_cli ecr get-login-password | docker login --username AWS --password-stdin "$registry" >/dev/null
docker pull "$pipeline_image" >/dev/null

run_catalog() {
  local output_path="$1"
  shift
  if ! docker run --rm --network host \
    --env-file "$credentials_env" \
    --env AWS_REGION="$region" --env AWS_DEFAULT_REGION="$region" \
    --volume "$work_directory/evidence:/evidence" \
    --entrypoint market-pipeline "$pipeline_image" \
    bootstrap-legacy-catalog \
    --artifact-root /evidence \
    --bucket "$bucket" \
    --expected-object-count "$expected_object_count" \
    --expected-manifest-count "$expected_manifest_count" \
    "$@" >"$output_path" 2>"$error_log"; then
    echo 'Market catalog command failed; sanitized diagnostics follow.' >&2
    sed -E \
      -e 's#(postgresql(\+psycopg)?://)[^@[:space:]]+@#\1<redacted>@#g' \
      -e 's#((password|secret|token|api[_-]?key)[=:])[^[:space:]]+#\1<redacted>#Ig' \
      "$error_log" | tail -n 20 >&2
    exit 1
  fi
  jq -e 'type == "object"' "$output_path" >/dev/null
  : >"$error_log"
}

run_catalog "$dry_report"
jq -e --argjson objects "$expected_object_count" --argjson manifests "$expected_manifest_count" \
  '.status == "DRY_RUN" and .verified_object_count == $objects and .manifest_count == $manifests and (.source_digest | test("^[0-9a-f]{64}$"))' \
  "$dry_report" >/dev/null
observed_source_digest="$(jq -er '.source_digest' "$dry_report")"

if [[ "$phase" == dry-run ]]; then
  jq -cn \
    --arg status passed --arg phase DryRun --arg root_sha "$root_sha" \
    --arg pipeline_source_commit "$pipeline_source_commit" --arg pipeline_image "$pipeline_image" \
    --arg bucket "$bucket" --argjson dry_run "$(cat "$dry_report")" \
    '{status:$status,phase:$phase,root_sha:$root_sha,pipeline_source_commit:$pipeline_source_commit,pipeline_image:$pipeline_image,bucket:$bucket,dry_run:$dry_run}'
  exit 0
fi

test "$observed_source_digest" = "$expected_source_digest"
run_catalog "$apply_report" --execute
jq -e --arg digest "$expected_source_digest" \
  '(.status == "APPLIED" or .status == "ALREADY_APPLIED") and .source_digest == $digest' \
  "$apply_report" >/dev/null
run_catalog "$replay_report" --execute
jq -e --arg digest "$expected_source_digest" \
  '.status == "ALREADY_APPLIED" and .source_digest == $digest and .inserted_row_count == 0' \
  "$replay_report" >/dev/null

jq -cn \
  --arg status passed --arg phase Apply --arg root_sha "$root_sha" \
  --arg pipeline_source_commit "$pipeline_source_commit" --arg pipeline_image "$pipeline_image" \
  --arg bucket "$bucket" --argjson dry_run "$(cat "$dry_report")" \
  --argjson applied "$(cat "$apply_report")" --argjson replay "$(cat "$replay_report")" \
  '{status:$status,phase:$phase,root_sha:$root_sha,pipeline_source_commit:$pipeline_source_commit,pipeline_image:$pipeline_image,bucket:$bucket,dry_run:$dry_run,applied:$applied,replay:$replay}'
