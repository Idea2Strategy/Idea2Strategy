#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

readonly FLYWAY_IMAGE='redgate/flyway@sha256:52cdd559dc8ae38a17b56615e3c7137d9b01470271112525b40373de470bb005'
readonly AWS_CLI_IMAGE='amazon/aws-cli@sha256:310813a7eae8fd88da1cc9c37970e3500b0ff3984479e1012f0a6fd44e453f63'
readonly CONSUMERS=(backend batch backtest trading pipeline)

archive=''
archive_sha256=''
bundle_sha256=''
expected_migration_count=''
database_host=''
database_name=''
database_port=''
master_secret_arn=''
policy_seed_sql=''
policy_seed_sha256=''
scoring_seed_sql=''
scoring_seed_sha256=''
region=''
root_sha=''
runtime_secret_arns_base64=''
work_directory=''

while (($#)); do
  case "$1" in
    --archive) archive="$2"; shift 2 ;;
    --archive-sha256) archive_sha256="$2"; shift 2 ;;
    --bundle-sha256) bundle_sha256="$2"; shift 2 ;;
    --expected-migration-count) expected_migration_count="$2"; shift 2 ;;
    --database-host) database_host="$2"; shift 2 ;;
    --database-name) database_name="$2"; shift 2 ;;
    --database-port) database_port="$2"; shift 2 ;;
    --master-secret-arn) master_secret_arn="$2"; shift 2 ;;
    --policy-seed-sql) policy_seed_sql="$2"; shift 2 ;;
    --policy-seed-sha256) policy_seed_sha256="$2"; shift 2 ;;
    --scoring-seed-sql) scoring_seed_sql="$2"; shift 2 ;;
    --scoring-seed-sha256) scoring_seed_sha256="$2"; shift 2 ;;
    --region) region="$2"; shift 2 ;;
    --root-sha) root_sha="$2"; shift 2 ;;
    --runtime-secret-arns-base64) runtime_secret_arns_base64="$2"; shift 2 ;;
    --work-directory) work_directory="$2"; shift 2 ;;
    *) echo 'Unsupported database bootstrap argument.' >&2; exit 64 ;;
  esac
done

for required in archive archive_sha256 bundle_sha256 expected_migration_count database_host database_name database_port master_secret_arn policy_seed_sql policy_seed_sha256 scoring_seed_sql scoring_seed_sha256 region root_sha runtime_secret_arns_base64 work_directory; do
  test -n "${!required}" || { echo "Missing required argument: $required" >&2; exit 64; }
done
[[ "$archive_sha256" =~ ^[0-9a-f]{64}$ ]]
[[ "$bundle_sha256" =~ ^[0-9a-f]{64}$ ]]
[[ "$expected_migration_count" =~ ^[1-9][0-9]*$ ]]
[[ "$policy_seed_sha256" =~ ^[0-9a-f]{64}$ ]]
[[ "$scoring_seed_sha256" =~ ^[0-9a-f]{64}$ ]]
[[ "$root_sha" =~ ^[0-9a-f]{40}$ ]]
[[ "$region" == 'ap-northeast-2' ]]
[[ "$database_host" =~ ^[A-Za-z0-9.-]+$ ]]
[[ "$database_name" =~ ^[A-Za-z0-9_]+$ ]]
[[ "$database_port" =~ ^[0-9]+$ ]]
[[ "$master_secret_arn" == arn:aws:secretsmanager:* ]]

mkdir -p "$work_directory"
chmod 0700 "$work_directory"

aws() {
  docker run --rm --network host \
    --volume "$work_directory:$work_directory:ro" \
    --env AWS_REGION="$region" --env AWS_DEFAULT_REGION="$region" \
    "$AWS_CLI_IMAGE" "$@"
}

pull_image() {
  local image="$1" attempt
  for attempt in 1 2 3 4 5; do
    docker pull "$image" >/dev/null && return 0
    sleep $((attempt * 5))
  done
  echo "Database bootstrap image pull failed after retries: $image" >&2
  return 1
}

aws_retry() {
  local attempt
  for attempt in 1 2 3 4 5; do
    aws "$@" && return 0
    sleep $((attempt * 5))
  done
  echo 'Database bootstrap AWS command failed after retries.' >&2
  return 1
}

