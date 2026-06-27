# =============================================================================
# Outputs - RDS Instance Information
# =============================================================================

output "deployment_mode" {
  description = "Deployment mode: provisioned or serverless"
  value       = local.deployment_mode
}

output "db_identifier" {
  description = "The RDS instance/cluster identifier"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].cluster_identifier : aws_db_instance.main[0].identifier
}

output "db_arn" {
  description = "The ARN of the RDS instance/cluster"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].arn : aws_db_instance.main[0].arn
}

output "db_endpoint" {
  description = "The connection endpoint"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].endpoint : aws_db_instance.main[0].endpoint
}

output "db_reader_endpoint" {
  description = "The reader endpoint (Aurora Serverless only)"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].reader_endpoint : null
}

output "db_address" {
  description = "The hostname of the RDS instance/cluster"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].endpoint : aws_db_instance.main[0].address
}

output "db_port" {
  description = "The database port"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].port : aws_db_instance.main[0].port
}

output "db_name" {
  description = "The database name"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].database_name : aws_db_instance.main[0].db_name
}

output "db_username" {
  description = "The master username"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].master_username : aws_db_instance.main[0].username
  sensitive   = true
}

output "db_resource_id" {
  description = "The RDS Resource ID (for IAM auth)"
  value       = local.is_serverless ? aws_rds_cluster.serverless[0].cluster_resource_id : aws_db_instance.main[0].resource_id
}

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------
output "security_group_id" {
  description = "The security group ID for the RDS instance"
  value       = aws_security_group.rds.id
}

output "secret_arn" {
  description = "The ARN of the Secrets Manager secret containing credentials"
  value       = aws_secretsmanager_secret.master_password.arn
}

# -----------------------------------------------------------------------------
# SSM Parameter Paths (for reference)
# -----------------------------------------------------------------------------
output "ssm_endpoint_path" {
  description = "SSM parameter path for database endpoint"
  value       = aws_ssm_parameter.db_endpoint.name
}

output "ssm_secret_arn_path" {
  description = "SSM parameter path for secret ARN"
  value       = aws_ssm_parameter.db_secret_arn.name
}
