variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "database_subnet_ids" {
  description = "List of subnet IDs for the database"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

# Database Configuration
variable "engine" {
  description = "Database engine"
  type        = string
  default     = "postgres"

  validation {
    condition = contains([
      "mysql", "postgres", "oracle-ee", "oracle-se2", "sqlserver-ee",
      "sqlserver-se", "sqlserver-ex", "sqlserver-web"
    ], var.engine)
    error_message = "Engine must be a valid RDS engine type."
  }
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.6"
}

variable "instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "payments"
}

variable "username" {
  description = "Username for the database"
  type        = string
  default     = "payments_user"
}

variable "manage_master_user_password" {
  description = "Whether to manage the master user password with AWS Secrets Manager"
  type        = bool
  default     = true
}

# Storage Configuration
variable "allocated_storage" {
  description = "Initial allocated storage (GB)"
  type        = number
  default     = 100
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage (GB) for autoscaling"
  type        = number
  default     = 1000
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.storage_type)
    error_message = "Storage type must be one of: gp2, gp3, io1, io2."
  }
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "iops" {
  description = "Amount of provisioned IOPS (for io1/io2 storage types)"
  type        = number
  default     = null
}

# Network Configuration
variable "publicly_accessible" {
  description = "Make database publicly accessible"
  type        = bool
  default     = false
}

# Backup Configuration
variable "backup_retention_period" {
  description = "Backup retention period (days)"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "backup_window" {
  description = "Backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "copy_tags_to_snapshot" {
  description = "Copy tags to snapshots"
  type        = bool
  default     = true
}

variable "delete_automated_backups" {
  description = "Delete automated backups when instance is deleted"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting"
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "Snapshot identifier to restore from"
  type        = string
  default     = null
}

# Maintenance Configuration
variable "maintenance_window" {
  description = "Maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

# High Availability
variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "create_read_replica" {
  description = "Create a read replica"
  type        = bool
  default     = true
}

variable "replica_instance_class" {
  description = "Instance class for read replica (defaults to main instance class)"
  type        = string
  default     = null
}

# Monitoring Configuration
variable "monitoring_interval" {
  description = "Enhanced monitoring interval (seconds). 0 = disabled"
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_kms_key_id" {
  description = "KMS key ID for Performance Insights encryption"
  type        = string
  default     = null
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period (days)"
  type        = number
  default     = 7

  validation {
    condition     = contains([7, 31, 62, 93, 124, 155, 186, 217, 248, 279, 310, 341, 372, 403, 434, 465, 496, 527, 558, 589, 620, 651, 682, 713, 731], var.performance_insights_retention_period)
    error_message = "Performance Insights retention period must be a valid value."
  }
}

# Logging Configuration
variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = []
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "CloudWatch log group retention period"
  type        = number
  default     = 7
}

# Parameter and Option Groups
variable "parameter_group_family" {
  description = "Parameter group family (auto-detected for postgres)"
  type        = string
  default     = ""
}

variable "db_parameters" {
  description = "List of database parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "db_options" {
  description = "List of database options"
  type = list(object({
    option_name = string
    option_settings = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = []
}

# Character Set and Timezone (for specific engines)
variable "character_set_name" {
  description = "Character set name (Oracle only)"
  type        = string
  default     = null
}

variable "timezone" {
  description = "Timezone (SQL Server only)"
  type        = string
  default     = null
}

# Secrets Management
variable "create_db_secret" {
  description = "Create database secret in AWS Secrets Manager"
  type        = bool
  default     = true
}

variable "secret_recovery_window_in_days" {
  description = "Secret recovery window in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