master_json=''
seed_role='idea2strategy_policy_seed_bootstrap'
declare -A passwords=()
declare -A old_passwords=()
declare -A old_versions=()
declare -A new_versions=()
declare -A promoted_versions=()
rotation_started=false
rotation_committed=false
initial_rotation=false
pending_cleanup_complete=false
drop_seed_role() {
  local exists
  exists="$(PGUSER="$master_username" PGPASSWORD="$master_password" psql -X -qAt -v ON_ERROR_STOP=1 -c \
    "SELECT 1 FROM pg_roles WHERE rolname = '$seed_role';")"
  if [[ "$exists" == '1' ]]; then
    PGUSER="$master_username" PGPASSWORD="$master_password" psql -X -q -v ON_ERROR_STOP=1 <<SQL >/dev/null
REVOKE CONNECT ON DATABASE "$database_name" FROM $seed_role;
REVOKE USAGE ON SCHEMA trading, backtest FROM $seed_role;
REVOKE SELECT, INSERT ON TABLE trading.fee_policy_versions, trading.buying_power_buffer_policy_versions, backtest.execution_policy_versions FROM $seed_role;
REVOKE USAGE ON SCHEMA competition FROM $seed_role;
REVOKE SELECT, INSERT ON TABLE competition.scoring_template_versions FROM $seed_role;
DROP ROLE $seed_role;
SQL
  fi
}
rollback_runtime_credentials() {
  local consumer secret_arn rollback_sql
  local rollback_failed=false
  if [[ "$rotation_started" == true && "$rotation_committed" != true ]]; then
    rollback_sql="$work_directory/runtime-roles-rollback.sql"
    {
      echo 'BEGIN;'
      if [[ "$initial_rotation" == true ]]; then
        for consumer in "${CONSUMERS[@]}"; do
          printf "SELECT format('REVOKE %%I FROM %%I', 'idea2strategy_%s', 'idea2strategy_%s_runtime') WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'idea2strategy_%s_runtime') \\gexec\n" "$consumer" "$consumer" "$consumer"
          printf 'DROP ROLE IF EXISTS idea2strategy_%s_runtime;\n' "$consumer"
        done
      else
        for consumer in "${CONSUMERS[@]}"; do
          printf "ALTER ROLE idea2strategy_%s_runtime PASSWORD '%s';\n" "$consumer" "${old_passwords[$consumer]}"
        done
      fi
      echo 'COMMIT;'
    } >"$rollback_sql"
    chmod 0600 "$rollback_sql"
    PGUSER="$master_username" PGPASSWORD="$master_password" psql -X -q -v ON_ERROR_STOP=1 -f "$rollback_sql" >/dev/null || rollback_failed=true
    rm -f -- "$rollback_sql"

    for consumer in "${CONSUMERS[@]}"; do
      if [[ -n "${promoted_versions[$consumer]:-}" ]]; then
        secret_arn="$(jq -er --arg consumer "$consumer" '.[$consumer]' "$runtime_secret_arns_file")"
        if [[ "$initial_rotation" == true && -z "${old_versions[$consumer]:-}" ]]; then
          aws_retry secretsmanager update-secret-version-stage --region "$region" --secret-id "$secret_arn" \
            --version-stage AWSCURRENT --remove-from-version-id "${new_versions[$consumer]}" >/dev/null || rollback_failed=true
        else
          aws_retry secretsmanager update-secret-version-stage --region "$region" --secret-id "$secret_arn" \
            --version-stage AWSCURRENT --move-to-version-id "${old_versions[$consumer]}" \
            --remove-from-version-id "${new_versions[$consumer]}" >/dev/null || rollback_failed=true
        fi
      fi
    done
  fi

  if [[ "$pending_cleanup_complete" != true ]]; then
    for consumer in "${CONSUMERS[@]}"; do
      if [[ -n "${new_versions[$consumer]:-}" ]]; then
        secret_arn="$(jq -er --arg consumer "$consumer" '.[$consumer]' "$runtime_secret_arns_file")"
        aws_retry secretsmanager update-secret-version-stage --region "$region" --secret-id "$secret_arn" \
          --version-stage AWSPENDING --remove-from-version-id "${new_versions[$consumer]}" >/dev/null || rollback_failed=true
      fi
    done
  fi
  if [[ "$rollback_failed" == true ]]; then
    echo 'Database bootstrap credential rollback failed and requires operator attention.' >&2
    return 1
  fi
}
cleanup() {
  local status=$?
  local rollback_status=0
  trap - EXIT
  set +e
  if [[ -n "${PGHOST:-}" && -n "${PGDATABASE:-}" && -n "${master_username:-}" && -n "${master_password:-}" ]]; then
    rollback_runtime_credentials || rollback_status=$?
    drop_seed_role >/dev/null 2>&1
  fi
  master_json=''
  for consumer in "${CONSUMERS[@]}"; do
    passwords["$consumer"]=''
    old_passwords["$consumer"]=''
  done
  find "$work_directory" -type f -exec chmod 0600 {} + 2>/dev/null
  rm -rf -- "$work_directory"
  if [[ "$rollback_status" -ne 0 ]]; then
    exit 68
  fi
  exit "$status"
}
trap cleanup EXIT

