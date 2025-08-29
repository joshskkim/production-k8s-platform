variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

# Engine Configuration
variable "engine" {
  description = "Cache engine (redis or memcached)"
  type        = string
  default     = "redis"

  validation {
    condition     = contains(["redis", "memcached"], var.engine)
    error_message = "Engine must be either 'redis' or 'memcached'."
  }
}

variable "engine_version" {
  description = "Engine version"
  type        = string
  default     = "7.0"
}

variable "node_type" {
  description = "Node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "port" {
  description = "Port number"
  type        = number
  default     = 6379
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "redis7"
}

variable "parameters" {
  description = "List of parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]
}

# Cluster Configuration
variable "num_cache_clusters" {
  description = "Number of cache clusters (nodes)"
  type        = number
  default     = 2
}

variable "cluster_mode_enabled" {
  description = "Enable cluster mode (Redis only)"
  type        = bool
  default     = false
}

variable "num_node_groups" {
  description = "Number of node groups (shards) for cluster mode"
  type        = number
  default     = 1
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes per node group"
  type        = number
  default     = 1
}

# Security Configuration
variable "at_rest_encryption_enabled" {
  description = "Enable at-rest encryption"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable transit encryption"
  type        = bool
  default     = true
}

variable "auth_token_enabled" {
  description = "Enable auth token"
  type        = bool
  default     = true
}

variable "auth_token_update_strategy" {
  description = "Auth token update strategy (SET, ROTATE, DELETE)"
  type        = string
  default     = "ROTATE"

  validation {
    condition     = contains(["SET", "ROTATE", "DELETE"], var.auth_token_update_strategy)
    error_message = "Auth token update strategy must be SET, ROTATE, or DELETE."
  }
}

# High Availability
variable "automatic_failover_enabled" {
  description = "Enable automatic failover"
  type        = bool
  default     = true
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = true
}

# Backup Configuration
variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 5
}

variable "snapshot_window" {
  description = "Daily time range for snapshots (UTC)"
  type        = string
  default     = "03:00-05:00"
}

variable "final_snapshot_identifier" {
  description = "Final snapshot identifier"
  type        = string
  default     = null
}

# Maintenance Configuration
variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
  default     = false
}

# Notifications
variable "notification_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = null
}

# Logging Configuration
variable "log_delivery_configuration_enabled" {
  description = "Enable log delivery configuration"
  type        = bool
  default     = true
}

variable "log_delivery_configurations" {
  description = "Log delivery configurations"
  type = list(object({
    destination      = string
    destination_type = string
    log_format       = string
    log_type         = string
  }))
  default = [
    {
      destination      = ""
      destination_type = "cloudwatch-logs"
      log_format       = "text"
      log_type         = "slow-log"
    }
  ]
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "CloudWatch log group retention period"
  type        = number
  default     = 7
}

# Data Tiering (Redis 6.2+)
variable "data_tiering_enabled" {
  description = "Enable data tiering"
  type        = bool
  default     = false
}

# Availability Zones (Memcached)
variable "preferred_availability_zones" {
  description = "Preferred availability zones for Memcached nodes"
  type        = list(string)
  default     = []
}

# User Management (Redis 6.0+)
variable "create_users" {
  description = "Create ElastiCache users"
  type        = bool
  default     = false
}

variable "users" {
  description = "List of ElastiCache users"
  type = list(object({
    user_id       = string
    user_name     = string
    access_string = string
    passwords     = list(string)
  }))
  default = []
}

variable "create_user_group" {
  description = "Create ElastiCache user group"
  type        = bool
  default     = false
}

# Secrets Management
variable "create_auth_token_secret" {
  description = "Create auth token secret in AWS Secrets Manager"
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