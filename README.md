# GCP VPC Terraform Module

A production-ready, reusable Terraform module for creating VPC networks on Google Cloud Platform with public and private subnets, Cloud NAT, and firewall rules — configured per environment using `.tfvars` files.

---

## What This Module Creates

For each environment (dev / staging / prod), this module provisions:

| Resource | Purpose |
|----------|---------|
| **VPC Network** | Your isolated cloud network (global in GCP) |
| **Public Subnet** | For internet-facing resources — load balancers, bastions, web servers |
| **Private Subnet** | For internal resources — databases, app servers, workers |
| **Cloud Router** | Required by Cloud NAT to manage routing |
| **Cloud NAT** | Lets private subnet VMs reach the internet without public IPs |
| **Firewall: Internal** | Allows all traffic between public and private subnets |
| **Firewall: SSH** | Allows SSH (port 22) to VMs tagged `public` from allowed CIDRs |
| **Firewall: HTTP/S** | Allows ports 80/443 to VMs tagged `web-server` from anywhere |

---

## Architecture

```
                      Internet
                         │
            ┌────────────┴────────────┐
            │      Firewall Rules     │
            │   (SSH, HTTP/S, ICMP)   │
            └────────────┬────────────┘
                         │
          ┌──────────────┴──────────────┐
          │     VPC Network (Global)    │
          │                             │
          │  ┌───────────┐ ┌──────────┐ │
          │  │  Public   │ │ Private  │ │
          │  │  Subnet   │ │ Subnet   │ │
          │  │ (regional)│ │(regional)│ │
          │  │           │ │          │ │
          │  │ • Bastion │ │ • App    │ │
          │  │ • LB      │ │ • DB     │ │
          │  │ • Web     │ │ • Worker │ │
          │  └───────────┘ └─────┬────┘ │
          │                      │      │
          │               ┌──────┴────┐ │
          │               │ Cloud NAT │ │
          │               │ + Router  │ │
          │               └──────┬────┘ │
          └──────────────────────┼──────┘
                                 │
                            Internet
                      (outbound only)
```

---

## Directory Structure

```
gcp-vpc-terraform/
│
├── main.tf                              # Root — calls the VPC module
├── variables.tf                         # Root — variable declarations
├── outputs.tf                           # Root — exposes module outputs
├── .gitignore                           # Git ignore rules for Terraform
│
├── modules/
│   └── vpc/
│       ├── main.tf                      # All GCP resources (VPC, subnets, NAT, firewalls)
│       ├── variables.tf                 # Input variable definitions with docs
│       └── outputs.tf                   # Output values for other modules
│
└── environments/
    ├── dev/
    │   └── dev.tfvars                   # Dev: small, cheap, relaxed security
    ├── staging/
    │   └── staging.tfvars               # Staging: mirrors prod at smaller scale
    └── prod/
        └── prod.tfvars                  # Prod: large, locked down, full logging
```

---

## Prerequisites

### 1. Install Terraform (>= 1.5.0)

```bash
# macOS
brew install terraform

# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify
terraform --version
```

### 2. Install Google Cloud CLI

```bash
# Follow: https://cloud.google.com/sdk/docs/install
# Then authenticate:
gcloud auth application-default login
```

### 3. Enable Required GCP APIs

```bash
gcloud services enable compute.googleapis.com --project=YOUR_PROJECT_ID
```

### 4. Update Your Project ID

Edit the `.tfvars` file for your target environment:

```bash
# In environments/dev/dev.tfvars, change:
project_id = "your-gcp-project-id"    # ← Replace with your actual project ID
```

---

## Quick Start

```bash
# 1. Clone the repo
git clone <your-repo-url>
cd gcp-vpc-terraform

# 2. Initialize Terraform (downloads GCP provider)
terraform init

# 3. Preview what will be created (dry run — no changes made)
terraform plan -var-file="environments/dev/dev.tfvars"

# 4. Create the infrastructure (type "yes" to confirm)
terraform apply -var-file="environments/dev/dev.tfvars"

# 5. See what was created
terraform output
```

---

## Deploying Per Environment

Each environment has its own `.tfvars` file with different settings:

```bash
# Dev — small subnets, no flow logs, relaxed SSH
terraform apply -var-file="environments/dev/dev.tfvars"

# Staging — medium subnets, flow logs ON, IAP-only SSH
terraform apply -var-file="environments/staging/staging.tfvars"

# Production — large subnets, everything locked down
terraform apply -var-file="environments/prod/prod.tfvars"
```