printf '%s  %s\n' "$archive_sha256" "$archive" | sha256sum --check --status
printf '%s  %s\n' "$policy_seed_sha256" "$policy_seed_sql" | sha256sum --check --status
printf '%s  %s\n' "$scoring_seed_sha256" "$scoring_seed_sql" | sha256sum --check --status
if grep -Eq "^[[:space:]]*\\\\" "$policy_seed_sql" ||
   grep -Eiq '(^|[^A-Za-z_])(alter|create|drop|grant|revoke|copy|do|call|truncate|delete|update|merge|begin|commit|rollback|set[[:space:]]+role|reset[[:space:]]+role)([^A-Za-z_]|$)' "$policy_seed_sql"; then
  echo 'Policy seed SQL contains a forbidden command or psql metacommand.' >&2
  exit 65
fi
mapfile -t policy_seed_targets < <(grep -Poi '\binsert\s+into\s+\K(?:(?:"?[a-z_]+"?)\.)?"?[a-z_]+"?' "$policy_seed_sql" | tr -d '"' | tr '[:upper:]' '[:lower:]')
test "${#policy_seed_targets[@]}" -ge 3
for required_target in trading.fee_policy_versions trading.buying_power_buffer_policy_versions backtest.execution_policy_versions; do
  printf '%s\n' "${policy_seed_targets[@]}" | grep -Fxq "$required_target"
done

if grep -Eq "^[[:space:]]*\\\\" "$scoring_seed_sql" ||
   grep -Eiq '(^|[^A-Za-z_])(alter|create|drop|grant|revoke|copy|do|call|truncate|delete|update|merge|begin|commit|rollback|set[[:space:]]+role|reset[[:space:]]+role)([^A-Za-z_]|$)' "$scoring_seed_sql"; then
  echo 'Scoring seed SQL contains a forbidden command or psql metacommand.' >&2
  exit 65
fi
mapfile -t scoring_seed_targets < <(grep -Poi '\binsert\s+into\s+\K(?:(?:"?[a-z_]+"?)\.)?"?[a-z_]+"?' "$scoring_seed_sql" | tr -d '"' | tr '[:upper:]' '[:lower:]')
test "${#scoring_seed_targets[@]}" -ge 4
for target in "${scoring_seed_targets[@]}"; do
  [[ "$target" == 'competition.scoring_template_versions' ]] || {
    echo "Scoring seed SQL targets a forbidden table: $target" >&2
    exit 65
  }
done
for target in "${policy_seed_targets[@]}"; do
  case "$target" in
    trading.fee_policy_versions|trading.buying_power_buffer_policy_versions|backtest.execution_policy_versions) ;;
    *) echo "Policy seed SQL targets a forbidden table: $target" >&2; exit 65 ;;
  esac
done

if tar -tzf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  echo 'Unsafe path in Flyway archive.' >&2
  exit 65
fi
tar -xzf "$archive" -C "$work_directory"
bundle_directory="$work_directory/flyway-ci-bundle"
manifest="$bundle_directory/migration-bundle.manifest"
recorded_digest="$bundle_directory/migration-bundle.sha256"
test -f "$manifest" && test -f "$recorded_digest"
test "$(tr -d '\r\n' <"$recorded_digest")" = "$bundle_sha256"
printf '%s  %s\n' "$bundle_sha256" "$manifest" | sha256sum --check --status
test "$(head -n 1 "$manifest" | tr -d '\r')" = 'idea2strategy-flyway-bundle-v1'

