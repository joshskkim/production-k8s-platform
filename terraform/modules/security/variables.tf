variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

# EKS Configuration
variable "workstation_cidr_blocks" {
  description = "CIDR blocks for workstation access to EKS"
  type        = list(string)
  default     = []
}

variable "enable_ssh_access" {
  description = "Enable SSH access to worker nodes"
  type        = bool
  default     = false
}

variable "ssh_access_cidr_blocks" {
  description = "CIDR blocks for SSH access to nodes"
  type        = list(string)
  default     = []
}

# Database Configuration
variable "enable_rds_bastion_access" {
  description = "Enable bastion access to RDS"
  type        = bool
  default     = false
}

variable "enable_redis_bastion_access" {
  description = "Enable bastion access to Redis"
  type        = bool
  default     = false
}

variable "bastion_cidr_blocks" {
  description = "CIDR blocks for bastion host access to other resources"
  type        = list(string)
  default     = []
}

# Optional Security Groups
variable "enable_bastion_sg" {
  description = "Create bastion host security group"
  type        = bool
  default     = false
}

variable "bastion_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access bastion host"
  type        = list(string)
  default     = []
}

variable "enable_rdp_bastion" {
  description = "Enable RDP access for Windows bastion"
  type        = bool
  default     = false
}

variable "enable_vpc_endpoints_sg" {
  description = "Create VPC endpoints security group"
  type        = bool
  default     = false
}

variable "enable_lambda_sg" {
  description = "Create Lambda security group"
  type        = bool
  default     = false
}

variable "enable_efs_sg" {
  description = "Create EFS security group"
  type        = bool
  default     = false
}

variable "enable_monitoring_sg" {
  description = "Create monitoring security group"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
