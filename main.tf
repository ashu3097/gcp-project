

module "vpc" {
  source = "./modules/vpc"

  project_id          = var.project_id
  region              = var.region
  environment         = var.environment
  vpc_name            = var.vpc_name
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr

  routing_mode                     = var.routing_mode
  enable_cloud_nat                 = var.enable_cloud_nat
  enable_flow_logs                 = var.enable_flow_logs
  enable_ssh_firewall              = var.enable_ssh_firewall
  enable_http_firewall             = var.enable_http_firewall
  ssh_allowed_cidrs                = var.ssh_allowed_cidrs
  nat_min_ports_per_vm             = var.nat_min_ports_per_vm
  public_subnet_secondary_ranges   = var.public_subnet_secondary_ranges
  private_subnet_secondary_ranges  = var.private_subnet_secondary_ranges
}