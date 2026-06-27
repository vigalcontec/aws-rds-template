# =============================================================================
# Configuration - Update these values for your project
# =============================================================================

locals {
  # ─────────────────────────────────────────────────────────────────────────────
  # Project Configuration (UPDATE THESE)
  # ─────────────────────────────────────────────────────────────────────────────
  db_name      = "my-database" # Database identifier (without env suffix)
  project_name = "my-project"  # Project name for tagging
  company_name = "vigalcontec" # Company name for resource naming

  # ─────────────────────────────────────────────────────────────────────────────
  # AWS Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  aws_region = "eu-west-1"

  # ─────────────────────────────────────────────────────────────────────────────
  # RDS Engine Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Deployment mode: "provisioned" (traditional RDS) or "serverless" (Aurora Serverless v2)
  deployment_mode = "serverless"

  # Engine options:
  # - Provisioned: postgres, mysql, mariadb
  # - Serverless:  aurora-postgresql, aurora-mysql
  engine         = "aurora-postgresql"   # For serverless, use aurora-postgresql or aurora-mysql
  engine_version = "16.4"                
  family         = "aurora-postgresql16" 

  # Database name (created on instance)
  database_name = "appdb"

  # Master username (password managed via Secrets Manager)
  master_username = "dbadmin"

  # ─────────────────────────────────────────────────────────────────────────────
  # Instance Configuration (per environment) - For PROVISIONED mode
  # ─────────────────────────────────────────────────────────────────────────────
  instance_config = {
    dev = {
      instance_class      = "db.t3.micro"
      allocated_storage   = 20
      max_storage         = 100
      multi_az            = false
      deletion_protection = false
    }
    qa = {
      instance_class      = "db.t3.small"
      allocated_storage   = 50
      max_storage         = 200
      multi_az            = false
      deletion_protection = false
    }
    prod = {
      instance_class      = "db.t3.medium"
      allocated_storage   = 100
      max_storage         = 500
      multi_az            = true
      deletion_protection = true
    }
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Serverless Configuration (per environment) - For SERVERLESS mode
  # ─────────────────────────────────────────────────────────────────────────────
  # Aurora Serverless v2 uses ACUs (Aurora Capacity Units)
  # 1 ACU = ~2 GB RAM, min 0.5 ACU, max 128 ACU
  serverless_config = {
    dev = {
      min_capacity        = 0.5 # Minimum ACUs (can scale to zero with 0.5)
      max_capacity        = 2   # Maximum ACUs
      deletion_protection = false
    }
    qa = {
      min_capacity        = 0.5
      max_capacity        = 4
      deletion_protection = false
    }
    prod = {
      min_capacity        = 2 # Keep warm for production
      max_capacity        = 16
      deletion_protection = true
    }
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Backup Configuration (per environment)
  # ─────────────────────────────────────────────────────────────────────────────
  backup_config = {
    dev = {
      retention_period = 7
      backup_window    = "03:00-04:00"
    }
    qa = {
      retention_period = 14
      backup_window    = "03:00-04:00"
    }
    prod = {
      retention_period = 35
      backup_window    = "02:00-03:00"
    }
  }

  # Maintenance window (UTC)
  maintenance_window = "Mon:04:00-Mon:05:00"

  # ─────────────────────────────────────────────────────────────────────────────
  # Network Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # VPC SSM parameter paths (from aws-vpc-network-template)
  vpc_ssm_prefix = "/${var.environment}/${local.project_name}/vpc"

  # Port (default: 5432 for PostgreSQL, 3306 for MySQL)
  port = 5432

  # Public accessibility (should be false for production)
  publicly_accessible = false

  # ─────────────────────────────────────────────────────────────────────────────
  # Performance & Monitoring
  # ─────────────────────────────────────────────────────────────────────────────
  performance_insights_enabled   = var.environment == "prod" ? true : false
  performance_insights_retention = var.environment == "prod" ? 7 : 0

  # Enhanced monitoring interval (0 to disable, 1/5/10/15/30/60 seconds)
  monitoring_interval = var.environment == "prod" ? 60 : 0

  # CloudWatch Logs exports (postgresql: postgresql, upgrade; mysql: audit, error, general, slowquery)
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # ─────────────────────────────────────────────────────────────────────────────
  # Storage Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  storage_type       = "gp3"
  storage_encrypted  = true
  iops               = null # Only for io1/io2 storage types
  storage_throughput = null # Only for gp3 (minimum 125 MiB/s)

  # ─────────────────────────────────────────────────────────────────────────────
  # Computed Values (DO NOT MODIFY)
  # ─────────────────────────────────────────────────────────────────────────────
  account_id   = data.aws_caller_identity.current.account_id
  full_name    = "${local.db_name}-${var.environment}"
  state_bucket = "tfstate-${local.company_name}-${var.environment}-${local.account_id}"

  # Deployment mode flags
  is_serverless = local.deployment_mode == "serverless"
  is_aurora     = startswith(local.engine, "aurora-")

  # Current environment config
  current_instance   = local.instance_config[var.environment]
  current_serverless = local.serverless_config[var.environment]
  current_backup     = local.backup_config[var.environment]

  # Common tags
  common_tags = {
    Project     = local.project_name
    Database    = local.db_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
