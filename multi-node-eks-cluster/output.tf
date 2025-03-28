output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.eks_cluster.name}"
}
