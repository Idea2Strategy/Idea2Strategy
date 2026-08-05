provider "aws" {
  region              = var.aws_region
  profile             = var.aws_profile != "" ? var.aws_profile : null
  allowed_account_ids = var.expected_aws_account_id != "" ? [var.expected_aws_account_id] : null

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ec2_managed_prefix_list" "cloudfront_origin" {
  count = local.enable_public_edge ? 1 : 0

  name = "com.amazonaws.global.cloudfront.origin-facing"
}

data "aws_ami" "ubuntu_2404_arm64" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