sql_count=0
declare -A listed_migrations=()
declare -A listed_versions=()
while IFS=$'\t' read -r migration expected_hash; do
  migration="${migration%$'\r'}"
  expected_hash="${expected_hash%$'\r'}"
  [[ "$migration" =~ ^[VR][A-Za-z0-9_.-]+\.sql$ ]] || { echo 'Invalid Flyway manifest migration name.' >&2; exit 65; }
  [[ "$expected_hash" =~ ^[0-9a-f]{64}$ ]] || { echo 'Invalid Flyway manifest checksum.' >&2; exit 65; }
  normalized_migration="${migration,,}"
  [[ -z "${listed_migrations[$normalized_migration]+x}" ]] || { echo "Duplicate Flyway manifest migration: $migration" >&2; exit 65; }
  listed_migrations["$normalized_migration"]=1
  if [[ "$migration" =~ ^V([0-9]+([._][0-9]+)*)__ ]]; then
    version="${BASH_REMATCH[1]}"
    normalized_version=''
    IFS='._' read -ra version_segments <<<"$version"
    for segment in "${version_segments[@]}"; do
      segment="${segment#${segment%%[!0]*}}"
      [[ -n "$segment" ]] || segment='0'
      normalized_version+="${normalized_version:+.}${segment}"
    done
    [[ -z "${listed_versions[$normalized_version]+x}" ]] || {
      echo "Duplicate Flyway migration version $normalized_version: $migration and ${listed_versions[$normalized_version]}" >&2
      exit 65
    }
    listed_versions["$normalized_version"]="$migration"
  fi
  test -f "$bundle_directory/$migration" || { echo "Flyway migration is missing: $migration" >&2; exit 65; }
  printf '%s  %s\n' "$expected_hash" "$bundle_directory/$migration" | sha256sum --check --status || {
    echo "Flyway migration checksum mismatch: $migration" >&2
    exit 65
  }
  sql_count=$((sql_count + 1))
done < <(tail -n +2 "$manifest")
test "$sql_count" -gt 0 || { echo 'Flyway manifest must contain at least one migration.' >&2; exit 65; }
test "$sql_count" = "$expected_migration_count" || { echo 'Flyway manifest migration count does not match the validated invocation.' >&2; exit 65; }
mapfile -t bundle_sql_files < <(find "$bundle_directory" -maxdepth 1 -type f -name '*.sql' -printf '%f\n' | sort)
test "${#bundle_sql_files[@]}" = "$sql_count" || { echo 'Flyway bundle SQL file count does not match the exact manifest.' >&2; exit 65; }
for sql_file in "${bundle_sql_files[@]}"; do
  normalized_migration="${sql_file,,}"
  [[ -n "${listed_migrations[$normalized_migration]+x}" ]] || { echo "Flyway migration is not listed in the manifest: $sql_file" >&2; exit 65; }
done

runtime_secret_arns_file="$work_directory/runtime-secret-arns.json"
printf '%s' "$runtime_secret_arns_base64" | base64 --decode >"$runtime_secret_arns_file"
chmod 0600 "$runtime_secret_arns_file"
test "$(jq -r 'keys | sort | join(",")' "$runtime_secret_arns_file")" = 'backend,backtest,batch,pipeline,trading'
for consumer in "${CONSUMERS[@]}"; do
  jq -er --arg consumer "$consumer" '.[$consumer] | select(startswith("arn:aws:secretsmanager:"))' "$runtime_secret_arns_file" >/dev/null
done

pull_image "$AWS_CLI_IMAGE"
pull_image "$FLYWAY_IMAGE"

master_json="$(aws_retry secretsmanager get-secret-value \
  --region "$region" \
  --secret-id "$master_secret_arn" \
  --query SecretString \
  --output text)"
master_username="$(jq -er '.username | select(length > 0)' <<<"$master_json")"
master_password="$(jq -er '.password | select(length > 0)' <<<"$master_json")"

database_exists="$(PGHOST="$database_host" PGPORT="$database_port" PGDATABASE=postgres \
  PGUSER="$master_username" PGPASSWORD="$master_password" PGSSLMODE=require \
  psql -X -qAt -v ON_ERROR_STOP=1 -v target_database="$database_name" <<'SQL'
