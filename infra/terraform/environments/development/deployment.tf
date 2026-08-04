resource "terraform_data" "full_release_guard" {
  count = local.enable_service_stack ? 1 : 0

  input = {
    account_id          = var.expected_aws_account_id
    frontend_release_id = var.frontend_release_id
    image_digests       = var.container_image_digests
  }

  lifecycle {
    precondition {
      condition     = var.expected_aws_account_id != ""
      error_message = "expected_aws_account_id is required before planning or applying the full phase."
    }

    precondition {
      condition     = var.rds_backup_retention_days >= 7
      error_message = "The full phase requires at least seven days of RDS PITR retention."
    }

    precondition {
      condition = (
        toset(keys(var.container_image_digests)) == local.required_runtime_images &&
        var.frontend_release_id != ""
      )
      error_message = "The full phase requires every runtime image digest and an immutable frontend_release_id."
    }
  }
}

resource "aws_ssm_parameter" "runtime_image" {
  for_each = local.enable_service_stack ? var.container_image_digests : {}

  name  = "${local.parameter_path}/deployment/images/${each.key}"
  type  = "String"
  value = "${aws_ecr_repository.this[each.key].repository_url}@${each.value}"
}

resource "aws_ssm_parameter" "frontend_release" {
  count = local.enable_service_stack ? 1 : 0

  name  = "${local.parameter_path}/deployment/frontend-release"
  type  = "String"
  value = var.frontend_release_id
}
