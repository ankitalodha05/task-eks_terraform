# 📘 Guide: Create a Minimal AWS EKS Cluster with Terraform

---

## 🧠 Goal:
Create a minimal working **AWS EKS cluster** with a **single worker node** using **Terraform**.

---

## ✅ High-Level Requirements for EKS
To create an EKS cluster, we need:

1. **VPC and Subnets** – EKS needs networking to communicate
2. **EKS Cluster** – The managed control plane (Kubernetes master)
3. **IAM Role for EKS Cluster** – So EKS can create and manage AWS resources
4. **EKS Node Group (Worker Nodes)** – EC2 instances that run containers
5. **IAM Role for Node Group** – For EC2 nodes to interact with EKS and pull images from ECR

---

## 🧰 Prerequisites

| Tool        | Requirement                   |
|-------------|-------------------------------|
| ✅ Terraform | [Install Terraform](https://developer.hashicorp.com/terraform/downloads) |
| ✅ AWS CLI   | [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| ✅ AWS Credentials | Run `aws configure` to set access key, secret, and default region |
| ✅ kubectl   | [Install kubectl](https://kubernetes.io/docs/tasks/tools/) to interact with your EKS cluster |


## 🔍 Terraform Code Explained

### 🟡 1. Define Supported Subnets for Control Plane
```hcl
locals {
  eks_subnet_ids = [
    "subnet-0775ebb58d1935928", # us-east-1a
    "subnet-0394685e7d1d8f619"  # us-east-1b
  ]
}
```
✅ These subnets are in Availability Zones supported by EKS for creating the control plane.

### 🟡 2. IAM Role for EKS Cluster (Control Plane)
```hcl
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

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
```
✅ This IAM Role allows the EKS service to assume the role and manage the control plane. It is required because EKS, as a managed service, needs to create and control networking components (like ENIs), CloudWatch logs, and other AWS services on behalf of your cluster.

### 🟡 3. Attach EKS Cluster Policy to IAM Role
```hcl
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
```
✅ This policy allows the EKS control plane to interact with other AWS resources like EC2 and VPC.

### 🟡 4. Create the EKS Cluster
```hcl
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = local.eks_subnet_ids
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}
```
✅ This block provisions the EKS control plane using the specified IAM role and subnet configuration. The `vpc_config` field tells EKS where to place control plane network interfaces. The `depends_on` ensures that the necessary IAM role and policy attachment are fully created before attempting to create the cluster. This prevents race conditions during Terraform apply.

### 🟡 5. IAM Role for Worker Node Group
```hcl
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

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
✅ This IAM Role allows EC2 instances in the worker node group to assume permissions, join the cluster, communicate with the control plane, access networking resources, and pull container images from ECR.

### 🟡 6. Attach Policies to Worker Node Role
```hcl
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
```
✅ These policies let worker nodes:
- Join the EKS cluster
- Manage pod networking (CNI plugin)
- Pull container images from Amazon ECR

### 🟡 7. Create Managed Node Group
```hcl
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = local.eks_subnet_ids

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t2.micro"]
}
```
✅ Creates a managed node group that automatically handles the provisioning and lifecycle of EC2 instances. The scaling configuration defines the desired number of worker nodes (1 in this case), and the node group is tied to the EKS cluster using the `cluster_name`. This allows Kubernetes workloads (pods) to run on these nodes.
-----

## 🚀 How to Deploy

### 🟢 Step 1: Initialize Terraform
```bash
terraform init
```

---

### 🟢 Step 2: Preview the Plan
```bash
terraform plan
```

---

### 🟢 Step 3: Apply and Create EKS Cluster
```bash
terraform apply -auto-approved
```

---

### 🟢 Step 4: Update kubeconfig
```bash
aws eks --region us-east-1 update-kubeconfig --name my-eks-cluster
```

---

### 🟢 Step 5: Verify the Cluster
```bash
kubectl get nodes
```
✅ You should see **1 EC2 node** in the output.

