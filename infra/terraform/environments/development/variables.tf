variable "aws_region" {
  description = "AWS region for Development."
  type        = string
  default     = "ap-northeast-2"
}

variable "email_region" {
  description = "AWS region used only for Development transactional SES delivery."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.email_region == "us-east-1"
    error_message = "Development email delivery must remain in us-east-1 until the Seoul SES production-access correction is approved and a separate migration is reviewed."
  }
}

variable "aws_profile" {
  description = "Local AWS CLI profile. CI can override this value."
  type        = string
  default     = "idea2strategy-terraform"
}

variable "expected_aws_account_id" {
  description = "Exact AWS account allowed for this Development stack. Required for host_ready and full."
  type        = string
  default     = ""

  validation {
    condition     = var.expected_aws_account_id == "" || can(regex("^[0-9]{12}$", var.expected_aws_account_id))
    error_message = "expected_aws_account_id must be empty or an exact 12-digit AWS account ID."
  }
}

variable "development_iam_user_names" {
  description = "IAM users who receive MFA-protected Development application access. Login profiles and passwords remain outside Terraform."
  type        = set(string)
  default = [
    "SeoDongWi",
    "hjcud",
    "hoyow",
    "kcrmin",
    "pjy"
  ]
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "idea2strategy"
}

variable "environment" {
  description = "Environment name. This root intentionally supports Development only."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This Terraform root may create only the dev environment."
  }
}

variable "deployment_phase" {
  description = "Development rollout phase. host_ready creates the private-by-ingress runtime for SSM verification; full adds the public edge only after DNS delegation."
  type        = string
  default     = "market_data_bootstrap"

  validation {
    condition     = contains(["market_data_bootstrap", "dns_foundation", "host_ready", "full"], var.deployment_phase)
    error_message = "deployment_phase must be market_data_bootstrap, dns_foundation, host_ready, or full."
  }
}

variable "runtime_database_name" {
  description = "Canonical application database created additively by the reviewed bootstrap; the legacy market-loader database remains preserved."
  type        = string
  default     = "idea2strategy_runtime"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{2,62}$", var.runtime_database_name)) && var.runtime_database_name != "idea2strategy"
    error_message = "runtime_database_name must be a safe PostgreSQL identifier distinct from the preserved legacy idea2strategy database."
  }
}

variable "vpc_cidr" {
  description = "Development VPC CIDR."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public application subnets. Runtime security groups remain egress-only except the CloudFront-restricted Core origin."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required."
  }
}

variable "private_db_subnet_cidrs" {
  description = "Two private DB subnet CIDRs used by the RDS subnet group."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]

  validation {
    condition     = length(var.private_db_subnet_cidrs) == 2
    error_message = "Exactly two private DB subnet CIDRs are required."
  }
}

variable "service_instance_type" {
  description = "Core EC2 size. Increase only after memory, GC, latency and CPU-credit evidence."
  type        = string
  default     = "t4g.medium"
}

variable "trading_instance_type" {
  description = "On-Demand ARM64 trading runtime size."
  type        = string
  default     = "c7g.xlarge"
}

variable "trading_market_data_feed" {
  description = "Paid Alpaca SIP real-time feed for the internal Development demonstration."
  type        = string
  default     = "sip"

  validation {
    condition     = var.trading_market_data_feed == "sip"
    error_message = "trading_market_data_feed must be sip."
  }
}

variable "backtest_instance_type" {
  description = "Scale-to-zero ARM64 backtest worker size."
  type        = string
  default     = "t4g.medium"
}

variable "service_root_volume_gib" {
  description = "Encrypted gp3 root volume size for the service EC2."
  type        = number
  default     = 30

  validation {
    condition     = var.service_root_volume_gib >= 8
    error_message = "service_root_volume_gib must be at least 8 GiB."
  }
}

variable "trading_root_volume_gib" {
  description = "Encrypted gp3 root volume size for the trading runtime."
  type        = number
  default     = 20

  validation {
    condition     = var.trading_root_volume_gib >= 8
    error_message = "trading_root_volume_gib must be at least 8 GiB."
  }
}

