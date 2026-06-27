# =============================================================================
# Terraform Backend Configuration
# =============================================================================
# Backend is configured dynamically using -backend-config in CI/CD
# This allows the same code to work across environments

terraform {
  backend "s3" {
    # These values are provided via -backend-config in CI/CD:
    #- bucket  = "tfstate-{company}-{env}-{account}"
    #- key     = "rds/{db_name}/terraform.tfstate"
    #- region  = "eu-west-1"
    #- encrypt = true

    # For local development, create backend_override.tf with:
    # terraform {
    #   backend "s3" {
    #     bucket  = "tfstate-vigalcontec-dev-123456789012"
    #     key     = "rds/my-database/terraform.tfstate"
    #     region  = "eu-west-1"
    #     encrypt = true
    #   }
    # }
  }
}