SELECT 1 FROM pg_database WHERE datname = :'target_database';
SQL
)"
if [[ "$database_exists" != '1' ]]; then
  PGHOST="$database_host" PGPORT="$database_port" PGDATABASE=postgres \
    PGUSER="$master_username" PGPASSWORD="$master_password" PGSSLMODE=require \
    psql -X -q -v ON_ERROR_STOP=1 -v target_database="$database_name" <<'SQL' >/dev/null
SELECT format('CREATE DATABASE %I', :'target_database')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'target_database')
\gexec
SQL
fi

export FLYWAY_URL="jdbc:postgresql://${database_host}:${database_port}/${database_name}?sslmode=require"
export FLYWAY_USER="$master_username"
export FLYWAY_PASSWORD="$master_password"
flyway() {
  docker run --rm --network host \
    --volume "$bundle_directory:/flyway/sql:ro" \
    --env FLYWAY_URL --env FLYWAY_USER --env FLYWAY_PASSWORD \
    "$FLYWAY_IMAGE" -connectRetries=30 "$@"
}

# The canonical bundle is assembled from independently versioned services.
# A reviewed migration can therefore arrive after a higher version from another
# service has already been applied. The manifest/checksum gate above keeps this
# bounded to the exact published bundle while allowing that late migration.
flyway -outOfOrder=true migrate >&2
flyway validate >&2
flyway_info="$(flyway -outputType=json info)"
if jq -e '[.. | objects | .state? // empty | ascii_downcase] | any(. == "pending")' <<<"$flyway_info" >/dev/null; then
  echo 'Flyway still reports pending migrations.' >&2
  exit 66
fi
unset FLYWAY_PASSWORD FLYWAY_USER FLYWAY_URL

export PGHOST="$database_host" PGPORT="$database_port" PGDATABASE="$database_name"
export PGUSER="$master_username" PGPASSWORD="$master_password" PGSSLMODE=require

group_count="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "SELECT count(*) FROM pg_roles WHERE rolname IN ('idea2strategy_backend','idea2strategy_batch','idea2strategy_backtest','idea2strategy_trading','idea2strategy_pipeline') AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication AND NOT rolbypassrls;")"
test "$group_count" = '5'

seed_password="$(openssl rand -hex 32)"
drop_seed_role
psql -X -q -v ON_ERROR_STOP=1 <<SQL >/dev/null
CREATE ROLE $seed_role LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 1 PASSWORD '$seed_password';
GRANT CONNECT ON DATABASE "$database_name" TO $seed_role;
GRANT USAGE ON SCHEMA trading, backtest TO $seed_role;
GRANT SELECT, INSERT ON TABLE trading.fee_policy_versions, trading.buying_power_buffer_policy_versions, backtest.execution_policy_versions TO $seed_role;
GRANT USAGE ON SCHEMA competition TO $seed_role;
GRANT SELECT, INSERT ON TABLE competition.scoring_template_versions TO $seed_role;
SQL
PGUSER="$seed_role" PGPASSWORD="$seed_password" psql -X -q -v ON_ERROR_STOP=1 --single-transaction -f "$policy_seed_sql" >/dev/null
PGUSER="$seed_role" PGPASSWORD="$seed_password" psql -X -q -v ON_ERROR_STOP=1 --single-transaction -f "$scoring_seed_sql" >/dev/null
drop_seed_role
seed_password=''

