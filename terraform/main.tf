provider "aws" {
  region = "ap-south-1"
}

# Create the IAM role for the EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      }
    ]
  })
}

# Create the IAM role for the node group
resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      }
    ]
  })
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "alvin-eks-cluster"
  cluster_version = "1.27"

  # Use the created IAM roles
  cluster_iam_role_name = aws_iam_role.eks_cluster_role.name

  node_group_defaults = {
    desired_capacity = 2
    max_size         = 3
    min_size         = 1
    instance_type    = "t3.medium"
  }

  node_groups = {
    default = {
      node_role_arn = aws_iam_role.eks_node_group_role.arn
    }
  }
}
