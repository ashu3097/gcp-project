output "vpc_id"                { value = google_compute_network.vpc.id }
output "vpc_name"              { value = google_compute_network.vpc.name }
output "vpc_self_link"         { value = google_compute_network.vpc.self_link }
output "public_subnet_id"     { value = google_compute_subnetwork.public.id }
output "public_subnet_name"   { value = google_compute_subnetwork.public.name }
output "public_subnet_self_link" { value = google_compute_subnetwork.public.self_link }
output "public_subnet_cidr"   { value = google_compute_subnetwork.public.ip_cidr_range }
output "private_subnet_id"    { value = google_compute_subnetwork.private.id }
output "private_subnet_name"  { value = google_compute_subnetwork.private.name }
output "private_subnet_self_link" { value = google_compute_subnetwork.private.self_link }
output "private_subnet_cidr"  { value = google_compute_subnetwork.private.ip_cidr_range }
output "router_name" {
  value = var.enable_cloud_nat ? google_compute_router.router[0].name : ""
}
output "nat_name" {
  value = var.enable_cloud_nat ? google_compute_router_nat.nat[0].name : ""
}