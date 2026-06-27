# AWS RDS Template

[![Terraform](https://img.shields.io/badge/Terraform-1.10%2B-7B42BC?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-RDS-FF9900?logo=amazonrds)](https://aws.amazon.com/rds/)

Production-ready AWS RDS PostgreSQL/MySQL template with Terraform and GitHub Actions CI/CD.

---

## 📋 Table of Contents

- [Features](#features)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [SSM Parameters](#ssm-parameters)
- [Connecting to the Database](#connecting-to-the-database)
- [Cost Estimates](#cost-estimates)

---

## Features

- ✅ **RDS Instance** - PostgreSQL or MySQL support
- ✅ **Multi-AZ** - High availability for production
- ✅ **Auto-scaling Storage** - gp3 with automatic expansion
- ✅ **Secrets Manager** - Secure password management
- ✅ **IAM Authentication** - Database access via IAM roles
- ✅ **Performance Insights** - Query performance monitoring
- ✅ **Enhanced Monitoring** - OS-level metrics
- ✅ **CloudWatch Alarms** - CPU, storage, connections
- ✅ **Automated Backups** - Configurable retention
- ✅ **Terraform** - Infrastructure as Code
- ✅ **GitHub Actions** - CI/CD pipeline with OIDC authentication
- ✅ **Multi-environment** - dev, qa, prod support
- ✅ **SSM Integration** - Export connection details to Parameter Store

---

## Repository Structure

```
aws-rds-template/
├── .github/
│   └── workflows/
│       └── deploy.yml              # CI/CD pipeline
├── terraform/
│   ├── config.tf                   # ⭐ PROJECT CONFIG (edit this!)
│   ├── main.tf                     # RDS instance, security group, secrets
│   ├── variables.tf                # Runtime variables (env)
│   ├── outputs.tf                  # Output values
│   ├── backend.tf                  # S3 backend (uses -backend-config)
│   └── ssm_exports.tf              # SSM parameter exports
├── CHANGELOG.md
└── README.md
```

---

## Prerequisites

- **Terraform 1.10+**
- **AWS CLI v2**
- **GitHub repository** with OIDC configured
- **VPC deployed** via `aws-vpc-network-template`

### Bootstrap Requirements

This template requires:
1. `aws-bootstrap-tfstate-oidc` - S3 bucket for Terraform state, IAM role for GitHub Actions
2. `aws-vpc-network-template` - VPC with database subnets and subnet group

---

## Quick Start

### 1. Create New Repository from Template

```bash
# Clone template
git clone https://github.com/vigalcontec/aws-rds-template.git my-database
cd my-database

# Remove template git history
rm -rf .git
git init
```

### 2. Configure Your Project

Edit `terraform/config.tf`:

```hcl
locals {
  db_name      = "my-app-db"        # Your database identifier
  project_name = "my-project"       # Your project name
  company_name = "vigalcontec"      # Your company name
  
  # Engine
  engine         = "postgres"       # postgres or mysql
  engine_version = "16.3"
  family         = "postgres16"
  
  # Database
  database_name   = "appdb"
  master_username = "dbadmin"
}
```

### 3. Configure GitHub Secrets

Add the following secrets to your GitHub repository (`Settings > Secrets and variables > Actions`):

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN_DEV` | ARN of the GitHub Actions IAM role for dev |
| `AWS_ROLE_ARN_QA` | ARN of the GitHub Actions IAM role for qa |
| `AWS_ROLE_ARN_PROD` | ARN of the GitHub Actions IAM role for prod |

### 4. Enable CI/CD Workflows

Edit `.github/workflows/deploy.yml` and uncomment the triggers:

```yaml
on:
  workflow_dispatch:
    # ... (keep this for manual runs)
  
  # UNCOMMENT THESE LINES:
  push:
    branches: [main, develop, "feature/*", "release/*"]
    paths:
      - 'terraform/**'
      - '.github/workflows/deploy.yml'
  pull_request:
    branches: [main, develop]
    paths:
      - 'terraform/**'
```

---

## Configuration

### Deployment Mode

Choose between **Provisioned** (traditional RDS) or **Serverless** (Aurora Serverless v2):

```hcl
# Provisioned (default) - fixed instance size
deployment_mode = "provisioned"

# Serverless - auto-scaling capacity
deployment_mode = "serverless"
```

### Engine Options

```hcl
# ─────────────────────────────────────────────────────────────────
# PROVISIONED MODE
# ─────────────────────────────────────────────────────────────────
# PostgreSQL
engine         = "postgres"
engine_version = "16.3"
family         = "postgres16"
port           = 5432

# MySQL
engine         = "mysql"
engine_version = "8.0"
family         = "mysql8.0"
port           = 3306

# ─────────────────────────────────────────────────────────────────
# SERVERLESS MODE (Aurora Serverless v2)
# ─────────────────────────────────────────────────────────────────
# Aurora PostgreSQL
deployment_mode = "serverless"
engine          = "aurora-postgresql"
engine_version  = "15.4"
family          = "aurora-postgresql15"
port            = 5432

# Aurora MySQL
deployment_mode = "serverless"
engine          = "aurora-mysql"
engine_version  = "3.04.0"
family          = "aurora-mysql8.0"
port            = 3306
```

### Instance Sizing (Provisioned Mode)

Pre-configured per environment in `config.tf`:

| Environment | Instance Class | Storage | Multi-AZ | Deletion Protection |
|-------------|---------------|---------|----------|---------------------|
| dev | db.t3.micro | 20-100 GB | No | No |
| qa | db.t3.small | 50-200 GB | No | No |
| prod | db.t3.medium | 100-500 GB | Yes | Yes |

### Serverless Scaling (Serverless Mode)

Aurora Serverless v2 uses ACUs (Aurora Capacity Units). 1 ACU ≈ 2 GB RAM.

| Environment | Min ACU | Max ACU | Deletion Protection |
|-------------|---------|---------|---------------------|
| dev | 0.5 | 2 | No |
| qa | 0.5 | 4 | No |
| prod | 2 | 16 | Yes |

**Cost optimization:** Set `min_capacity = 0.5` to allow scaling near zero during idle periods.

### Backup Configuration

| Environment | Retention | Backup Window |
|-------------|-----------|---------------|
| dev | 7 days | 03:00-04:00 UTC |
| qa | 14 days | 03:00-04:00 UTC |
| prod | 35 days | 02:00-03:00 UTC |

---

## Deployment

### GitHub Actions (Recommended)

| Branch | Environment |
|--------|-------------|
| `main` | prod |
| `release/*` | qa |
| `develop`, `feature/*` | dev |

### Manual Deploy/Destroy

1. Go to **Actions** → **Deploy RDS**
2. Click **Run workflow**
3. Select:
   - **Environment:** dev, qa, or prod
   - **Action:** `deploy` or `destroy`

### Local Deployment

```bash
cd terraform

# Create backend_override.tf with your backend config
terraform init \
  -backend-config="bucket=tfstate-vigalcontec-dev-123456789012" \
  -backend-config="key=rds/my-app-db/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="encrypt=true"

terraform apply -var="environment=dev"
```

---

## SSM Parameters

The template exports connection details to SSM Parameter Store:

| Parameter | Description |
|-----------|-------------|
| `/{env}/{project}/rds/{db}/endpoint` | Full endpoint (host:port) |
| `/{env}/{project}/rds/{db}/address` | Hostname only |
| `/{env}/{project}/rds/{db}/port` | Port number |
| `/{env}/{project}/rds/{db}/database_name` | Database name |
| `/{env}/{project}/rds/{db}/secret_arn` | Secrets Manager ARN |
| `/{env}/{project}/rds/{db}/security_group_id` | Security group ID |
| `/{env}/{project}/rds/{db}/instance_arn` | RDS instance ARN |
| `/{env}/{project}/rds/{db}/resource_id` | Resource ID (for IAM auth) |

---

## Connecting to the Database

### Get Credentials from Secrets Manager

```bash
# Get secret ARN from SSM
SECRET_ARN=$(aws ssm get-parameter \
  --name "/dev/my-project/rds/my-app-db/secret_arn" \
  --query "Parameter.Value" --output text)

# Get credentials
aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --query "SecretString" --output text | jq .
```

### Python Example

```python
import boto3
import json
import psycopg2

# Get credentials from Secrets Manager
secrets = boto3.client('secretsmanager')
secret = json.loads(
    secrets.get_secret_value(SecretId='my-app-db-dev-master-password')['SecretString']
)

# Connect
conn = psycopg2.connect(
    host=secret['host'],
    port=secret['port'],
    database=secret['dbname'],
    user=secret['username'],
    password=secret['password']
)
```

### IAM Authentication (Recommended)

```python
import boto3
import psycopg2

rds = boto3.client('rds')
token = rds.generate_db_auth_token(
    DBHostname='my-app-db-dev.xxx.eu-west-1.rds.amazonaws.com',
    Port=5432,
    DBUsername='iam_user',
    Region='eu-west-1'
)

conn = psycopg2.connect(
    host='my-app-db-dev.xxx.eu-west-1.rds.amazonaws.com',
    port=5432,
    database='appdb',
    user='iam_user',
    password=token,
    sslmode='require'
)
```

---

## Cost Estimates

### Monthly Costs (eu-west-1)

| Environment | Instance | Storage | Multi-AZ | Estimated Cost |
|-------------|----------|---------|----------|----------------|
| dev | db.t3.micro | 20 GB gp3 | No | ~$15/month |
| qa | db.t3.small | 50 GB gp3 | No | ~$30/month |
| prod | db.t3.medium | 100 GB gp3 | Yes | ~$120/month |

**Additional costs:**
- Secrets Manager: ~$0.40/secret/month
- Performance Insights: Free (7-day retention)
- Enhanced Monitoring: Free tier available
- Backups: Free up to 100% of provisioned storage

---

## Security Best Practices

1. **Never expose publicly** - Keep `publicly_accessible = false`
2. **Use IAM authentication** - Avoid long-lived passwords
3. **Rotate credentials** - Enable Secrets Manager rotation
4. **Encrypt at rest** - Always enabled by default
5. **Use SSL/TLS** - Enforce encrypted connections
6. **Restrict security groups** - Only allow necessary CIDR ranges

---

## License

MIT