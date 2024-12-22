provider "aws" {
  region = "ap-south-1"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "18.0.0" # Specify a compatible version
  cluster_name    = "alvin-eks-cluster"
  cluster_version = "1.27"

  node_group_defaults = {
    ami_type = "AL2_x86_64"
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
