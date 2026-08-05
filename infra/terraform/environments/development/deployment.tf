resource "terraform_data" "full_release_guard" {
  count = local.enable_service_stack ? 1 : 0

  input = {
    account_id    = var.expected_aws_account_id
    image_digests = var.container_image_digests
  }

  lifecycle {
    precondition {
      condition     = var.expected_aws_account_id != ""
      error_message = "expected_aws_account_id is required before planning or applying host_ready or full."
    }

    precondition {
      condition     = var.rds_backup_retention_days >= 7
      error_message = "The host_ready and full phases require at least seven days of RDS PITR retention."
    }

    precondition {
      condition     = toset(keys(var.container_image_digests)) == local.required_runtime_images
      error_message = "The host_ready and full phases require every runtime image digest."
    }
  }
}

resource "terraform_data" "public_release_guard" {
  count = local.enable_public_edge ? 1 : 0

  input = { frontend_release_id = var.frontend_release_id }

  lifecycle {
    precondition {
      condition     = var.enable_https
      error_message = "The full phase requires end-to-end HTTPS, including the CloudFront-to-Core origin connection."
    }

    precondition {
      condition     = var.dns_delegation_verified
      error_message = "The full phase requires verified public DNS delegation before Core DNS-01 certificate bootstrap."
    }

    precondition {
      condition     = var.frontend_release_id != ""
      error_message = "The full phase requires an immutable frontend_release_id."
    }
  }
}

resource "aws_ssm_parameter" "runtime_image" {
  for_each = local.enable_service_stack ? var.container_image_digests : {}

  name  = "${local.parameter_path}/deployment/images/${each.key}"
  type  = "String"
  value = "${data.aws_ecr_repository.this[each.key].repository_url}@${each.value}"
}

resource "aws_ssm_parameter" "frontend_release" {
  count = local.enable_public_edge ? 1 : 0

  name  = "${local.parameter_path}/deployment/frontend-release"
  type  = "String"
  value = var.frontend_release_id
}
