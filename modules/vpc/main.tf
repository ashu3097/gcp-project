# =============================================================================
# GCP VPC MODULE - main.tf
# =============================================================================
# This module creates a Virtual Private Cloud (VPC) in Google Cloud Platform
# with public and private subnets, a Cloud NAT for private subnet internet
# access, and firewall rules.
#
# WHAT IS A VPC?
# A VPC (Virtual Private Cloud) is your own isolated network inside GCP.
# Think of it as your private data center in the cloud. All your resources
# (VMs, databases, etc.) live inside a VPC.
#
# GCP VPC vs AWS VPC - KEY DIFFERENCE:
# In AWS, a VPC is regional. In GCP, a VPC is GLOBAL — it spans all regions.
# But subnets in GCP are regional (tied to a specific region like us-central1).
# =============================================================================


# -----------------------------------------------------------------------------
# 1. THE VPC NETWORK
# -----------------------------------------------------------------------------
# google_compute_network = The VPC itself (the big container for everything)
#
# Think of this as creating the "building" — subnets are the "rooms" inside it.
# -----------------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  # name: The name of your VPC as it appears in GCP Console.
  # We prefix it with the environment (dev/staging/prod) so you can tell
  # them apart easily.
  name = "${var.environment}-${var.vpc_name}"

  # project: Which GCP project this VPC belongs to.
  # A GCP "project" is like an AWS "account" — it's the top-level container
  # for billing and resource organization.
  project = var.project_id

  # auto_create_subnetworks: IMPORTANT — set this to FALSE.
  #
  # If true, GCP auto-creates one subnet in EVERY region (30+ subnets!).
  # That's called "auto mode" and it's messy for production use.
  #
  # We set false to use "custom mode" — we define exactly which subnets
  # we want, in which regions, with which IP ranges. Much cleaner.
  auto_create_subnetworks = false

  # routing_mode: Controls how routes are shared across regions.
  #
  # "REGIONAL" = Routes only apply within the same region.
  #              Cheaper, simpler, fine for single-region setups.
  #
  # "GLOBAL"   = Routes are shared across ALL regions.
  #              Needed if you have resources in multiple regions
  #              that need to talk to each other.
  #
  # We use REGIONAL by default — you can override this in tfvars.
  routing_mode = var.routing_mode

  # delete_default_routes_on_create: Should GCP delete the default
  # internet route (0.0.0.0/0) when creating this VPC?
  #
  # false = Keep the default route (most common — your public subnet
  #         needs this route to reach the internet).
  # true  = Delete it (use this for fully isolated/private networks).
  delete_default_routes_on_create = false

  # description: Just a human-readable note for your team.
  description = "VPC for ${var.environment} environment"
}


