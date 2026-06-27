# =============================================================================
# AWS RDS PostgreSQL/MySQL Instance (Provisioned or Aurora Serverless v2)
# =============================================================================

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = local.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get VPC configuration from SSM (deployed by aws-vpc-network-template)
data "aws_ssm_parameter" "vpc_id" {
  name = "${local.vpc_ssm_prefix}/${local.project_name}/vpc_id"
}

data "aws_ssm_parameter" "database_subnet_ids" {
  name = "${local.vpc_ssm_prefix}/${local.project_name}/database_subnet_ids"
}

data "aws_ssm_parameter" "database_subnet_group_name" {
  name = "${local.vpc_ssm_prefix}/${local.project_name}/database_subnet_group_name"
}

# -----------------------------------------------------------------------------
# Random Password for Master User
# -----------------------------------------------------------------------------
resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# -----------------------------------------------------------------------------
# Secrets Manager - Master Password
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "master_password" {
  name        = "${local.full_name}-master-password"
  description = "Master password for RDS instance ${local.full_name}"

  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Name = "${local.full_name}-master-password"
  }
}

resource "aws_secretsmanager_secret_version" "master_password" {
  secret_id = aws_secretsmanager_secret.master_password.id
  secret_string = jsonencode({
    username = local.master_username
    password = random_password.master.result
    engine   = local.engine
    host     = local.is_serverless ? aws_rds_cluster.serverless[0].endpoint : aws_db_instance.main[0].address
    port     = local.port
    dbname   = local.database_name
  })

  depends_on = [aws_db_instance.main, aws_rds_cluster.serverless]
}

# -----------------------------------------------------------------------------
# Security Group for RDS
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${local.full_name}-rds-sg"
  description = "Security group for RDS instance ${local.full_name}"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  tags = {
    Name = "${local.full_name}-rds-sg"
  }
}

# Ingress rule - Allow from VPC CIDR (customize as needed)
resource "aws_vpc_security_group_ingress_rule" "rds_from_vpc" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow database traffic from VPC"
  ip_protocol       = "tcp"
  from_port         = local.port
  to_port           = local.port
  cidr_ipv4         = data.aws_vpc.main.cidr_block

  tags = {
    Name = "${local.full_name}-rds-ingress"
  }
}

# Egress rule - Allow all outbound
resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.full_name}-rds-egress"
  }
}

# Get VPC details for CIDR
data "aws_vpc" "main" {
  id = data.aws_ssm_parameter.vpc_id.value
}

