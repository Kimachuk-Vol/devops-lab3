terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Провайдер налаштований на floci (локальний емулятор AWS на порту 4566).
# Для справжнього AWS Free Tier: use_floci = false і реальні ключі в ~/.aws/credentials.
provider "aws" {
  region     = var.region
  access_key = var.use_floci ? "test" : null
  secret_key = var.use_floci ? "test" : null

  skip_credentials_validation = var.use_floci
  skip_metadata_api_check     = var.use_floci
  skip_requesting_account_id  = var.use_floci
  s3_use_path_style           = var.use_floci

  dynamic "endpoints" {
    for_each = var.use_floci ? [1] : []
    content {
      apigateway = var.floci_endpoint
      lambda     = var.floci_endpoint
      s3         = var.floci_endpoint
      iam        = var.floci_endpoint
      sts        = var.floci_endpoint
    }
  }
}