# -----------------------------------------------------------------------------
# 2. PUBLIC SUBNET
# -----------------------------------------------------------------------------
# google_compute_subnetwork = A subnet (a range of IP addresses within the VPC)
#
# PUBLIC subnet = Resources here CAN have public IP addresses and can be
# reached directly from the internet (if firewall rules allow it).
#
# Use for: Load balancers, bastion hosts, web servers that need direct
#          internet access.
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "public" {
  # name: Shows up in GCP Console. We include env + "public" for clarity.
  name = "${var.environment}-public-subnet"

  # project & region: Where this subnet lives.
  # Remember: VPC is global, but subnets are REGIONAL.
  project = var.project_id
  region  = var.region

  # network: Which VPC this subnet belongs to.
  # self_link is the full URL reference to the VPC we created above.
  network = google_compute_network.vpc.self_link

  # ip_cidr_range: The IP address range for this subnet.
  #
  # CIDR notation crash course:
  #   10.0.1.0/24 means:
  #     - Network: 10.0.1.x
  #     - /24 = 256 IP addresses (10.0.1.0 to 10.0.1.255)
  #     - GCP reserves 4 IPs, so you get 252 usable addresses.
  #
  #   Common sizes:
  #     /24 = 256 IPs   (small apps, dev environments)
  #     /20 = 4,096 IPs (medium workloads)
  #     /16 = 65,536 IPs (large production environments)
  #
  # IMPORTANT: Public and private subnets MUST NOT overlap!
  # Example: Public = 10.0.1.0/24, Private = 10.0.2.0/24 ✓
  #          Public = 10.0.1.0/24, Private = 10.0.1.0/24 ✗ (overlap!)
  ip_cidr_range = var.public_subnet_cidr

  # private_ip_google_access: Can VMs WITHOUT a public IP still reach
  # Google APIs (like Cloud Storage, BigQuery, etc.)?
  #
  # true  = Yes, even VMs without public IPs can call Google APIs.
  #         This is a GCP-specific feature — very useful!
  # false = No, they'd need a public IP or Cloud NAT to reach Google APIs.
  #
  # We enable it even on the public subnet because it's free and useful.
  private_ip_google_access = true

  # purpose: What this subnet is used for.
  # "PRIVATE" is the default for regular VM subnets (confusing name —
  # it does NOT mean the subnet is private; it just means "general use").
  # Other options: INTERNAL_HTTPS_LOAD_BALANCER, REGIONAL_MANAGED_PROXY, etc.
  purpose = "PRIVATE"

  # log_config: Enable VPC Flow Logs for this subnet.
  #
  # Flow Logs record metadata about network traffic (source, dest, bytes,
  # etc.) — incredibly useful for debugging and security monitoring.
  #
  # aggregation_interval: How often logs are batched.
  #   INTERVAL_5_SEC  = Most detailed (expensive)
  #   INTERVAL_10_MIN = Cheapest, less granular
  #
  # flow_sampling: What fraction of traffic to log.
  #   0.5 = Log 50% of flows (good balance of cost vs visibility)
  #   1.0 = Log everything (expensive but complete)
  #
  # metadata: What extra info to include in logs.
  #   INCLUDE_ALL_METADATA = Include VM names, regions, etc. (recommended)
  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_10_MIN"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }

  # secondary_ip_range: Extra IP ranges attached to this subnet.
  #
  # GKE (Google Kubernetes Engine) REQUIRES these for:
  #   - Pod IPs (every container gets its own IP)
  #   - Service IPs (internal load balancer IPs for Kubernetes services)
  #
  # If you're NOT using GKE, you can leave these empty in your tfvars.
  # If you ARE using GKE, you MUST define these or cluster creation fails.
  dynamic "secondary_ip_range" {
    for_each = var.public_subnet_secondary_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}


# -----------------------------------------------------------------------------
# 3. PRIVATE SUBNET
# -----------------------------------------------------------------------------
# PRIVATE subnet = Resources here do NOT get public IPs. They are hidden
# from the internet. They can still REACH the internet via Cloud NAT
# (defined below), but nobody can reach IN to them directly.
#
# Use for: Databases, application servers, internal microservices,
#          anything that shouldn't be exposed to the public internet.
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "private" {
  name    = "${var.environment}-private-subnet"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.self_link

  ip_cidr_range = var.private_subnet_cidr

  # This is CRITICAL for private subnets — it lets VMs without public IPs
  # still talk to Google Cloud APIs (Storage, BigQuery, Pub/Sub, etc.)
  # without going through the internet.
  private_ip_google_access = true

  purpose = "PRIVATE"

  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_10_MIN"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }

  dynamic "secondary_ip_range" {
    for_each = var.private_subnet_secondary_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}


# -----------------------------------------------------------------------------
# 4. CLOUD ROUTER
# -----------------------------------------------------------------------------
# google_compute_router = A virtual router that manages dynamic routing.
#
# WHY DO WE NEED THIS?
# Cloud NAT (next section) requires a Cloud Router to function.
# The router handles BGP (Border Gateway Protocol) sessions and
# advertises routes so traffic knows where to go.
#
# Think of it as the "traffic controller" for your private subnet's
# outbound internet access.
# -----------------------------------------------------------------------------
resource "google_compute_router" "router" {
  # Only create the router if Cloud NAT is enabled.
  count = var.enable_cloud_nat ? 1 : 0

  name    = "${var.environment}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.self_link

  # bgp: BGP configuration for the router.
  # asn = Autonomous System Number. For private use, pick any number
  #       in the range 64512–65534. This is just an identifier.
  bgp {
    asn = 64514
  }
}


# -----------------------------------------------------------------------------
# 5. CLOUD NAT (Network Address Translation)
# -----------------------------------------------------------------------------
# google_compute_router_nat = Allows VMs without public IPs to access
# the internet for outbound connections (e.g., downloading packages,
# calling external APIs).
#
# HOW IT WORKS:
# VM in private subnet → Cloud NAT translates its private IP to a
# public IP → Request goes to the internet → Response comes back
# through NAT → Delivered to the VM.
#
# The VM never gets a public IP. It's like using a VPN — the outside
# world sees the NAT's IP, not the VM's IP.
#
# GCP Cloud NAT vs AWS NAT Gateway:
# - GCP Cloud NAT is SOFTWARE-DEFINED (no actual "gateway" instance).
#   It's managed by Google and scales automatically.
# - AWS NAT Gateway is a managed appliance you pay per-hour for.
# - GCP Cloud NAT is generally cheaper and simpler.
# -----------------------------------------------------------------------------
resource "google_compute_router_nat" "nat" {
  count = var.enable_cloud_nat ? 1 : 0

  name    = "${var.environment}-nat"
  project = var.project_id
  region  = var.region
  router  = google_compute_router.router[0].name

  # nat_ip_allocate_option:
  #
  # "AUTO_ONLY" = GCP automatically assigns public IPs for NAT.
  #               Simplest option. GCP manages the IPs for you.
  #
  # "MANUAL_ONLY" = You provide your own static IPs.
  #                 Use this if you need predictable outbound IPs
  #                 (e.g., to whitelist your IP at an external service).
  nat_ip_allocate_option = "AUTO_ONLY"

  # source_subnetwork_ip_ranges_to_nat:
  #
  # "ALL_SUBNETWORKS_ALL_IP_RANGES" = NAT applies to ALL subnets (easy).
  # "LIST_OF_SUBNETWORKS"           = NAT applies only to specific subnets.
  #
  # We use LIST_OF_SUBNETWORKS so ONLY the private subnet uses NAT.
  # The public subnet doesn't need NAT because VMs there have public IPs.
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  # subnetwork: Which subnet(s) should use this NAT.
  subnetwork {
    name                    = google_compute_subnetwork.private.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  # log_config: NAT logging for troubleshooting.
  # "ERRORS_ONLY" = Only log when NAT fails (e.g., port exhaustion).
  # "ALL"         = Log everything (verbose, useful for debugging).
  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }

  # min_ports_per_vm: Minimum NAT ports allocated per VM.
  #
  # Each outbound connection uses one port. If a VM makes many simultaneous
  # connections (e.g., a web scraper), it needs more ports.
  # Default is 64. Increase for busy VMs.
  min_ports_per_vm = var.nat_min_ports_per_vm
}


# -----------------------------------------------------------------------------
# 6. FIREWALL RULES
# -----------------------------------------------------------------------------
# google_compute_firewall = Controls what traffic is allowed in/out of VMs.
#
# GCP FIREWALL vs AWS SECURITY GROUPS - KEY DIFFERENCES:
# - GCP firewalls are applied at the VPC level (not per-instance).
# - GCP uses "network tags" to target specific VMs.
# - GCP has an implicit "deny all ingress, allow all egress" default.
# - GCP firewall rules have priorities (lower number = higher priority).
#
# IMPORTANT: "allow" rules add exceptions to the default "deny all".
# -----------------------------------------------------------------------------

# --- Allow internal communication within the VPC ---
# This lets VMs in your VPC talk to each other freely.
# Without this, even VMs in the same subnet can't communicate!
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  # direction: INGRESS = incoming traffic, EGRESS = outgoing traffic.
  direction = "INGRESS"

  # priority: Lower number = evaluated first.
  # 1000 is the default. Use lower numbers for more important rules.
  # Range: 0 (highest) to 65535 (lowest).
  priority = 1000

  # allow: What protocols/ports to permit.
  # "icmp" = Ping (useful for troubleshooting connectivity).
  # "tcp"  = All TCP ports (web, SSH, databases, etc.).
  # "udp"  = All UDP ports (DNS, some streaming protocols).
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  # source_ranges: Which IPs can send traffic matching this rule.
  # We allow traffic from both our subnets — so public and private
  # subnet resources can communicate with each other.
  source_ranges = [
    var.public_subnet_cidr,
    var.private_subnet_cidr,
  ]
}

# --- Allow SSH access to public subnet VMs ---
# This lets you SSH into VMs tagged with "public" from allowed IPs.
resource "google_compute_firewall" "allow_ssh_public" {
  count = var.enable_ssh_firewall ? 1 : 0

  name    = "${var.environment}-allow-ssh-public"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    # Port 22 = SSH (Secure Shell) — the standard port for remote login.
    ports = ["22"]
  }

  # source_ranges: WHO can SSH in.
  #
  # ⚠️  NEVER use ["0.0.0.0/0"] in production! That means "anyone on
  # the entire internet can try to SSH into your VMs."
  #
  # Instead, restrict to:
  # - Your office IP: ["203.0.113.50/32"]
  # - A VPN range:    ["10.8.0.0/24"]
  # - Google IAP:     ["35.235.240.0/20"] (recommended — see below)
  #
  # 35.235.240.0/20 is Google's Identity-Aware Proxy (IAP) range.
  # IAP lets you SSH into VMs through Google's secure tunnel —
  # no public IP or VPN needed! It's the recommended way to access
  # GCP VMs. You authenticate with your Google account.
  source_ranges = var.ssh_allowed_cidrs

  # target_tags: Only VMs with this network tag get this rule.
  # When you create a VM, you assign tags like ["public", "web-server"].
  # This rule ONLY applies to VMs tagged "public".
  target_tags = ["public"]
}

# --- Allow HTTP/HTTPS to web-server tagged VMs ---
resource "google_compute_firewall" "allow_http_https" {
  count = var.enable_http_firewall ? 1 : 0

  name    = "${var.environment}-allow-http-https"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    # Port 80  = HTTP  (unencrypted web traffic)
    # Port 443 = HTTPS (encrypted web traffic — always prefer this!)
    ports = ["80", "443"]
  }

  # 0.0.0.0/0 = Allow from anywhere on the internet.
  # This is OK for web servers — they're MEANT to be public.
  # But you'd never do this for SSH or database ports.
  source_ranges = ["0.0.0.0/0"]

  target_tags = ["web-server"]
}