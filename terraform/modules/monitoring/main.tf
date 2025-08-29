# Create a local file with the monitoring configuration
resource "local_file" "monitoring_values" {
  content = yamlencode({
    namespace = var.namespace
    prometheus = {
      storageClass  = var.storage_class_name
      storageSize   = var.prometheus_storage_size
      retention     = var.prometheus_retention
      retentionSize = var.prometheus_retention_size
      resources = {
        requests = {
          cpu    = var.prometheus_cpu_request
          memory = var.prometheus_memory_request
        }
        limits = {
          cpu    = var.prometheus_cpu_limit
          memory = var.prometheus_memory_limit
        }
      }
    }
    grafana = {
      enabled      = var.grafana_enabled
      password     = var.grafana_admin_password
      persistence  = var.grafana_persistence_enabled
      storageSize  = var.grafana_storage_size
      storageClass = var.storage_class_name
      resources = {
        requests = {
          cpu    = var.grafana_cpu_request
          memory = var.grafana_memory_request
        }
        limits = {
          cpu    = var.grafana_cpu_limit
          memory = var.grafana_memory_limit
        }
      }
    }
    loki = {
      enabled = var.loki_enabled
    }
    alertmanager = {
      config       = var.alertmanager_config
      storageSize  = var.alertmanager_storage_size
      storageClass = var.storage_class_name
    }
    versions = {
      prometheus_operator_crds = var.prometheus_operator_crds_version
      kube_prometheus_stack    = var.kube_prometheus_stack_version
      loki                     = var.loki_version
      promtail                 = var.promtail_version
    }
  })
  filename = "${path.root}/monitoring-config.yaml"
}

# Create the monitoring deployment script
resource "local_file" "deploy_monitoring" {
  content = templatefile("${path.module}/templates/deploy-monitoring.sh", {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
    namespace    = var.namespace
  })
  filename        = "${path.root}/deploy-monitoring.sh"
  file_permission = "0755"
}

# Create the monitoring cleanup script
resource "local_file" "cleanup_monitoring" {
  content = templatefile("${path.module}/templates/cleanup-monitoring.sh", {
    namespace = var.namespace
  })
  filename        = "${path.root}/cleanup-monitoring.sh"
  file_permission = "0755"
}

# Create Helm values files
resource "local_file" "prometheus_values" {
  content = yamlencode({
    prometheus = {
      prometheusSpec = {
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = var.storage_class_name
              resources = {
                requests = {
                  storage = var.prometheus_storage_size
                }
              }
            }
          }
        }
        retention     = var.prometheus_retention
        retentionSize = var.prometheus_retention_size
        resources = {
          requests = {
            cpu    = var.prometheus_cpu_request
            memory = var.prometheus_memory_request
          }
          limits = {
            cpu    = var.prometheus_cpu_limit
            memory = var.prometheus_memory_limit
          }
        }
        serviceMonitorSelectorNilUsesHelmValues = false
        ruleSelectorNilUsesHelmValues           = false
      }
    }
    grafana = {
      enabled       = var.grafana_enabled
      adminPassword = var.grafana_admin_password
      persistence = {
        enabled          = var.grafana_persistence_enabled
        size             = var.grafana_storage_size
        storageClassName = var.storage_class_name
      }
      resources = {
        requests = {
          cpu    = var.grafana_cpu_request
          memory = var.grafana_memory_request
        }
        limits = {
          cpu    = var.grafana_cpu_limit
          memory = var.grafana_memory_limit
        }
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        storage = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = var.storage_class_name
              resources = {
                requests = {
                  storage = var.alertmanager_storage_size
                }
              }
            }
          }
        }
      }
      config = var.alertmanager_config
    }
  })
  filename = "${path.root}/prometheus-values.yaml"
}

resource "local_file" "loki_values" {
  count = var.loki_enabled ? 1 : 0

  content = yamlencode({
    loki = {
      auth_enabled = false
      commonConfig = {
        replication_factor = 1
      }
      storage = {
        type = "filesystem"
      }
    }
    deploymentMode = "SingleBinary"
    singleBinary = {
      replicas = 1
    }
    test = {
      enabled = false
    }
    monitoring = {
      selfMonitoring = {
        enabled = false
      }
      lokiCanary = {
        enabled = false
      }
    }
  })
  filename = "${path.root}/loki-values.yaml"
}

resource "local_file" "promtail_values" {
  count = var.loki_enabled ? 1 : 0

  content = yamlencode({
    config = {
      lokiAddress = "http://loki:3100/loki/api/v1/push"
      serverPort  = 3101
    }
  })
  filename = "${path.root}/promtail-values.yaml"
}