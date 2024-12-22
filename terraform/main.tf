provider "aws" {
  region = "ap-south-1"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "18.0.0" # Use a compatible version
  cluster_name    = "alvin-eks-cluster"
  cluster_version = "1.27"

  vpc_id     = "vpc-xxxxxxxx" # Replace with your VPC ID
  subnet_ids = ["subnet-xxxxxxx", "subnet-xxxxxxx"] # Replace with your Subnet IDs

  node_group_defaults = {
    ami_type      = "AL2_x86_64"
    instance_type = "t3.medium"
  }

  node_groups = {
    default = {
      desired_capacity = 2
      max_size         = 2
      min_size         = 1
    }
  }
}

output "eks_cluster_name" {
  value = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_arn" {
  value = module.eks.cluster_arn
}
