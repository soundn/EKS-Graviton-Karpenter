output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "subnet_ids" {
  value = module.vpc.subnet_ids
}