variable "backtest_root_volume_gib" {
  description = "Encrypted gp3 scratch volume for streaming backtests; durable recovery remains in S3 and PostgreSQL."
  type        = number
  default     = 40

  validation {
    condition     = var.backtest_root_volume_gib >= 20
    error_message = "backtest_root_volume_gib must be at least 20 GiB."
  }
}

variable "service_target_port" {
  description = "Core HTTPS origin port reached only from the CloudFront origin-facing prefix list."
  type        = number
  default     = 443
}

variable "frontend_domain_name" {
  description = "Public hostname served by CloudFront."
  type        = string
  default     = "ideatostrategy.com"
}

variable "origin_domain_name" {
  description = "Public DNS name for the fixed-EIP Core HTTPS origin. The security group permits CloudFront origin-facing addresses only."
  type        = string
  default     = "origin.ideatostrategy.com"
}

variable "domain_name" {
  description = "Authoritative domain to move to Route 53 after existing records are copied."
  type        = string
  default     = "ideatostrategy.com"
}

variable "existing_hosted_zone_id" {
  description = "Existing Route 53 Hosted Zone ID. Empty creates a new zone without changing registrar delegation."
  type        = string
  default     = ""
}

variable "legacy_www_ipv4_address" {
  description = "Existing registrar-era www A record preserved during Route 53 delegation. Change only in a separately reviewed traffic cutover."
  type        = string
  default     = "121.254.178.253"

  validation {
    condition     = can(cidrhost("${var.legacy_www_ipv4_address}/32", 0))
    error_message = "legacy_www_ipv4_address must be a valid IPv4 address."
  }
}

variable "transactional_email_from_address" {
  description = "Verified SES sender used by Backend API and Worker. This is public configuration, not a credential."
  type        = string
  default     = "no-reply@ideatostrategy.com"
}

variable "google_oauth_client_id" {
  description = "Public Google OAuth web client ID. Empty keeps customer Google sign-in disabled."
  type        = string
  default     = ""

  validation {
    condition     = var.google_oauth_client_id == "" || can(regex("^[0-9]+-[A-Za-z0-9_-]+\\.apps\\.googleusercontent\\.com$", var.google_oauth_client_id))
    error_message = "google_oauth_client_id must be empty or a Google web client ID."
  }
}

variable "dns_delegation_verified" {
  description = "Explicit operator evidence that the public registrar delegates the apex to the reviewed Route 53 zone. Required for full; never infer it from zone creation alone."
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Enable ACM validation, HTTPS listener, and HTTP redirect after Route 53 delegation is complete."
  type        = bool
  default     = false
}

variable "queue_visibility_timeout_seconds" {
  description = "Visibility timeout for durable worker queues."
  type        = number
  default     = 900
}

variable "queue_max_receive_count" {
  description = "Receive attempts before SQS moves a message to its DLQ."
  type        = number
  default     = 5
}

variable "rds_instance_class" {
  description = "Initial low-cost RDS measurement size."
  type        = string
  default     = "db.t4g.small"
}

variable "rds_allocated_storage_gib" {
  description = "Initial RDS gp3 storage."
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage_gib" {
  description = "RDS storage autoscaling ceiling."
  type        = number
  default     = 100
}

variable "rds_backup_retention_days" {
  description = "Automatic backup and point-in-time recovery retention."
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Protect Development RDS against accidental deletion."
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch application and host log retention."
  type        = number
  default     = 14
}

variable "enable_waf" {
  description = "Attach a minimal CloudFront WAF policy before public Development access."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Maximum requests from one IP in a five-minute WAF evaluation window."
  type        = number
  default     = 2000
}

variable "operations_alert_email" {
  description = "Optional operations email for SNS alarms. Subscription remains pending until confirmed."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Development monthly cost budget in USD."
  type        = number
  default     = 180
}

variable "alpaca_api_key_secret_name" {
  description = "Existing Secrets Manager secret containing the ALPACA_API_KEY JSON field. Terraform reads metadata only."
  type        = string
  default     = "idea2strategy-dev/backtest/alpaca"
}

variable "alpaca_secret_key_secret_name" {
  description = "Existing Secrets Manager secret containing the ALPACA_SECRET_KEY JSON field. Terraform reads metadata only."
  type        = string
  default     = "idea2strategy-dev/backtest/alpaca-secret"
}

