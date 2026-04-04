# =============================================================================
# DEV ENVIRONMENT — dev.tfvars
# =============================================================================
# Usage:
#   terraform plan  -var-file="environments/dev/dev.tfvars"
#   terraform apply -var-file="environments/dev/dev.tfvars"
#
# Philosophy: Minimal cost, easy debugging, relaxed security for development.
# =============================================================================

# --- REQUIRED: Change these to YOUR values ---
project_id = "kkgcplabs01-036"      # ← Replace with your GCP project ID
region     = "us-central1"               # ← Mumbai (closest to Bhopal)

# --- Environment ---
environment = "dev"
vpc_name    = "main-vpc"                 # Final name: "dev-main-vpc"

# --- Network Design ---
# Small subnets for dev — /24 = 252 usable IPs each (plenty for dev)
public_subnet_cidr  = "10.0.1.0/24"     # 10.0.1.0 → 10.0.1.255
private_subnet_cidr = "10.0.2.0/24"     # 10.0.2.0 → 10.0.2.255

# --- Routing ---
routing_mode = "REGIONAL"                # Single region is fine for dev

# --- Cloud NAT ---
enable_cloud_nat     = true              # Let private VMs reach the internet
nat_min_ports_per_vm = 64                # Default is fine for dev workloads

# --- Logging ---
enable_flow_logs = false                 # Save money — no flow logs in dev

# --- Firewall ---
enable_ssh_firewall  = true
enable_http_firewall = true

# SSH access — open for dev convenience (restrict in prod!)
ssh_allowed_cidrs = [
  "35.235.240.0/20",                    # Google IAP (secure SSH tunneling)
  "0.0.0.0/0",                          # Allow from anywhere (OK for dev only!)
]

# --- GKE Secondary Ranges (uncomment if using Kubernetes) ---
# public_subnet_secondary_ranges = []
# private_subnet_secondary_ranges = [
#   {
#     range_name    = "gke-pods"
#     ip_cidr_range = "10.10.0.0/16"
#   },
#   {
#     range_name    = "gke-services"
#     ip_cidr_range = "10.20.0.0/20"
#   },
# ]