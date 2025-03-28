output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "kubeconfig_command" {
  value = "aws eks --region us-east-1 update-kubeconfig --name my-eks-cluster"
}
