variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "internal" {
  description = "Whether the load balancer is internal or external"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the load balancer"
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle"
  type        = number
  default     = 60
}

variable "enable_http2" {
  description = "Indicates whether HTTP/2 is enabled"
  type        = bool
  default     = true
}

variable "ssl_certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "access_logs_enabled" {
  description = "Enable access logs for the load balancer"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket for access logs"
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "S3 prefix for access logs"
  type        = string
  default     = "alb-access-logs"
}

variable "target_groups" {
  description = "Map of target groups to create"
  type = map(object({
    port                = number
    protocol            = string
    priority            = number
    host_header         = optional(string)
    path_pattern        = optional(string)
    stickiness_enabled  = optional(bool, false)
    stickiness_duration = optional(number, 86400)
    health_check = object({
      enabled             = optional(bool, true)
      healthy_threshold   = optional(number, 2)
      interval            = optional(number, 30)
      matcher             = optional(string, "200")
      path                = optional(string, "/healthz")
      protocol            = optional(string, "HTTP")
      timeout             = optional(number, 5)
      unhealthy_threshold = optional(number, 2)
    })
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
