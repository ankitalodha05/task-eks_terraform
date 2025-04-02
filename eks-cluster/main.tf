# Define only supported subnets for EKS control plane
locals {
  eks_subnet_ids = [
    "subnet-0775ebb58d1935928", # us-east-1a
    "subnet-0394685e7d1d8f619"  # us-east-1b
  ]
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "cluster_role" {
  name = "cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# attaching cluster policy
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# cluster creation
resource "aws_eks_cluster" "cluster" {
  name     = "my-cluster"
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids = local.eks_subnet_ids
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# IAM role for worker node
resource "aws_iam_role" "node_role" {
  name = "single-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# attach permissions
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# worker node creation , single-ec2
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "node-group"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = local.eks_subnet_ids

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t2.micro"]
}