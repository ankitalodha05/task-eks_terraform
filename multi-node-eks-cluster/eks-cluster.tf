locals {
  private_subnets = [
    aws_subnet.dev-pvt-1.id,
    aws_subnet.dev-pvt-2.id
  ]
}

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn

  #This tells EKS where to deploy the control plane networking-wise.
  vpc_config {
    subnet_ids              = local.private_subnets
    security_group_ids      = [aws_security_group.dev-sg.id]
    endpoint_private_access = true #allows to access the EKS cluster’s API within vpc
    endpoint_public_access  = true #allows access to the EKS API from outside the VPC, eg. kubectl.
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  #ensures terraform waits for the IAM role policy to attach, before creating the cluster.
}
