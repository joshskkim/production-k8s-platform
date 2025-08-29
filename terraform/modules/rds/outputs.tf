output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "RDS instance database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "RDS instance username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_password" {
  description = "RDS instance password"
  value       = var.manage_master_user_password ? null : random_password.master.result
  sensitive   = true
}

output "db_replica_endpoint" {
  description = "RDS read replica endpoint"
  value       = var.create_read_replica ? aws_db_instance.replica[0].endpoint : null
  sensitive   = true
}

output "db_subnet_group_id" {
  description = "Database subnet group ID"
  value       = aws_db_subnet_group.main.id
}

output "db_parameter_group_id" {
  description = "Database parameter group ID"
  value       = aws_db_parameter_group.main.id
}

output "db_secret_arn" {
  description = "Database secret ARN"
  value       = var.create_db_secret ? aws_secretsmanager_secret.database[0].arn : null
}

output "enhanced_monitoring_role_arn" {
  description = "Enhanced monitoring role ARN"
  value       = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = aws_kms_key.rds.key_id
}
