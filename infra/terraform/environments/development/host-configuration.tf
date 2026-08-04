resource "aws_ssm_association" "backtest_host_safety" {
  count = local.enable_service_stack ? 1 : 0
  name  = "AWS-RunShellScript"

  targets {
    key    = "tag:Role"
    values = ["backtest-worker"]
  }

  parameters = {
    commands = join("\n", [
      "set -euo pipefail",
      "sysctl -w vm.overcommit_memory=2",
      "sysctl -w vm.overcommit_ratio=80",
      "install -d -m 0755 /var/lib/idea2strategy/backtest",
      "test ! -e /var/lib/idea2strategy/backtest/recovery-required"
    ])
  }
}
