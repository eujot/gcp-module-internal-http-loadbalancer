# Internal HTTP load balancer with a managed instance group backend

data "google_compute_network" "ilb_network" {
  name    = var.network
  project = var.network_project == "" ? var.project : var.network_project
}

data "google_compute_subnetwork" "proxy_subnet" {
  name    = var.proxysubnetwork
  project = var.network_project == "" ? var.project : var.network_project
  region  = var.region
}

data "google_compute_subnetwork" "ilb_subnet" {
  name    = var.subnetwork
  project = var.network_project == "" ? var.project : var.network_project
  region  = var.region
}

data "google_compute_region_ssl_certificate" "ssl_cert" {
  provider = google-beta
  name = var.ssl_cert
}

# Reserved internal address
resource "google_compute_address" "ilbip" {
  provider = google-beta
  name       = "${var.name}-ip"
  subnetwork = data.google_compute_subnetwork.ilb_subnet.self_link
  address_type = "INTERNAL"
  address      = var.address
  purpose      = "SHARED_LOADBALANCER_VIP"
}

# HTTP forwarding rule
resource "google_compute_forwarding_rule" "http" {
  provider = google-beta
  name                  = var.name
  region                = var.region
  depends_on            = [data.google_compute_subnetwork.proxy_subnet]
  ip_protocol           = "TCP"
  ip_address            = google_compute_address.ilbip.id
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.default.self_link
  network               = data.google_compute_network.ilb_network.self_link
  subnetwork            = data.google_compute_subnetwork.ilb_subnet.self_link
  network_tier          = "PREMIUM"
}

# HTTPS forwarding rule
resource "google_compute_forwarding_rule" "https" {
  provider = google-beta
  count      = var.ssl ? 1 : 0
  name                  = "${var.name}-https"
  region                = var.region
  depends_on            = [data.google_compute_subnetwork.proxy_subnet]
  ip_protocol           = "TCP"
  ip_address            = google_compute_address.ilbip.id
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.default[0].self_link
  network               = data.google_compute_network.ilb_network.self_link
  subnetwork            = data.google_compute_subnetwork.ilb_subnet.self_link
  network_tier          = "PREMIUM"
}

# HTTP target proxy
resource "google_compute_region_target_http_proxy" "default" {
  provider = google-beta
  name     = "${var.name}-http-proxy"
  url_map  = google_compute_region_url_map.default.self_link
}

# HTTPS proxy when ssl is true
resource "google_compute_region_target_https_proxy" "default" {
  provider = google-beta
  count   = var.ssl ? 1 : 0
  name    = "${var.name}-https-proxy"
  url_map  = google_compute_region_url_map.default.self_link

  ssl_certificates = [data.google_compute_region_ssl_certificate.ssl_cert.self_link]
}

# URL map
resource "google_compute_region_url_map" "default" {
  provider        = google-beta
  name            = var.name
  region          = var.region
  default_service = google_compute_region_backend_service.default[keys(var.backends)[0]].self_link

}

# backend service
resource "google_compute_region_backend_service" "default" {
  provider        = google-beta
  for_each = var.backends

  name                  = "${var.name}-backend-${each.key}"
  region                = var.region
  port_name             = each.value.port_name
  protocol              = each.value.protocol
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = 10
  health_checks         = [each.value.health_check["type"] == "tcp" ? module.lb_health_check.tcp_self_link[0] : module.lb_health_check.http_self_link[0]]

  dynamic "backend" {
    for_each = toset(each.value["groups"])
    content {
      balancing_mode               = lookup(backend.value, "balancing_mode")
      capacity_scaler              = lookup(backend.value, "capacity_scaler")
      description                  = lookup(backend.value, "description")
      group                        = lookup(backend.value, "group")
      max_connections              = lookup(backend.value, "max_connections")
      max_connections_per_instance = lookup(backend.value, "max_connections_per_instance")
      max_connections_per_endpoint = lookup(backend.value, "max_connections_per_endpoint")
      max_rate                     = lookup(backend.value, "max_rate")
      max_rate_per_instance        = lookup(backend.value, "max_rate_per_instance")
      max_rate_per_endpoint        = lookup(backend.value, "max_rate_per_endpoint")
      max_utilization              = lookup(backend.value, "max_utilization")
    }
  }
}

module "lb_health_check" {
  source = "../base/terraform_base_compute_health_check"

  name         = var.name
  project      = var.project
  health_check = var.backends["default"].health_check
}
