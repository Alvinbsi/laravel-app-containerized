provider "aws" {
  region = "ap-south-1"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "alvin-eks-cluster"
  cluster_version = "1.27"
  worker_groups = [
    {
      instance_type = "t3.medium"
      asg_desired_capacity = 2
      asg_min_size         = 1
      asg_max_size         = 2
    }
  ]
}
