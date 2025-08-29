# terraform/modules/monitoring/outputs.tf

output "monitoring_namespace" {
  description = "Name of the monitoring namespace"
  value       = var.namespace
}

output "deployment_script" {
  description = "Path to the monitoring deployment script"
  value       = local_file.deploy_monitoring.filename
}

output "cleanup_script" {
  description = "Path to the monitoring cleanup script"
  value       = local_file.cleanup_monitoring.filename
}

output "monitoring_config_file" {
  description = "Path to the monitoring configuration file"
  value       = local_file.monitoring_values.filename
}

output "prometheus_values_file" {
  description = "Path to the Prometheus Helm values file"
  value       = local_file.prometheus_values.filename
}

output "loki_values_file" {
  description = "Path to the Loki Helm values file"
  value       = var.loki_enabled ? local_file.loki_values[0].filename : null
}

output "promtail_values_file" {
  description = "Path to the Promtail Helm values file"
  value       = var.loki_enabled ? local_file.promtail_values[0].filename : null
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "monitoring_urls" {
  description = "URLs for accessing monitoring services (via port-forward)"
  value = {
    prometheus   = "kubectl port-forward -n ${var.namespace} svc/kube-prometheus-stack-prometheus 9090:9090"
    grafana      = "kubectl port-forward -n ${var.namespace} svc/kube-prometheus-stack-grafana 3000:80"
    alertmanager = "kubectl port-forward -n ${var.namespace} svc/kube-prometheus-stack-alertmanager 9093:9093"
    loki         = var.loki_enabled ? "kubectl port-forward -n ${var.namespace} svc/loki 3100:3100" : null
  }
}