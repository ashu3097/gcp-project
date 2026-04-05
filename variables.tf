variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_name" {
  type    = string
  default = "main-vpc"
}

variable "routing_mode" {
  type    = string
  default = "REGIONAL"
}

variable "public_subnet_cidr" {
  type = string
}

variable "private_subnet_cidr" {
  type = string
}

variable "enable_cloud_nat" {
  type    = bool
  default = true
}

variable "enable_flow_logs" {
  type    = bool
  default = false
}

variable "enable_ssh_firewall" {
  type    = bool
  default = true
}

variable "enable_http_firewall" {
  type    = bool
  default = true
}

variable "ssh_allowed_cidrs" {
  type    = list(string)
  default = ["35.235.240.0/20"]
}

variable "nat_min_ports_per_vm" {
  type    = number
  default = 64
}

variable "public_subnet_secondary_ranges" {
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = []
}

variable "private_subnet_secondary_ranges" {
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = []
}