variable "pipeline_schedule_expression" {
  description = "Optional EventBridge schedule for the desired-zero pipeline task. Empty disables scheduled runs."
  type        = string
  default     = ""
}

variable "container_image_digests" {
  description = "Immutable sha256 digests keyed by every deployable runtime image. Required for host_ready and full."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for digest in values(var.container_image_digests) : can(regex("^sha256:[0-9a-f]{64}$", digest))
    ])
    error_message = "Every container image digest must use the exact sha256:<64 lowercase hex> form."
  }
}

variable "frontend_release_id" {
  description = "Immutable frontend build/release identifier uploaded to the private frontend bucket."
  type        = string
  default     = ""
}

variable "backtest_policy_artifacts" {
  description = "Checksum- and S3-version-pinned Backtest policy objects in the market-data bucket. Required keys are execution-policy and runtime-policy."
  type = map(object({
    key        = string
    version_id = string
    sha256     = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for artifact in values(var.backtest_policy_artifacts) :
      artifact.key != "" && artifact.version_id != "" && can(regex("^[0-9a-f]{64}$", artifact.sha256))
    ])
    error_message = "Every Backtest policy artifact needs an S3 key, immutable version_id, and lowercase SHA-256."
  }
}

variable "trading_runtime_artifacts" {
  description = "Checksum- and S3-version-pinned Trading materialization inputs. runtime is market-gateway or trading-worker and local_path is relative to that runtime's read-only mount."
  type = map(object({
    runtime    = string
    key        = string
    version_id = string
    sha256     = string
    local_path = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for artifact in values(var.trading_runtime_artifacts) :
      contains(["market-gateway", "trading-worker"], artifact.runtime) &&
      artifact.key != "" && artifact.version_id != "" &&
      can(regex("^[0-9a-f]{64}$", artifact.sha256)) &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9._/-]*$", artifact.local_path)) &&
      !strcontains(artifact.local_path, "..")
    ])
    error_message = "Every Trading artifact needs a supported runtime, immutable S3 version, lowercase SHA-256, and traversal-free relative local_path."
  }
}

variable "runtime_database_secret_names" {
  description = "Existing Secrets Manager JSON credentials for least-privilege LOGIN roles. Exact keys backend, batch, backtest, trading, and pipeline are mandatory for host_ready and full; Terraform reads metadata only."
  type        = map(string)
  default = {
    backend  = "idea2strategy-dev/database/backend-runtime"
    batch    = "idea2strategy-dev/database/batch-runtime"
    backtest = "idea2strategy-dev/database/backtest-runtime"
    trading  = "idea2strategy-dev/database/trading-runtime"
    pipeline = "idea2strategy-dev/database/pipeline-runtime"
  }

  validation {
    condition = (
      toset(keys(var.runtime_database_secret_names)) == toset(["backend", "batch", "backtest", "trading", "pipeline"]) &&
      alltrue([for name in values(var.runtime_database_secret_names) : name != ""])
    )
    error_message = "runtime_database_secret_names must contain only non-empty backend, batch, backtest, trading, and pipeline secret names."
  }
}

variable "enable_backtest_outbox_relay" {
  description = "Enable the verified Backend Outbox publisher for all three Backtest lanes. A full release candidate must explicitly set this true."
  type        = bool
  default     = false
}

variable "enable_operator_auth" {
  description = "Enable the dedicated operator OIDC and RBAC read plane. Set false only for a pre-DNS Development host rollout; operator routes then remain unavailable instead of accepting weaker identity."
  type        = bool
  default     = true
}

variable "enable_cognito_operator_identity" {
  description = "Create the dedicated AWS-native operator identity plane. Keep false until the namespaced MFA assurance proposal has fresh product-authority approval."
  type        = bool
  default     = false
}

variable "operator_auth_issuer" {
  description = "Exact HTTPS issuer for the dedicated operator OIDC JWT. Required for a full release; it is not inferred from customer login."
  type        = string
  default     = ""

  validation {
    condition     = var.operator_auth_issuer == "" || can(regex("^https://[^/?#]+(?:/[^?#]*)?$", var.operator_auth_issuer))
    error_message = "operator_auth_issuer must be empty or an exact HTTPS issuer without query or fragment."
  }
}

