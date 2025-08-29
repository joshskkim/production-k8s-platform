# Generate random auth token for Redis
resource "random_password" "auth_token" {
  count = var.auth_token_enabled ? 1 : 0

  length  = 32
  special = false
}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.name_prefix}-cache-subnet-group"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  family = var.parameter_group_family
  name   = "${var.name_prefix}-${var.engine}-params"

  dynamic "parameter" {
    for_each = var.parameters
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

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  count = var.log_delivery_configuration_enabled ? 1 : 0

  name              = "/aws/elasticache/${var.name_prefix}-${var.engine}"
  retention_in_days = var.cloudwatch_log_group_retention_in_days

  tags = var.tags
}

# ElastiCache Replication Group (Redis)
resource "aws_elasticache_replication_group" "redis" {
  count = var.engine == "redis" ? 1 : 0

  replication_group_id = "${var.name_prefix}-redis"
  description          = "Redis cluster for ${var.name_prefix}"

  # Engine configuration
  engine               = var.engine
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = var.port
  parameter_group_name = aws_elasticache_parameter_group.main.name

  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = var.security_group_ids

  # Cluster configuration
  num_cache_clusters = var.cluster_mode_enabled ? null : var.num_cache_clusters

  # Cluster mode configuration (for Redis)
  dynamic "num_node_groups" {
    for_each = var.cluster_mode_enabled ? [1] : []
    content {
      num_node_groups         = var.num_node_groups
      replicas_per_node_group = var.replicas_per_node_group
    }
  }

  # Security
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.auth_token_enabled ? random_password.auth_token[0].result : null
  auth_token_update_strategy = var.auth_token_update_strategy

  # High Availability
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  # Backup configuration
  snapshot_retention_limit  = var.snapshot_retention_limit
  snapshot_window           = var.snapshot_window
  final_snapshot_identifier = var.final_snapshot_identifier

  # Maintenance
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  # Notifications
  notification_topic_arn = var.notification_topic_arn

  # Log delivery configuration
  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configuration_enabled ? var.log_delivery_configurations : []
    content {
      destination      = log_delivery_configuration.value.destination_type == "cloudwatch-logs" ? aws_cloudwatch_log_group.main[0].name : log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  # Data tiering (Redis 6.2+)
  data_tiering_enabled = var.data_tiering_enabled

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis"
  })
}

# ElastiCache Cluster (Memcached)
resource "aws_elasticache_cluster" "memcached" {
  count = var.engine == "memcached" ? 1 : 0

  cluster_id           = "${var.name_prefix}-memcached"
  engine               = var.engine
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_clusters
  parameter_group_name = aws_elasticache_parameter_group.main.name
  port                 = var.port
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = var.security_group_ids

  # Maintenance
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  # Notifications
  notification_topic_arn = var.notification_topic_arn

  # Availability Zone configuration for Memcached
  dynamic "preferred_availability_zones" {
    for_each = length(var.preferred_availability_zones) > 0 ? [var.preferred_availability_zones] : []
    content {
      preferred_availability_zones = preferred_availability_zones.value
    }
  }

  # Log delivery configuration
  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configuration_enabled ? var.log_delivery_configurations : []
    content {
      destination      = log_delivery_configuration.value.destination_type == "cloudwatch-logs" ? aws_cloudwatch_log_group.main[0].name : log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-memcached"
  })
}

# Store auth token in AWS Secrets Manager
resource "aws_secretsmanager_secret" "auth_token" {
  count = var.auth_token_enabled && var.create_auth_token_secret ? 1 : 0

  name                    = "${var.name_prefix}/${var.engine}/auth"
  description             = "${var.engine} auth token for ${var.name_prefix}"
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "auth_token" {
  count = var.auth_token_enabled && var.create_auth_token_secret ? 1 : 0

  secret_id = aws_secretsmanager_secret.auth_token[0].id
  secret_string = jsonencode({
    auth_token = random_password.auth_token[0].result
    endpoint   = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : aws_elasticache_cluster.memcached[0].cluster_address
    port       = var.port
    engine     = var.engine
  })
}

# ElastiCache User (Redis 6.0+)
resource "aws_elasticache_user" "main" {
  count = var.create_users ? length(var.users) : 0

  user_id       = var.users[count.index].user_id
  user_name     = var.users[count.index].user_name
  access_string = var.users[count.index].access_string
  engine        = "REDIS"
  passwords     = var.users[count.index].passwords

  tags = var.tags
}

# ElastiCache User Group (Redis 6.0+)
resource "aws_elasticache_user_group" "main" {
  count = var.create_user_group ? 1 : 0

  engine        = "REDIS"
  user_group_id = "${var.name_prefix}-user-group"
  user_ids      = concat(["default"], aws_elasticache_user.main[*].user_id)

  tags = var.tags

  depends_on = [aws_elasticache_user.main]
}