mapfile -t expected_scoring_ids < <(grep -Eo "'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'" "$scoring_seed_sql" | tr -d "'" | sort -u)
test "${#expected_scoring_ids[@]}" -gt 0
scoring_id_list=''
for scoring_id in "${expected_scoring_ids[@]}"; do
  [[ "$scoring_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
  scoring_id_list+="${scoring_id_list:+,}'${scoring_id}'"
done

policy_row_counts="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "SELECT json_build_object('fee',(SELECT count(*) FROM trading.fee_policy_versions WHERE effective_from <= now() AND (effective_to IS NULL OR effective_to > now())),'buffer',(SELECT count(*) FROM trading.buying_power_buffer_policy_versions WHERE effective_from <= now() AND (effective_to IS NULL OR effective_to > now())),'execution',(SELECT count(*) FROM backtest.execution_policy_versions WHERE retired_at IS NULL));")"
jq -e '.fee >= 1 and .buffer >= 1 and .execution >= 1' <<<"$policy_row_counts" >/dev/null
policy_versions="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "SELECT json_build_object('fee',COALESCE((SELECT json_agg(json_build_object('policy_code',policy_code,'version',version,'rules_hash',rules_hash) ORDER BY policy_code,version) FROM trading.fee_policy_versions WHERE effective_from <= now() AND (effective_to IS NULL OR effective_to > now())),'[]'::json),'buffer',COALESCE((SELECT json_agg(json_build_object('policy_code',policy_code,'version',version,'rules_hash',rules_hash) ORDER BY policy_code,version) FROM trading.buying_power_buffer_policy_versions WHERE effective_from <= now() AND (effective_to IS NULL OR effective_to > now())),'[]'::json),'execution',COALESCE((SELECT json_agg(json_build_object('version',version,'policy_artifact_hash',policy_artifact_hash) ORDER BY version) FROM backtest.execution_policy_versions WHERE retired_at IS NULL),'[]'::json));")"
jq -e '.fee | length >= 1' <<<"$policy_versions" >/dev/null
jq -e '.buffer | length >= 1' <<<"$policy_versions" >/dev/null
jq -e '.execution | length >= 1' <<<"$policy_versions" >/dev/null
scoring_versions="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "SELECT COALESCE(json_agg(json_build_object('id',id,'template_code',template_code,'version',version,'rules_hash',rules_hash) ORDER BY template_code,version),'[]'::json) FROM competition.scoring_template_versions WHERE id IN ($scoring_id_list);")"
jq -e --argjson expected "${#expected_scoring_ids[@]}" 'length == $expected' <<<"$scoring_versions" >/dev/null

existing_runtime_login_count="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "SELECT count(*) FROM pg_roles WHERE rolname IN ('idea2strategy_backend_runtime','idea2strategy_batch_runtime','idea2strategy_backtest_runtime','idea2strategy_trading_runtime','idea2strategy_pipeline_runtime');")"
if [[ "$existing_runtime_login_count" == '0' ]]; then
  initial_rotation=true
elif [[ "$existing_runtime_login_count" != '5' ]]; then
  echo 'Database bootstrap found a partial runtime login role set.' >&2
  exit 67
fi

versions='{}'
for consumer in "${CONSUMERS[@]}"; do
  login_role="idea2strategy_${consumer}_runtime"
  secret_arn="$(jq -er --arg consumer "$consumer" '.[$consumer]' "$runtime_secret_arns_file")"
  if [[ "$initial_rotation" != true ]]; then
    current_secret="$(aws_retry secretsmanager get-secret-value --region "$region" --secret-id "$secret_arn" \
      --version-stage AWSCURRENT --query '{VersionId:VersionId,SecretString:SecretString}' --output json)"
    old_versions["$consumer"]="$(jq -er '.VersionId | select(length > 0)' <<<"$current_secret")"
    current_username="$(jq -er '.SecretString | fromjson | .username' <<<"$current_secret")"
    old_passwords["$consumer"]="$(jq -er '.SecretString | fromjson | .password | select(test("^[0-9a-f]{64}$"))' <<<"$current_secret")"
    [[ "$current_username" == "$login_role" ]] || {
      echo "Database bootstrap current secret username mismatch: $consumer" >&2
      exit 67
    }
    current_secret=''
    current_username=''
  else
    secret_description="$(aws_retry secretsmanager describe-secret --region "$region" --secret-id "$secret_arn")"
    old_versions["$consumer"]="$(jq -r '[((.VersionIdsToStages // {}) | to_entries[]) | select(.value | index("AWSCURRENT")) | .key][0] // ""' <<<"$secret_description")"
    secret_description=''
  fi

  passwords["$consumer"]="$(openssl rand -hex 32)"
  password="${passwords[$consumer]}"
  pipeline_url=''
  if [[ "$consumer" == pipeline ]]; then
    pipeline_url="$(jq -cn \
      --arg username "$login_role" --arg password "$password" \
      --arg host "$database_host" --arg port "$database_port" --arg dbname "$database_name" \
      '{username:$username,password:$password,host:$host,port:$port,dbname:$dbname}' | \
      python3 -c 'import json,sys; from urllib.parse import quote; d=json.load(sys.stdin); print("postgresql+psycopg://%s:%s@%s:%s/%s?sslmode=require" % (quote(d["username"],safe=""),quote(d["password"],safe=""),d["host"],d["port"],quote(d["dbname"],safe="")))')"
  fi
  secret_file="$work_directory/${consumer}-secret.json"
  if [[ "$consumer" == pipeline ]]; then
    jq -cn --arg engine postgres --arg host "$database_host" --arg port "$database_port" \
      --arg dbname "$database_name" --arg username "$login_role" --arg password "$password" \
      --arg url "$pipeline_url" \
      '{engine:$engine,host:$host,port:$port,dbname:$dbname,username:$username,password:$password,PIPELINE_WORKER_DATABASE_URL:$url}' >"$secret_file"
  else
    jq -cn --arg engine postgres --arg host "$database_host" --arg port "$database_port" \
      --arg dbname "$database_name" --arg username "$login_role" --arg password "$password" \
      '{engine:$engine,host:$host,port:$port,dbname:$dbname,username:$username,password:$password}' >"$secret_file"
  fi
  chmod 0600 "$secret_file"
  new_versions["$consumer"]="$(aws_retry secretsmanager put-secret-value --region "$region" --secret-id "$secret_arn" \
    --secret-string "file://$secret_file" --version-stages AWSPENDING --query VersionId --output text)"
  rm -f -- "$secret_file"
  [[ -n "${new_versions[$consumer]}" && "${new_versions[$consumer]}" != None ]]
  versions="$(jq -cn --argjson current "$versions" --arg consumer "$consumer" --arg version "${new_versions[$consumer]}" '$current + {($consumer):$version}')"
done

roles_sql="$work_directory/runtime-roles.sql"
{
  echo 'BEGIN;'
  for consumer in "${CONSUMERS[@]}"; do
    login_role="idea2strategy_${consumer}_runtime"
    password="${passwords[$consumer]}"
    printf "DO \$bootstrap\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '%s') THEN CREATE ROLE %s; END IF; END \$bootstrap\$;\n" "$login_role" "$login_role"
    printf "ALTER ROLE %s LOGIN INHERIT NOCREATEDB NOCREATEROLE CONNECTION LIMIT -1 PASSWORD '%s';\n" "$login_role" "$password"
    printf "DO \$bootstrap\$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '%s' AND (rolsuper OR rolreplication OR rolbypassrls)) THEN RAISE EXCEPTION 'runtime login role %s has forbidden privileged attributes'; END IF; END \$bootstrap\$;\n" "$login_role" "$login_role"
    printf "SELECT format('REVOKE %%I FROM %%I', granted.rolname, '%s') FROM pg_auth_members membership JOIN pg_roles granted ON granted.oid = membership.roleid JOIN pg_roles member ON member.oid = membership.member WHERE member.rolname = '%s' \\gexec\n" "$login_role" "$login_role"
    printf 'GRANT idea2strategy_%s TO %s;\n' "$consumer" "$login_role"
  done
  echo 'COMMIT;'
} >"$roles_sql"
chmod 0600 "$roles_sql"
rotation_started=true
psql -X -q -v ON_ERROR_STOP=1 -f "$roles_sql" >/dev/null
rm -f -- "$roles_sql"

membership_count="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "WITH expected(login_role, group_role) AS (VALUES ('idea2strategy_backend_runtime','idea2strategy_backend'),('idea2strategy_batch_runtime','idea2strategy_batch'),('idea2strategy_backtest_runtime','idea2strategy_backtest'),('idea2strategy_trading_runtime','idea2strategy_trading'),('idea2strategy_pipeline_runtime','idea2strategy_pipeline')) SELECT count(*) FROM expected e JOIN pg_roles member ON member.rolname=e.login_role AND member.rolcanlogin AND NOT member.rolsuper AND NOT member.rolcreatedb AND NOT member.rolcreaterole AND NOT member.rolreplication AND NOT member.rolbypassrls JOIN pg_auth_members m ON m.member=member.oid JOIN pg_roles granted ON granted.oid=m.roleid AND granted.rolname=e.group_role;")"
test "$membership_count" = '5'
all_membership_count="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "SELECT count(*) FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member WHERE member.rolname IN ('idea2strategy_backend_runtime','idea2strategy_batch_runtime','idea2strategy_backtest_runtime','idea2strategy_trading_runtime','idea2strategy_pipeline_runtime');")"
test "$all_membership_count" = '5'
owned_object_count="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "SELECT (SELECT count(*) FROM pg_database d JOIN pg_roles r ON r.oid=d.datdba WHERE r.rolname LIKE 'idea2strategy_%_runtime') + (SELECT count(*) FROM pg_namespace n JOIN pg_roles r ON r.oid=n.nspowner WHERE r.rolname LIKE 'idea2strategy_%_runtime') + (SELECT count(*) FROM pg_class c JOIN pg_roles r ON r.oid=c.relowner WHERE r.rolname LIKE 'idea2strategy_%_runtime');")"
test "$owned_object_count" = '0'

table_count="$(psql -X -qAt -v ON_ERROR_STOP=1 -c \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema IN ('identity','strategy','bot','storage','market_data','trading','backtest','performance','competition','operations') AND table_type='BASE TABLE';")"
test "$table_count" -gt 0

for consumer in "${CONSUMERS[@]}"; do
  login_role="idea2strategy_${consumer}_runtime"
  password="${passwords[$consumer]}"
  PGPASSWORD="$password" PGUSER="$login_role" psql -X -qAt -v ON_ERROR_STOP=1 -c 'SELECT 1;' >/dev/null
  secret_arn="$(jq -er --arg consumer "$consumer" '.[$consumer]' "$runtime_secret_arns_file")"
  if [[ "$initial_rotation" == true ]]; then
    if [[ -n "${old_versions[$consumer]}" ]]; then
      aws_retry secretsmanager update-secret-version-stage --region "$region" --secret-id "$secret_arn" \
        --version-stage AWSCURRENT --move-to-version-id "${new_versions[$consumer]}" \
        --remove-from-version-id "${old_versions[$consumer]}" >/dev/null
    else
      aws_retry secretsmanager update-secret-version-stage --region "$region" --secret-id "$secret_arn" \
        --version-stage AWSCURRENT --move-to-version-id "${new_versions[$consumer]}" >/dev/null
    fi
  else
    aws_retry secretsmanager update-secret-version-stage --region "$region" --secret-id "$secret_arn" \
      --version-stage AWSCURRENT --move-to-version-id "${new_versions[$consumer]}" \
      --remove-from-version-id "${old_versions[$consumer]}" >/dev/null
  fi
  promoted_versions["$consumer"]="${new_versions[$consumer]}"
done
rotation_committed=true
for consumer in "${CONSUMERS[@]}"; do
  secret_arn="$(jq -er --arg consumer "$consumer" '.[$consumer]' "$runtime_secret_arns_file")"
  if ! aws_retry secretsmanager update-secret-version-stage --region "$region" --secret-id "$secret_arn" \
    --version-stage AWSPENDING --remove-from-version-id "${new_versions[$consumer]}" >/dev/null; then
    echo "Database bootstrap could not remove the optional AWSPENDING label for $consumer." >&2
  fi
done
pending_cleanup_complete=true

master_json=''
master_username=''
master_password=''
unset PGPASSWORD PGUSER PGHOST PGPORT PGDATABASE PGSSLMODE

jq -cn \
  --arg status passed \
  --arg root_sha "$root_sha" \
  --arg bundle_sha256 "$bundle_sha256" \
  --arg policy_seed_sha256 "$policy_seed_sha256" \
  --arg scoring_seed_sha256 "$scoring_seed_sha256" \
  --arg flyway_image "$FLYWAY_IMAGE" \
  --arg aws_cli_image "$AWS_CLI_IMAGE" \
  --argjson migrations "$expected_migration_count" \
  --argjson tables "$table_count" \
  --argjson login_roles 5 \
  --argjson policy_row_counts "$policy_row_counts" \
  --argjson policy_versions "$policy_versions" \
  --argjson scoring_versions "$scoring_versions" \
  --argjson secret_versions "$versions" \
  '{status:$status,root_sha:$root_sha,bundle_sha256:$bundle_sha256,policy_seed_sha256:$policy_seed_sha256,scoring_seed_sha256:$scoring_seed_sha256,flyway_image:$flyway_image,aws_cli_image:$aws_cli_image,migrations:$migrations,tables:$tables,login_roles:$login_roles,policy_row_counts:$policy_row_counts,policy_versions:$policy_versions,scoring_versions:$scoring_versions,secret_versions:$secret_versions}'
