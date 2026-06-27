# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-27

### Added

- Aurora Serverless v2 support with `deployment_mode = "serverless"`
- Serverless scaling configuration (ACU min/max per environment)
- Aurora cluster and instance resources
- Cluster parameter groups for Aurora
- Reader endpoint SSM parameter for Aurora
- ACU capacity CloudWatch alarm for serverless mode
- Deployment mode SSM parameter export

### Changed

- Outputs now dynamically return values based on deployment mode
- SSM exports support both provisioned and serverless modes
- CloudWatch alarms are mode-specific

## [1.0.0] - 2026-06-27

### Added

- Initial RDS template release
- Terraform configuration for RDS instance (provisioned mode) with:
  - PostgreSQL and MySQL engine support
  - Environment-specific instance sizing (dev/qa/prod)
  - Multi-AZ deployment for production
  - Automated backups with configurable retention
  - Storage auto-scaling (gp3)
  - Server-side encryption
  - IAM database authentication
  - Performance Insights (production)
  - Enhanced Monitoring (production)
  - CloudWatch Logs exports
- Security features:
  - Secrets Manager for master password
  - Dedicated security group with VPC CIDR access
  - Deletion protection for production
- CloudWatch alarms for production:
  - CPU utilization
  - Free storage space
  - Database connections
- DB Parameter Group with PostgreSQL logging
- SSM Parameter Store exports:
  - Endpoint, address, port
  - Database name
  - Secret ARN
  - Security group ID
  - Instance ARN and resource ID
- GitHub Actions CI/CD workflow with:
  - Multi-environment support (dev, qa, prod)
  - OIDC authentication
  - Terraform plan on PRs
  - Deploy and destroy actions
  - Checkov security scanning
- Integration with aws-vpc-network-template via SSM parameters
- Comprehensive README with setup instructions
