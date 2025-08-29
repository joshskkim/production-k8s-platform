# terraform/modules/monitoring/outputs.tf

output "monitoring_namespace" {
  description = "Name of the monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_service_name" {
  description = "Name of the Prometheus service"
  value       = "kube-prometheus-stack-prometheus"
}

output "grafana_service_name" {
  description = "Name of the Grafana service"
  value       = "kube-prometheus-stack-grafana"
}

output "alertmanager_service_name" {
  description = "Name of the AlertManager service"
  value       = "kube-prometheus-stack-alertmanager"
}

output "prometheus_url" {
  description = "Internal URL for Prometheus"
  value       = "http://kube-prometheus-stack-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090"
}

output "grafana_url" {
  description = "Internal URL for Grafana"
  value       = "http://kube-prometheus-stack-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:80"
}

output "alertmanager_url" {
  description = "Internal URL for AlertManager"
  value       = "http://kube-prometheus-stack-alertmanager.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9093"
}

output "loki_url" {
  description = "Internal URL for Loki"
  value       = var.loki_enabled ? "http://loki.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:3100" : null
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}
