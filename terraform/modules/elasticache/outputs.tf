output "replication_group_id" {
  description = "ElastiCache replication group ID"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].id : null
}

output "cluster_id" {
  description = "ElastiCache cluster ID"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].id : null
}

output "primary_endpoint_address" {
  description = "Address of the primary endpoint"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : null
  sensitive   = true
}

output "reader_endpoint_address" {
  description = "Address of the reader endpoint"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].reader_endpoint_address : null
  sensitive   = true
}

output "configuration_endpoint_address" {
  description = "Address of the configuration endpoint (cluster mode)"
  value       = var.engine == "redis" && var.cluster_mode_enabled ? aws_elasticache_replication_group.redis[0].configuration_endpoint_address : null
  sensitive   = true
}

output "cluster_address" {
  description = "Memcached cluster address"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].cluster_address : null
  sensitive   = true
}

output "port" {
  description = "Port number"
  value       = var.port
}

output "auth_token" {
  description = "Auth token"
  value       = var.auth_token_enabled ? random_password.auth_token[0].result : null
  sensitive   = true
}

output "auth_token_secret_arn" {
  description = "Auth token secret ARN"
  value       = var.auth_token_enabled && var.create_auth_token_secret ? aws_secretsmanager_secret.auth_token[0].arn : null
}

output "subnet_group_name" {
  description = "ElastiCache subnet group name"
  value       = aws_elasticache_subnet_group.main.name
}

output "parameter_group_name" {
  description = "ElastiCache parameter group name"
  value       = aws_elasticache_parameter_group.main.name
}

output "user_group_id" {
  description = "ElastiCache user group ID"
  value       = var.create_user_group ? aws_elasticache_user_group.main[0].id : null
}
