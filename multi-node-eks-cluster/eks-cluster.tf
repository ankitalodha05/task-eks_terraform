locals {
  private_subnets = [
    aws_subnet.dev-pvt-1.id,
    aws_subnet.dev-pvt-2.id
  ]
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  #This tells EKS where and how to deploy the control plane networking-wise.
  vpc_config {
    subnet_ids              = local.private_subnets
    security_group_ids      = [aws_security_group.dev-sg.id]
    endpoint_private_access = true #This allows you to access the EKS cluster’s API within the VPC (private network).
    endpoint_public_access  = true #This allows access to the EKS API from outside the VPC, such as from your laptop using kubectl.
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
  #It ensures Terraform waits for the IAM role policy attachment (which grants the cluster permissions) to finish before creating the cluster.
}