# -----------------------------------------------------------------------------
# DB Parameter Group (for Provisioned RDS)
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  count = local.is_serverless ? 0 : 1

  name        = "${local.full_name}-params"
  family      = local.family
  description = "Parameter group for ${local.full_name}"

  # PostgreSQL specific parameters
  dynamic "parameter" {
    for_each = local.engine == "postgres" ? [1] : []
    content {
      name  = "log_statement"
      value = "all"
    }
  }

  dynamic "parameter" {
    for_each = local.engine == "postgres" ? [1] : []
    content {
      name  = "log_min_duration_statement"
      value = "1000" # Log queries taking more than 1 second
    }
  }

  tags = {
    Name = "${local.full_name}-params"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# DB Cluster Parameter Group (for Aurora Serverless v2)
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_parameter_group" "serverless" {
  count = local.is_serverless ? 1 : 0

  name        = "${local.full_name}-cluster-params"
  family      = local.family
  description = "Cluster parameter group for ${local.full_name}"

  # Aurora PostgreSQL specific parameters
  dynamic "parameter" {
    for_each = local.engine == "aurora-postgresql" ? [1] : []
    content {
      name  = "log_statement"
      value = "all"
    }
  }

  dynamic "parameter" {
    for_each = local.engine == "aurora-postgresql" ? [1] : []
    content {
      name  = "log_min_duration_statement"
      value = "1000"
    }
  }

  tags = {
    Name = "${local.full_name}-cluster-params"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# DB Option Group (for MySQL/MariaDB features - Provisioned only)
# -----------------------------------------------------------------------------
resource "aws_db_option_group" "main" {
  count = !local.is_serverless && (local.engine == "mysql" || local.engine == "mariadb") ? 1 : 0

  name                     = "${local.full_name}-options"
  option_group_description = "Option group for ${local.full_name}"
  engine_name              = local.engine
  major_engine_version     = split(".", local.engine_version)[0]

  tags = {
    Name = "${local.full_name}-options"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# IAM Role for Enhanced Monitoring (Provisioned only)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  count = !local.is_serverless && local.monitoring_interval > 0 ? 1 : 0

  name = "${local.full_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.full_name}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = !local.is_serverless && local.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# -----------------------------------------------------------------------------
# RDS Instance (Provisioned Mode)
# -----------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  count = local.is_serverless ? 0 : 1

  identifier = local.full_name

  # Engine
  engine         = local.engine
  engine_version = local.engine_version

  # Instance
  instance_class = local.current_instance.instance_class

  # Storage
  allocated_storage     = local.current_instance.allocated_storage
  max_allocated_storage = local.current_instance.max_storage
  storage_type          = local.storage_type
  storage_encrypted     = local.storage_encrypted
  iops                  = local.iops
  storage_throughput    = local.storage_throughput

  # Database
  db_name  = local.database_name
  username = local.master_username
  password = random_password.master.result
  port     = local.port

  # Network
  db_subnet_group_name   = data.aws_ssm_parameter.database_subnet_group_name.value
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = local.publicly_accessible
  multi_az               = local.current_instance.multi_az

  # Parameter & Option Groups
  parameter_group_name = aws_db_parameter_group.main[0].name
  option_group_name    = local.engine == "mysql" || local.engine == "mariadb" ? aws_db_option_group.main[0].name : null

  # Backup
  backup_retention_period   = local.current_backup.retention_period
  backup_window             = local.current_backup.backup_window
  maintenance_window        = local.maintenance_window
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${local.full_name}-final-snapshot" : null

  # Monitoring
  performance_insights_enabled          = local.performance_insights_enabled
  performance_insights_retention_period = local.performance_insights_retention
  monitoring_interval                   = local.monitoring_interval
  monitoring_role_arn                   = local.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  enabled_cloudwatch_logs_exports       = local.enabled_cloudwatch_logs_exports

  # Security
  deletion_protection                 = local.current_instance.deletion_protection
  iam_database_authentication_enabled = true

  # Upgrades
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = var.environment != "prod"

  tags = {
    Name = local.full_name
  }

  lifecycle {
    ignore_changes = [
      password # Password managed by Secrets Manager after initial creation
    ]
  }
}

# =============================================================================
# AURORA SERVERLESS V2 RESOURCES
# =============================================================================

# -----------------------------------------------------------------------------
# Aurora Serverless v2 DB Subnet Group
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "serverless" {
  count = local.is_serverless ? 1 : 0

  name        = "${local.full_name}-subnet-group"
  description = "Subnet group for Aurora Serverless ${local.full_name}"
  subnet_ids  = split(",", data.aws_ssm_parameter.database_subnet_ids.value)

  tags = {
    Name = "${local.full_name}-subnet-group"
  }
}

# -----------------------------------------------------------------------------
# Aurora Serverless v2 Cluster
# -----------------------------------------------------------------------------
resource "aws_rds_cluster" "serverless" {
  count = local.is_serverless ? 1 : 0

  cluster_identifier = local.full_name

  # Engine
  engine         = local.engine
  engine_mode    = "provisioned" # Required for Serverless v2
  engine_version = local.engine_version

  # Database
  database_name   = local.database_name
  master_username = local.master_username
  master_password = random_password.master.result
  port            = local.port

  # Network
  db_subnet_group_name   = aws_db_subnet_group.serverless[0].name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = local.current_serverless.min_capacity
    max_capacity = local.current_serverless.max_capacity
  }

  # Parameter Group
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.serverless[0].name

  # Backup
  backup_retention_period      = local.current_backup.retention_period
  preferred_backup_window      = local.current_backup.backup_window
  preferred_maintenance_window = local.maintenance_window
  copy_tags_to_snapshot        = true
  skip_final_snapshot          = var.environment != "prod"
  final_snapshot_identifier    = var.environment == "prod" ? "${local.full_name}-final-snapshot" : null

  # Security
  storage_encrypted                   = true
  deletion_protection                 = local.current_serverless.deletion_protection
  iam_database_authentication_enabled = true

  # CloudWatch Logs
  enabled_cloudwatch_logs_exports = local.engine == "aurora-postgresql" ? ["postgresql"] : ["audit", "error", "slowquery"]

  # Upgrades
  apply_immediately           = var.environment != "prod"
  allow_major_version_upgrade = false

  tags = {
    Name = local.full_name
  }

  lifecycle {
    ignore_changes = [
      master_password
    ]
  }
}

# -----------------------------------------------------------------------------
# Aurora Serverless v2 Instance
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "serverless" {
  count = local.is_serverless ? 1 : 0

  identifier         = "${local.full_name}-instance-1"
  cluster_identifier = aws_rds_cluster.serverless[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.serverless[0].engine
  engine_version     = aws_rds_cluster.serverless[0].engine_version

  # Performance
  performance_insights_enabled          = local.performance_insights_enabled
  performance_insights_retention_period = local.performance_insights_enabled ? 7 : null

  # Upgrades
  auto_minor_version_upgrade = true
  apply_immediately          = var.environment != "prod"

  tags = {
    Name = "${local.full_name}-instance-1"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms (Provisioned Mode)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = !local.is_serverless && var.environment == "prod" ? 1 : 0

  alarm_name          = "${local.full_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main[0].identifier
  }

  tags = {
    Name = "${local.full_name}-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "storage_low" {
  count = !local.is_serverless && var.environment == "prod" ? 1 : 0

  alarm_name          = "${local.full_name}-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240 # 10 GB in bytes
  alarm_description   = "RDS free storage space is low"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main[0].identifier
  }

  tags = {
    Name = "${local.full_name}-storage-low"
  }
}

resource "aws_cloudwatch_metric_alarm" "connections_high" {
  count = !local.is_serverless && var.environment == "prod" ? 1 : 0

  alarm_name          = "${local.full_name}-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "RDS database connections are high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main[0].identifier
  }

  tags = {
    Name = "${local.full_name}-connections-high"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms (Serverless Mode)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "serverless_cpu_high" {
  count = local.is_serverless && var.environment == "prod" ? 1 : 0

  alarm_name          = "${local.full_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora Serverless CPU utilization is high"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.serverless[0].cluster_identifier
  }

  tags = {
    Name = "${local.full_name}-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "serverless_acu_high" {
  count = local.is_serverless && var.environment == "prod" ? 1 : 0

  alarm_name          = "${local.full_name}-acu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = local.current_serverless.max_capacity * 0.8 # 80% of max
  alarm_description   = "Aurora Serverless ACU capacity is high"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.serverless[0].cluster_identifier
  }

  tags = {
    Name = "${local.full_name}-acu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "serverless_connections_high" {
  count = local.is_serverless && var.environment == "prod" ? 1 : 0

  alarm_name          = "${local.full_name}-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Aurora Serverless database connections are high"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.serverless[0].cluster_identifier
  }

  tags = {
    Name = "${local.full_name}-connections-high"
  }
}
