variable "name" {
  description = "Name for the forwarding rule and prefix for supporting resources"
  type        = string
}

variable "project" {
  description = "The project to deploy to, if not set the default provider project is used."
  default     = ""
}

variable "region" {
  description = "Region for cloud resources."
  default     = "us-central1"
}

variable "network" {
  description = "Name of the network to create resources in."
  default     = "default"
}

variable "subnetwork" {
  description = "Name of the subnetwork to create resources in."
  default     = "default"
}

variable "proxysubnetwork" {
  description = "Name of the PROXY subnetwork to create resources in."
  default     = "default"
}

variable "network_project" {
  description = "Name of the project for the network. Useful for shared VPC. Default is var.project."
  default     = ""
}

variable "backends" {
  description = "Map backend indices to list of backend maps."
  type = map(object({
    description                     = string
    protocol                        = string
    port                            = number
    port_name                       = string
    timeout_sec                     = number
    connection_draining_timeout_sec = number
    enable_cdn                      = bool
    session_affinity                = string
    affinity_cookie_ttl_sec         = number
    health_check = object({
      check_interval_sec  = number
      timeout_sec         = number
      healthy_threshold   = number
      unhealthy_threshold = number
      request_path        = string
      port                = number
      port_name           = string
      host                = string
      proxy_header        = string
      request             = string
      type                = string
      response            = string
    })
    log_config = object({
      enable      = bool
      sample_rate = number
    })
    groups = list(object({
      group                        = string
      balancing_mode               = string
      capacity_scaler              = number
      description                  = string
      max_connections              = number
      max_connections_per_instance = number
      max_connections_per_endpoint = number
      max_rate                     = number
      max_rate_per_instance        = number
      max_rate_per_endpoint        = number
      max_utilization              = number
    }))

  }))
}

variable "http_forward" {
  description = "Set to `false` to disable HTTP port 80 forward"
  type        = bool
  default     = true
}

variable "ssl" {
  description = "Set to `true` to enable SSL support, requires variable `ssl_certificates` - a list of self_link certs"
  type        = bool
  default     = false
}

variable "ssl_cert" {
  description = "Name of the SSL certificate in GCP"
  default     = null
}

variable "address" {
  description = "Private ip address for LB"
  default     = null
}