### Destroying Resources

```bash
# Remove all resources for an environment
terraform destroy -var-file="environments/dev/dev.tfvars"
```

---

## IP Address Plan

Each environment uses a separate IP block to avoid conflicts if you ever peer VPCs together:

| Environment | Public Subnet  | Private Subnet  | Usable IPs (Public) | Usable IPs (Private) | Routing  |
|-------------|----------------|-----------------|----------------------|----------------------|----------|
| dev         | `10.0.1.0/24`  | `10.0.2.0/24`   | 252                  | 252                  | REGIONAL |
| staging     | `10.1.0.0/20`  | `10.1.16.0/20`  | 4,092                | 4,092                | REGIONAL |
| prod        | `10.2.0.0/20`  | `10.2.16.0/16`  | 4,092                | 65,532               | GLOBAL   |

---

## Key Configuration Differences by Environment

| Setting              | Dev          | Staging       | Prod            |
|----------------------|-------------|---------------|-----------------|
| Flow Logs            | OFF (save $) | ON            | ON              |
| SSH Access           | Open + IAP   | IAP only      | IAP only        |
| NAT Ports/VM         | 64           | 128           | 256             |
| Routing Mode         | REGIONAL     | REGIONAL      | GLOBAL          |
| Subnet Size          | /24 (small)  | /20 (medium)  | /16-/20 (large) |

---

## GKE (Kubernetes) Support

If you plan to use Google Kubernetes Engine, uncomment the secondary IP ranges in your `.tfvars`:

```hcl
private_subnet_secondary_ranges = [
  {
    range_name    = "gke-pods"
    ip_cidr_range = "10.10.0.0/16"       # 65K pod IPs
  },
  {
    range_name    = "gke-services"
    ip_cidr_range = "10.20.0.0/20"       # 4K service IPs
  },
]
```

---

## Remote State (Team Usage)

For team collaboration, store Terraform state in a GCS bucket instead of locally. Uncomment the backend block in `main.tf`:

```hcl
# 1. First, create the bucket manually (one time):
#    gsutil mb -l asia-south1 gs://my-company-terraform-state

# 2. Then uncomment in main.tf:
backend "gcs" {
  bucket = "my-company-terraform-state"
  prefix = "vpc"
}

# 3. Re-initialize:
#    terraform init -migrate-state
```

---

## Useful Commands

```bash
# Format all .tf files consistently
terraform fmt -recursive

# Validate configuration syntax
terraform validate

# Show current state
terraform show

# List all resources Terraform is managing
terraform state list

# See a specific resource's details
terraform state show module.vpc.google_compute_network.vpc
```

---

## Connecting to VMs After Deployment

### Public Subnet VM (via IAP — recommended)

```bash
gcloud compute ssh VM_NAME \
  --zone=asia-south1-a \
  --tunnel-through-iap
```

### Private Subnet VM (via bastion or IAP)

```bash
# Option 1: IAP tunnel (no bastion needed!)
gcloud compute ssh PRIVATE_VM_NAME \
  --zone=asia-south1-a \
  --tunnel-through-iap \
  --internal-ip

# Option 2: SSH through a bastion in the public subnet
gcloud compute ssh BASTION_NAME --zone=asia-south1-a \
  -- -A  # Forward SSH agent
# Then from the bastion:
ssh PRIVATE_VM_INTERNAL_IP
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `Error 403: Compute API not enabled` | Compute Engine API is off | `gcloud services enable compute.googleapis.com` |
| `Error: Quota exceeded` | Not enough quota for the region | Request quota increase in GCP Console |
| `Error: subnet CIDR overlap` | Two subnets have overlapping IP ranges | Change one subnet's CIDR in `.tfvars` |
| NAT port exhaustion errors | VMs making too many outbound connections | Increase `nat_min_ports_per_vm` in `.tfvars` |
| Can't SSH into VM | Firewall rule missing or wrong tags | Ensure VM has `public` tag, check `ssh_allowed_cidrs` |
| Private VM can't reach internet | Cloud NAT not enabled or misconfigured | Set `enable_cloud_nat = true` |

---

## Contributing

1. Create a feature branch: `git checkout -b feature/my-change`
2. Make changes and test: `terraform plan -var-file="environments/dev/dev.tfvars"`
3. Format code: `terraform fmt -recursive`
4. Validate: `terraform validate`
5. Open a pull request

---

## License

MIT