variable "operator_auth_jwk_set_uri" {
  description = "Exact HTTPS JWKS URI for the dedicated operator OIDC provider."
  type        = string
  default     = ""

  validation {
    condition     = var.operator_auth_jwk_set_uri == "" || can(regex("^https://[^/?#]+/[^?#]+$", var.operator_auth_jwk_set_uri))
    error_message = "operator_auth_jwk_set_uri must be empty or an HTTPS JWKS URI without query or fragment."
  }
}

variable "operator_auth_audience" {
  description = "Single exact audience accepted by the Backend operator JWT verifier."
  type        = string
  default     = ""

  validation {
    condition     = var.operator_auth_audience == "" || can(regex("^[A-Za-z0-9][A-Za-z0-9._:/-]{0,255}$", var.operator_auth_audience))
    error_message = "operator_auth_audience must be a newline-free exact audience token."
  }
}

variable "operator_auth_allowed_acr_values" {
  description = "Exact OIDC acr values that prove recent operator MFA. At least one acr/amr value is required for full deployment."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for value in var.operator_auth_allowed_acr_values : can(regex("^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$", value))])
    error_message = "operator_auth_allowed_acr_values must contain only bounded claim tokens."
  }
}

variable "operator_auth_allowed_amr_values" {
  description = "Exact OIDC amr values that prove recent operator MFA. At least one acr/amr value is required for full deployment."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for value in var.operator_auth_allowed_amr_values : can(regex("^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$", value))])
    error_message = "operator_auth_allowed_amr_values must contain only bounded claim tokens."
  }
}

variable "operator_auth_mfa_claim_name" {
  description = "Optional exact HTTPS namespaced claim used by a reviewed provider that cannot emit reserved acr/amr claims."
  type        = string
  default     = ""

  validation {
    condition     = var.operator_auth_mfa_claim_name == "" || can(regex("^https://[^/?#]+/[^?#]+$", var.operator_auth_mfa_claim_name))
    error_message = "operator_auth_mfa_claim_name must be empty or an exact HTTPS namespaced claim without query or fragment."
  }
}

variable "operator_auth_allowed_mfa_claim_values" {
  description = "Exact accepted values for the reviewed namespaced MFA claim."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for value in var.operator_auth_allowed_mfa_claim_values : can(regex("^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$", value))])
    error_message = "operator_auth_allowed_mfa_claim_values must contain only bounded exact claim tokens."
  }
}

variable "operator_rbac_catalog_version" {
  description = "Immutable operator RBAC catalog version installed by the reviewed bootstrap receipt."
  type        = string
  default     = ""

  validation {
    condition     = var.operator_rbac_catalog_version == "" || can(regex("^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$", var.operator_rbac_catalog_version))
    error_message = "operator_rbac_catalog_version must be a bounded immutable identifier."
  }
}

variable "operator_rbac_catalog_read_permission_id" {
  description = "UUID of the catalog-read permission in the selected operator RBAC catalog."
  type        = string
  default     = ""
}

variable "operator_rbac_assignment_read_permission_id" {
  description = "UUID of the assignment-read permission in the selected operator RBAC catalog."
  type        = string
  default     = ""
}

variable "operator_rbac_grant_permission_id" {
  description = "UUID of the grant-command permission in the selected operator RBAC catalog."
  type        = string
  default     = ""
}

variable "operator_rbac_revoke_permission_id" {
  description = "UUID of the revoke-command permission in the selected operator RBAC catalog."
  type        = string
  default     = ""
}

variable "operator_case_queue_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_detail_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_assign_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_reassign_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_unassign_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_start_review_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_request_information_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_resolve_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_reject_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_apply_sanction_permission_id" {
  type    = string
  default = ""
}
variable "operator_case_release_sanction_permission_id" {
  type    = string
  default = ""
}
variable "operator_sanction_apply_permission_id" {
  type    = string
  default = ""
}
variable "operator_sanction_lift_permission_id" {
  type    = string
  default = ""
}
