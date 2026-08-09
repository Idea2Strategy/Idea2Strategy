# Canonical derivation of BACKTEST_WORKER_CORRELATION_ID for the Development backtest worker.
#
# scripts/backtest-worker-correlation-id.sh is the single definition. A copy lives in
# infra/terraform/environments/development/templates/ec2-user-data.sh.tftpl so a booting instance
# stamps the value, and scripts/deploy-development-core-runtime.ps1 reads the file from disk so a
# rollout re-stamps an instance that booted before this contract existed.
# scripts/test-backtest-correlation-derivation.ps1 fails when the two copies drift. They must agree,
# because an instance that reboots and an instance that is rolled out have to keep the same
# correlation id.
#
# The result-event contract requires metadata.correlationId to be a UUID, and an EC2 instance id is
# not one (root #439, INT03 run c0df2755). BACKTEST_WORKER_ID keeps the instance id — which host
# executed — and this value carries the contract's UUID field.
#
# Derived rather than generated so it is stable for the life of the instance: a random value would
# change on every restart and stop correlating the events it exists to tie together. The derivation is
# a SHA-256 over a fixed namespace and the instance id, laid out as an RFC 4122 string with the
# version and variant nibbles fixed. It is deterministic and collision-resistant for this purpose; it
# is not a spec-conformant v5 UUID, and nothing may treat it as one beyond being a stable identifier.
idea2strategy_backtest_worker_correlation_id() {
  local instance_id="$1" digest correlation_id
  if [ -z "$instance_id" ]; then
    echo "An instance id is required to derive the backtest worker correlation id." >&2
    return 1
  fi
  digest="$(printf 'idea2strategy:development:backtest-worker-correlation:%s' "$instance_id" | sha256sum | cut -c1-32)"
  correlation_id="${digest:0:8}-${digest:8:4}-5${digest:13:3}-8${digest:17:3}-${digest:20:12}"
  case "$correlation_id" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-5[0-9a-f][0-9a-f][0-9a-f]-8[0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
    *)
      echo "Derived backtest worker correlation id is not a UUID: $correlation_id" >&2
      return 1
      ;;
  esac
  printf '%s' "$correlation_id"
}
