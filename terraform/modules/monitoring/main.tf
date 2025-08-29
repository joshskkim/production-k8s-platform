# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  provider = kubernetes

  metadata {
    name = var.namespace
    labels = {
      name                                 = var.namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# Prometheus Operator CRDs
resource "helm_release" "prometheus_operator_crds" {
  name       = "prometheus-operator-crds"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-operator-crds"
  version    = var.prometheus_operator_crds_version
  namespace  = var.namespace

  depends_on = [kubernetes_namespace.monitoring]
}

# kube-prometheus-stack
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version
  namespace  = var.namespace

  # (all your set blocks here)
  values = [yamlencode({
    prometheus   = { prometheusSpec = { additionalScrapeConfigs = var.additional_scrape_configs } }
    grafana      = {}
    alertmanager = { config = var.alertmanager_config }
  })]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.prometheus_operator_crds
  ]
}

# Loki
resource "helm_release" "loki" {
  provider = helm
  count    = var.loki_enabled ? 1 : 0

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_version
  namespace  = var.namespace

  # (all your set blocks & values here)
  depends_on = [kubernetes_namespace.monitoring]
}

# Promtail
resource "helm_release" "promtail" {
  provider = helm
  count    = var.loki_enabled ? 1 : 0

  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = var.promtail_version
  namespace  = var.namespace

  set {
    name  = "config.lokiAddress"
    value = "http://loki:3100/loki/api/v1/push"
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.loki
  ]
}

# Service Monitors
resource "kubernetes_manifest" "service_monitors" {
  provider = kubernetes
  for_each = var.service_monitors

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = merge({ app = each.key }, each.value.labels)
    }
    spec = {
      selector          = { matchLabels = each.value.selector }
      endpoints         = each.value.endpoints
      namespaceSelector = { matchNames = each.value.namespaces }
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# Prometheus Rules
resource "kubernetes_manifest" "prometheus_rules" {
  provider = kubernetes
  for_each = var.prometheus_rules

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = { app = each.key, role = "alert-rules" }
    }
    spec = { groups = each.value.groups }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
