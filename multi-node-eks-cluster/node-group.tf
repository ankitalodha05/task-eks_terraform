resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "custom-node-group"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = local.private_subnets


  scaling_config { #This block controls how many worker nodes to run
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.micro"]
}
