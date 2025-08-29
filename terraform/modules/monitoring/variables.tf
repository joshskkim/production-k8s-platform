variable "eks_cluster_endpoint" {
  type        = string
  description = "EKS cluster endpoint"
}

variable "eks_cluster_ca" {
  type        = string
  description = "EKS cluster CA certificate (base64)"
}

variable "eks_cluster_token" {
  type        = string
  description = "EKS cluster authentication token"
}

variable "namespace" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Helm chart versions
variable "prometheus_operator_crds_version" {
  description = "Version of prometheus-operator-crds Helm chart"
  type        = string
  default     = "7.0.0"
}

variable "kube_prometheus_stack_version" {
  description = "Version of kube-prometheus-stack Helm chart"
  type        = string
  default     = "55.0.0"
}

variable "loki_version" {
  description = "Version of Loki Helm chart"
  type        = string
  default     = "5.38.0"
}

variable "promtail_version" {
  description = "Version of Promtail Helm chart"
  type        = string
  default     = "6.15.3"
}

# Storage configuration
variable "storage_class_name" {
  description = "Storage class name for persistent volumes"
  type        = string
  default     = "gp2"
}

# Prometheus configuration
variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "50Gi"
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "30d"
}

variable "prometheus_retention_size" {
  description = "Prometheus data retention size"
  type        = string
  default     = "45GB"
}

variable "prometheus_cpu_request" {
  description = "CPU request for Prometheus"
  type        = string
  default     = "200m"
}

variable "prometheus_memory_request" {
  description = "Memory request for Prometheus"
  type        = string
  default     = "2Gi"
}

variable "prometheus_cpu_limit" {
  description = "CPU limit for Prometheus"
  type        = string
  default     = "1000m"
}

variable "prometheus_memory_limit" {
  description = "Memory limit for Prometheus"
  type        = string
  default     = "4Gi"
}

# Grafana configuration
variable "grafana_enabled" {
  description = "Enable Grafana deployment"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = "change-me-in-production"
  sensitive   = true
}

variable "grafana_persistence_enabled" {
  description = "Enable persistence for Grafana"
  type        = bool
  default     = true
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
  default     = "10Gi"
}

variable "grafana_cpu_request" {
  description = "CPU request for Grafana"
  type        = string
  default     = "100m"
}

variable "grafana_memory_request" {
  description = "Memory request for Grafana"
  type        = string
  default     = "128Mi"
}

variable "grafana_cpu_limit" {
  description = "CPU limit for Grafana"
  type        = string
  default     = "500m"
}

variable "grafana_memory_limit" {
  description = "Memory limit for Grafana"
  type        = string
  default     = "512Mi"
}

variable "grafana_dashboards" {
  description = "Grafana dashboards configuration"
  type        = map(any)
  default     = {}
}

# AlertManager configuration
variable "alertmanager_storage_size" {
  description = "Storage size for AlertManager"
  type        = string
  default     = "10Gi"
}

variable "alertmanager_config" {
  description = "AlertManager configuration"
  type        = any
  default = {
    global = {
      smtp_smarthost = "localhost:587"
      smtp_from      = "alertmanager@example.org"
    }
    route = {
      group_by        = ["alertname"]
      group_wait      = "10s"
      group_interval  = "10s"
      repeat_interval = "1h"
      receiver        = "web.hook"
    }
    receivers = [
      {
        name = "web.hook"
        webhook_configs = [
          {
            url = "http://127.0.0.1:5001/"
          }
        ]
      }
    ]
  }
}

# Loki configuration
variable "loki_enabled" {
  description = "Enable Loki deployment"
  type        = bool
  default     = true
}

variable "loki_storage_type" {
  description = "Loki storage type (filesystem or s3)"
  type        = string
  default     = "filesystem"
}

variable "loki_s3_bucket" {
  description = "S3 bucket for Loki storage"
  type        = string
  default     = ""
}

variable "loki_read_replicas" {
  description = "Number of Loki read replicas"
  type        = number
  default     = 1
}

variable "loki_write_replicas" {
  description = "Number of Loki write replicas"
  type        = number
  default     = 1
}

variable "loki_backend_replicas" {
  description = "Number of Loki backend replicas"
  type        = number
  default     = 1
}

# Service Monitors
variable "service_monitors" {
  description = "Service monitors to create"
  type = map(object({
    selector = map(string)
    endpoints = list(object({
      port     = string
      interval = optional(string, "30s")
      path     = optional(string, "/metrics")
    }))
    namespaces = list(string)
    labels     = optional(map(string), {})
  }))
  default = {}
}

# Prometheus Rules
variable "prometheus_rules" {
  description = "Prometheus rules to create"
  type = map(object({
    groups = list(object({
      name     = string
      interval = optional(string, "30s")
      rules = list(object({
        alert       = optional(string)
        expr        = string
        for         = optional(string, "2m")
        labels      = optional(map(string), {})
        annotations = optional(map(string), {})
      }))
    }))
  }))
  default = {}
}

# Additional scrape configurations
variable "additional_scrape_configs" {
  description = "Additional scrape configurations for Prometheus"
  type        = list(any)
  default     = []
}
