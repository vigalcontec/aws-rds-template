# =============================================================================
# SSM Parameter Exports - RDS Configuration
# =============================================================================
# Export RDS details to SSM for use by other services (Lambdas, ECS, etc.)
# Path convention: /{environment}/{project}/rds/{db_name}/{parameter}

locals {
  ssm_prefix = "/${var.environment}/${local.project_name}/rds/${local.db_name}"
}

# -----------------------------------------------------------------------------
# Connection Parameters
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "db_endpoint" {
  name        = "${local.ssm_prefix}/endpoint"
  description = "RDS endpoint for ${local.full_name}"
  type        = "String"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].endpoint : aws_db_instance.main[0].endpoint

  tags = {
    Name = "${local.full_name}-endpoint"
  }
}

resource "aws_ssm_parameter" "db_reader_endpoint" {
  count = local.is_serverless ? 1 : 0

  name        = "${local.ssm_prefix}/reader_endpoint"
  description = "Aurora reader endpoint for ${local.full_name}"
  type        = "String"
  value       = aws_rds_cluster.serverless[0].reader_endpoint

  tags = {
    Name = "${local.full_name}-reader-endpoint"
  }
}

resource "aws_ssm_parameter" "db_address" {
  name        = "${local.ssm_prefix}/address"
  description = "RDS hostname for ${local.full_name}"
  type        = "String"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].endpoint : aws_db_instance.main[0].address

  tags = {
    Name = "${local.full_name}-address"
  }
}

resource "aws_ssm_parameter" "db_port" {
  name        = "${local.ssm_prefix}/port"
  description = "RDS port for ${local.full_name}"
  type        = "String"
  value       = tostring(local.is_serverless ? aws_rds_cluster.serverless[0].port : aws_db_instance.main[0].port)

  tags = {
    Name = "${local.full_name}-port"
  }
}

resource "aws_ssm_parameter" "db_name" {
  name        = "${local.ssm_prefix}/database_name"
  description = "Database name for ${local.full_name}"
  type        = "String"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].database_name : aws_db_instance.main[0].db_name

  tags = {
    Name = "${local.full_name}-database-name"
  }
}

resource "aws_ssm_parameter" "deployment_mode" {
  name        = "${local.ssm_prefix}/deployment_mode"
  description = "Deployment mode for ${local.full_name}"
  type        = "String"
  value       = local.deployment_mode

  tags = {
    Name = "${local.full_name}-deployment-mode"
  }
}

# -----------------------------------------------------------------------------
# Security Parameters
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "db_secret_arn" {
  name        = "${local.ssm_prefix}/secret_arn"
  description = "Secrets Manager ARN for ${local.full_name} credentials"
  type        = "String"
  value       = aws_secretsmanager_secret.master_password.arn

  tags = {
    Name = "${local.full_name}-secret-arn"
  }
}

resource "aws_ssm_parameter" "db_security_group_id" {
  name        = "${local.ssm_prefix}/security_group_id"
  description = "Security group ID for ${local.full_name}"
  type        = "String"
  value       = aws_security_group.rds.id

  tags = {
    Name = "${local.full_name}-security-group-id"
  }
}

# -----------------------------------------------------------------------------
# Instance/Cluster Parameters
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "db_arn" {
  name        = "${local.ssm_prefix}/arn"
  description = "RDS instance/cluster ARN for ${local.full_name}"
  type        = "String"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].arn : aws_db_instance.main[0].arn

  tags = {
    Name = "${local.full_name}-arn"
  }
}

resource "aws_ssm_parameter" "db_resource_id" {
  name        = "${local.ssm_prefix}/resource_id"
  description = "RDS resource ID for ${local.full_name} (for IAM auth)"
  type        = "String"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].cluster_resource_id : aws_db_instance.main[0].resource_id

  tags = {
    Name = "${local.full_name}-resource-id"
  }
}
