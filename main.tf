module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr     = var.vpc_cidr
  subnet_count = var.subnet_count
}

module "iam" {
  source = "./modules/iam"
}

module "eks" {
  source = "./modules/eks"
  
  cluster_name        = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.subnet_ids
  cluster_role_arn   = module.iam.cluster_role_arn
  node_group_role_arn = module.iam.node_group_role_arn
  ssh_key_name       = var.ssh_key_name
}

module "karpenter" {
  source = "./modules/karpenter"

  cluster_name       = var.cluster_name
  cluster_endpoint   = module.eks.cluster_endpoint
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.subnet_ids
  eks_cluster_id    = module.eks.cluster_id
  cluster_version   = module.eks.cluster_version
}

# Node Template for Karpenter
resource "aws_eks_node_group" "karpenter" {
  cluster_name    = module.eks.cluster_id
  node_group_name = "karpenter-node-group"
  node_role_arn   = module.iam.node_group_role_arn
  subnet_ids      = module.vpc.subnet_ids

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  # Enable both AMD64 and ARM64 instances
  ami_type = "AL2_x86_64"  # Default AMI type
  
  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}