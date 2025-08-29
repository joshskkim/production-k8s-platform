# Generate random password for database
resource "random_password" "master" {
  length  = 16
  special = true
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.tags
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  family = var.engine == "postgres" ? "postgres${split(".", var.engine_version)[0]}" : var.parameter_group_family
  name   = "${var.name_prefix}-${var.engine}-params"

  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# DB Option Group (for engines that support it)
resource "aws_db_option_group" "main" {
  count = var.engine == "mysql" || var.engine == "oracle-ee" || var.engine == "oracle-se2" || var.engine == "sqlserver-ee" || var.engine == "sqlserver-se" || var.engine == "sqlserver-ex" || var.engine == "sqlserver-web" ? 1 : 0

  name                     = "${var.name_prefix}-${var.engine}-options"
  option_group_description = "Option group for ${var.name_prefix} ${var.engine}"
  engine_name              = var.engine
  major_engine_version     = split(".", var.engine_version)[0]

  dynamic "option" {
    for_each = var.db_options
    content {
      option_name = option.value.option_name

      dynamic "option_settings" {
        for_each = lookup(option.value, "option_settings", [])
        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Enhanced Monitoring IAM Role
resource "aws_iam_role" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.name_prefix}-rds-enhanced-monitoring"

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-${var.database_name}"

  # Engine configuration
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Database configuration
  db_name  = var.database_name
  username = var.username
  password = var.manage_master_user_password ? null : random_password.master.result

  # Master user password management
  manage_master_user_password   = var.manage_master_user_password
  master_user_secret_kms_key_id = var.manage_master_user_password ? aws_kms_key.rds.key_id : null

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.storage_encrypted ? aws_kms_key.rds.arn : null
  iops                  = var.storage_type == "io1" || var.storage_type == "io2" ? var.iops : null

  # Network & Security
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = var.publicly_accessible

  # Parameter and Option Groups
  parameter_group_name = aws_db_parameter_group.main.name
  option_group_name    = var.engine == "postgres" ? null : try(aws_db_option_group.main[0].name, null)

  # Backup configuration
  backup_retention_period  = var.backup_retention_period
  backup_window            = var.backup_window
  copy_tags_to_snapshot    = var.copy_tags_to_snapshot
  delete_automated_backups = var.delete_automated_backups
  deletion_protection      = var.deletion_protection

  # Maintenance
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # High Availability
  multi_az = var.multi_az

  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null

  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled && var.performance_insights_kms_key_id != null ? var.performance_insights_kms_key_id : aws_kms_key.rds.arn
  performance_insights_retention_period = var.performance_insights_retention_period

  # Logs
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # Snapshot configuration
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-${var.database_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  snapshot_identifier       = var.snapshot_identifier

  # Character set (Oracle only)
  character_set_name = var.character_set_name

  # Timezone (SQL Server only)
  timezone = var.timezone

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.database_name}"
  })

  lifecycle {
    ignore_changes = [
      password,
      final_snapshot_identifier,
    ]
  }

  depends_on = [aws_cloudwatch_log_group.database]
}

# # Read Replica
# resource "aws_db_instance" "replica" {
#   manage_master_user_password = false
#   count = var.create_read_replica ? 1 : 0

#   identifier = "${var.name_prefix}-${var.database_name}-replica"

#   # Replica configuration
#   replicate_source_db = aws_db_instance.main.identifier
#   instance_class      = var.replica_instance_class != null ? var.replica_instance_class : var.instance_class

#   # Storage (inherited from source)
#   storage_encrypted = var.storage_encrypted
#   kms_key_id        = var.storage_encrypted ? aws_kms_key.rds.arn : null

#   # Network & Security
#   vpc_security_group_ids = var.security_group_ids
#   publicly_accessible    = var.publicly_accessible

#   # Monitoring
#   monitoring_interval = var.monitoring_interval
#   monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null

#   # Performance Insights
#   performance_insights_enabled          = var.performance_insights_enabled
#   performance_insights_kms_key_id       = var.performance_insights_enabled && var.performance_insights_kms_key_id != null ? var.performance_insights_kms_key_id : aws_kms_key.rds.arn
#   performance_insights_retention_period = var.performance_insights_retention_period

#   # Maintenance
#   auto_minor_version_upgrade = var.auto_minor_version_upgrade

#   # Snapshot configuration
#   skip_final_snapshot = true

#   tags = merge(var.tags, {
#     Name = "${var.name_prefix}-${var.database_name}-replica"
#     Role = "replica"
#   })

#   depends_on = [aws_db_instance.main]
# }

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "database" {
  for_each = toset(var.enabled_cloudwatch_logs_exports)

  name              = "/aws/rds/instance/${var.name_prefix}-${var.database_name}/${each.key}"
  retention_in_days = var.cloudwatch_log_group_retention_in_days

  tags = var.tags
}

# Store database credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "database" {
  count = var.create_db_secret ? 1 : 0

  name                    = "${var.name_prefix}/rds/${var.database_name}"
  description             = "Database credentials for ${var.name_prefix} ${var.database_name}"
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "database" {
  count = var.create_db_secret ? 1 : 0

  secret_id = aws_secretsmanager_secret.database[0].id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = var.manage_master_user_password ? "managed-by-aws" : random_password.master.result
    engine   = aws_db_instance.main.engine
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
    # Read replica information if available
    # replica_host = var.create_read_replica ? aws_db_instance.replica[0].endpoint : null
  })
}
