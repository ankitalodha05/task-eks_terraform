# AWS EKS Cluster Setup with Terraform

## Objective

Provision a basic AWS EKS cluster with one managed node group using Terraform.

---

## Prerequisites

| Tool         | Description |
|--------------|-------------|
| Terraform    | [Install Terraform](https://developer.hashicorp.com/terraform/downloads) |
| AWS CLI      | [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| AWS Credentials | Run `aws configure` to set access key, secret, and default region |
| kubectl      | [Install kubectl](https://kubernetes.io/docs/tasks/tools/) to interact with your EKS cluster |

---

## Terraform Code

### 1. Subnet Configuration

```hcl
locals {
  eks_subnet_ids = [
    "subnet-0775ebb58d1935928", # us-east-1a
    "subnet-0394685e7d1d8f619"  # us-east-1b
  ]
}
```

---

### 2. IAM Role for EKS Cluster (Control Plane)

```hcl
resource "aws_iam_role" "cluster_role" {
  name        = "cluster-role"
  description = "IAM role for EKS control plane"

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

  tags = {
    Name        = "cluster-role"
    Environment = "dev"
  }
}
```

---

### 3. Attach EKS Cluster Policy

```hcl
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
```

---

### 4. Create the EKS Cluster

```hcl
resource "aws_eks_cluster" "cluster" {
  name     = "my-cluster"
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids = local.eks_subnet_ids
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}
```

---

### 5. IAM Role for Worker Nodes

```hcl
resource "aws_iam_role" "node_role" {
  name = "node-role"

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
```

---

### 6. Attach Policies to Node Role

```hcl
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
```

---

### 7. Create Managed Node Group

```hcl
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
```

---

## Deployment Steps

### Step 1: Initialize Terraform

```bash
terraform init
```

---

### Step 2: Preview Resources

```bash
terraform plan
```

---

### Step 3: Apply Infrastructure

```bash
terraform apply -auto-approve
```

---

### Step 4: Configure kubectl

```bash
aws eks --region us-east-1 update-kubeconfig --name my-cluster
```

---

### Step 5: Verify the Cluster

```bash
kubectl get nodes
```

Expected output: one running EC2 node.

---

-![image](https://github.com/user-attachments/assets/3ec64683-5528-4c0d-9a50-d632422ccecd)
-![image](https://github.com/user-attachments/assets/b0c18425-3a39-49ab-83de-a68012c1dba5)
-![image](https://github.com/user-attachments/assets/49062a69-ff94-4b00-8062-82f11dc96944)
-![image](https://github.com/user-attachments/assets/9d8bdccb-8a6b-40ae-9d47-83377da02b3d)



