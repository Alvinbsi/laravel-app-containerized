variable "region" {
  default = "ap-south-1"
}
```

3. **`outputs.tf`**:
```hcl
output "eks_cluster_name" {
  value = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}