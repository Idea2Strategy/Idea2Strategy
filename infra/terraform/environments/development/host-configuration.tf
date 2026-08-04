resource "aws_ssm_association" "batch_host_safety" {
  name             = "AWS-RunShellScript"
  association_name = "${local.name_prefix}-batch-host-safety"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.batch.id]
  }

  parameters = {
    commands = <<-SHELL
      set -eu
      if ! command -v growpart >/dev/null 2>&1; then apt-get update && apt-get install -y cloud-guest-utils; fi
      growpart /dev/nvme0n1 1 || true
      resize2fs /dev/nvme0n1p1
      if [ ! -f /swapfile ]; then fallocate -l ${var.batch_swap_gib}G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=${var.batch_swap_gib * 1024} status=progress; fi
      chmod 600 /swapfile
      file /swapfile | grep -q 'swap file' || mkswap /swapfile
      swapon --show=NAME --noheadings | grep -qx '/swapfile' || swapon /swapfile
      grep -q '^/swapfile[[:space:]]' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
      printf 'vm.swappiness=10\n' > /etc/sysctl.d/99-idea2strategy-swap.conf
      sysctl --system >/dev/null
    SHELL
  }

  wait_for_success_timeout_seconds = 300
}

resource "aws_ssm_association" "compute_host_safety" {
  count = local.enable_service_stack ? 1 : 0

  name             = "AWS-RunShellScript"
  association_name = "${local.name_prefix}-compute-host-safety"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.compute[0].id]
  }

  parameters = {
    commands = <<-SHELL
      set -eu
      if ! command -v growpart >/dev/null 2>&1; then apt-get update && apt-get install -y cloud-guest-utils; fi
      growpart /dev/nvme0n1 1 || true
      resize2fs /dev/nvme0n1p1
      if [ ! -f /swapfile ]; then fallocate -l ${var.batch_swap_gib}G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=${var.batch_swap_gib * 1024} status=progress; fi
      chmod 600 /swapfile
      file /swapfile | grep -q 'swap file' || mkswap /swapfile
      swapon --show=NAME --noheadings | grep -qx '/swapfile' || swapon /swapfile
      grep -q '^/swapfile[[:space:]]' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
      printf 'vm.swappiness=10\n' > /etc/sysctl.d/99-idea2strategy-swap.conf
      sysctl --system >/dev/null
    SHELL
  }

  wait_for_success_timeout_seconds = 300
}
