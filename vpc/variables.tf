# --- Project & Region ---

variable "project_id" {
  description = <<-EOT
    Your GCP Project ID (NOT the project name or number).
    Find it: GCP Console → Top-left dropdown → look for the ID column.
    Example: "my-company-prod-123456"

    This is the billing and resource container for everything you create.
  EOT
  type = string
}

variable "region" {
  description = <<-EOT
    The GCP region where subnets will be created.
    A region is a geographic location with multiple data centers (zones).

    Common regions:
      asia-south1       = Mumbai, India
      us-central1       = Iowa, USA
      us-east1          = South Carolina, USA
      europe-west1      = Belgium
      asia-southeast1   = Singapore

    Choose the region closest to your users for lowest latency.
  EOT
  type = string
}

# --- VPC Configuration ---

variable "environment" {
  description = <<-EOT
    Environment name — used as a prefix for all resource names.
    Examples: "dev", "staging", "prod"

    This ensures resources from different environments don't clash.
    e.g., "dev-my-vpc" vs "prod-my-vpc"
  EOT
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_name" {
  description = <<-EOT
    Base name for the VPC. Will be prefixed with the environment.
    Final name = "{environment}-{vpc_name}"
    Example: vpc_name = "main-vpc" → "dev-main-vpc"
  EOT
  type    = string
  default = "main-vpc"
}

variable "routing_mode" {
  description = <<-EOT
    How routes are shared across regions in this VPC.

    "REGIONAL" = Routes only apply within one region. (Default)
    "GLOBAL"   = Routes apply across all regions.
  EOT
  type    = string
  default = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "Routing mode must be REGIONAL or GLOBAL."
  }
}

# --- Subnet CIDRs ---

variable "public_subnet_cidr" {
  description = <<-EOT
    IP address range for the PUBLIC subnet in CIDR notation.

    CIDR quick reference:
      /24 = 256 IPs  (e.g., 10.0.1.0/24 → 10.0.1.0 to 10.0.1.255)
      /20 = 4096 IPs
      /16 = 65536 IPs

    RULES:
      - Must be within RFC 1918 private ranges
      - Must NOT overlap with the private subnet CIDR
      - GCP reserves 4 IPs per subnet
  EOT
  type = string
}

variable "private_subnet_cidr" {
  description = <<-EOT
    IP address range for the PRIVATE subnet in CIDR notation.

    Typically larger than public subnet because most resources
    (databases, app servers, workers) should be private.
  EOT
  type = string
}

# --- Secondary IP Ranges (for GKE / Kubernetes) ---

variable "public_subnet_secondary_ranges" {
  description = "Secondary IP ranges for the public subnet. Required by GKE."
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = []
}

variable "private_subnet_secondary_ranges" {
  description = "Secondary IP ranges for the private subnet. Required by GKE."
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = []
}

# --- Feature Toggles ---

variable "enable_cloud_nat" {
  description = <<-EOT
    true  = Private subnet VMs can reach the internet without public IPs.
    false = Private subnet VMs are fully isolated from the internet.
  EOT
  type    = bool
  default = true
}

variable "enable_flow_logs" {
  description = <<-EOT
    true  = Enable VPC Flow Logs (recommended for staging/prod).
    false = Disable (fine for dev to save money).
  EOT
  type    = bool
  default = false
}

variable "enable_ssh_firewall" {
  description = "Create a firewall rule allowing SSH (port 22) to 'public' tagged VMs."
  type    = bool
  default = true
}

variable "enable_http_firewall" {
  description = "Create a firewall rule allowing HTTP/HTTPS to 'web-server' tagged VMs."
  type    = bool
  default = true
}

# --- Firewall Configuration ---

variable "ssh_allowed_cidrs" {
  description = <<-EOT
    CIDR ranges allowed to SSH in.
      ✅ ["35.235.240.0/20"]  → Google IAP only (RECOMMENDED)
      ❌ ["0.0.0.0/0"]        → NEVER in production!
  EOT
  type    = list(string)
  default = ["35.235.240.0/20"]
}

variable "nat_min_ports_per_vm" {
  description = <<-EOT
    Minimum NAT ports per VM.
    64 = Default. 256 = API-heavy servers. 2048 = Heavy workloads.
  EOT
  type    = number
  default = 64
}